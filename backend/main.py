from fastapi import FastAPI
from app import database, models, auth
from fastapi.middleware.cors import CORSMiddleware

models.Base.metadata.create_all(bind=database.engine)

app = FastAPI(title="Flutter Fitness Backend")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # for now; later you can restrict to real domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(auth.router)