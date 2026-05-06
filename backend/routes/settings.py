from fastapi import APIRouter, Depends, Body
from core.security import get_admin_user
from services.settings_service import settings_service
from core.firebase import db

router = APIRouter(prefix="/settings", tags=["settings"])

@router.get("")
async def get_settings(uid: str = Depends(get_admin_user)):
    """
    Fetches all global system settings.
    Only accessible to admins.
    """
    return settings_service.get_settings()

@router.patch("")
async def update_settings(
    uid: str = Depends(get_admin_user),
    data: dict = Body(...)
):
    """
    Updates global system settings in Firestore.
    Only accessible to admins.
    The SettingsService listener will automatically update the local cache.
    """
    # Filter allowed keys to prevent arbitrary document writes
    allowed_keys = [
        "chat_enabled", 
        "maintenance_mode", 
        "leaderboard_paused", 
        "leaderboard_disabled",
        "backup_disabled"
    ]
    update_data = {k: v for k, v in data.items() if k in allowed_keys}
    
    if update_data:
        db.collection("system").document("config").set(update_data, merge=True)
    
    return settings_service.get_settings()
