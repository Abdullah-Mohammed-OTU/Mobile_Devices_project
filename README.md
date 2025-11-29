# Mobile Devices Project

Project for CSCI4100U that pairs a FastAPI backend with a Flutter mobile client.

## Getting Started

### Backend (FastAPI)
- Login logic is also deployed at `https://mobile-devices-project.onrender.com` (used by the app by default). The service may sleep when idle; if login fails, visit that URL in a browser, wait for the JSON `{"message": "API is running!"}`, then try logging in again. If it still fails, run the backend locally using the steps below.
- Ensure you have Python 3.10+.
- Create a virtual environment and install dependencies:
  - `cd backend`
  - `python -m venv .venv`
  - `source .venv/bin/activate` (Windows: `.venv\Scripts\activate`)
  - `pip install -r requirements.txt`
- Run the API:
  - `uvicorn main:app --reload`
- The server listens at `http://localhost:8000`.

### Frontend (Flutter)
- Install Flutter 3.19+ and confirm `flutter doctor` passes.
- From the project root:
  - `cd project`
  - `flutter pub get`
  - `flutter run`
- The app expects the backend to be running locally at `http://localhost:8000` for authentication.
- Login screen offers navigation to create an account, request a reset email, and enter a reset token to finalize a new password through the FastAPI endpoints.

## How It Works
- **FastAPI backend** has authentication endpoints (`/register`, `/verify/{token}`, `/login`, `/forgot-password`, `/reset-password/{token}`) and uses an SQLite database via SQLAlchemy.
- **Email verification** uses SMTP credentials from `.env`; registration sends a verification link and password resets send a recovery token.
- **JWT issuance** happens on successful login; the backend signs tokens with `JWT_SECRET` and the Flutter app stores the token in memory for the active session.
- **Flutter client** starts on the login screen, posts credentials to `/login`, and switches to the main dashboard once a token is returned.
- **Logout** clears the in-memory token and returns the user to the login page.
