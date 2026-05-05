# DreamHunter

DreamHunter is an interactive 2D RPG/Adventure game developed using the **Flutter** framework and the **Flame** engine. It features dynamic gameplay elements, integrated user authentication, and persistent cloud storage.

This project is submitted for the Finals in the following subjects:
- Algorithm and Complexity [CS22AX]
- Networking [CS22AX]
- Database Management System [CS22AX]

## Ecosystem

The project consists of three main components:
1. **Frontend (Game):** Developed with Flutter and Flame.
2. **Backend (API):** Built with FastAPI and Python.
3. **Admin Dashboard:** A secondary Flutter application for administration.

## Tech Stack

- **Game Engine:** [Flame](https://flame-engine.org/)
- **Framework:** [Flutter](https://flutter.dev/)
- **Backend:** [FastAPI](https://fastapi.tiangolo.com/), Python
- **Database & Auth:** [Firebase Authentication](https://firebase.google.com/products/auth), [Cloud Firestore](https://firebase.google.com/products/firestore)

## Getting Started

### Prerequisites
- Flutter SDK
- Python 3.10+
- Firebase Project configured

### Installation

**1. Backend Setup**
```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload
```

**2. Frontend (Game) Setup**
```bash
cd frontend
flutter pub get
flutter run
```

**3. Admin App Setup**
```bash
cd admin
flutter pub get
flutter run
```

## Releases
You can find the latest builds in the root directory:
- `DreamHunter.apk` - The main game application.
- `DH-Admin.apk` - The administration dashboard.
