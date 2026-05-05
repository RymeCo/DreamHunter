from fastapi import APIRouter, Depends, HTTPException
from core.security import get_current_user, get_admin_user
from services.player_service import PlayerService
from models.player import LeaderboardCache
from services.settings_service import settings_service

router = APIRouter(prefix="/leaderboard", tags=["leaderboard"])

@router.get("", response_model=LeaderboardCache)
async def get_leaderboard():
    """
    Fetches the daily cached leaderboard.
    """
    settings = settings_service.get_settings()
    
    # 1. If Disabled: Return empty data (No one shows up)
    if settings.get("leaderboard_disabled", False):
        return {
            "lastUpdated": "",
            "topLevels": [],
            "topCoins": []
        }
        
    # 2. If Paused: Just return the cache (last people are still there, but not updating)
    return PlayerService.get_leaderboard_cache()

@router.get("/health")
async def health_check():
    return {"status": "ok", "message": "Leaderboard router is active"}

@router.post("/refresh", include_in_schema=False)
async def manual_refresh(uid: str = Depends(get_admin_user)):
    """
    Internal endpoint to force a refresh.
    Only accessible to admins.
    """
    try:
        return PlayerService.refresh_leaderboards()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/clear", include_in_schema=False)
async def clear_leaderboard(
    metric: str, # "level" or "coins"
    uid: str = Depends(get_admin_user)
):
    """
    Clears the specified leaderboard metric in the cache.
    Only accessible to admins.
    """
    if metric not in ["level", "coins"]:
        raise HTTPException(status_code=400, detail="Invalid metric. Use 'level' or 'coins'.")
    
    try:
        return PlayerService.clear_leaderboard(metric)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
