from fastapi import APIRouter, HTTPException, Depends, status
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
import secrets, os, hashlib, bcrypt
from . import database, models, email_utils, jwt_handler
from dotenv import load_dotenv
from pydantic import BaseModel

load_dotenv()
router = APIRouter()
PEPPER = os.getenv("PEPPER")

if not PEPPER:
    raise RuntimeError("PEPPER environment variable must be set.")


def _prepare_password(password: str) -> bytes:
    # Combine user password with the pepper and hash before bcrypt
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


class RegisterRequest(BaseModel):
    email: str
    username: str
    password: str

class LoginRequest(BaseModel):
    email: str
    password: str

class ForgotPasswordRequest(BaseModel):
    email: str

class ResetPasswordRequest(BaseModel):
    new_password: str

class DeleteAccountRequest(BaseModel):
    email: str


@router.post("/register")
def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    if db.query(models.User).filter_by(email=payload.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")

    hashed_pw = _hash_password(payload.password)
    token = secrets.token_urlsafe(32)
    user = models.User(email=payload.email, username=payload.username, password=hashed_pw, verification_token=token)
    db.add(user)
    db.commit()

    verify_link = f"https://mobile-devices-project.onrender.com/verify/{token}"
    email_utils.send_email(payload.email, "Verify your account", f"Click to verify: {verify_link}")
    return JSONResponse(content={"message": "Verification email sent"}, status_code=status.HTTP_201_CREATED)

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
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(models.User).filter_by(email=payload.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if not user.is_verified:
        raise HTTPException(status_code=401, detail="Email not verified")
    if not _verify_password(payload.password, user.password):
        raise HTTPException(status_code=401, detail="Incorrect password")
    token = jwt_handler.create_token(payload.email)
    return {"token": token}

@router.post("/forgot-password")
def forgot_password(payload: ForgotPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(models.User).filter_by(email=payload.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="Email not found")
    token = secrets.token_urlsafe(32)
    user.reset_token = token
    db.commit()
    email_utils.send_email(payload.email, "Password reset", f"Here is your reset token: {token}")
    return {"message": "Reset link sent"}

@router.post("/reset-password/{token}")
def reset_password(token: str, payload: ResetPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(models.User).filter_by(reset_token=token).first()
    if not user:
        raise HTTPException(status_code=400, detail="Invalid token")
    user.password = _hash_password(payload.new_password)
    user.reset_token = None
    db.commit()
    return {"message": "Password updated"}


@router.delete("/delete-account")
@router.delete("/delete-account/")
def delete_account(payload: DeleteAccountRequest | None = None, email: str | None = None, db: Session = Depends(get_db)):
    target_email = (payload.email if payload else None) or email
    if not target_email:
        raise HTTPException(status_code=400, detail="Email is required")

    user = db.query(models.User).filter_by(email=target_email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Remove any associated data first (currently food logs keyed by user email)
    db.query(models.FoodLog).filter_by(user=target_email).delete()
    db.delete(user)
    db.commit()
    return {"message": "Account and related data deleted"}
