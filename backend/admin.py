import os
from datetime import datetime, timezone, timedelta
from typing import Optional, List
from fastapi import APIRouter, HTTPException, Depends, Header
from pydantic import BaseModel
from firebase_admin import auth, firestore

router = APIRouter(prefix="/admin", tags=["Superadmin"])

# --- Models ---

class UserBanRequest(BaseModel):
    isBanned: bool
    until: Optional[str] = None # ISO format string for temporary bans

class UserMuteRequest(BaseModel):
    durationHours: Optional[int] = None # 0 to unmute
    until: Optional[str] = None # ISO format string for custom durations

class MaintenanceRequest(BaseModel):
    chatMaintenance: Optional[bool] = None
    shopMaintenance: Optional[bool] = None

class BroadcastRequest(BaseModel):
    message: str
    isPersistent: bool = False

class AutoModConfigRequest(BaseModel):
    autoModEnabled: Optional[bool] = None
    moderationLevel: Optional[str] = None
    decayDays: Optional[int] = None
    strike1Action: Optional[str] = None
    strike1DurationHours: Optional[int] = None
    strike2Action: Optional[str] = None
    strike2DurationHours: Optional[int] = None
    strike3Action: Optional[str] = None
    strike3DurationHours: Optional[int] = None

class BatchActionRequest(BaseModel):
    uids: List[str]
    action: str # 'ban', 'unban', 'mute', 'unmute'
    params: Optional[dict] = None

# --- Dependencies ---

async def verify_admin(authorization: Optional[str] = Header(None)):
    """
    Dependency to check if the user is an admin.
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization header")
    
    token = authorization.split("Bearer ")[1]
    try:
        decoded_token = auth.verify_id_token(token)
        uid = decoded_token['uid']
        
        # Check environment variable
        admin_uids = os.getenv("ADMIN_UIDS", "").split(",")
        if uid in admin_uids:
            return decoded_token
            
        # Check Firestore
        db = firestore.client()
        user_doc = db.collection('users').document(uid).get()
        if user_doc.exists and user_doc.to_dict().get('isAdmin', False):
            return decoded_token
            
        raise HTTPException(status_code=403, detail="Admin privileges required")
    except Exception:
        raise HTTPException(status_code=403, detail="Admin privileges required")

# --- Helper Functions ---

def log_audit(
    admin_uid: str, 
    action: str, 
    target: Optional[str] = None, 
    details: Optional[str] = None, 
    admin_email: Optional[str] = None,
    target_name: Optional[str] = None,
    target_email: Optional[str] = None
):
    """Log an administrative action to the audit_logs collection."""
    db = firestore.client()
    db.collection('audit_logs').add({
        "adminUid": admin_uid,
        "adminEmail": admin_email,
        "action": action,
        "target": target,
        "targetName": target_name,
        "targetEmail": target_email,
        "details": details,
        "timestamp": firestore.SERVER_TIMESTAMP
    })

# --- Endpoints ---

@router.get("/players/search")
async def search_players(
    query: Optional[str] = None, 
    isBanned: Optional[bool] = None,
    isAdmin: Optional[bool] = None,
    admin: dict = Depends(verify_admin)
):
    """Advanced player search with filtering."""
    db = firestore.client()
    users_ref = db.collection('users')
    
    # Apply indexed filters directly in Firestore query
    if isBanned is not None:
        users_ref = users_ref.where("isBanned", "==", isBanned)
    if isAdmin is not None:
        users_ref = users_ref.where("isAdmin", "==", isAdmin)
        
    # Limit base results to prevent overhead
    docs = list(users_ref.limit(200).stream())
    results = []
    
    for d in docs:
        u = d.to_dict()
        if 'uid' not in u:
            u['uid'] = d.id
            
        if query:
            q = query.lower()
            # If search query provided, filter in-memory for flexible match
            if q not in u.get('displayName', '').lower() and \
               q not in u.get('email', '').lower() and \
               q not in u.get('uid', '').lower():
                continue
        
        results.append(u)
        
    return results

@router.get("/users/{uid}")
async def get_user_profile(uid: str, admin: dict = Depends(verify_admin)):
    """Fetch a single player's profile by UID."""
    db = firestore.client()
    user_doc = db.collection('users').document(uid).get()
    
    if not user_doc.exists:
        raise HTTPException(status_code=404, detail="Player not found")
        
    data = user_doc.to_dict()
    if 'uid' not in data:
        data['uid'] = user_doc.id
        
    return data

