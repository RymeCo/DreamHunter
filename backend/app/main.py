import json
from datetime import datetime, timezone
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware

from .core.config import settings
from .core.firebase import db
from .api.endpoints import user, economy, chat, admin

class CustomJSONResponse(JSONResponse):
    def render(self, content: Any) -> bytes:
        def serialize(obj):
            if isinstance(obj, datetime):
                return obj.isoformat()
            return str(obj)

        return json.dumps(
            content,
            ensure_ascii=False,
            allow_nan=False,
            indent=None,
            separators=(",", ":"),
            default=serialize,
        ).encode("utf-8")

app = FastAPI(
    title=settings.PROJECT_NAME, 
    default_response_class=CustomJSONResponse
)

# Enable CORS for Flutter web/local development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Routers
app.include_router(user.router)
app.include_router(economy.router)
app.include_router(chat.router)
app.include_router(admin.router)

@app.get("/")
@app.head("/")
async def root():
    """Health check endpoint for Render deployment."""
    return {"status": "ok", "message": f"{settings.PROJECT_NAME} is running"}

@app.get("/health")
async def health_check():
    """Detailed health check for monitoring."""
    try:
        # Check Firestore connectivity
        db.collection('metadata').document('system_config').get()
        return {
            "status": "ok",
            "db": "up",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Service Unavailable: {str(e)}")

async def initialize_firestore():
    """Ensures critical metadata and config documents exist in Firestore."""
    print("Checking Firestore initialization...")
    
    # 1. System Config
    sys_ref = db.collection('metadata').document('system_config')
    if not sys_ref.get().exists:
        sys_ref.set({
            "chatMaintenance": False,
            "shopMaintenance": False,
            "lastInitialized": datetime.now(timezone.utc).isoformat()
        })
        print("Initialized metadata/system_config")

    # 2. Moderation Config
    mod_ref = db.collection('metadata').document('moderation_config')
    if not mod_ref.get().exists:
        mod_ref.set({
            "autoModEnabled": True,
            "decayDays": 30,
            "strike3Action": "mute",
            "strike3DurationHours": 24,
            "bannedWords": ["****"],
            "modCanMute": True,
            "modCanWarn": True,
            "modCanHideMessages": True
        })
        print("Initialized metadata/moderation_config")

@app.on_event("startup")
async def startup_event():
    await initialize_firestore()
