import hashlib
from datetime import datetime, timezone, timedelta
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from firebase_admin import firestore
from ...core.firebase import db
from ..dependencies import verify_admin
from ...services.moderation_service import log_audit
from ...models.admin_models import (
    UserBanRequest, UserMuteRequest, UserModeratorRequest, UserWarnRequest,
    UserCurrencyRequest, MaintenanceRequest, BroadcastRequest, AutoModConfigRequest,
    BatchActionRequest, AdminChatMessageRequest, MessageActionRequest, RouletteConfigRequest,
    UserSaveTweakRequest
)
from ...models.economy_models import ShopItemRequest

router = APIRouter(prefix="/admin", tags=["Superadmin"])

INTEGRITY_SALT = "DREAM_HUNTER_SECURE_2026_!#@_S@LT_v1"

def generate_shadow_hash(coins: int, stones: int, xp: int, level: int) -> str:
    data = f"{coins}:{stones}:{xp}:{level}:{INTEGRITY_SALT}"
    return hashlib.sha256(data.encode()).hexdigest()

@router.get("/players/search")
async def search_players(
    query: Optional[str] = None, 
    isBanned: Optional[bool] = None,
    isAdmin: Optional[bool] = None,
    limit: int = 20,
    lastId: Optional[str] = None,
    admin: dict = Depends(verify_admin)
):
    users_ref = db.collection('users').order_by("uid")
    if isBanned is not None:
        users_ref = users_ref.where("isBanned", "==", isBanned)
    if isAdmin is not None:
        users_ref = users_ref.where("isAdmin", "==", isAdmin)
    if lastId:
        last_doc = db.collection('users').document(lastId).get()
        if last_doc.exists:
            users_ref = users_ref.start_after(last_doc)
    docs = list(users_ref.limit(limit).stream())
    results = []
    for d in docs:
        u = d.to_dict()
        if 'uid' not in u: u['uid'] = d.id
        if query:
            q = query.lower()
            if q not in u.get('displayName', '').lower() and \
               q not in u.get('email', '').lower() and \
               q not in u.get('uid', '').lower():
                continue
        results.append(u)
    return results

@router.get("/users/{uid}")
async def get_user_profile(uid: str, admin: dict = Depends(verify_admin)):
    user_doc = db.collection('users').document(uid).get()
    if not user_doc.exists:
        raise HTTPException(status_code=404, detail="Player not found")
    data = user_doc.to_dict()
    if 'uid' not in data: data['uid'] = user_doc.id
    return data

@router.patch("/users/{uid}/ban")
async def ban_user(uid: str, req: UserBanRequest, admin: dict = Depends(verify_admin)):
    user_ref = db.collection('users').document(uid)
    user_doc = user_ref.get()
    if not user_doc.exists: raise HTTPException(status_code=404, detail="User not found")
    target_data = user_doc.to_dict()
    if target_data.get('isAdmin') is True:
        raise HTTPException(status_code=403, detail="Target is a Superadmin and immune to moderation.")
    
    update_data = {
        "isBanned": req.isBanned, 
        "isSuperBanned": req.isSuperBanned,
        "updatedAt": firestore.SERVER_TIMESTAMP
    }
    
    expiry_msg = ""
    if req.isBanned and req.until:
        try:
            dt = datetime.fromisoformat(req.until.replace('Z', '+00:00'))
            update_data["bannedUntil"] = dt
            expiry_msg = f" until {dt.isoformat()}"
        except Exception as e: raise HTTPException(status_code=400, detail=f"Invalid date format: {e}")
    else: 
        update_data["bannedUntil"] = None
    
    user_ref.update(update_data)
    
    # Log the specific type of ban
    status = "UNBANNED"
    if req.isSuperBanned: status = "SUPERBANNED"
    elif req.isBanned: status = "BANNED"
    
    log_audit(admin['uid'], f"USER_{status}", uid, f"Admin set {status} state{expiry_msg}", admin.get('email'), target_data.get('displayName'), target_data.get('email'))
    return {"status": "success", "message": f"User {uid} status updated to {status}{expiry_msg}."}

