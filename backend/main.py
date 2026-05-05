from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes import auth, profile, leaderboard, chat, settings, admin
from services.player_service import PlayerService
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from datetime import datetime
import pytz

app = FastAPI(title="DreamHunter API", version="1.0.0")

scheduler = BackgroundScheduler()
pht = pytz.timezone('Asia/Manila')

def scheduled_leaderboard_refresh():
    print(f"[{datetime.now()}] Running scheduled leaderboard refresh...")
    PlayerService.refresh_leaderboards()

scheduler.add_job(
    scheduled_leaderboard_refresh,
    CronTrigger(hour=0, minute=0, second=1, timezone=pht)
)
scheduler.start()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api")
app.include_router(profile.router, prefix="/api")
app.include_router(leaderboard.router, prefix="/api")
app.include_router(chat.router, prefix="/api")
app.include_router(settings.router, prefix="/api")
app.include_router(admin.router, prefix="/api")

@app.api_route("/", methods=["GET", "HEAD"])
async def root():
    return {"message": "Welcome to the DreamHunter API", "status": "online"}
