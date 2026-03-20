import os
import json
import re
from datetime import datetime, timezone, timedelta
from typing import Optional, List, Any

from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv

# Load environment variables for local development
load_dotenv()

# Initialize Firebase BEFORE including admin router
import firebase_admin
from firebase_admin import credentials, auth, firestore

service_account_env = os.getenv("FIREBASE_SERVICE_ACCOUNT")

if service_account_env:
    try:
        cred_dict = json.loads(service_account_env)
        cred = credentials.Certificate(cred_dict)
        firebase_admin.initialize_app(cred)
    except Exception as e:
        print(f"Error initializing Firebase from ENV: {e}")
elif os.path.exists("serviceAccountKey.json"):
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
else:
    try:
        firebase_admin.initialize_app()
    except Exception as e:
        print("Firebase could not be initialized. Please check your service account configuration.")

from admin import router as admin_router

class CustomJSONResponse(JSONResponse):
    def render(self, content: Any) -> bytes:
        def serialize(obj):
            if isinstance(obj, datetime):
                return obj.isoformat()
            return str(obj)

        return json.dumps(
            content,
            ensure_ascii=False,
            allow_nan=False,
            indent=None,
            separators=(",", ":"),
            default=serialize,
        ).encode("utf-8")

app = FastAPI(title="DreamHunter API", default_response_class=CustomJSONResponse)
app.include_router(admin_router)

@app.get("/")
@app.head("/")
async def root():
    """Health check endpoint for Render deployment."""
    return {"status": "ok", "message": "DreamHunter API is running"}