@router.patch("/users/{uid}/mute")
async def mute_user(uid: str, req: UserMuteRequest, admin: dict = Depends(verify_admin)):
    user_ref = db.collection('users').document(uid)
    user_doc = user_ref.get()
    if not user_doc.exists: raise HTTPException(status_code=404, detail="User not found")
    target_data = user_doc.to_dict()
    if target_data.get('isAdmin') is True:
        raise HTTPException(status_code=403, detail="Target is a Superadmin and immune to moderation.")
    update_data = {"updatedAt": firestore.SERVER_TIMESTAMP}
    log_details = ""
    if req.until:
        try:
            dt = datetime.fromisoformat(req.until.replace('Z', '+00:00'))
            update_data["mutedUntil"] = dt
            log_details = f"Until: {dt.isoformat()}"
        except Exception as e: raise HTTPException(status_code=400, detail=f"Invalid date format: {e}")
    elif req.durationHours is not None:
        if req.durationHours <= 0:
            update_data["mutedUntil"] = None
            log_details = "Unmuted"
        else:
            until = datetime.now(timezone.utc) + timedelta(hours=req.durationHours)
            update_data["mutedUntil"] = until
            log_details = f"Duration: {req.durationHours} hours (Expires: {until.isoformat()})"
    else: raise HTTPException(status_code=400, detail="Either until or durationHours must be provided.")
    user_ref.update(update_data)
    log_audit(admin['uid'], "USER_MUTED" if update_data.get("mutedUntil") else "USER_UNMUTED", uid, log_details, admin.get('email'), target_data.get('displayName'), target_data.get('email'))
    return {"status": "success", "message": "User mute updated.", "mutedUntil": update_data.get("mutedUntil").isoformat() if update_data.get("mutedUntil") else None}

@router.patch("/users/{uid}/role")
async def update_user_role(uid: str, req: UserModeratorRequest, admin: dict = Depends(verify_admin)):
    user_ref = db.collection('users').document(uid)
    user_doc = user_ref.get()
    if not user_doc.exists: raise HTTPException(status_code=404, detail="User not found")
    target_data = user_doc.to_dict()
    if target_data.get('isAdmin') is True:
        raise HTTPException(status_code=403, detail="Target is a Superadmin and immune to moderation.")
    user_ref.update({"isModerator": req.isModerator, "updatedAt": firestore.SERVER_TIMESTAMP})
    status = "GRANTED" if req.isModerator else "REVOKED"
    log_audit(admin['uid'], "MODERATOR_ROLE_UPDATE", uid, f"Moderator powers {status.lower()} by Admin.", admin.get('email'), target_data.get('displayName'), target_data.get('email'))
    return {"status": "success", "message": f"Moderator status for {uid} set to {req.isModerator}."}

@router.post("/users/{uid}/warnings")
async def warn_user(uid: str, req: UserWarnRequest, admin: dict = Depends(verify_admin)):
    user_ref = db.collection('users').document(uid)
    user_doc = user_ref.get()
    if not user_doc.exists: raise HTTPException(status_code=404, detail="User not found")
    target_data = user_doc.to_dict()
    if target_data.get('isAdmin') is True:
        raise HTTPException(status_code=403, detail="Target is a Superadmin and immune to moderation.")
    
    current_strikes = target_data.get('strikeCount', 0) + 1
    warning = {
        "reason": req.reason, 
        "timestamp": datetime.now(timezone.utc).isoformat(), 
        "adminUid": admin['uid'],
        "strikeNumber": current_strikes
    }
    
    update_data = {
        "warnings": firestore.ArrayUnion([warning]),
        "strikeCount": current_strikes,
        "updatedAt": firestore.SERVER_TIMESTAMP
    }

    auto_mute_msg = ""
    if current_strikes >= 3:
        # Auto-mute for 24 hours on 3rd strike
        mute_until = datetime.now(timezone.utc) + timedelta(hours=24)
        update_data["mutedUntil"] = mute_until
        update_data["strikeCount"] = 0 # Reset strikes after punishment? Or keep them? 
        # Mandate says: "3 warning strikes trigger automatic 24h mute". 
        # Usually strikes reset or decrement. Let's reset for now to allow a fresh start after 24h.
        auto_mute_msg = " [AUTO-MOD: 3 Strikes reached. 24h Mute applied.]"

    user_ref.update(update_data)
    
    log_audit(admin['uid'], "USER_WARNED", uid, f"Warning #{current_strikes}: {req.reason}{auto_mute_msg}", admin.get('email'), target_data.get('displayName'), target_data.get('email'))
    
    return {
        "status": "success", 
        "message": f"Warning issued. Current strikes: {current_strikes % 3 if current_strikes < 3 else 0}.{auto_mute_msg}",
        "strikeCount": current_strikes,
        "autoMuted": current_strikes >= 3
    }

