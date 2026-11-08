import numpy as np, pandas as pd
from datetime import datetime, timedelta

N_PATIENTS, N_DAYS, SEED = 600, 60, 42
START = datetime(2026, 1, 5)          # a Monday
MEDS = [("MED001", "Metformin"), ("MED002", "Amlodipine"), ("MED003", "Atorvastatin"), ("MED004", "Aspirin"),
        ("MED005", "Losartan"), ("MED006", "Omeprazole"), ("MED007", "Levothyroxine"), ("MED008", "Warfarin"),
        ("MED009", "Gliclazide"), ("MED010", "Vitamin D")]
TIMES = {0: [7, 8, 9], 1: [12, 13, 14], 2: [18, 19, 20], 3: [21, 22]}
SLOT_NAMES = ["morning", "midday", "evening", "night"]
sig = lambda x: 1 / (1 + np.exp(-x))


def slot_of(h):
    return 0 if 5 <= h < 11 else 1 if 11 <= h < 16 else 2 if 16 <= h < 21 else 3


def main():
    rng = np.random.default_rng(SEED)
    rows = []
    for p in range(N_PATIENTS):
        pid = f"P{p+1:04d}"
        age = int(np.clip(rng.normal(74, 8), 55, 95))
        ncond = int(np.clip(rng.poisson(1.0 + (age - 55) / 20), 0, 6))
        nmed = int(np.clip(rng.integers(1, 5) + (ncond > 3), 1, 5))
        meds = rng.choice(len(MEDS), size=nmed, replace=False)
        # schedule: each medicine takes 1-3 daily times (from different parts of the day)
        sched = []
        for m in meds:
            for s in rng.choice(4, size=int(rng.choice([1, 1, 1, 2])), replace=False):
                sched.append((MEDS[m][0], MEDS[m][1], int(rng.choice(TIMES[int(s)])), 0))
        # vitals / context (patient-level)
        hr = float(np.clip(rng.normal(76, 8) + 0.1 * (age - 74), 52, 120))
        spo2 = float(np.clip(rng.normal(96.5, 1.6) - 0.03 * (age - 74), 85, 100))
        steps = float(np.clip(rng.normal(3800, 1600) - 40 * (age - 74), 300, 12000))
        falls = int(rng.poisson(0.25 + 0.02 * max(0, age - 70)))
        sym_n = int(rng.poisson(1.2 + 0.4 * ncond))
        sym_sev = float(np.clip(rng.normal(2.0, 0.8), 0, 5)) if sym_n else 0.0

        # ---- hidden habits ----
        base = rng.normal(-2.6, 0.6)
        slot_eff = np.zeros(4)
        if rng.random() < 0.40: slot_eff[0] = rng.normal(3.0, 0.5)       # forgets mornings
        if rng.random() < 0.20: slot_eff[1] = rng.normal(2.6, 0.5)       # forgets midday
        if rng.random() < 0.25: slot_eff[2] = rng.normal(2.4, 0.5)       # forgets evenings
        if rng.random() < 0.30: slot_eff[3] = rng.normal(2.8, 0.5)       # forgets bedtime
        med_eff = {m: rng.normal(0, 0.3) for m, _, _, _ in sched}
        if rng.random() < 0.45 and nmed > 1:                              # one problem medicine
            med_eff[sched[rng.integers(len(sched))][0]] += rng.normal(3.0, 0.5)
        weekend = rng.normal(0.6, 0.5)
        phase = 0.0
        prev_missed = 0.0
        z_age = 0.025 * (age - 74) + 0.08 * max(0, nmed - 2) + 0.05 * ncond

        for d in range(N_DAYS):
            day = START + timedelta(days=d)
            dow = day.weekday()
            phase = 0.85 * phase + rng.normal(0, 0.2)                    # slowly changing "bad phase"
            for mid, mname, hour, _ in sorted(sched, key=lambda x: x[2]):
                s = slot_of(hour)
                z = (base + z_age + slot_eff[s] + med_eff[mid] + (weekend if dow >= 5 else 0)
                     + phase + 0.7 * prev_missed)
                p_miss = float(sig(z))
                missed = int(rng.random() < p_miss)
                delay = 0.0 if missed else float(np.clip(rng.exponential(6 + 30 * p_miss), 0, 55))
                prev_missed = float(missed)
                rows.append((pid, mid, mname, day.replace(hour=hour), day.strftime("%a"), s, SLOT_NAMES[s], d, missed,
                             round(delay, 1), age, ncond, nmed, round(hr, 1), round(spo2, 1), round(steps),
                             falls, sym_n, round(sym_sev, 1), round(p_miss, 4)))
    df = pd.DataFrame(rows, columns=[
        "patient_id", "medicine_id", "medicine_name", "scheduled_at", "day_of_week", "slot_id", "time_slot", "day_index",
        "missed", "delay_min", "age", "num_conditions", "medication_count", "avg_heart_rate", "avg_oxygen_pct",
        "daily_steps", "fall_events_30d", "symptom_count_14d", "avg_symptom_severity", "true_miss_prob"])
    df.to_csv("medguardian_dose_dataset.csv", index=False)
    df.head(3000).drop(columns=["true_miss_prob"]).to_excel("medguardian_dose_dataset_sample.xlsx", index=False)
    print(f"rows={len(df):,} patients={df.patient_id.nunique()} days={N_DAYS} doses/patient/day={len(df)/N_PATIENTS/N_DAYS:.1f}")
    print(f"overall missed rate = {df.missed.mean():.1%}")
    print(df.groupby('time_slot').missed.mean().round(3).to_dict())
    print("Bayes-optimal accuracy ceiling (knowing the hidden true probability):",
          f"{((df.true_miss_prob > 0.5) == (df.missed == 1)).mean():.1%}")


if __name__ == "__main__":
    main()
