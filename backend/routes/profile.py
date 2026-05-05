from fastapi import APIRouter, Depends, HTTPException, status
from core.security import get_current_user
from services.player_service import PlayerService
from models.player import PlayerModel
from services.settings_service import settings_service

router = APIRouter(prefix="/profile", tags=["profile"])

@router.get("", response_model=PlayerModel)
async def get_profile(uid: str = Depends(get_current_user)):
    """
    Fetches the authenticated user's profile.
    """
    player = PlayerService.get_player(uid)
    if not player:
        raise HTTPException(status_code=404, detail="Player not found")
    return player

@router.patch("/update", response_model=PlayerModel)
async def update_profile(data: dict, uid: str = Depends(get_current_user)):
    """
    Updates specific fields of the player profile.
    Check if backup is globally disabled first.
    """
    if settings_service.get_settings().get("backup_disabled", False):
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="BACKUP_DISABLED"
        )
        
    return PlayerService.update_player(uid, data)
