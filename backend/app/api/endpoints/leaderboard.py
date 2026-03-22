from fastapi import APIRouter, Depends, Query
from typing import List, Optional
from firebase_admin import firestore
from ...core.firebase import db
from ..dependencies import optional_firebase_token

router = APIRouter(prefix="/leaderboard", tags=["Leaderboard"])

@router.get("/top")
async def get_top_players(
    by: str = Query("level", enum=["level", "coins", "playtime"]),
    limit: int = 10,
    decoded_token: Optional[dict] = Depends(optional_firebase_token)
):
    """
    Returns the top players ranked by the specified criteria AND the current user's standing.
    """
    field_map = {
        "level": "level",
        "coins": "dreamCoins",
        "playtime": "playtime"
    }
    sort_field = field_map.get(by, "level")
    
    # Query Firestore for the top players
    if by == "level":
        users_ref = db.collection('users').order_by("level", direction=firestore.Query.DESCENDING).order_by("xp", direction=firestore.Query.DESCENDING)
    else:
        users_ref = db.collection('users').order_by(sort_field, direction=firestore.Query.DESCENDING)
    
    docs = users_ref.limit(limit).stream()
    
    top_players = []
    rank = 1
    for d in docs:
        u = d.to_dict()
        top_players.append({
            "rank": rank,
            "uid": d.id,
            "displayName": u.get("displayName", "Dreamer"),
            "level": u.get("level", 1),
            "xp": u.get("xp", 0),
            "dreamCoins": u.get("dreamCoins", 0),
            "playtime": u.get("playtime", 0)
        })
        rank += 1
        
    # If not logged in, just return the top players
    if not decoded_token:
        return {"top": top_players, "user": None}

    uid = decoded_token['uid']
    # Now get the current user's standing
    user_doc = db.collection('users').document(uid).get()
    if not user_doc.exists:
        return {"top": top_players, "user": None}
    
    user_data = user_doc.to_dict()
    user_val = user_data.get(sort_field, 0)
    
    # Calculate rank: count users with more value than current user
    if by == "level":
        user_xp = user_data.get("xp", 0)
        # Count users with higher level OR same level but higher XP
        higher_level_count = db.collection('users').where("level", ">", user_data.get("level", 1)).count().get()
        same_level_higher_xp_count = db.collection('users').where("level", "==", user_data.get("level", 1)).where("xp", ">", user_xp).count().get()
        user_rank = higher_level_count[0][0].value + same_level_higher_xp_count[0][0].value + 1
    else:
        higher_val_count = db.collection('users').where(sort_field, ">", user_val).count().get()
        user_rank = higher_val_count[0][0].value + 1
        
    user_standing = {
        "rank": user_rank,
        "uid": uid,
        "displayName": user_data.get("displayName", "You"),
        "level": user_data.get("level", 1),
        "xp": user_data.get("xp", 0),
        "dreamCoins": user_data.get("dreamCoins", 0),
        "playtime": user_data.get("playtime", 0)
    }
        
    return {"top": top_players, "user": user_standing}
