import numpy as np

GRACE_H = 1.0          # a dose is only known to be missed 1 hour after its time
PRIOR_N = 3.0          # smoothing strength for small samples
DEFAULT_RATE = 0.25    # used before any history exists
SLOTS = ["morning", "midday", "evening", "night"]

PATIENT_FIELDS = ["age", "num_conditions", "medication_count", "avg_heart_rate", "avg_oxygen_pct",
                  "daily_steps", "fall_events_30d", "symptom_count_14d", "avg_symptom_severity"]

HISTORY_FEATURES = [
    "miss_rate_7d", "miss_rate_14d", "miss_rate_30d", "missed_streak", "avg_delay_min_14d",
    "hours_since_last_miss", "never_missed", "n_history_30d", "doses_per_day_7d",
    "slot_miss_rate", "med_miss_rate", "med_slot_miss_rate", "weekday_miss_rate",
    "prev_same_dose_missed", "slot_gap", "med_gap", "miss_x_delay",
]
DOSE_FEATURES = ["slot_morning", "slot_midday", "slot_evening", "slot_night", "is_weekend", "hour"]
FEATURES = PATIENT_FIELDS + DOSE_FEATURES + HISTORY_FEATURES


def slot_of(hour: float) -> int:
    if 5 <= hour < 11:
        return 0
    if 11 <= hour < 16:
        return 1
    if 16 <= hour < 21:
        return 2
    return 3


def _smooth(missed: float, n: float, prior: float) -> float:
    return (missed + PRIOR_N * prior) / (n + PRIOR_N)


def dose_features(h, t, patient: dict) -> dict:
    """h: dict of numpy arrays sorted by time - ts (hours), missed (0/1), delay (min), med (str), slot (int)
       t: dict - ts (hours), med (str), slot (int), dow (0=Mon), hour (float)
       patient: dict with PATIENT_FIELDS"""
    ts = h["ts"]
    cut = int(np.searchsorted(ts, t["ts"] - GRACE_H, side="right"))
    ts, missed, delay, med, slot = ts[:cut], h["missed"][:cut], h["delay"][:cut], h["med"][:cut], h["slot"][:cut]
    age = t["ts"] - ts
    w7, w14, w30 = age <= 168, age <= 336, age <= 720
    n30 = int(w30.sum())
    base = float(missed[w30].mean()) if n30 else DEFAULT_RATE

    def rate(mask, fallback):
        n = int(mask.sum())
        return float(missed[mask].mean()) if n else fallback

    r30 = base
    r14 = rate(w14, r30)
    r7 = rate(w7, r14)

    streak = 0
    for v in missed[::-1]:
        if v >= 1:
            streak += 1
            if streak >= 10:
                break
        else:
            break

    taken14 = w14 & (missed == 0)
    avg_delay = float(delay[taken14].mean()) if taken14.any() else 0.0

    miss_idx = np.nonzero(missed >= 1)[0]
    never = 0 if len(miss_idx) else 1
    hsl = float(min(t["ts"] - ts[miss_idx[-1]], 336.0)) if len(miss_idx) else 336.0

    same_slot = w30 & (slot == t["slot"])
    same_med = w30 & (med == t["med"])
    same_both = same_slot & same_med
    # same weekday over the last 4 weeks
    dow_hist = ((np.floor(ts / 24.0).astype(np.int64) + 3) % 7)   # epoch day 0 = Thursday (3) -> Monday = 0
    same_dow = w30 & (dow_hist == t["dow"])

    slot_rate = _smooth(float(missed[same_slot].sum()), float(same_slot.sum()), base)
    med_rate = _smooth(float(missed[same_med].sum()), float(same_med.sum()), base)
    both_rate = _smooth(float(missed[same_both].sum()), float(same_both.sum()), med_rate)
    dow_rate = _smooth(float(missed[same_dow].sum()), float(same_dow.sum()), base)

    prev_same = base
    idx = np.nonzero((med == t["med"]) & (slot == t["slot"]))[0]
    if len(idx):
        prev_same = float(missed[idx[-1]])

    n7 = int(w7.sum())
    f = {k: float(patient[k]) for k in PATIENT_FIELDS}
    f.update({
        "slot_morning": float(t["slot"] == 0), "slot_midday": float(t["slot"] == 1),
        "slot_evening": float(t["slot"] == 2), "slot_night": float(t["slot"] == 3),
        "is_weekend": float(t["dow"] >= 5), "hour": float(t["hour"]),
        "miss_rate_7d": r7, "miss_rate_14d": r14, "miss_rate_30d": r30,
        "missed_streak": float(streak), "avg_delay_min_14d": avg_delay,
        "hours_since_last_miss": hsl, "never_missed": float(never),
        "n_history_30d": float(n30), "doses_per_day_7d": n7 / 7.0,
        "slot_miss_rate": slot_rate, "med_miss_rate": med_rate, "med_slot_miss_rate": both_rate,
        "weekday_miss_rate": dow_rate, "prev_same_dose_missed": prev_same,
        "slot_gap": slot_rate - base, "med_gap": med_rate - base,
        "miss_x_delay": r14 * avg_delay / 60.0,
    })
    return f
