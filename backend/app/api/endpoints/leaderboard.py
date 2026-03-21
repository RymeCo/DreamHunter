from fastapi import APIRouter, Depends, Query
from typing import List, Optional
from firebase_admin import firestore
from ...core.firebase import db
from ..dependencies import verify_firebase_token

router = APIRouter(prefix="/leaderboard", tags=["Leaderboard"])

@router.get("/top")
async def get_top_players(
    by: str = Query("level", enum=["level", "coins", "playtime"]),
    limit: int = 10,
    decoded_token: dict = Depends(verify_firebase_token)
):
    """
    Returns the top players ranked by the specified criteria.
    """
    field_map = {
        "level": "level",
        "coins": "dreamCoins",
        "playtime": "playtime"
    }
    
    # Query Firestore for the top players
    # We order by the field descending and limit the results.
    # Note: For xp within a level, we should ideally order by level then xp.
    if by == "level":
        users_ref = db.collection('users').order_by("level", direction=firestore.Query.DESCENDING).order_by("xp", direction=firestore.Query.DESCENDING)
    else:
        sort_field = field_map.get(by, "level")
        users_ref = db.collection('users').order_by(sort_field, direction=firestore.Query.DESCENDING)
    
    docs = users_ref.limit(limit).stream()
    
    results = []
    rank = 1
    for d in docs:
        u = d.to_dict()
        results.append({
            "rank": rank,
            "uid": d.id,
            "displayName": u.get("displayName", "Dreamer"),
            "level": u.get("level", 1),
            "xp": u.get("xp", 0),
            "dreamCoins": u.get("dreamCoins", 0),
            "playtime": u.get("playtime", 0)
        })
        rank += 1
        
    return results
