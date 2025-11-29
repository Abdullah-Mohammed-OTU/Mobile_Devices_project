import base64
import os
from email.mime.text import MIMEText
from typing import Dict

from dotenv import load_dotenv
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

load_dotenv()

GMAIL_SENDER = os.getenv("GMAIL_SENDER")
GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID")
GOOGLE_CLIENT_SECRET = os.getenv("GOOGLE_CLIENT_SECRET")
GOOGLE_REFRESH_TOKEN = os.getenv("GOOGLE_REFRESH_TOKEN")
GMAIL_SCOPES = ["https://www.googleapis.com/auth/gmail.send"]

if not all([GMAIL_SENDER, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REFRESH_TOKEN]):
    raise RuntimeError(
        "GMAIL_SENDER, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, and GOOGLE_REFRESH_TOKEN must be set."
    )


def _build_gmail_service():
    # Use a long-lived refresh token to obtain an access token on demand.
    credentials = Credentials(
        token=None,
        refresh_token=GOOGLE_REFRESH_TOKEN,
        token_uri="https://oauth2.googleapis.com/token",
        client_id=GOOGLE_CLIENT_ID,
        client_secret=GOOGLE_CLIENT_SECRET,
        scopes=GMAIL_SCOPES,
    )
    credentials.refresh(Request())
    return build("gmail", "v1", credentials=credentials)


def _create_message(recipient: str, subject: str, body: str) -> Dict[str, str]:
    msg = MIMEText(body)
    msg["From"] = GMAIL_SENDER
    msg["To"] = recipient
    msg["Subject"] = subject
    raw = base64.urlsafe_b64encode(msg.as_bytes()).decode("utf-8")
    return {"raw": raw}


def send_email(recipient: str, subject: str, body: str):
    service = _build_gmail_service()
    message = _create_message(recipient, subject, body)
    service.users().messages().send(userId="me", body=message).execute()
