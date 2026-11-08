import json, os, secrets, time
from collections import defaultdict, deque
from datetime import datetime, timedelta
from typing import List, Literal, Optional
import joblib, numpy as np, pandas as pd
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field
from sklearn.linear_model import LogisticRegression
from features import FEATURES, SLOTS, dose_features, slot_of

HERE = os.path.dirname(os.path.abspath(__file__))
bundle = joblib.load(os.path.join(HERE, "model.joblib"))
pipeline, meta = bundle["pipeline"], bundle["meta"]
metrics = json.load(open(os.path.join(HERE, "model_metrics.json")))
# ───────────────────────── security settings (environment variables) ─────────────────────────
API_KEY = os.environ.get("API_KEY", "")                       # shared secret (legacy / server-to-server)
AUTH_MODE = os.environ.get("AUTH_MODE", "key").lower()        # key | firebase | either
FIREBASE_PROJECT_ID = os.environ.get("FIREBASE_PROJECT_ID", "")
ON_CLOUD_RUN = bool(os.environ.get("K_SERVICE"))              # set automatically by Cloud Run
ENABLE_DOCS = os.environ.get("ENABLE_DOCS", "0" if ON_CLOUD_RUN else "1") == "1"   # /docs hidden on Cloud Run
RATE_LIMIT_PER_MIN = int(os.environ.get("RATE_LIMIT_PER_MIN", "60"))
if AUTH_MODE not in ("key", "firebase", "either"):
    raise RuntimeError("AUTH_MODE must be key, firebase or either")
if ON_CLOUD_RUN and AUTH_MODE == "key" and not API_KEY:
    raise RuntimeError("Refusing to start on Cloud Run with no API_KEY (the API would be open to the internet)")
if AUTH_MODE in ("firebase", "either") and not FIREBASE_PROJECT_ID:
    raise RuntimeError("FIREBASE_PROJECT_ID is required when AUTH_MODE is firebase or either")
# Cloud Run serves LOGISTIC REGRESSION only - refuse to start with any other model type.
clf = pipeline.named_steps["clf"]
if not isinstance(clf, LogisticRegression):          # Cloud Run serves LOGISTIC REGRESSION only
    raise RuntimeError("model.joblib is not a LogisticRegression model")
assert list(meta["features"]) == list(FEATURES), "features.py changed since the model was trained - retrain"
COEF = clf.coef_[0]
EPOCH = datetime(1970, 1, 1)
PLATT_A, PLATT_B = meta["platt_a"], meta["platt_b"]

app = FastAPI(title="MedGuardian Risk API", version="3.1",
              docs_url="/docs" if ENABLE_DOCS else None, redoc_url=None,
              openapi_url="/openapi.json" if ENABLE_DOCS else None)


# ───────────────────────── request / response ─────────────────────────
class Patient(BaseModel):
    age: int = Field(72, ge=0, le=120)
    num_conditions: int = Field(0, ge=0, le=30)
    medication_count: int = Field(1, ge=0, le=50)
    avg_heart_rate: float = Field(76, ge=0, le=300)
    avg_oxygen_pct: float = Field(97, ge=0, le=100)
    daily_steps: float = Field(3000, ge=0, le=100000)
    fall_events_30d: int = Field(0, ge=0, le=100)
    symptom_count_14d: int = Field(0, ge=0, le=200)
    avg_symptom_severity: float = Field(0, ge=0, le=5)


class HistoryDose(BaseModel):
    medication_id: str = Field(..., min_length=1, max_length=64)
    medication_name: str = Field("", max_length=80)
    scheduled_at: datetime                      # the patient's LOCAL time, e.g. 2026-11-01T08:00:00
    status: Literal["taken", "missed"]
    delay_min: float = Field(0, ge=0, le=1440)  # minutes late when taken


class UpcomingDose(BaseModel):
    medication_id: str = Field(..., min_length=1, max_length=64)
    medication_name: str = Field("", max_length=80)
    scheduled_at: datetime


