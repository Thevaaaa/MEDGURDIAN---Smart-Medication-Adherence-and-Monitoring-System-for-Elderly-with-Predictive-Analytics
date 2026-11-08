import json, sys, time
import numpy as np, pandas as pd, joblib
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import GridSearchCV, GroupKFold
from sklearn.metrics import (accuracy_score, precision_score, recall_score, f1_score, roc_auc_score,
                             average_precision_score, brier_score_loss, confusion_matrix)
from features import FEATURES, dose_features, PATIENT_FIELDS

QUICK = "--quick" in sys.argv
CSV = "medguardian_dose_dataset.csv"
EPOCH = np.datetime64("1970-01-01T00:00:00")
TRAIN_DAYS = 42


def build_feature_table(df):
    df = df.sort_values(["patient_id", "scheduled_at"]).reset_index(drop=True)
    ts_all = ((pd.to_datetime(df.scheduled_at).values - EPOCH) / np.timedelta64(1, "h")).astype(float)
    out = []
    for pid, g in df.groupby("patient_id", sort=False):
        idx = g.index.values
        h = {"ts": ts_all[idx], "missed": g.missed.values.astype(float), "delay": g.delay_min.values.astype(float),
             "med": g.medicine_id.values.astype(object), "slot": g.slot_id.values.astype(int)}
        patient = {k: g.iloc[0][k] for k in PATIENT_FIELDS}
        dts = pd.to_datetime(g.scheduled_at)
        for j, i in enumerate(idx):
            t = {"ts": ts_all[i], "med": h["med"][j], "slot": int(h["slot"][j]), "dow": int(dts.iloc[j].dayofweek),
                 "hour": float(dts.iloc[j].hour)}
            out.append(dose_features(h, t, patient))
    X = pd.DataFrame(out, columns=FEATURES)
    X.index = df.index
    return df, X


def pipe(C=1.0, cw=None):
    return Pipeline([("imp", SimpleImputer(strategy="median")), ("sc", StandardScaler()),
                     ("clf", LogisticRegression(C=C, class_weight=cw, max_iter=3000))])


def metrics(y, p, thr=0.5):
    pred = (p >= thr).astype(int)
    bins = np.linspace(0, 1, 11)
    ece = 0.0
    for a, b in zip(bins[:-1], bins[1:]):
        m = (p >= a) & (p < b if b < 1 else p <= b)
        if m.any():
            ece += m.mean() * abs(p[m].mean() - y[m].mean())
    return {"accuracy": accuracy_score(y, pred), "precision": precision_score(y, pred), "recall": recall_score(y, pred),
            "f1": f1_score(y, pred), "roc_auc": roc_auc_score(y, p), "pr_auc": average_precision_score(y, p),
            "brier": brier_score_loss(y, p), "ece": ece, "n": int(len(y))}


def fit_platt(raw, y):
    z = np.log(np.clip(raw, 1e-6, 1 - 1e-6) / (1 - np.clip(raw, 1e-6, 1 - 1e-6))).reshape(-1, 1)
    lr = LogisticRegression(C=1e6, max_iter=1000).fit(z, y)
    return float(lr.coef_[0, 0]), float(lr.intercept_[0])


def apply_platt(raw, a, b):
    z = np.log(np.clip(raw, 1e-6, 1 - 1e-6) / (1 - np.clip(raw, 1e-6, 1 - 1e-6)))
    return 1 / (1 + np.exp(-(a * z + b)))


