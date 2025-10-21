import smtplib, os
from email.mime.text import MIMEText
from dotenv import load_dotenv

load_dotenv()
SMTP_USER = os.getenv("SMTP_USER")
SMTP_PASS = os.getenv("SMTP_PASS")
SMTP_HOST = os.getenv("SMTP_HOST")
SMTP_PORT = int(os.getenv("SMTP_PORT", 587))

def send_email(recipient, subject, body):
    msg = MIMEText(body)
    msg["From"] = SMTP_USER
    msg["To"] = recipient
    msg["Subject"] = subject

    with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
        server.starttls()
        server.login(SMTP_USER, SMTP_PASS)
        server.send_message(msg)