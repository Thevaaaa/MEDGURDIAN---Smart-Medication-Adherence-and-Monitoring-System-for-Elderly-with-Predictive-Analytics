# MedGuardian — Smart Medication Adherence & Monitoring System for Elderly with Predictive Analytics

[![Flutter](https://img.shields.io/badge/Flutter-3.6+-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115+-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![Python](https://img.shields.io/badge/Python-3.12+-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore%20%7C%20FCM-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com/)
[![scikit-learn](https://img.shields.io/badge/scikit--learn-Logistic%20Regression-F7931E?logo=scikitlearn&logoColor=white)](https://scikit-learn.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**MedGuardian** is a comprehensive, AI-driven healthcare assistance system engineered to improve medication adherence and safety monitoring for elderly patients, particularly those managing multiple chronic conditions (polypharmacy).

The system seamlessly combines a cross-platform **Flutter mobile application** for patients and caregivers with a high-performance **Python FastAPI machine learning microservice** that forecasts the risk of missed medication doses using calibrated Logistic Regression.

---

## 📑 Table of Contents

- [System Architecture](#-system-architecture)
- [Key Features](#-key-features)
- [Repository Structure](#-repository-structure)
- [Machine Learning & Predictive Analytics](#-machine-learning--predictive-analytics)
- [Getting Started](#-getting-started)
  - [Prerequisites](#prerequisites)
  - [1. MedGuardian ML API Setup](#1-medguardian-ml-api-setup)
  - [2. MedGuardian Flutter Mobile App Setup](#2-medguardian-flutter-mobile-app-setup)
- [API Reference](#-api-reference)
- [Security & Privacy](#-security--privacy)
- [Usability & Clinical Context](#-usability--clinical-context)
- [Author & Acknowledgments](#-author--acknowledgments)

---

## 🏛 System Architecture

MedGuardian follows a modular, client-server decoupled architecture:

```
┌────────────────────────────────────────────────────────┐
│                   MedGuardian App                      │
│             (Flutter Cross-Platform UI)                │
│  - Senior-Friendly Interface & Large Touch Targets     │
│  - Real-Time Fall Detection Background Service        │
│  - SOS Emergency Dispatch & GPS Geolocation            │
│  - Health Vitals Sync (Heart Rate, Steps, SpO2)        │
└───────────────┬────────────────────────┬───────────────┘
                │                        │
       REST / JSON (Dose Risk)    Firestore SDK / FCM Sync
                │                        │
                ▼                        ▼
┌───────────────────────────────┐  ┌────────────────────────────────────┐
│      MedGuardian ML API       │  │        Google Firebase Cloud       │
│  (FastAPI + Logistic Regr.)   │  │  - Cloud Firestore (Real-Time DB)  │
│  - 32 Adherence & Dose Feats  │  │  - Firebase Authentication (Auth)   │
│  - Platt Scaling Calibration  │  │  - Cloud Messaging (Push Alerts)   │
│  - Cloud Run Container Ready  │  │  - Cloud Storage (Profile & Media) │
└───────────────────────────────┘  └────────────────────────────────────┘
```

---

## ✨ Key Features

### 1. Smart Medication Adherence
- **Customized Dose Schedules**: Timed alerts for Morning, Midday, Evening, and Night dosage slots.
- **Visual Pill Verification**: Clear medicine labels, dosages, instructions, and pill imagery.
- **Adherence Logging**: One-tap confirmation ("Taken", "Snoozed", "Missed") recording response delay in minutes.

### 2. Predictive Analytics & Proactive Intervention
- **Predictive Risk Scoring**: Pre-computes miss probability for upcoming scheduled doses using patient history and time characteristics.
- **Dynamic Risk Leveling**: Automatically tags doses as `low`, `moderate`, or `high` risk, enabling early caregiver intervention before doses are missed.
- **Transparent Explainability**: Extracts top contributing model weights explaining *why* a specific dose is high risk (e.g., weekend morning fatigue, medication complexity).

### 3. Elderly Safety & Fall Detection
- **Continuous Sensor Monitoring**: Accelerometer and gyroscope tracking utilizing `sensors_plus` and Android Foreground Services.
- **Automated Fall Alert Flow**: 30-second audible countdown allowing false-alarm cancellation prior to emergency broadcast.
- **Instant SOS Dispatch**: Sends SMS, push notification, battery level, and exact Google Maps GPS coordinates to designated family members and caregivers.

### 4. Health Vitals Tracking
- Integrates with Google Health Connect to monitor heart rate, blood oxygen (SpO2), and daily step counts to correlate physical activity with treatment compliance.

---

## 📂 Repository Structure

```
MedGuardian/
├── README.md                      # Complete system documentation
├── .gitignore                     # Repository-wide git ignore rules
│
├── medguardianapp/                # Flutter Mobile Application
│   ├── lib/                       # Core application source code (56 Dart files)
│   │   ├── main.dart              # Application entry point & service bootstrap
│   │   ├── app.dart               # MaterialApp routing & theme configuration
│   │   ├── models/                # Data models (Medication, Dose, Vitals, User)
│   │   ├── screens/               # UI screens (Elderly, Caregiver, Auth, Shared)
│   │   ├── services/              # Firebase, Fall Detection, Health Sync, Risk API
│   │   ├── theme/                 # App design system, animations & colors
│   │   ├── utils/                 # Formatters, navigation helpers & validators
│   │   └── widgets/               # Reusable UI components & visual charts
│   ├── test/                      # Unit & widget test suites
│   ├── integration_test/          # End-to-end smoke & flow tests
│   ├── functions/                 # Firebase Cloud Functions (alerts & sweeps)
│   ├── android/                   # Android native wrapper & configuration
│   ├── ios/                       # iOS native wrapper & configuration
│   ├── assets/                    # Branding assets & application logo
│   ├── pubspec.yaml               # Flutter package dependencies and metadata
│   ├── pubspec.lock               # Deterministic dependency lock file
│   ├── firebase.json              # Firebase CLI project settings
│   ├── firestore.rules            # Firestore database security rules
│   ├── firestore.indexes.json     # Firestore composite query indexes
│   ├── storage.rules              # Firebase Storage access rules
│   └── analysis_options.yaml      # Dart static analysis configuration
│
└── medguardian_ML_API/            # Python FastAPI Machine Learning Microservice
    ├── main.py                    # FastAPI application & risk prediction endpoints
    ├── features.py                # 32-feature extraction pipeline & sliding windows
    ├── train_model.py             # Model training, Platt calibration, & evaluation
    ├── generate_dose_dataset.py   # Synthetic clinical dose generator (synthetic cohort)
    ├── medguardian_dose_dataset.csv # Dose-level training dataset
    ├── requirements.txt           # Python library dependencies
    ├── Dockerfile                 # Multi-stage production container build
    └── .gitignore                 # Python specific ignore rules
```

---

## 🧠 Machine Learning & Predictive Analytics

The prediction service evaluates medication non-adherence risk at the individual dose level:

- **Algorithm**: Regularized Logistic Regression with `StandardScaler` and `SimpleImputer` pipeline.
- **Calibration**: Platt scaling (sigmoid calibration) converting raw logits into reliable empirical probabilities.
- **Validation**: GroupKFold cross-validation grouped by patient ID to ensure high generalization to unseen individuals.
- **Feature Matrix (32 Features)**:
  - **Patient Demographics & Vitals**: Age, number of chronic conditions, medication count, resting heart rate, oxygen saturation, daily steps, 30-day fall events, symptom severity.
  - **Dose Context**: Time slot (Morning, Midday, Evening, Night), scheduled hour, weekend indicator.
  - **Historical Adherence**: 7-day, 14-day, and 30-day historical miss rates, current missed streak, average delay in minutes, slot-specific miss rates, medicine-specific miss rates, interaction terms.

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK**: `^3.6.0` ([Installation Guide](https://docs.flutter.dev/get-started/install))
- **Dart SDK**: Bundled with Flutter
- **Android Studio** / **VS Code** with Flutter & Dart extensions
- **Python**: `3.10` - `3.12` ([Download Python](https://www.python.org/))
- **Docker** (Optional, for containerized ML deployment)

---

### 1. MedGuardian ML API Setup

#### Local Environment
```bash
# Navigate to the ML API folder
cd medguardian_ML_API

# Create and activate a Python virtual environment
python -m venv .venv
source .venv/bin/activate      # Linux / macOS
# or
.venv\Scripts\activate         # Windows

# Install dependencies
pip install -r requirements.txt

# (Optional) Generate dataset and train the model
python generate_dose_dataset.py
python train_model.py --quick

# Start the FastAPI server
uvicorn main:app --host 0.0.0.0 --port 8080 --reload
```
Interactive Swagger documentation will be available at: `http://localhost:8080/docs`

#### Docker Deployment
```bash
cd medguardian_ML_API
docker build -t medguardian-ml-api .
docker run -p 8080:8080 medguardian-ml-api
```

---

### 2. MedGuardian Flutter Mobile App Setup

```bash
# Navigate to the Flutter application directory
cd medguardianapp

# Fetch package dependencies
flutter pub get

# Connect an Android emulator or physical device (with USB debugging enabled)
flutter devices

# Run the application in debug mode
flutter run
```

> **Note on Firebase & Google Services:**
> The mobile app communicates with Firebase for authentication and Firestore synchronization. Ensure that a valid `google-services.json` is placed in `medguardianapp/android/app/` and the Google Maps API key is configured in `AndroidManifest.xml`.

---

## 📡 API Reference

### Health Check
- `GET /health` — Verifies service status, model type, feature dimensions, and uptime.

### Single Dose Risk Prediction
- `POST /predict`
- Evaluates risk for an upcoming dose.
- **Sample Request**:
```json
{
  "patient": {
    "age": 74,
    "num_conditions": 3,
    "medication_count": 6,
    "avg_heart_rate": 78,
    "avg_oxygen_pct": 96,
    "daily_steps": 2800,
    "fall_events_30d": 1
  },
  "dose": {
    "medicine_id": "metformin_500",
    "scheduled_at": "2026-11-09T08:00:00Z"
  },
  "history": [
    {
      "scheduled_at": "2026-11-08T08:00:00Z",
      "missed": false,
      "delay_min": 15,
      "medicine_id": "metformin_500"
    }
  ]
}
```
- **Sample Response**:
```json
{
  "probability": 0.284,
  "risk_level": "low",
  "confidence": "high",
  "top_risk_factors": ["High medication count", "Morning slot miss history"]
}
```

### Batch Dose Evaluation
- `POST /predict/batch` — Assesses a list of scheduled doses over the upcoming 24–48 hours for schedule optimization.

---

## 🔒 Security & Privacy

- **Data Privacy**: Patient healthcare identifiers are pseudonymized; machine learning training utilizes synthetic cohorts adhering to medical data protection principles.
- **Firebase Security Rules**: Granular role-based access control configured in `firestore.rules` and `storage.rules` ensuring patient data can only be accessed by authenticated owners and verified caregivers.
- **Environment Isolation**: Production deployments utilize environment variables for `API_KEY` and `FIREBASE_PROJECT_ID`.

---

## 📊 Usability & Clinical Evaluation

MedGuardian underwent structured usability testing with elderly participants and caregivers evaluating:
- **System Usability Scale (SUS)** score targeting an "Acceptable / Excellent" rating.
- **Task Completion Rate** for dose confirmation, medication scheduling, and emergency cancellation.
- **Fall Detection Sensitivity vs. Specificity** balancing rapid response against nuisance alerts.

---

## 👨‍💻 Project Attribution

- **Project**: MedGuardian Final Year Project (FYP)
- **Author**: Theva ([@Thevaaaa](https://github.com/Thevaaaa))
- **Repository**: [MEDGURDIAN---Smart-Medication-Adherence-and-Monitoring-System-for-Elderly-with-Predictive-Analytics](https://github.com/Thevaaaa/MEDGURDIAN---Smart-Medication-Adherence-and-Monitoring-System-for-Elderly-with-Predictive-Analytics)
