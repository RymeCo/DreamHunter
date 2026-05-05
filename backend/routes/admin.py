from fastapi import APIRouter, Depends, HTTPException, Query, Body, status
from typing import List, Optional
from core.security import get_admin_user
from core.firebase import db, auth_client
from datetime import datetime
from models.player import PlayerModel

router = APIRouter(prefix="/admin", tags=["admin"])

def _format_player_summary(p: dict):
    """Helper to ensure consistent search result structure."""
    return {
        "uid": p.get("uid"),
        "name": p.get("name"),
        "email": p.get("email"),
        "level": p.get("level", 1),
        "role": p.get("role", "player")
    }

@router.get("/players/search")
async def search_players(
    q: str = Query(..., min_length=2),
    uid: str = Depends(get_admin_user)
):
    """
    Searches for players by name, UID, or Email.
    Uses Firebase Auth for O(0-cost) email lookup when possible.
    """
    results = {} # Use dict to deduplicate by UID automatically
    
    # 1. Search by exact UID (O(1) read)
    uid_doc = db.collection("players").document(q).get()
    if uid_doc.exists:
        p = uid_doc.to_dict()
        results[p["uid"]] = _format_player_summary(p)

    # 2. Search by exact Email (O(1) with Auth API - 0 Firestore read for Auth)
    if "@" in q and len(results) < 20:
        try:
            user = auth_client.get_user_by_email(q)
            if user.uid not in results:
                p_doc = db.collection("players").document(user.uid).get()
                if p_doc.exists:
                    results[user.uid] = _format_player_summary(p_doc.to_dict())
        except Exception:
            pass # Email not found in Auth

    # 3. Search by Name (Prefix Search - Lazy)
    if len(results) < 20:
        name_query = db.collection("players") \
            .where("name", ">=", q) \
            .where("name", "<=", q + "\uf8ff") \
            .limit(20).stream()
        
        for doc in name_query:
            p = doc.to_dict()
            if p["uid"] not in results:
                results[p["uid"]] = _format_player_summary(p)
                if len(results) >= 20: break

    # Convert to list and sort by name
    sorted_results = sorted(results.values(), key=lambda x: x["name"].lower())
    return sorted_results

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

from routes.chat import manager

@router.get("/system/health")
async def get_system_health(uid: str = Depends(get_admin_user)):
    """
    Fetches basic system metrics.
    0-cost mindset: Only triggered manually by admins.
    """
    # 1. Registration Count (Rough estimate via Firestore metadata or collection stats)
    # Note: For absolute 0-cost, we could use a counter, but for small-medium scale, 
    # aggregation queries are efficient.
    try:
        # This is a metadata-only operation in many cases or a low-cost aggregation
        player_count = db.collection("players").count().get()[0][0].value
    except Exception:
        player_count = "Unknown"

    # 2. Live Connections (From memory manager - 0 cost)
    active_chats = sum(len(conns) for conns in manager.active_connections.values())
    regions_active = len([r for r, c in manager.active_connections.items() if len(c) > 0])

    return {
        "status": "online",
        "totalPlayers": player_count,
        "activeChatConnections": active_chats,
        "activeRegions": regions_active,
        "timestamp": datetime.now().isoformat()
    }