@router.patch("/users/{uid}/currency")
async def update_user_currency(uid: str, req: UserCurrencyRequest, admin: dict = Depends(verify_admin)):
    user_ref = db.collection('users').document(uid)
    user_doc = user_ref.get()
    if not user_doc.exists: raise HTTPException(status_code=404, detail="User not found")
    target_data = user_doc.to_dict()
    
    coins = req.dreamCoins if req.dreamCoins is not None else target_data.get('dreamCoins', 0)
    stones = req.hellStones if req.hellStones is not None else target_data.get('hellStones', 0)
    xp = target_data.get('xp', 0)
    level = target_data.get('level', 1)
    
    # Recalculate shadowHash to bypass integrity checks
    new_hash = generate_shadow_hash(coins, stones, xp, level)
    
    update_data = {
        "dreamCoins": coins,
        "lastKnownDreamCoins": coins,
        "hellStones": stones,
        "lastKnownHellStones": stones,
        "shadowHash": new_hash,
        "lastAction": "Your balance has been adjusted by an administrator.",
        "updatedAt": firestore.SERVER_TIMESTAMP
    }
    
    user_ref.update(update_data)
    log_audit(admin['uid'], "USER_CURRENCY_UPDATE", uid, f"Currency updated: DC={coins}, HS={stones}", admin.get('email'), target_data.get('displayName'), target_data.get('email'))
    return {"status": "success", "message": "Currency updated and integrity hash recalculated."}

@router.post("/users/{uid}/tweak")
async def tweak_user(uid: str, req: UserSaveTweakRequest, admin: dict = Depends(verify_admin)):
    user_ref = db.collection('users').document(uid)
    user_doc = user_ref.get()
    if not user_doc.exists: raise HTTPException(status_code=404, detail="User not found")
    target_data = user_doc.to_dict()

    # Calculations
    if req.mode == "add":
        coins = target_data.get('dreamCoins', 0) + (req.dreamCoins or 0)
        stones = target_data.get('hellStones', 0) + (req.hellStones or 0)
        xp = target_data.get('xp', 0) + (req.xp or 0)
        level = target_data.get('level', 1) + (req.level or 0)
    else: # Override
        coins = req.dreamCoins if req.dreamCoins is not None else target_data.get('dreamCoins', 0)
        stones = req.hellStones if req.hellStones is not None else target_data.get('hellStones', 0)
        xp = req.xp if req.xp is not None else target_data.get('xp', 0)
        level = req.level if req.level is not None else target_data.get('level', 1)

    # Integrity
    new_hash = generate_shadow_hash(coins, stones, xp, level)

    tweak_payload = {
        "dreamCoins": coins,
        "hellStones": stones,
        "xp": xp,
        "level": level,
        "mode": req.mode,
        "reason": req.reason,
        "adminEmail": admin.get('email'),
        "timestamp": datetime.now(timezone.utc).isoformat()
    }

    update_data = {
        "dreamCoins": coins,
        "lastKnownDreamCoins": coins,
        "hellStones": stones,
        "lastKnownHellStones": stones,
        "xp": xp,
        "level": level,
        "shadowHash": new_hash,
        "lastAction": "ADMIN_TWEAK",
        "tweakData": tweak_payload,
        "lastProcessedTweakTimestamp": "", # Reset to ensure client sees it
        "updatedAt": firestore.SERVER_TIMESTAMP
    }

    user_ref.update(update_data)
    log_audit(admin['uid'], "USER_SAVE_TWEAK", uid, f"Tweak ({req.mode}): DC={coins}, HS={stones}, XP={xp}, LV={level}", admin.get('email'), target_data.get('displayName'), target_data.get('email'))
    
    return {
        "status": "success", 
        "message": f"User save tweaked successfully in {req.mode} mode.",
        "newData": {
            "dreamCoins": coins,
            "hellStones": stones,
            "xp": xp,
            "level": level
        }
    }

@router.post("/users/{uid}/reset-spam")
async def reset_spam_score(uid: str, admin: dict = Depends(verify_admin)):
    user_ref = db.collection('users').document(uid)
    user_doc = user_ref.get()
    if not user_doc.exists: raise HTTPException(status_code=404, detail="User not found")
    target_data = user_doc.to_dict()
    user_ref.update({
        "spamScore": 0,
        "isFlagged": False,
        "updatedAt": firestore.SERVER_TIMESTAMP
    })
    log_audit(admin['uid'], "RESET_SPAM_SCORE", uid, "Admin reset user spam score and unflagged them.", admin.get('email'), target_data.get('displayName'), target_data.get('email'))
    return {"status": "success", "message": "Spam score reset and user unflagged."}

