# Mobile Devices Project

Project for CSCI4100U that pairs a FastAPI backend with a Flutter mobile client.

## Getting Started

### Backend (FastAPI)
- Ensure you have Python 3.10+.
- Create a virtual environment and install dependencies:
  - `cd backend`
  - `python -m venv .venv`
  - `source .venv/bin/activate` (Windows: `.venv\Scripts\activate`)
  - `pip install -r requirements.txt`
- Create a `.env` file in `backend/` with the required values:
  - `DATABASE_URL=sqlite:///./users.db` (or your database connection string)
  - `PEPPER=<random string>`
  - `JWT_SECRET=<random string>`
  - `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS` (for email delivery)
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
- **FastAPI backend** exposes authentication endpoints (`/register`, `/verify/{token}`, `/login`, `/forgot-password`, `/reset-password/{token}`) backed by an SQLite database via SQLAlchemy.
- **Email verification** uses SMTP credentials from `.env`; registration sends a verification link and password resets send a recovery link.
- **JWT issuance** happens on successful login; the backend signs tokens with `JWT_SECRET` and the Flutter app stores the token in memory for the active session.
- **Flutter client** starts on the login screen, posts credentials to `/login`, and switches to the main dashboard once a token is returned.
- **Logout** clears the in-memory token and returns the user to the login page.
