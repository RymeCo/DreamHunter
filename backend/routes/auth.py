from fastapi import APIRouter, Depends
from core.security import get_current_user
from services.player_service import PlayerService
from models.player import PlayerModel

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/sync", response_model=PlayerModel)
async def sync_user(uid: str = Depends(get_current_user)):
    """
    Called after login to ensure the player document exists in Firestore.
    """
    return PlayerService.sync_player(uid)