class PredictIn(BaseModel):
    patient: Patient = Patient()
    history: List[HistoryDose] = Field(default_factory=list, max_length=3000)
    upcoming: List[UpcomingDose] = Field(default_factory=list, max_length=60)
    now: Optional[datetime] = None              # patient's local time (defaults to the newest history item)


def to_hours(d: datetime) -> float:
    return (d.replace(tzinfo=None) - EPOCH).total_seconds() / 3600.0


def level_of(p: float) -> str:
    return "low" if p < 0.34 else "moderate" if p < 0.67 else "high"


def calibrated(raw: float) -> float:
    raw = min(max(raw, 1e-6), 1 - 1e-6)
    z = np.log(raw / (1 - raw))
    return float(1 / (1 + np.exp(-(PLATT_A * z + PLATT_B))))


# ───────────────────────── explanations ─────────────────────────
def explain(f: dict, x_scaled: np.ndarray, med_name: str, slot: int, p: float) -> List[str]:
    """Top reasons = (standardised feature value x model weight). Sentences are fixed templates."""
    contrib = {k: float(c * v) for k, c, v in zip(FEATURES, COEF, x_scaled)}
    sl = SLOTS[slot]
    med = med_name or "this medicine"
    T = {
        "slot_miss_rate": f"{sl.capitalize()} doses are missed {f['slot_miss_rate']*100:.0f}% of the time",
        "slot_gap": f"You miss {sl} doses more than your other doses",
        "med_miss_rate": f"{med} is missed {f['med_miss_rate']*100:.0f}% of the time",
        "med_gap": f"{med} is missed more often than your other medicines",
        "med_slot_miss_rate": f"{med} at this time of day is often missed",
        "miss_rate_7d": f"{f['miss_rate_7d']*100:.0f}% of doses missed in the last 7 days",
        "miss_rate_14d": f"{f['miss_rate_14d']*100:.0f}% of doses missed in the last 14 days",
        "miss_rate_30d": f"{f['miss_rate_30d']*100:.0f}% of doses missed in the last 30 days",
        "missed_streak": f"{int(f['missed_streak'])} missed dose(s) in a row just before this one",
        "prev_same_dose_missed": f"The last {med} at this time was missed",
        "weekday_miss_rate": "Doses on this day of the week are often missed",
        "is_weekend": "Weekend doses are missed more often",
        "avg_delay_min_14d": f"Doses are taken about {f['avg_delay_min_14d']:.0f} min late on average",
        "miss_x_delay": "Doses are both missed and taken late",
        "age": f"Age {int(f['age'])} adds some risk",
        "fall_events_30d": "A recent fall adds risk",
        "symptom_count_14d": "Recent symptoms add risk",
        "avg_symptom_severity": "Recent symptoms were fairly severe",
        "avg_oxygen_pct": f"Low oxygen average ({f['avg_oxygen_pct']:.0f}%) adds risk",
        "daily_steps": "Low daily activity adds risk",
        "medication_count": f"Taking {int(f['medication_count'])} medicines adds complexity",
        "num_conditions": "Several health conditions add risk",
        "never_missed": None, "hour": None, "hours_since_last_miss": None, "n_history_30d": None, "doses_per_day_7d": None,
        "slot_morning": "Morning doses are the hardest to remember" if slot == 0 else None,
        "slot_night": "Bedtime doses are easy to forget" if slot == 3 else None,
        "slot_midday": None, "slot_evening": None,
    }
    # a reason is only shown when the feature is genuinely in the risky range AND above this model's typical value
    G = {"slot_miss_rate": f["slot_miss_rate"] >= 0.25, "slot_gap": f["slot_gap"] >= 0.10,
         "med_miss_rate": f["med_miss_rate"] >= 0.25, "med_gap": f["med_gap"] >= 0.10,
         "med_slot_miss_rate": f["med_slot_miss_rate"] >= 0.25, "miss_rate_7d": f["miss_rate_7d"] >= 0.20,
         "miss_rate_14d": f["miss_rate_14d"] >= 0.20, "miss_rate_30d": f["miss_rate_30d"] >= 0.20,
         "missed_streak": f["missed_streak"] >= 1, "prev_same_dose_missed": f["prev_same_dose_missed"] >= 0.5,
         "weekday_miss_rate": f["weekday_miss_rate"] >= 0.30, "is_weekend": f["is_weekend"] >= 1,
         "avg_delay_min_14d": f["avg_delay_min_14d"] >= 20, "miss_x_delay": f["miss_x_delay"] >= 0.10,
         "age": f["age"] >= 80, "fall_events_30d": f["fall_events_30d"] >= 1, "symptom_count_14d": f["symptom_count_14d"] >= 3,
         "avg_symptom_severity": f["avg_symptom_severity"] >= 3, "avg_oxygen_pct": f["avg_oxygen_pct"] <= 94,
         "daily_steps": f["daily_steps"] <= 2000, "medication_count": f["medication_count"] >= 4,
         "num_conditions": f["num_conditions"] >= 3, "slot_morning": slot == 0, "slot_night": slot == 3}
    if p >= 0.34:
        ranked = sorted(((v, k) for k, v in contrib.items() if v > 0.15 and T.get(k) and G.get(k) and x_scaled[FEATURES.index(k)] > 0), reverse=True)
        out = []
        for _, k in ranked:
            if T[k] not in out:
                out.append(T[k])
            if len(out) == 3:
                break
        if not out:
            out = ["Several small factors add up"]
    else:  # low risk: say what is working in the user's favour
        P = {"slot_miss_rate": (f["slot_miss_rate"] <= 0.15, f"{sl.capitalize()} doses are usually taken"),
             "med_miss_rate": (f["med_miss_rate"] <= 0.15, f"{med} is rarely missed"),
             "med_slot_miss_rate": (f["med_slot_miss_rate"] <= 0.15, f"{med} at this time of day is rarely missed"),
             "miss_rate_14d": (f["miss_rate_14d"] <= 0.10, "Very few doses missed in the last 14 days"),
             "prev_same_dose_missed": (f["prev_same_dose_missed"] < 0.5, "The last dose at this time was taken")}
        good = sorted(((contrib[k], P[k][1]) for k in P if P[k][0] and contrib[k] < -0.05))
        out = [t for _, t in good[:2]] or ["Adherence has been steady — keep it up"]
    if f["n_history_30d"] < 10:
        out.append("Not much history yet — the estimate will sharpen as more doses are recorded")
    return out


