import os
import json
from datetime import datetime, timezone, timedelta
from typing import Optional, List

import firebase_admin
from firebase_admin import credentials, auth, firestore
from fastapi import FastAPI, HTTPException, Depends, Header, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv

# Load environment variables for local development
load_dotenv()

app = FastAPI(title="DreamHunter API")

@app.get("/")
@app.head("/")
async def root():
    """Health check endpoint for Render deployment."""
    return {"status": "ok", "message": "DreamHunter API is running"}

# Enable CORS for Flutter web/local development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Firebase
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

class ChatConfigUpdate(BaseModel):
    archiveMessages: Optional[bool] = None
    moderationTier: Optional[str] = None

class UserBanRequest(BaseModel):
    isBanned: bool

class UserMuteRequest(BaseModel):
    durationHours: int # 0 to unmute

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

async def verify_admin(decoded_token: dict = Depends(verify_firebase_token)):
    """
    Dependency to check if the user is an admin.
    For now, we check if the UID is in an admin_uids collection or environment variable.
    """
    # Simple hardcoded check or environment variable check
    admin_uids = os.getenv("ADMIN_UIDS", "").split(",")
    if decoded_token['uid'] not in admin_uids:
        # Check Firestore for admin status as fallback
        user_doc = db.collection('users').document(decoded_token['uid']).get()
        if not user_doc.exists or not user_doc.to_dict().get('isAdmin', False):
            raise HTTPException(status_code=403, detail="Admin privileges required")
    return decoded_token

# --- Helper Functions ---

def enforce_chat_lifecycle(region: str):
    """
    Background task to enforce the 100-message cap per region and 
    handle togglable archival.
    """
    try:
        messages_ref = db.collection('chats').document(region).collection('messages')
        query = messages_ref.order_by("timestamp", direction=firestore.Query.DESCENDING)
        docs = list(query.stream())
        
        if len(docs) > 100:
            docs_to_remove = docs[100:]
            
            config_ref = db.collection('metadata').document('chat_config')
            config_doc = config_ref.get()
            archive_messages = False
            if config_doc.exists:
                archive_messages = config_doc.to_dict().get('archiveMessages', False)
                
            batch = db.batch()
            for doc in docs_to_remove:
                if archive_messages:
                    archive_ref = db.collection('chat_archives').document(region).collection('messages').document(doc.id)
                    batch.set(archive_ref, doc.to_dict())
                batch.delete(doc.reference)
            batch.commit()
    except Exception as e:
        print(f"Error enforcing chat lifecycle: {e}")


# --- Endpoints ---

@app.get("/user/profile")
async def get_user_profile(decoded_token: dict = Depends(verify_firebase_token)):
    """
    Fetches user data from Firestore using UID. 
    Includes migration logic for legacy displayName-keyed documents.
    """
    uid = decoded_token['uid']
    display_name = decoded_token.get('name', 'Dreamer')
    email = decoded_token.get('email')
    
    user_ref = db.collection('users').document(uid)
    doc = user_ref.get()
    
    if doc.exists:
        return doc.to_dict()
    
    legacy_ref = db.collection('users').document(display_name)
    legacy_doc = legacy_ref.get()
    
    if legacy_doc.exists:
        legacy_data = legacy_doc.to_dict()
        user_ref.set(legacy_data)
        legacy_ref.delete()
        return legacy_data

    now = datetime.now(timezone.utc)
    default_profile = {
        "uid": uid,
        "email": email,
        "displayName": display_name,
        "playerNumber": None,
        "createdAt": now.isoformat(),
        "isBanned": False,
        "mutedUntil": None,
        "isAdmin": False
    }
    
    db_profile = default_profile.copy()
    db_profile["createdAt"] = firestore.SERVER_TIMESTAMP
    user_ref.set(db_profile)
    
    return default_profile

@app.patch("/users/display-name")
async def patch_user_display_name(name: str, decoded_token: dict = Depends(verify_firebase_token)):
    uid = decoded_token['uid']
    db.collection('users').document(uid).update({"displayName": name})
    return {"status": "success", "displayName": name}

