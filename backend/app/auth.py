from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
import secrets, os, hashlib, bcrypt
from . import database, models, email_utils, jwt_handler
from dotenv import load_dotenv

load_dotenv()
router = APIRouter()
PEPPER = os.getenv("PEPPER")

if not PEPPER:
    raise RuntimeError("PEPPER environment variable must be set.")


def _prepare_password(password: str) -> bytes:
    """Combine user password with the pepper and hash before bcrypt."""
    combined = f"{password}{PEPPER}".encode("utf-8")
    return hashlib.sha256(combined).digest()


def _hash_password(password: str) -> str:
    return bcrypt.hashpw(_prepare_password(password), bcrypt.gensalt()).decode("utf-8")


def _verify_password(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(_prepare_password(password), hashed.encode("utf-8"))

def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.get("/")
def root():
    return {"message": "API is running!"}

@router.post("/register")
def register(email: str, username: str, password: str, db: Session = Depends(get_db)):
    if db.query(models.User).filter_by(email=email).first():
        raise HTTPException(status_code=400, detail="Email already registered")

    hashed_pw = _hash_password(password)
    token = secrets.token_urlsafe(32)
    user = models.User(email=email, username=username, password=hashed_pw, verification_token=token)
    db.add(user)
    db.commit()

    verify_link = f"http://localhost:8000/verify/{token}"
    email_utils.send_email(email, "Verify your account", f"Click to verify: {verify_link}")
    return {"message": "Verification email sent"}

@router.get("/verify/{token}")
def verify(token: str, db: Session = Depends(get_db)):
    user = db.query(models.User).filter_by(verification_token=token).first()
    if not user:
        raise HTTPException(status_code=400, detail="Invalid token")
    user.is_verified = True
    user.verification_token = None
    db.commit()
    return {"message": "Account verified"}

@router.post("/login")
def login(email: str, password: str, db: Session = Depends(get_db)):
    user = db.query(models.User).filter_by(email=email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if not user.is_verified:
        raise HTTPException(status_code=401, detail="Email not verified")
    if not _verify_password(password, user.password):
        raise HTTPException(status_code=401, detail="Incorrect password")
    token = jwt_handler.create_token(email)
    return {"token": token}

@router.post("/forgot-password")
def forgot_password(email: str, db: Session = Depends(get_db)):
    user = db.query(models.User).filter_by(email=email).first()
    if not user:
        raise HTTPException(status_code=404, detail="Email not found")
    token = secrets.token_urlsafe(32)
    user.reset_token = token
    db.commit()
    reset_link = f"http://localhost:8000/reset-password/{token}"
    email_utils.send_email(email, "Password reset", f"Click to reset your password: {reset_link}")
    return {"message": "Reset link sent"}

@router.post("/reset-password/{token}")
def reset_password(token: str, new_password: str, db: Session = Depends(get_db)):
    user = db.query(models.User).filter_by(reset_token=token).first()
    if not user:
        raise HTTPException(status_code=400, detail="Invalid token")
    user.password = _hash_password(new_password)
    user.reset_token = None
    db.commit()
    return {"message": "Password updated"}