@app.get("/health")
async def health_check():
    """Detailed health check for monitoring."""
    try:
        # Check Firestore connectivity
        db.collection('metadata').document('system_config').get()
        return {
            "status": "ok",
            "db": "up",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Service Unavailable: {str(e)}")

# Enable CORS for Flutter web/local development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

db = firestore.client()

# --- Models ---

class ChatMessage(BaseModel):
    text: str
    senderDevice: str

class ReportRequest(BaseModel):
    reportedMessageId: str
    originalMessageText: str
    senderId: str
    senderDevice: str
    reporterId: str
    messageTimestamp: str
    categories: List[str]
    reporterEmail: Optional[str] = None

class SyncRequest(BaseModel):
    dreamCoins: int
    hellStones: int

# --- Economy Constants ---
MAX_DREAM_COINS_PER_HOUR = 5000
HELL_TO_DREAM_RATE = 100

# --- Dependencies ---

async def verify_firebase_token(authorization: Optional[str] = Header(None)):
    """
    Dependency to verify the Firebase ID Token sent from the Flutter app.
    Expects header: Authorization: Bearer <ID_TOKEN>
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization header")
    
    token = authorization.split("Bearer ")[1]
    try:
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired Firebase token")

# --- Firestore Initialization ---

async def initialize_firestore():
    """Ensures critical metadata and config documents exist in Firestore."""
    print("Checking Firestore initialization...")
    
    # 1. System Config
    sys_ref = db.collection('metadata').document('system_config')
    if not sys_ref.get().exists:
        sys_ref.set({
            "chatMaintenance": False,
            "shopMaintenance": False,
            "lastInitialized": datetime.now(timezone.utc).isoformat()
        })
        print("Initialized metadata/system_config")

    # 2. Moderation Config
    mod_ref = db.collection('metadata').document('moderation_config')
    if not mod_ref.get().exists:
        mod_ref.set({
            "autoModEnabled": True,
            "decayDays": 30,
            "strike3Action": "mute",
            "strike3DurationHours": 24,
            "bannedWords": ["****"], # Default placeholder
            "modCanMute": True,
            "modCanWarn": True,
            "modCanHideMessages": True
        })
        print("Initialized metadata/moderation_config")

@app.on_event("startup")
async def startup_event():
    await initialize_firestore()

# --- Email Notification Helper ---

def send_urgent_report_email(report_id: str, message_text: str):
    """Placeholder for sending urgent email notifications."""
    # In production, use smtplib or a service like Resend/SendGrid.
    # For now, we log it to the console (visible in Render logs).
    print(f"!!! URGENT REPORT [{report_id}] !!!")
    print(f"Message Content: {message_text}")
    print("Action Required: Check Admin Dashboard immediately.")

# --- Endpoints ---

@app.get("/user/profile")
async def get_user_profile_data(decoded_token: dict = Depends(verify_firebase_token)):
    """
    Fetches user data from Firestore using UID. 
    Unified with Admin profile logic but accessible to normal users.
    """
    uid = decoded_token['uid']
    display_name = decoded_token.get('name', 'Dreamer')
    email = decoded_token.get('email')
    
    user_ref = db.collection('users').document(uid)
    doc = user_ref.get()
    
    if doc.exists:
        data = doc.to_dict()
        if 'uid' not in data:
            data['uid'] = doc.id
        return data
    
    now = datetime.now(timezone.utc)
    default_profile = {
        "uid": uid,
        "email": email,
        "displayName": display_name,
        "playerNumber": None,
        "createdAt": now.isoformat(),
        "isBanned": False,
        "mutedUntil": None,
        "isAdmin": False,
        "isModerator": False,
        "warnings": [],
        "dreamCoins": 0,
        "hellStones": 0,
        "lastKnownDreamCoins": 0,
        "lastKnownHellStones": 0,
        "lastSyncTimestamp": now.isoformat()
    }
    
    db_profile = default_profile.copy()
    db_profile["createdAt"] = firestore.SERVER_TIMESTAMP
    user_ref.set(db_profile)
    
    return default_profile

# --- Store Management ---

class ShopItemRequest(BaseModel):
    name: str
    type: str # character, powerup, item
    price: int
    currencyType: str # coins, tokens
    assetPath: str
    description: str

@app.post("/admin/shop")
async def add_shop_item(item: ShopItemRequest, decoded_token: dict = Depends(verify_firebase_token)):
    admin_uid = decoded_token['uid']
    admin_doc = db.collection('users').document(admin_uid).get()
    if not admin_doc.exists or not admin_doc.to_dict().get('isAdmin', False):
        raise HTTPException(status_code=403, detail="Admin privileges required.")
    
    item_ref = db.collection('shop_items').document()
    item_data = item.model_dump()
    item_data['id'] = item_ref.id
    item_data['createdAt'] = firestore.SERVER_TIMESTAMP
    
    item_ref.set(item_data)
    return {"status": "success", "itemId": item_ref.id}

@app.get("/shop")
async def get_shop_items():
    items = db.collection('shop_items').stream()
    return [item.to_dict() for item in items]

@app.patch("/users/display-name")
async def patch_user_display_name(name: str, decoded_token: dict = Depends(verify_firebase_token)):
    uid = decoded_token['uid']
    db.collection('users').document(uid).update({"displayName": name})
    return {"status": "success", "displayName": name}

@app.post("/chats/{region}/messages")
async def post_chat_message(region: str, msg: ChatMessage, decoded_token: dict = Depends(verify_firebase_token)):
    uid = decoded_token['uid']
    now = datetime.now(timezone.utc)
    
    user_ref = db.collection('users').document(uid)
    user_doc = user_ref.get()
    
    if not user_doc.exists:
        raise HTTPException(status_code=404, detail="User not found")
    
    user_data = user_doc.to_dict()
    
    # Check if banned
    if user_data.get('isBanned'):
        banned_until = user_data.get('bannedUntil')
        if not banned_until or banned_until.replace(tzinfo=timezone.utc) > now:
            detail = "You are permanently banned."
            if banned_until:
                diff = banned_until.replace(tzinfo=timezone.utc) - now
                hours, remainder = divmod(int(diff.total_seconds()), 3600)
                minutes, _ = divmod(remainder, 60)
                detail = f"You are banned for {hours}h {minutes}m."
            raise HTTPException(status_code=403, detail=detail)
            
    # Check if muted
    muted_until = user_data.get('mutedUntil')
    if muted_until:
        if isinstance(muted_until, str):
            muted_until = datetime.fromisoformat(muted_until.replace('Z', '+00:00'))
        
        if muted_until.replace(tzinfo=timezone.utc) > now:
            diff = muted_until.replace(tzinfo=timezone.utc) - now
            hours, remainder = divmod(int(diff.total_seconds()), 3600)
            minutes, _ = divmod(remainder, 60)
            raise HTTPException(status_code=403, detail=f"You are muted for {hours}h {minutes}m.")

    # --- Auto-Mod Logic ---
    from admin import log_audit # Import here to avoid circular dependencies if any
    
    config_doc = db.collection('metadata').document('moderation_config').get()
    config = config_doc.to_dict() if config_doc.exists else {}
    
    banned_words = config.get('bannedWords', [])
    text = msg.text
    censored_text = text
    hit_blacklist = False
    
    for word in banned_words:
        if word.lower() in text.lower():
            hit_blacklist = True
            # Simple censorship: replace word with asterisks
            censored_text = re.sub(re.escape(word), '*' * len(word), censored_text, flags=re.IGNORECASE)

    if hit_blacklist:
        # Strike logic
        warnings = user_data.get('warnings', [])
        
        # Decay logic: remove old warnings if decayDays is set
        decay_days = config.get('decayDays', 30)
        valid_warnings = []
        for w in warnings:
            w_time = datetime.fromisoformat(w['timestamp'].replace('Z', '+00:00'))
            if (now - w_time).days < decay_days:
                valid_warnings.append(w)
        
        new_warning = {
            "reason": "Automod: Blacklisted word used.",
            "timestamp": now.isoformat(),
            "adminUid": "SYSTEM_AUTOMOD"
        }
        valid_warnings.append(new_warning)
        user_ref.update({"warnings": valid_warnings})
        
        # Check strike count for automatic actions
        strike_count = len(valid_warnings)
        if strike_count >= 3:
            # Auto-ban or Auto-mute based on config
            action = config.get('strike3Action', 'mute')
            duration = config.get('strike3DurationHours', 24)
            until = now + timedelta(hours=duration)
            
            if action == 'ban':
                user_ref.update({"isBanned": True, "bannedUntil": until})
                log_audit(
                    admin_uid="SYSTEM_AUTOMOD",
                    action="AUTOMOD_BAN",
                    target=uid,
                    details=f"User reached {strike_count} strikes. Auto-banned for {duration}h.",
                    target_name=user_data.get('displayName'),
                    target_email=user_data.get('email')
                )
            else:
                user_ref.update({"mutedUntil": until})
                log_audit(
                    admin_uid="SYSTEM_AUTOMOD",
                    action="AUTOMOD_MUTE",
                    target=uid,
                    details=f"User reached {strike_count} strikes. Auto-muted for {duration}h.",
                    target_name=user_data.get('displayName'),
                    target_email=user_data.get('email')
                )
                
    # Save message to Firestore
    message_data = {
        "text": censored_text,
        "senderUid": uid,
        "senderName": user_data.get('displayName', 'Dreamer'),
        "senderDevice": msg.senderDevice,
        "timestamp": firestore.SERVER_TIMESTAMP,
        "isAdmin": user_data.get('isAdmin', False),
        "isModerator": user_data.get('isModerator', False),
        "region": region
    }
    
    db.collection('chats').document(region).collection('messages').add(message_data)
    
    return {"status": "success", "censored": hit_blacklist}

@app.post("/reports")
async def report_content(report: ReportRequest):
    """
    Public endpoint to submit a content report with Anti-Spam and Self-Report protection.
    """
    # 1. Self-Report Check
    if report.reporterId == report.senderId:
        raise HTTPException(status_code=400, detail="You cannot report your own messages.")

    db_client = firestore.client()
    
    # 2. Anti-Spam / Duplicate Check
    # Check if this reporter has already reported this specific message
    existing_reports = db_client.collection('reports') \
        .where("reportedMessageId", "==", report.reportedMessageId) \
        .where("reporterId", "==", report.reporterId) \
        .limit(1).get()
    
    if len(existing_reports) > 0:
        return {"status": "success", "message": "Report already received. Thank you!"}

    # 3. Urgency / Unique Reporter Count
    # Find how many unique reporters have flagged this message
    total_reporters = db_client.collection('reports') \
        .where("reportedMessageId", "==", report.reportedMessageId) \
        .get()
    
    unique_count = len(total_reporters) + 1 # Include this current report
    is_urgent = unique_count >= 5

    now = datetime.now(timezone.utc)
    report_data = report.model_dump()
    report_data["reportTimestamp"] = now.isoformat()
    report_data["status"] = "pending"
    report_data["isUrgent"] = is_urgent
    report_data["reporterCount"] = unique_count
    
    new_report_ref = db_client.collection('reports').document()
    new_report_ref.set(report_data)

    # 4. Auto-Hide & Notification
    if is_urgent:
        send_urgent_report_email(new_report_ref.id, report.originalMessageText)
    
    return {"status": "success", "message": "Report submitted successfully.", "urgent": is_urgent}

class OfflineTransaction(BaseModel):
    id: str
    type: str # PURCHASE, CONVERSION, EARN
    itemId: Optional[str] = None
    dreamDelta: int
    hellDelta: int
    timestamp: str

class ReconcileRequest(BaseModel):
    transactions: List[OfflineTransaction]

@app.post("/economy/reconcile")
async def reconcile_economy(req: ReconcileRequest, decoded_token: dict = Depends(verify_firebase_token)):
    uid = decoded_token['uid']
    user_ref = db.collection('users').document(uid)
    doc = user_ref.get()
    
    if not doc.exists:
        raise HTTPException(status_code=404, detail="User not found")
        
    data = doc.to_dict()
    current_dream = data.get('dreamCoins', 0)
    current_hell = data.get('hellStones', 0)
    
    # Sort transactions by timestamp
    transactions = sorted(req.transactions, key=lambda t: t.timestamp)
    
    # Process each transaction
    total_earned = 0
    for t in transactions:
        if t.type == 'EARN':
            total_earned += t.dreamDelta
        
        current_dream += t.dreamDelta
        current_hell += t.hellDelta
        
        # Prevent negative balances
        if current_dream < 0 or current_hell < 0:
            raise HTTPException(status_code=400, detail=f"Insufficient funds during reconciliation at {t.timestamp}")

    # Security: Earn cap check (simple version for now)
    # In a real app, we'd check timestamps against the last sync
    if total_earned > 10000: # Arbitrary large cap for batch
        from admin import log_audit
        log_audit(
            admin_uid="SYSTEM_SECURITY",
            action="ECONOMY_RECONCILE_ANOMALY",
            target=uid,
            details=f"Large earn in batch: {total_earned}. Flagging for review.",
            target_name=data.get('displayName'),
            target_email=data.get('email')
        )

    # Update state
    now = datetime.now(timezone.utc)
    user_ref.update({
        "dreamCoins": current_dream,
        "hellStones": current_hell,
        "lastKnownDreamCoins": current_dream,
        "lastKnownHellStones": current_hell,
        "lastSyncTimestamp": now.isoformat()
    })
    
    return {
        "status": "success", 
        "dreamCoins": current_dream, 
        "hellStones": current_hell
    }

@app.post("/economy/sync")
async def sync_economy(req: SyncRequest, decoded_token: dict = Depends(verify_firebase_token)):
    uid = decoded_token['uid']
    now = datetime.now(timezone.utc)
    
    user_ref = db.collection('users').document(uid)
    doc = user_ref.get()
    
    if not doc.exists:
        raise HTTPException(status_code=404, detail="User not found")
        
    data = doc.to_dict()
    
    # --- Security Validation ---
    last_sync_str = data.get('lastSyncTimestamp')
    last_dream = data.get('lastKnownDreamCoins', 0)
    
    if last_sync_str:
        last_sync = datetime.fromisoformat(last_sync_str.replace('Z', '+00:00'))
        hours_passed = (now - last_sync).total_seconds() / 3600.0
        time_delta_hours = max(hours_passed, 0.016) # min 1 minute
        
        max_allowed = last_dream + int(MAX_DREAM_COINS_PER_HOUR * time_delta_hours)
        
        if req.dreamCoins > (max_allowed + 500):
            from admin import log_audit
            log_audit(
                admin_uid="SYSTEM_SECURITY",
                action="ECONOMY_ANOMALY",
                target=uid,
                details=f"Anomaly: {req.dreamCoins} requested. Max: {max_allowed}. Reverting to {last_dream}.",
                target_name=data.get('displayName'),
                target_email=data.get('email')
            )
            # Revert to last known safe state
            user_ref.update({
                "dreamCoins": last_dream,
                "lastSyncTimestamp": now.isoformat()
            })
            return {
                "status": "anomaly_detected", 
                "message": "Unusual activity detected.",
                "dreamCoins": last_dream,
                "hellStones": data.get('hellStones', 0)
            }

    # If safe, update
    user_ref.update({
        "dreamCoins": req.dreamCoins,
        "hellStones": req.hellStones,
        "lastKnownDreamCoins": req.dreamCoins,
        "lastKnownHellStones": req.hellStones,
        "lastSyncTimestamp": now.isoformat()
    })
    
    return {"status": "success", "dreamCoins": req.dreamCoins, "hellStones": req.hellStones}

@app.post("/economy/convert")
async def convert_currency(hell_stones: int, decoded_token: dict = Depends(verify_firebase_token)):
    if hell_stones <= 0:
        raise HTTPException(status_code=400, detail="Invalid amount")
        
    uid = decoded_token['uid']
    user_ref = db.collection('users').document(uid)
    doc = user_ref.get()
    
    if not doc.exists:
        raise HTTPException(status_code=404, detail="User not found")
        
    data = doc.to_dict()
    current_hell = data.get('hellStones', 0)
    current_dream = data.get('dreamCoins', 0)
    
    if current_hell < hell_stones:
        raise HTTPException(status_code=400, detail="Insufficient Hell Stones")
        
    new_hell = current_hell - hell_stones
    new_dream = current_dream + (hell_stones * HELL_TO_DREAM_RATE)
    
    user_ref.update({
        "hellStones": new_hell,
        "dreamCoins": new_dream,
        "lastKnownDreamCoins": new_dream,
        "lastKnownHellStones": new_hell,
        "lastSyncTimestamp": datetime.now(timezone.utc).isoformat()
    })
    
    return {"status": "success", "dreamCoins": new_dream, "hellStones": new_hell}

if __name__ == "__main__":
    import uvicorn
    # Render provides the PORT environment variable
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)
