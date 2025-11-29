from sqlalchemy import Column, Integer, String, Boolean, Float, Date
from .database import Base

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    username = Column(String, unique=True)
    password = Column(String)
    is_verified = Column(Boolean, default=False)
    verification_token = Column(String, nullable=True)
    reset_token = Column(String, nullable=True)


class FoodLog(Base):
    __tablename__ = "food_logs"
    id = Column(Integer, primary_key=True, index=True)
    user = Column(String, index=True, nullable=False)
    food_name = Column(String, nullable=False)
    calories = Column(Float, nullable=False)
    date = Column(Date, nullable=False)
