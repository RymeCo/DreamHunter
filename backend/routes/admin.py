from fastapi import APIRouter, Depends, HTTPException, Query, Body, status
from typing import List, Optional
from core.security import get_admin_user
from core.firebase import db
from models.player import PlayerModel

router = APIRouter(prefix="/admin", tags=["admin"])

@router.get("/players/search")
async def search_players(
    q: str = Query(..., min_length=2),
    uid: str = Depends(get_admin_user)
):
    """
    Searches for players by name or UID.
    Returns a lightweight summary to minimize database costs.
    """
    results = []
    
    # 1. Search by exact UID
    uid_doc = db.collection("players").document(q).get()
    if uid_doc.exists:
        p = uid_doc.to_dict()
        results.append({
            "uid": p.get("uid"),
            "name": p.get("name"),
            "level": p.get("level", 1),
            "role": p.get("role", "player")
        })

    # 2. Search by Name (Prefix Search)
    # Note: Firestore doesn't support full-text search without external tools.
    # This prefix search is a 0-cost compromise.
    name_query = db.collection("players") \
        .where("name", ">=", q) \
        .where("name", "<=", q + "\uf8ff") \
        .limit(20).stream()
    
    for doc in name_query:
        p = doc.to_dict()
        # Avoid duplicating the UID result
        if not any(r["uid"] == p.get("uid") for r in results):
            results.append({
                "uid": p.get("uid"),
                "name": p.get("name"),
                "level": p.get("level", 1),
                "role": p.get("role", "player")
            })

    return results

@router.get("/players/{player_uid}", response_model=PlayerModel)
async def get_player_details(
    player_uid: str,
    uid: str = Depends(get_admin_user)
):
    """
    Fetches the absolute latest player profile for editing.
    """
    doc = db.collection("players").document(player_uid).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Player not found")
    return doc.to_dict()

@router.patch("/players/{player_uid}")
async def update_player(
    player_uid: str,
    uid: str = Depends(get_admin_user),
    data: dict = Body(...)
):
    """
    Updates player stats or moderation status.
    Irreversible changes; frontend must confirm first.
    """
    allowed_keys = [
        "coins", "stones", "level", "role",
        "isBannedPermanent", "isBannedFromChat", "isBannedFromLeaderboard"
    ]
    
    update_data = {k: v for k, v in data.items() if k in allowed_keys}
    if not update_data:
        raise HTTPException(status_code=400, detail="No valid update fields provided")

    db.collection("players").document(player_uid).set(update_data, merge=True)
    return {"status": "success", "updated": list(update_data.keys())}