@router.patch("/users/{uid}/ban")
async def ban_user(uid: str, req: UserBanRequest, admin: dict = Depends(verify_admin)):
    db = firestore.client()
    user_ref = db.collection('users').document(uid)
    
    # Verify user exists before update
    user_doc = user_ref.get()
    if not user_doc.exists:
        raise HTTPException(status_code=404, detail="User not found")
    
    target_data = user_doc.to_dict()
    target_name = target_data.get('displayName', 'Unknown')
    target_email = target_data.get('email', 'No Email')

    update_data = {
        "isBanned": req.isBanned,
        "updatedAt": firestore.SERVER_TIMESTAMP
    }
    
    expiry_msg = ""
    if req.isBanned and req.until:
        try:
            # Parse provided ISO string and ensure UTC
            dt = datetime.fromisoformat(req.until.replace('Z', '+00:00'))
            update_data["bannedUntil"] = dt
            expiry_msg = f" until {dt.isoformat()}"
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Invalid date format: {e}")
    else:
        update_data["bannedUntil"] = None

    user_ref.update(update_data)
    
    status = "BANNED" if req.isBanned else "UNBANNED"
    log_audit(
        admin_uid=admin['uid'], 
        admin_email=admin.get('email'),
        action=f"USER_{status}", 
        target=uid, 
        target_name=target_name,
        target_email=target_email,
        details=f"Admin {admin['uid']} set isBanned to {req.isBanned}{expiry_msg}"
    )
    return {"status": "success", "message": f"User {uid} has been {status.lower()}{expiry_msg}."}

@router.patch("/users/{uid}/mute")
async def mute_user(uid: str, req: UserMuteRequest, admin: dict = Depends(verify_admin)):
    db = firestore.client()
    user_ref = db.collection('users').document(uid)
    
    user_doc = user_ref.get()
    if not user_doc.exists:
        raise HTTPException(status_code=404, detail="User not found")
    
    target_data = user_doc.to_dict()
    target_name = target_data.get('displayName', 'Unknown')
    target_email = target_data.get('email', 'No Email')

    update_data = {
        "updatedAt": firestore.SERVER_TIMESTAMP
    }
    
    log_details = ""
    
    if req.until:
        try:
            dt = datetime.fromisoformat(req.until.replace('Z', '+00:00'))
            update_data["mutedUntil"] = dt
            log_details = f"Until: {dt.isoformat()}"
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Invalid date format: {e}")
    elif req.durationHours is not None:
        if req.durationHours <= 0:
            update_data["mutedUntil"] = None
            log_details = "Unmuted"
        else:
            until = datetime.now(timezone.utc) + timedelta(hours=req.durationHours)
            update_data["mutedUntil"] = until
            log_details = f"Duration: {req.durationHours} hours (Expires: {until.isoformat()})"
    else:
        raise HTTPException(status_code=400, detail="Either until or durationHours must be provided.")

    user_ref.update(update_data)
    
    log_audit(
        admin_uid=admin['uid'], 
        admin_email=admin.get('email'),
        action="USER_MUTED" if update_data.get("mutedUntil") else "USER_UNMUTED", 
        target=uid, 
        target_name=target_name,
        target_email=target_email,
        details=log_details
    )
    return {
        "status": "success", 
        "message": f"User mute updated.",
        "mutedUntil": update_data.get("mutedUntil").isoformat() if update_data.get("mutedUntil") else None
    }

@router.patch("/maintenance")
async def update_maintenance(req: MaintenanceRequest, admin: dict = Depends(verify_admin)):
    """Toggle maintenance modes for Chat or Shop."""
    db = firestore.client()
    update_data = {}
    if req.chatMaintenance is not None:
        update_data['chatMaintenance'] = req.chatMaintenance
    if req.shopMaintenance is not None:
        update_data['shopMaintenance'] = req.shopMaintenance
        
    if not update_data:
        return {"status": "success", "message": "No changes requested."}
        
    db.collection('metadata').document('system_config').set(update_data, merge=True)
    log_audit(admin['uid'], "MAINTENANCE_TOGGLE", details=str(update_data), admin_email=admin.get('email'))
    return {"status": "success", "config": update_data}

@router.post("/broadcast")
async def post_broadcast(req: BroadcastRequest, admin: dict = Depends(verify_admin)):
    """Send a global alert banner to all users."""
    db = firestore.client()
    broadcast_data = {
        "message": req.message,
        "isPersistent": req.isPersistent,
        "senderUid": admin['uid'],
        "timestamp": firestore.SERVER_TIMESTAMP
    }
    db.collection('metadata').document('global_alert').set(broadcast_data)
    log_audit(admin['uid'], "GLOBAL_BROADCAST", details=req.message, admin_email=admin.get('email'))
    return {"status": "success", "broadcast": broadcast_data}

