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
async def manual_refresh():
    """
    Internal endpoint to force a refresh.
    Temporarily unprotected for manual trigger.
    """
    return PlayerService.refresh_leaderboards()