def main():
    t0 = time.time()
    df = pd.read_csv(CSV, parse_dates=["scheduled_at"])
    df, X = build_feature_table(df)
    y = df.missed.values
    print(f"features built: {X.shape} in {time.time()-t0:.0f}s   miss rate {y.mean():.1%}")

    pats = np.array(sorted(df.patient_id.unique()))
    rng = np.random.default_rng(42)
    rng.shuffle(pats)
    n = len(pats)
    tr_p, va_p, te_p = set(pats[: int(.70 * n)]), set(pats[int(.70 * n): int(.85 * n)]), set(pats[int(.85 * n):])
    inp = lambda s: df.patient_id.isin(s).values
    early = (df.day_index < TRAIN_DAYS).values
    A_tr, A_va, A_te = inp(tr_p), inp(va_p), inp(te_p)

    # ---- tune logistic regression on the training patients (grouped CV, no patient in both folds) ----
    grid = GridSearchCV(pipe(), {"clf__C": [0.01, 0.1, 1, 10], "clf__class_weight": [None, "balanced"]},
                        scoring="roc_auc", cv=GroupKFold(5), n_jobs=2)
    grid.fit(X[A_tr], y[A_tr], groups=df.patient_id[A_tr])
    C, cw = grid.best_params_["clf__C"], grid.best_params_["clf__class_weight"]
    print("best LR settings:", grid.best_params_, f"(grouped CV AUC {grid.best_score_:.4f})")

    models = {"Logistic Regression": lambda: pipe(C, cw)}

    # ---- the three tests ----
    # A: unseen patients (train patients, all days  ->  test patients, all days)
    # B: future period   (train patients days<42   ->  train patients days>=42)
    # C: strict          (train patients days<42   ->  test patients days>=42)
    tests = {"A_unseen_patients": (A_tr, A_te), "B_future_period": (A_tr & early, A_tr & ~early),
             "C_strict_unseen_and_future": (A_tr & early, A_te & ~early)}
    results, probs = {}, {}
    for name, mk in models.items():
        results[name] = {}
        for tn, (tr, te) in tests.items():
            m = mk().fit(X[tr], y[tr])
            p = m.predict_proba(X[te])[:, 1]
            results[name][tn] = metrics(y[te], p)
            probs[(name, tn)] = (y[te], p)
        r = results[name]["C_strict_unseen_and_future"]
        print(f"{name:20s} strict test: acc {r['accuracy']:.4f} auc {r['roc_auc']:.4f} brier {r['brier']:.4f}")

    # naive baseline: "predict the patient's own 14-day miss rate"
    base_p = X.loc[tests["C_strict_unseen_and_future"][1], "miss_rate_14d"].values
    results["Baseline (14-day miss rate only)"] = {"C_strict_unseen_and_future": metrics(y[tests["C_strict_unseen_and_future"][1]], base_p)}

    # ---- final LR: fit on training patients, calibrate on separate validation patients, test on unseen patients ----
    final = pipe(C, cw).fit(X[A_tr], y[A_tr])
    raw_va = final.predict_proba(X[A_va])[:, 1]
    a, b = fit_platt(raw_va, y[A_va])
    raw_te = final.predict_proba(X[A_te])[:, 1]
    before, after = metrics(y[A_te], raw_te), metrics(y[A_te], apply_platt(raw_te, a, b))
    use_cal = after["brier"] < before["brier"] - 1e-4
    print(f"calibration: Brier {before['brier']:.4f} -> {after['brier']:.4f}  ECE {before['ece']:.4f} -> {after['ece']:.4f}  use={use_cal}")
    if not use_cal:
        a, b = 1.0, 0.0
    test_final = after if use_cal else before

    # behaviour check: does the model rank each patient's truly worst time slot highest?
    tb = df[A_te].copy()
    tb["p"] = apply_platt(raw_te, a, b)
    g = tb.groupby(["patient_id", "slot_id"]).agg(p=("p", "mean"), t=("true_miss_prob", "mean"), n=("p", "size")).reset_index()
    g = g[g.n >= 8]
    hits = tot = 0
    for _, s in g.groupby("patient_id"):
        if len(s) >= 2 and s.t.max() - s.t.min() > 0.25:
            tot += 1
            hits += int(s.loc[s.p.idxmax(), "slot_id"] == s.loc[s.t.idxmax(), "slot_id"])
    behaviour = {"patients_with_clear_slot_habit": tot, "worst_slot_identified": hits,
                 "rate": hits / tot if tot else None}
    print(f"behaviour check: worst time slot identified for {hits}/{tot} unseen patients")

    # ---- deploy model: refit on ALL patients so the app gets the best model; keep metrics from the held-out test above ----
    deploy = pipe(C, cw).fit(X, y)
    ceiling = float(((df.true_miss_prob > 0.5) == (y == 1)).mean())
    out = {"model": "Logistic Regression", "features": FEATURES, "platt_a": a, "platt_b": b,
           "threshold": 0.5, "trained_rows": int(len(df)), "trained_patients": int(len(pats)),
           "data": "synthetic dose-level data (not real patients)"}
    joblib.dump({"pipeline": deploy, "meta": out}, "model.joblib")
    summary = {"deployed_model": test_final, "tests": results, "calibration": {"before": before, "after": after, "applied": use_cal},
               "behaviour_check": behaviour, "synthetic_accuracy_ceiling": ceiling,
               "settings": {"C": C, "class_weight": cw}, "rows": int(len(df)), "patients": int(len(pats)),
               "features": FEATURES, "note": "All figures come from SYNTHETIC data."}
    json.dump(summary, open("model_metrics.json", "w"), indent=2, default=float)
    print(f"\nFINAL ACCURACY (Logistic Regression, unseen patients): {test_final['accuracy']*100:.2f}%")
    print(f"FINAL ACCURACY (strict: unseen patients + later days): {results['Logistic Regression']['C_strict_unseen_and_future']['accuracy']*100:.2f}%")
    print(f"(best any model could do on this synthetic data = {ceiling*100:.1f}%)")

    if not QUICK:
        charts(df, X, y, A_te, early, models, probs, results, deploy, a, b, raw_te)
    print(f"done in {time.time()-t0:.0f}s")