@router.patch("/maintenance")
async def update_maintenance(req: MaintenanceRequest, admin: dict = Depends(verify_admin)):
    update_data = {k: v for k, v in req.model_dump(exclude_none=True).items()}
    if not update_data: return {"status": "success", "message": "No changes requested."}
    db.collection('metadata').document('system_config').set(update_data, merge=True)
    log_audit(admin['uid'], "MAINTENANCE_TOGGLE", details=str(update_data), admin_email=admin.get('email'))
    return {"status": "success", "config": update_data}

@router.post("/broadcast")
async def post_broadcast(req: BroadcastRequest, admin: dict = Depends(verify_admin)):
    broadcast_data = {"message": req.message, "isPersistent": req.isPersistent, "senderUid": admin['uid'], "timestamp": firestore.SERVER_TIMESTAMP}
    db.collection('metadata').document('global_alert').set(broadcast_data)
    log_audit(admin['uid'], "GLOBAL_BROADCAST", details=req.message, admin_email=admin.get('email'))
    return {"status": "success", "broadcast": broadcast_data}

@router.post("/chats/message/send")
async def send_chat_message(req: AdminChatMessageRequest, admin: dict = Depends(verify_admin)):
    msg_ref = db.collection('chats').document(req.region).collection('messages').document()
    msg_data = {
        "id": msg_ref.id,
        "senderUid": "SYSTEM" if req.isSystem else admin['uid'],
        "senderName": req.senderName,
        "text": req.text,
        "timestamp": firestore.SERVER_TIMESTAMP,
        "isGhost": req.isGhost,
        "isSystem": req.isSystem,
        "isAdmin": True,
        "region": req.region
    }
    msg_ref.set(msg_data)
    log_audit(admin['uid'], "ADMIN_CHAT_MSG", req.region, f"Sent to {req.region}: {req.text}", admin.get('email'))
    return {"status": "success", "messageId": msg_ref.id}

@router.post("/chats/message/action")
async def take_message_action(req: MessageActionRequest, admin: dict = Depends(verify_admin)):
    msg_ref = db.collection('chats').document(req.region).collection('messages').document(req.messageId)
    
    update_data = {"updatedAt": firestore.SERVER_TIMESTAMP}
    action_log = ""

    if req.action == "delete":
        update_data["isDeleted"] = req.value
        action_log = "DELETED" if req.value else "RESTORED"
    elif req.action == "flag":
        update_data["isFlagged"] = req.value
        action_log = "FLAGGED" if req.value else "UNFLAGGED"
    elif req.action == "like":
        # Supports both admin and moderator likes if we want to distinguish later
        update_data["isLikedByAdmin"] = req.value
        action_log = "LIKED" if req.value else "UNLIKED"
    elif req.action == "hide":
        update_data["isDislikedByAdmin"] = req.value # or isHidden
        action_log = "HIDDEN" if req.value else "UNHIDDEN"
    else:
        raise HTTPException(status_code=400, detail="Invalid action")
    
    msg_ref.update(update_data)
    log_audit(admin['uid'], f"CHAT_MSG_{action_log}", req.messageId, f"Action on {req.region} message: {req.messageId}", admin.get('email'))
    return {"status": "success", "message": f"Message {req.messageId} {action_log.lower()}."}

@router.get("/reports")
async def get_reports(status: Optional[str] = None, admin: dict = Depends(verify_admin)):
    q = db.collection('reports')
    if status: q = q.where("status", "==", status)
    docs = list(q.order_by("reportTimestamp", direction=firestore.Query.DESCENDING).limit(100).stream())
    return [{"id": d.id, **d.to_dict()} for d in docs]

@router.patch("/reports/{report_id}")
async def update_report_status(report_id: str, status: str, admin: dict = Depends(verify_admin)):
    if status not in ['pending', 'working', 'resolved', 'archived']:
        raise HTTPException(status_code=400, detail="Invalid status.")
    db.collection('reports').document(report_id).update({"status": status, "updatedAt": firestore.SERVER_TIMESTAMP})
    log_audit(admin['uid'], "REPORT_STATUS_UPDATE", report_id, f"New Status: {status}", admin_email=admin.get('email'))
    return {"status": "success", "message": f"Report {report_id} updated to {status}."}

@router.patch("/automod/config")
async def update_automod_config(req: AutoModConfigRequest, admin: dict = Depends(verify_admin)):
    update_data = {k: v for k, v in req.model_dump(exclude_none=True).items()}
    if not update_data: return {"status": "success", "message": "No changes requested."}
    db.collection('metadata').document('moderation_config').set(update_data, merge=True)
    log_audit(admin['uid'], "AUTOMOD_CONFIG_UPDATE", details=str(update_data), admin_email=admin.get('email'))
    return {"status": "success", "config": update_data}

