from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field

from . import database, models


router = APIRouter(prefix="/food", tags=["food"])


def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()


class FoodLogRequest(BaseModel):
    user: str = Field(..., min_length=1)
    food_name: str = Field(..., min_length=1)
    calories: float = Field(..., gt=0)
    date: date


@router.post("/log")
def create_food_log(payload: FoodLogRequest, db: Session = Depends(get_db)):
    try:
        entry = models.FoodLog(
            user=payload.user,
            food_name=payload.food_name,
            calories=payload.calories,
            date=payload.date,
        )
        db.add(entry)
        db.commit()
        db.refresh(entry)
        return {
            "id": entry.id,
            "user": entry.user,
            "food_name": entry.food_name,
            "calories": entry.calories,
            "date": entry.date.isoformat(),
        }
    except Exception:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to save food log entry")
