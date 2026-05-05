from fastapi import APIRouter, Depends, HTTPException, status
from core.security import get_current_user
from services.player_service import PlayerService
from models.player import PlayerModel
from services.settings_service import settings_service

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/sync", response_model=PlayerModel)
async def sync_user(uid: str = Depends(get_current_user)):
    """
    Called after login to ensure the player document exists in Firestore.
    Checks for permanent bans and maintenance mode.
    """
    player = PlayerService.sync_player(uid)
    
    if settings_service.get_settings().get("maintenance_mode", False):
        if player.role != "admin":
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="MAINTENANCE_MODE"
            )

    if player.isBannedPermanent:
        from fastapi import HTTPException, status
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="ACCOUNT_BANNED_PERMANENT"
        )
        
    return player