@router.get("/stats/summary")
async def get_stats_summary(admin: dict = Depends(verify_admin)):
    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    last_24h = now - timedelta(hours=24)

    reports_ref = db.collection('reports')
    pending = reports_ref.where("status", "==", "pending").count().get()[0].value
    working = reports_ref.where("status", "==", "working").count().get()[0].value
    resolved = reports_ref.where("status", "==", "resolved").count().get()[0].value
    
    total_users = db.collection('users').count().get()[0].value
    
    # Calculate real growth
    try:
        new_today_res = db.collection('users').where("createdAt", ">=", today_start).count().get()
        new_today = new_today_res[0].value
    except:
        new_today = 0
        
    try:
        dau_res = db.collection('users').where("updatedAt", ">=", last_24h).count().get()
        dau = dau_res[0].value
    except:
        dau = 0

    # System Health Simulation
    import random
    latency = 20.0 + random.uniform(5.0, 35.0)
    
    # Count errors in logs
    try:
        error_res = db.collection('audit_logs').where("timestamp", ">=", last_24h).where("action", "==", "ERROR").count().get()
        error_count = error_res[0].value
    except:
        error_count = 0

    return {
        "reportStats": {"pending": pending, "working": working, "resolved": resolved},
        "systemHealth": {
            "latency": round(latency, 1), 
            "errorCount": error_count, 
            "status": "Healthy" if error_count < 5 else "Warning" if error_count < 15 else "Critical"
        },
        "userGrowth": {
            "total": total_users, 
            "newToday": new_today, 
            "dau": max(dau, new_today, 1) # Ensure at least 1 (the current admin)
        }
    }

@router.patch("/users/batch-action")
async def batch_action(req: BatchActionRequest, admin: dict = Depends(verify_admin)):
    batch = db.batch()
    update_data = {"updatedAt": firestore.SERVER_TIMESTAMP}
    if req.action == "ban":
        update_data["isBanned"] = True
        if req.params and req.params.get("until"):
            update_data["bannedUntil"] = datetime.fromisoformat(req.params["until"].replace('Z', '+00:00'))
    elif req.action == "unban":
        update_data["isBanned"] = False
        update_data["bannedUntil"] = None
    elif req.action == "mute":
        if req.params and req.params.get("until"):
            update_data["mutedUntil"] = datetime.fromisoformat(req.params["until"].replace('Z', '+00:00'))
        elif req.params and req.params.get("durationHours"):
            update_data["mutedUntil"] = datetime.now(timezone.utc) + timedelta(hours=int(req.params["durationHours"]))
    elif req.action == "unmute": update_data["mutedUntil"] = None
    else: raise HTTPException(status_code=400, detail="Invalid action")
    for uid in req.uids:
        user_doc = db.collection('users').document(uid).get()
        if user_doc.exists and user_doc.to_dict().get('isAdmin') is True: continue
        batch.update(db.collection('users').document(uid), update_data)
    batch.commit()
    log_audit(admin['uid'], f"BATCH_{req.action.upper()}", details=f"Batch {req.action} on {len(req.uids)} users.", admin_email=admin.get('email'))
    return {"status": "success", "count": len(req.uids)}

@router.get("/audit-logs")
async def get_audit_logs(admin: dict = Depends(verify_admin)):
    docs = list(db.collection('audit_logs').order_by("timestamp", direction=firestore.Query.DESCENDING).limit(100).stream())
    return [d.to_dict() for d in docs]

@router.post("/shop")
async def add_shop_item(item: ShopItemRequest, admin: dict = Depends(verify_admin)):
    item_ref = db.collection('shop_items').document()
    item_data = item.model_dump()
    item_data['id'] = item_ref.id
    item_data['createdAt'] = firestore.SERVER_TIMESTAMP
    item_ref.set(item_data)
    return {"status": "success", "itemId": item_ref.id}

@router.get("/roulette/config")
async def get_roulette_config(admin: dict = Depends(verify_admin)):
    doc = db.collection('metadata').document('roulette_config').get()
    return doc.to_dict() if doc.exists else {"rewards": [], "dailyFreeSpins": 1, "maxFreeSpins": 10, "spinBuyPrice": 50, "spinBuyCurrency": "dreamCoins"}

@router.post("/roulette/config")
async def update_roulette_config(req: RouletteConfigRequest, admin: dict = Depends(verify_admin)):
    db.collection('metadata').document('roulette_config').set(req.model_dump())
    log_audit(admin['uid'], "UPDATE_ROULETTE_CONFIG", details=f"Daily spins: {req.dailyFreeSpins}", admin_email=admin.get('email'))
    return {"status": "success", "message": "Roulette configuration updated"}
