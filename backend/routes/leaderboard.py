from fastapi import APIRouter, Depends, HTTPException
from core.security import get_current_user
from services.player_service import PlayerService
from models.player import LeaderboardCache

router = APIRouter(prefix="/leaderboard", tags=["leaderboard"])

@router.get("", response_model=LeaderboardCache)
async def get_leaderboard():
    """
    Fetches the daily cached leaderboard.
    """
    return PlayerService.get_leaderboard_cache()

@router.post("/refresh", include_in_schema=False)
async def manual_refresh(uid: str = Depends(get_current_user)):
    """
    Internal endpoint to force a refresh (to be called by scheduler).
    In a real app, this should be protected by an API Key or Admin role.
    """
    return PlayerService.refresh_leaderboards()