# ───────────────────────── behaviour insights (plain statistics of the user's own history) ─────────────────────────
def insights_from(hist: List[HistoryDose], now: datetime) -> List[dict]:
    out: List[dict] = []
    if len(hist) < 8:
        return out
    cutoff = now - timedelta(days=30)
    rows = [h for h in hist if h.scheduled_at.replace(tzinfo=None) >= cutoff] or hist
    miss = np.array([h.status == "missed" for h in rows], dtype=float)
    overall = float(miss.mean())
    slots = np.array([slot_of(h.scheduled_at.hour) for h in rows])
    for s in range(4):
        m = slots == s
        if m.sum() >= 6 and miss[m].mean() >= max(overall + 0.15, 0.25):
            out.append({"kind": "time_of_day", "title": f"You often miss {SLOTS[s]} doses",
                        "detail": f"{miss[m].mean()*100:.0f}% of {SLOTS[s]} doses were missed, against {overall*100:.0f}% overall."})
    names = {}
    for h in rows:
        names.setdefault(h.medication_id, h.medication_name or h.medication_id)
    for mid, nm in names.items():
        m = np.array([h.medication_id == mid for h in rows])
        if m.sum() >= 5 and miss[m].mean() >= max(overall + 0.15, 0.25) and len(names) > 1:
            out.append({"kind": "medicine", "title": f"{nm} is the one you forget most",
                        "detail": f"{miss[m].mean()*100:.0f}% of {nm} doses were missed, against {overall*100:.0f}% overall."})
    wk = np.array([h.scheduled_at.weekday() >= 5 for h in rows])
    if wk.sum() >= 6 and (~wk).sum() >= 6 and miss[wk].mean() - miss[~wk].mean() >= 0.15:
        out.append({"kind": "weekend", "title": "Weekends are harder",
                    "detail": f"{miss[wk].mean()*100:.0f}% missed at weekends against {miss[~wk].mean()*100:.0f}% on weekdays."})
    recent = [h for h in rows if h.scheduled_at.replace(tzinfo=None) >= now - timedelta(days=7)]
    prev = [h for h in rows if now - timedelta(days=14) <= h.scheduled_at.replace(tzinfo=None) < now - timedelta(days=7)]
    if len(recent) >= 5 and len(prev) >= 5:
        r, p = np.mean([h.status == "missed" for h in recent]), np.mean([h.status == "missed" for h in prev])
        if r - p >= 0.15:
            out.append({"kind": "trend", "title": "Missing more doses than last week", "detail": f"{r*100:.0f}% missed this week against {p*100:.0f}% the week before."})
        elif p - r >= 0.15:
            out.append({"kind": "trend", "title": "Doing better than last week", "detail": f"{r*100:.0f}% missed this week against {p*100:.0f}% the week before."})
    late = [h.delay_min for h in rows if h.status == "taken"]
    if len(late) >= 6 and np.mean(late) >= 30:
        out.append({"kind": "late", "title": "Doses are often taken late", "detail": f"On average {np.mean(late):.0f} minutes after the scheduled time."})
    if not out and overall <= 0.10:
        out.append({"kind": "steady", "title": "Steady routine", "detail": f"Only {overall*100:.0f}% of doses missed in the last 30 days."})
    return out


