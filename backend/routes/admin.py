from fastapi import APIRouter, Depends, HTTPException, Query, Body, status
from typing import List, Optional
from core.security import get_admin_user
from core.firebase import db, auth_client
from datetime import datetime
from models.player import PlayerModel
from services.player_service import PlayerService

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
    results = {} 
    
    uid_doc = db.collection("players").document(q).get()
    if uid_doc.exists:
        p = uid_doc.to_dict()
        results[p["uid"]] = _format_player_summary(p)

    if "@" in q and len(results) < 20:
        try:
            user = auth_client.get_user_by_email(q)
            if user.uid not in results:
                p_doc = db.collection("players").document(user.uid).get()
                if p_doc.exists:
                    results[user.uid] = _format_player_summary(p_doc.to_dict())
        except Exception:
            pass 

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

@router.patch("/players/{player_uid}")
async def update_player_admin(
    player_uid: str,
    data: dict = Body(...),
    uid: str = Depends(get_admin_user)
):
    """
    Updates player data from the admin panel.
    """
    return PlayerService.update_player(player_uid, data)

@router.get("/leaderboard")
async def get_leaderboard_admin(
    uid: str = Depends(get_admin_user)
):
    """
    Returns the cached leaderboard data.
    """
    return PlayerService.get_leaderboard_cache()

from routes.chat import manager
from services.settings_service import settings_service

@router.get("/system/health")
async def get_system_health(uid: str = Depends(get_admin_user)):
    try:
        player_count = db.collection("players").count().get()[0][0].value
    except Exception:
        player_count = 0
        
    try:
        verified_count = db.collection("players").where("isVerified", "==", True).count().get()[0][0].value
    except Exception:
        verified_count = 0

    unverified_count = max(0, player_count - verified_count)

    try:
        banned_count = db.collection("players").where("isBannedPermanent", "==", True).count().get()[0][0].value
    except Exception:
        banned_count = 0

    today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
    try:
        new_today = db.collection("players").where("createdAt", ">=", today_start).count().get()[0][0].value
    except Exception:
        new_today = 0

    active_chats = sum(len(conns) for conns in manager.active_connections.values())
    regions_active = len([r for r, c in manager.active_connections.items() if len(c) > 0])

    settings = settings_service.get_settings()

    return {
        "status": "online",
        "totalPlayers": player_count,
        "verifiedPlayers": verified_count,
        "unverifiedPlayers": unverified_count,
        "bannedPlayers": banned_count,
        "newPlayersToday": new_today,
        "activeChatConnections": active_chats,
        "activeRegions": regions_active,
        "maintenanceMode": settings.get("maintenance_mode", False),
        "leaderboardPaused": settings.get("leaderboard_paused", False),
        "chatEnabled": settings.get("chat_enabled", True),
        "timestamp": datetime.now().isoformat()
    }

@router.get("/system/announcement")
async def get_announcement(uid: str = Depends(get_admin_user)):
    """
    Fetches the current daily announcement and rules.
    """
    doc = db.collection("metadata").document("announcements").get()
    if doc.exists:
        return doc.to_dict()
    return {
        "daily_message": "Welcome to DreamHunter!",
        "rules": [
            "1. Be respectful to others.",
            "2. No spamming or advertising.",
            "3. Keep it family friendly."
        ]
    }

@router.patch("/system/announcement")
async def update_announcement(
    uid: str = Depends(get_admin_user),
    data: dict = Body(...)
):
    """
    Updates the daily announcement and rules.
    """
    db.collection("metadata").document("announcements").set(data, merge=True)
    return {"status": "ok", "message": "Announcement updated"}