@router.get("/reports")
async def get_reports(status: Optional[str] = None, admin: dict = Depends(verify_admin)):
    """Fetch reports by status lifecycle."""
    db = firestore.client()
    q = db.collection('reports')
    if status:
        q = q.where("status", "==", status)
    
    docs = list(q.order_by("reportTimestamp", direction=firestore.Query.DESCENDING).limit(100).stream())
    return [{"id": d.id, **d.to_dict()} for d in docs]

@router.patch("/reports/{report_id}")
async def update_report_status(report_id: str, status: str, admin: dict = Depends(verify_admin)):
    valid_statuses = ['pending', 'working', 'resolved', 'archived']
    if status not in valid_statuses:
        raise HTTPException(status_code=400, detail="Invalid status.")
        
    db = firestore.client()
    db.collection('reports').document(report_id).update({
        "status": status,
        "updatedAt": firestore.SERVER_TIMESTAMP
    })
    log_audit(admin['uid'], "REPORT_STATUS_UPDATE", report_id, f"New Status: {status}", admin_email=admin.get('email'))
    return {"status": "success", "message": f"Report {report_id} updated to {status}."}

@router.patch("/automod/config")
async def update_automod_config(req: AutoModConfigRequest, admin: dict = Depends(verify_admin)):
    """Customize the Auto-Moderation Strike System."""
    db = firestore.client()
    update_data = {}
    for field, value in req.model_dump(exclude_none=True).items():
        update_data[field] = value
        
    if not update_data:
        return {"status": "success", "message": "No changes requested."}
        
    db.collection('metadata').document('moderation_config').set(update_data, merge=True)
    log_audit(admin['uid'], "AUTOMOD_CONFIG_UPDATE", details=str(update_data), admin_email=admin.get('email'))
    return {"status": "success", "config": update_data}

@router.get("/stats/summary")
async def get_stats_summary(admin: dict = Depends(verify_admin)):
    """Consolidated summary for dashboard visuals."""
    db = firestore.client()
    
    # 1. Report Stats (Optimized with Aggregations)
    reports_ref = db.collection('reports')
    
    pending_count = reports_ref.where("status", "==", "pending").count().get()
    working_count = reports_ref.where("status", "==", "working").count().get()
    resolved_count = reports_ref.where("status", "==", "resolved").count().get()
    
    pending = pending_count[0][0].value
    working = working_count[0][0].value
    resolved = resolved_count[0][0].value
    
    # 2. User Growth Stats
    users_ref = db.collection('users')
    total_users = users_ref.count().get()[0][0].value
    
    # Mock DAU and New Today for now (In production, use indexed timestamps)
    new_today = 5 
    dau = 12
    
    # 3. System Health (Mock / Placeholder)
    latency = 45.5
    error_count = 0

    return {
        "reportStats": {
            "pending": pending,
            "working": working,
            "resolved": resolved
        },
        "systemHealth": {
            "latency": latency,
            "errorCount": error_count,
            "status": "Healthy" if latency < 200 else "Degraded"
        },
        "userGrowth": {
            "total": total_users,
            "newToday": new_today,
            "dau": dau
        }
    }

@router.patch("/users/batch-action")
async def batch_action(req: BatchActionRequest, admin: dict = Depends(verify_admin)):
    """Perform a moderation action on multiple players at once."""
    db = firestore.client()
    batch = db.batch()
    
    update_data = {"updatedAt": firestore.SERVER_TIMESTAMP}
    log_msg = f"Batch {req.action.upper()} on {len(req.uids)} users."
    
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
    elif req.action == "unmute":
        update_data["mutedUntil"] = None
    else:
        raise HTTPException(status_code=400, detail="Invalid action")

    for uid in req.uids:
        batch.update(db.collection('users').document(uid), update_data)
        
    batch.commit()
    
    log_audit(
        admin_uid=admin['uid'],
        admin_email=admin.get('email'),
        action=f"BATCH_{req.action.upper()}",
        details=f"{log_msg} Params: {req.params}"
    )
    
    return {"status": "success", "count": len(req.uids)}

@router.get("/audit-logs")
async def get_audit_logs(admin: dict = Depends(verify_admin)):
    """Retrieve history of all administrative actions."""
    db = firestore.client()
    docs = list(db.collection('audit_logs').order_by("timestamp", direction=firestore.Query.DESCENDING).limit(100).stream())
    return [d.to_dict() for d in docs]