def fallback_upcoming(hist: List[HistoryDose], now: datetime) -> List[UpcomingDose]:
    """No pending doses sent: score tomorrow's usual doses (same medicine + hour as the last 7 days)."""
    seen, res = set(), []
    for h in hist:
        if h.scheduled_at.replace(tzinfo=None) >= now - timedelta(days=7):
            key = (h.medication_id, h.scheduled_at.hour, h.scheduled_at.minute)
            if key not in seen:
                seen.add(key)
                d = (now + timedelta(days=1)).replace(hour=h.scheduled_at.hour, minute=h.scheduled_at.minute, second=0, microsecond=0)
                res.append(UpcomingDose(medication_id=h.medication_id, medication_name=h.medication_name, scheduled_at=d))
    return res[:60]


# ───────────────────────── routes ─────────────────────────
def _verify_token(token: str) -> Optional[dict]:
    """Verifies a Firebase Auth ID token (signature, expiry, audience = our project). Returns the claims or None."""
    try:
        from google.auth.transport import requests as g_requests
        from google.oauth2 import id_token
        return id_token.verify_firebase_token(token, g_requests.Request(), audience=FIREBASE_PROJECT_ID)
    except Exception:
        return None


_hits = defaultdict(deque)


def _rate_limited(identity: str) -> bool:
    """Sliding-window limiter per caller (per Cloud Run instance)."""
    now = time.monotonic()
    q = _hits[identity]
    while q and now - q[0] > 60:
        q.popleft()
    if len(q) >= RATE_LIMIT_PER_MIN:
        return True
    q.append(now)
    return False