@app.post("/chats/{region}/messages")
async def post_chat_message(
    region: str, 
    message: ChatMessage, 
    background_tasks: BackgroundTasks,
    decoded_token: dict = Depends(verify_firebase_token)
):
    """
    Sends a message to the specified regional chat.
    Enforces a 1-second spam cooldown using a Firestore transaction.
    """
    uid = decoded_token['uid']
    now_ts = datetime.now(timezone.utc).timestamp()
    
    # Use a transaction to check spam and post message
    transaction = db.transaction()
    user_ref = db.collection('users').document(uid)

    @firestore.transactional
    def send_in_transaction(transaction, user_ref, msg_text, device):
        snapshot = user_ref.get(transaction=transaction)
        user_data = snapshot.to_dict() if snapshot.exists else {}
        
        # 1. Ban/Mute Checks
        if user_data.get('isBanned', False):
            raise HTTPException(status_code=403, detail="You are permanently banned from Global Chat.")
        
        muted_until = user_data.get('mutedUntil')
        if muted_until:
            # Handle both ISO string and Firestore Timestamp
            if isinstance(muted_until, str):
                until_dt = datetime.fromisoformat(muted_until.replace('Z', '+00:00'))
            else:
                # Firestore returns datetime objects already
                until_dt = muted_until 
                
            if datetime.now(timezone.utc) < until_dt:
                raise HTTPException(status_code=403, detail=f"You are muted until {until_dt.strftime('%Y-%m-%d %H:%M:%S')} UTC.")

        # 2. Spam Cooldown
        last_msg_at = user_data.get('lastMessageAt', 0)
        if now_ts - last_msg_at < 1.0:
            raise HTTPException(status_code=429, detail="Please wait before sending another message.")
        
        display_name = user_data.get('displayName', 'Dreamer')
        
        # Update user's last message time
        transaction.update(user_ref, {'lastMessageAt': now_ts})
        
        # Construct message
        new_msg = {
            "text": msg_text,
            "senderUid": uid,
            "senderName": display_name,
            "senderDevice": device,
            "timestamp": firestore.SERVER_TIMESTAMP
        }
        
        chat_ref = db.collection('chats').document(region).collection('messages').document()
        transaction.set(chat_ref, new_msg)
        return chat_ref.id

    try:
        msg_id = send_in_transaction(transaction, user_ref, message.text, message.senderDevice)
        background_tasks.add_task(enforce_chat_lifecycle, region)
        return {"status": "success", "messageId": msg_id}
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/reports")
async def report_content(report: ReportRequest):
    """
    Public endpoint to submit a content report.
    """
    now = datetime.now(timezone.utc)
    report_data = report.model_dump()
    report_data["reportTimestamp"] = now.isoformat()
    report_data["status"] = "pending"
    
    db.collection('reports').add(report_data)
    return {"status": "success", "message": "Report submitted successfully."}

@app.patch("/admin/chat-config")
async def update_chat_config(
    config: ChatConfigUpdate, 
    _admin: dict = Depends(verify_admin)
):
    update_data = {}
    if config.archiveMessages is not None:
        update_data['archiveMessages'] = config.archiveMessages
    if config.moderationTier is not None:
        if config.moderationTier not in ['None', 'Mild', 'Aggressive']:
            raise HTTPException(status_code=400, detail="Invalid moderation tier.")
        update_data['moderationTier'] = config.moderationTier
        
    if not update_data:
        return {"status": "success", "message": "No changes requested."}
        
    db.collection('metadata').document('chat_config').set(update_data, merge=True)
    return {"status": "success", "updatedConfig": update_data}

@app.patch("/admin/users/{uid}/ban")
async def ban_user(uid: str, req: UserBanRequest, _admin: dict = Depends(verify_admin)):
    """Ban or unban a user from Global Chat."""
    db.collection('users').document(uid).update({"isBanned": req.isBanned})
    status = "banned" if req.isBanned else "unbanned"
    return {"status": "success", "message": f"User {uid} has been {status}."}

@app.patch("/admin/users/{uid}/mute")
async def mute_user(uid: str, req: UserMuteRequest, _admin: dict = Depends(verify_admin)):
    """Mute a user for a specific duration in hours. Set duration to 0 to unmute."""
    if req.durationHours <= 0:
        db.collection('users').document(uid).update({"mutedUntil": None})
        return {"status": "success", "message": f"User {uid} has been unmuted."}
    
    until = datetime.now(timezone.utc) + timedelta(hours=req.durationHours)
    db.collection('users').document(uid).update({"mutedUntil": until})
    return {"status": "success", "message": f"User {uid} has been muted until {until.isoformat()}."}

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)
