from fastapi import APIRouter, Depends, HTTPException, Query, Body, status
from typing import List, Optional
from core.security import get_admin_user
from core.firebase import db, auth_client

router = APIRouter(prefix="/admin", tags=["admin"])

@router.get("/players/search")
async def search_players(
    q: str = Query(..., min_length=2),
    uid: str = Depends(get_admin_user)
):
    """
    Searches for players by name, UID, or Email.
    Uses Firebase Auth for O(0-cost) email lookup when possible.
    """
    results = []
    
    # 1. Search by exact UID
    uid_doc = db.collection("players").document(q).get()
    if uid_doc.exists:
        p = uid_doc.to_dict()
        results.append({
            "uid": p.get("uid"),
            "name": p.get("name"),
            "email": p.get("email"),
            "level": p.get("level", 1),
            "role": p.get("role", "player")
        })

    # 2. Search by exact Email (O(1) with Auth API - 0 cost)
    if "@" in q:
        try:
            user = auth_client.get_user_by_email(q)
            if not any(r["uid"] == user.uid for r in results):
                p_doc = db.collection("players").document(user.uid).get()
                if p_doc.exists:
                    p = p_doc.to_dict()
                    results.append({
                        "uid": p.get("uid"),
                        "name": p.get("name"),
                        "email": p.get("email"),
                        "level": p.get("level", 1),
                        "role": p.get("role", "player")
                    })
        except Exception:
            pass # Email not found in Auth

    # 3. Search by Name (Prefix Search)
    name_query = db.collection("players") \
        .where("name", ">=", q) \
        .where("name", "<=", q + "\uf8ff") \
        .limit(20).stream()
    
    for doc in name_query:
        p = doc.to_dict()
        if not any(r["uid"] == p.get("uid") for r in results):
            results.append({
                "uid": p.get("uid"),
                "name": p.get("name"),
                "email": p.get("email"),
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
