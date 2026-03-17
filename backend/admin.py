import os
from datetime import datetime, timezone, timedelta
from typing import Optional, List
from fastapi import APIRouter, HTTPException, Depends, Header
from pydantic import BaseModel
from firebase_admin import auth, firestore

# Use the same database instance from the main app
db = firestore.client()

router = APIRouter(prefix="/admin", tags=["Superadmin"])

# --- Models ---

class UserBanRequest(BaseModel):
    isBanned: bool

class UserMuteRequest(BaseModel):
    durationHours: int # 0 to unmute

class ChatConfigUpdate(BaseModel):
    archiveMessages: Optional[bool] = None
    moderationTier: Optional[str] = None

class MaintenanceRequest(BaseModel):
    chatMaintenance: Optional[bool] = None
    shopMaintenance: Optional[bool] = None

class BroadcastRequest(BaseModel):
    message: str
    isPersistent: bool = False

class AutoModConfigRequest(BaseModel):
    autoModEnabled: Optional[bool] = None
    violationCategories: Optional[List[str]] = None
    strike1MuteHours: Optional[int] = None
    strike2MuteHours: Optional[int] = None
    strike3Ban: Optional[bool] = None

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
        user_doc = db.collection('users').document(uid).get()
        if user_doc.exists and user_doc.to_dict().get('isAdmin', False):
            return decoded_token
            
        raise HTTPException(status_code=403, detail="Admin privileges required")
    except Exception:
        raise HTTPException(status_code=403, detail="Admin privileges required")

# --- Helper Functions ---

def log_audit(admin_uid: str, action: str, target: Optional[str] = None, details: Optional[str] = None):
    """Log an administrative action to the audit_logs collection."""
    db.collection('audit_logs').add({
        "adminUid": admin_uid,
        "action": action,
        "target": target,
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
    users_ref = db.collection('users')
    
    # Start building query
    q = users_ref
    if isBanned is not None:
        q = q.where("isBanned", "==", isBanned)
    if isAdmin is not None:
        q = q.where("isAdmin", "==", isAdmin)
        
    # Note: Firestore doesn't support easy multi-field text search without Algolia/ElasticSearch.
    # For now, we fetch limited docs and filter in memory for small-scale apps.
    docs = list(q.limit(100).stream())
    results = [d.to_dict() for d in docs]
    
    if query:
        query = query.lower()
        results = [
            u for u in results 
            if query in u.get('displayName', '').lower() or 
               query in u.get('email', '').lower() or 
               query in u.get('uid', '').lower()
        ]
        
    return results

@router.patch("/users/{uid}/ban")
async def ban_user(uid: str, req: UserBanRequest, admin: dict = Depends(verify_admin)):
    db.collection('users').document(uid).update({"isBanned": req.isBanned})
    status = "banned" if req.isBanned else "unbanned"
    log_audit(admin['uid'], f"USER_{status.upper()}", uid)
    return {"status": "success", "message": f"User {uid} has been {status}."}

@router.patch("/users/{uid}/mute")
async def mute_user(uid: str, req: UserMuteRequest, admin: dict = Depends(verify_admin)):
    if req.durationHours <= 0:
        db.collection('users').document(uid).update({"mutedUntil": None})
        log_audit(admin['uid'], "USER_UNMUTED", uid)
        return {"status": "success", "message": f"User {uid} has been unmuted."}
    
    until = datetime.now(timezone.utc) + timedelta(hours=req.durationHours)
    db.collection('users').document(uid).update({"mutedUntil": until})
    log_audit(admin['uid'], "USER_MUTED", uid, f"Duration: {req.durationHours}h")
    return {"status": "success", "message": f"User {uid} has been muted until {until.isoformat()}."}

@router.patch("/maintenance")
async def update_maintenance(req: MaintenanceRequest, admin: dict = Depends(verify_admin)):
    """Toggle maintenance modes for Chat or Shop."""
    update_data = {}
    if req.chatMaintenance is not None:
        update_data['chatMaintenance'] = req.chatMaintenance
    if req.shopMaintenance is not None:
        update_data['shopMaintenance'] = req.shopMaintenance
        
    if not update_data:
        return {"status": "success", "message": "No changes requested."}
        
    db.collection('metadata').document('system_config').set(update_data, merge=True)
    log_audit(admin['uid'], "MAINTENANCE_TOGGLE", details=str(update_data))
    return {"status": "success", "config": update_data}

@router.post("/broadcast")
async def post_broadcast(req: BroadcastRequest, admin: dict = Depends(verify_admin)):
    """Send a global alert banner to all users."""
    broadcast_data = {
        "message": req.message,
        "isPersistent": req.isPersistent,
        "senderUid": admin['uid'],
        "timestamp": firestore.SERVER_TIMESTAMP
    }
    db.collection('metadata').document('global_alert').set(broadcast_data)
    log_audit(admin['uid'], "GLOBAL_BROADCAST", details=req.message)
    return {"status": "success", "broadcast": broadcast_data}

@router.get("/reports")
async def get_reports(status: Optional[str] = None, admin: dict = Depends(verify_admin)):
    """Fetch reports by status lifecycle."""
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
        
    db.collection('reports').document(report_id).update({
        "status": status,
        "updatedAt": firestore.SERVER_TIMESTAMP
    })
    log_audit(admin['uid'], "REPORT_STATUS_UPDATE", report_id, f"New Status: {status}")
    return {"status": "success", "message": f"Report {report_id} updated to {status}."}

@router.patch("/automod/config")
async def update_automod_config(req: AutoModConfigRequest, admin: dict = Depends(verify_admin)):
    """Customize the Auto-Moderation Strike System."""
    update_data = {}
    for field, value in req.model_dump(exclude_none=True).items():
        update_data[field] = value
        
    if not update_data:
        return {"status": "success", "message": "No changes requested."}
        
    db.collection('metadata').document('moderation_config').set(update_data, merge=True)
    log_audit(admin['uid'], "AUTOMOD_CONFIG_UPDATE", details=str(update_data))
    return {"status": "success", "config": update_data}

@router.get("/audit-logs")
async def get_audit_logs(admin: dict = Depends(verify_admin)):
    """Retrieve history of all administrative actions."""
    docs = list(db.collection('audit_logs').order_by("timestamp", direction=firestore.Query.DESCENDING).limit(100).stream())
    return [d.to_dict() for d in docs]