def charts(df, X, y, A_te, early, models, probs, results, deploy, a, b, raw_te):
    import os, matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from sklearn.metrics import roc_curve
    os.makedirs("analysis", exist_ok=True)
    tn = "C_strict_unseen_and_future"
    fig, ax = plt.subplots(1, 3, figsize=(16, 4.6))
    for name in models:
        yt, p = probs[(name, tn)]
        f, t, _ = roc_curve(yt, p); ax[0].plot(f, t, label=f"{name} (AUC {roc_auc_score(yt, p):.3f})")
    ax[0].plot([0, 1], [0, 1], "--", c="grey"); ax[0].set_title("ROC - unseen patients, later days"); ax[0].legend(); ax[0].set_xlabel("False positive rate"); ax[0].set_ylabel("True positive rate")
    yt, p = probs[("Logistic Regression", tn)]
    bins = np.linspace(0, 1, 11); mid, obs = [], []
    for lo, hi in zip(bins[:-1], bins[1:]):
        m = (p >= lo) & (p <= hi)
        if m.sum() > 30: mid.append(p[m].mean()); obs.append(yt[m].mean())
    ax[1].plot([0, 1], [0, 1], "--", c="grey"); ax[1].plot(mid, obs, "o-"); ax[1].set_title("Calibration (Logistic Regression)"); ax[1].set_xlabel("Predicted risk"); ax[1].set_ylabel("Actually missed")
    cm = confusion_matrix(yt, (p >= .5).astype(int)); ax[2].imshow(cm, cmap="Blues")
    for i in range(2):
        for j in range(2): ax[2].text(j, i, f"{cm[i, j]:,}", ha="center", va="center")
    ax[2].set_xticks([0, 1]); ax[2].set_xticklabels(["pred taken", "pred missed"]); ax[2].set_yticks([0, 1]); ax[2].set_yticklabels(["taken", "missed"]); ax[2].set_title("Confusion matrix")
    plt.tight_layout(); plt.savefig("analysis/1_roc_calibration_confusion.png", dpi=130); plt.close()

    fig, ax = plt.subplots(1, 2, figsize=(13, 4.6))
    names = list(results); accs = [results[n][tn]["accuracy"] * 100 for n in names]
    ax[0].barh([n.replace(" (14-day miss rate only)", "\n(14-day miss rate only)") for n in names], accs, color=["#1F6F6B", "#8E9B96"]); ax[0].set_xlim(50, 100); ax[0].set_title("Accuracy % (strict test): model vs simple baseline")
    for i, v in enumerate(accs): ax[0].text(v + .3, i, f"{v:.1f}", va="center")
    coef = pd.Series(deploy.named_steps["clf"].coef_[0], index=FEATURES).sort_values(key=abs, ascending=False)[:12][::-1]
    ax[1].barh(coef.index, coef.values, color=["#C0392B" if v > 0 else "#1F6F6B" for v in coef.values]); ax[1].set_title("Top Logistic Regression weights (red = raises risk)")
    plt.tight_layout(); plt.savefig("analysis/2_model_vs_baseline_and_weights.png", dpi=130); plt.close()

    fig, ax = plt.subplots(1, 3, figsize=(16, 4.4))
    df.groupby("time_slot").missed.mean().reindex(["morning", "midday", "evening", "night"]).mul(100).plot.bar(ax=ax[0], color="#1F6F6B"); ax[0].set_title("Missed % by time of day"); ax[0].set_ylabel("%")
    df.groupby("day_of_week").missed.mean().reindex(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]).mul(100).plot.bar(ax=ax[1], color="#2E86AB"); ax[1].set_title("Missed % by weekday")
    df.groupby("medicine_name").missed.mean().sort_values().mul(100).plot.barh(ax=ax[2], color="#C0392B"); ax[2].set_title("Missed % by medicine")
    plt.tight_layout(); plt.savefig("analysis/3_patterns_in_data.png", dpi=130); plt.close()
    print("charts saved in analysis/")


if __name__ == "__main__":
    main()
