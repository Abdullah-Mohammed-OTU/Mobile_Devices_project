from fastapi import FastAPI
from app import database, models, auth

models.Base.metadata.create_all(bind=database.engine)

app = FastAPI(title="Flutter Fitness Backend")
app.include_router(auth.router)