def authenticate(x_api_key: Optional[str], authorization: Optional[str]) -> str:
    """Returns the caller identity or raises 401 / 429. Modes: key (shared secret), firebase (ID token), either."""
    ident = None
    if AUTH_MODE in ("key", "either"):
        if not API_KEY:                                           # local development only (blocked on Cloud Run above)
            ident = "dev"
        elif x_api_key and secrets.compare_digest(x_api_key.encode(), API_KEY.encode()):
            ident = "key"
    if ident is None and AUTH_MODE in ("firebase", "either") and authorization and authorization.lower().startswith("bearer "):
        claims = _verify_token(authorization[7:].strip())
        uid = (claims or {}).get("uid") or (claims or {}).get("sub")
        if uid:
            ident = "uid:" + str(uid)
    if ident is None:
        raise HTTPException(status_code=401, detail="Invalid or missing credentials")
    if _rate_limited(ident):
        raise HTTPException(status_code=429, detail="Too many requests")
    return ident


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/model")
def model_info(x_api_key: Optional[str] = Header(None), authorization: Optional[str] = Header(None)):
    authenticate(x_api_key, authorization)
    t = metrics["tests"]["Logistic Regression"]
    return {"model": "Logistic Regression", "algorithm": "LogisticRegression (scikit-learn)", "data": meta["data"],
            "accuracy_unseen_patients": round(t["A_unseen_patients"]["accuracy"], 4),
            "accuracy_future_period": round(t["B_future_period"]["accuracy"], 4),
            "accuracy_strict": round(t["C_strict_unseen_and_future"]["accuracy"], 4),
            "roc_auc_strict": round(t["C_strict_unseen_and_future"]["roc_auc"], 4),
            "brier_calibrated": round(metrics["deployed_model"]["brier"], 4),
            "trained_rows": meta["trained_rows"], "features": len(FEATURES)}


@app.post("/predict_doses")
def predict_doses(body: PredictIn, x_api_key: Optional[str] = Header(None), authorization: Optional[str] = Header(None)):
    authenticate(x_api_key, authorization)
    hist = sorted(body.history, key=lambda h: h.scheduled_at.replace(tzinfo=None))
    if len(hist) < 3:
        raise HTTPException(status_code=422, detail="At least 3 recorded doses are needed")
    now = (body.now or hist[-1].scheduled_at).replace(tzinfo=None)
    h = {"ts": np.array([to_hours(x.scheduled_at) for x in hist]),
         "missed": np.array([1.0 if x.status == "missed" else 0.0 for x in hist]),
         "delay": np.array([x.delay_min for x in hist]),
         "med": np.array([x.medication_id for x in hist], dtype=object),
         "slot": np.array([slot_of(x.scheduled_at.hour) for x in hist])}
    ups = body.upcoming or fallback_upcoming(hist, now)
    if not ups:
        raise HTTPException(status_code=422, detail="No upcoming doses to score")
    patient = body.patient.model_dump()
    doses = []
    for u in sorted(ups, key=lambda x: x.scheduled_at.replace(tzinfo=None)):
        t = {"ts": to_hours(u.scheduled_at), "med": u.medication_id, "slot": slot_of(u.scheduled_at.hour),
             "dow": u.scheduled_at.weekday(), "hour": float(u.scheduled_at.hour)}
        f = dose_features(h, t, patient)
        x = pd.DataFrame([[f[k] for k in FEATURES]], columns=FEATURES)
        raw = float(pipeline.predict_proba(x)[0, 1])
        p = calibrated(raw)
        xs = pipeline[:-1].transform(x)[0]
        doses.append({"medication_id": u.medication_id, "medication_name": u.medication_name,
                      "scheduled_at": u.scheduled_at.isoformat(), "time_slot": SLOTS[t["slot"]],
                      "probability": round(p, 4), "percent": int(round(p * 100)), "level": level_of(p),
                      "reasons": explain(f, xs, u.medication_name, t["slot"], p)})
    # headline = average chance across the upcoming doses; reasons come from the riskiest dose
    prob = float(np.mean([d["probability"] for d in doses]))
    worst = max(doses, key=lambda d: d["probability"])
    return {"probability": round(prob, 4), "percent": int(round(prob * 100)), "level": level_of(prob),
            "factors": worst["reasons"], "riskiest_dose": {k: worst[k] for k in ("medication_id", "medication_name", "scheduled_at", "percent", "level")},
            "doses": doses, "insights": insights_from(hist, now), "history_doses": len(hist),
            "model": {"name": "Logistic Regression", "accuracy": round(metrics["tests"]["Logistic Regression"]["C_strict_unseen_and_future"]["accuracy"], 3),
                      "data": "synthetic"}}
