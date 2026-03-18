import os
import json
from datetime import datetime, timezone, timedelta
from typing import Optional, List, Any

from fastapi import FastAPI, HTTPException, Depends, Header, BackgroundTasks
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
            # Handle other firestore types if necessary
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
    config_ref = db.collection('metadata').document('moderation_config')

    @firestore.transactional
    def send_in_transaction(transaction, user_ref, config_ref, msg_text, device):
        snapshot = user_ref.get(transaction=transaction)
        user_data = snapshot.to_dict() if snapshot.exists else {}
        
        config_snap = config_ref.get(transaction=transaction)
        auto_mod_config = config_snap.to_dict() if config_snap.exists else {}
        
        # 1. Ban/Mute Checks
        if user_data.get('isBanned', False):
            raise HTTPException(status_code=403, detail="You are permanently banned from Global Chat.")
        
        muted_until = user_data.get('mutedUntil')
        if muted_until:
            if isinstance(muted_until, str):
                until_dt = datetime.fromisoformat(muted_until.replace('Z', '+00:00'))
            else:
                # Firestore returns datetime objects already
                until_dt = muted_until 
                
            if datetime.now(timezone.utc) < until_dt:
                raise HTTPException(status_code=403, detail=f"You are muted until {until_dt.strftime('%Y-%m-%d %H:%M:%S')} UTC.")

        # 2. Auto-Mod Scan (Toxic Word Filter)
        if auto_mod_config.get('autoModEnabled', False):
            # A starter list of toxic gaming keywords/slurs. 
            toxic_keywords = [
                'nigger', 'faggot', 'retard', 'ky$', 'kill yourself', 
                'cunt', 'whore', 'slut', 'fuck you', 'stfu',
                'noob team', 'trash player', 'dog water', 'garbage team',
                'ez win', 'easy clap', 'uninstall', 'hack', 'cheat'
            ] 
            
            # Check for matches
            msg_lower = msg_text.lower()
            if any(word in msg_lower for word in toxic_keywords):
                violations = user_data.get('violationCount', 0) + 1
                updates = {'violationCount': violations}
                
                if violations == 1:
                    hours = auto_mod_config.get('strike1MuteHours', 1)
                    updates['mutedUntil'] = datetime.now(timezone.utc) + timedelta(hours=hours)
                elif violations == 2:
                    hours = auto_mod_config.get('strike2MuteHours', 24)
                    updates['mutedUntil'] = datetime.now(timezone.utc) + timedelta(hours=hours)
                else:
                    if auto_mod_config.get('strike3Ban', True):
                        updates['isBanned'] = True
                    else:
                        updates['mutedUntil'] = datetime.now(timezone.utc) + timedelta(days=365)
                
                transaction.update(user_ref, updates)
                raise HTTPException(status_code=403, detail=f"Message blocked: Toxicity detected. Strike {violations} applied.")

        # 3. Spam Cooldown
        last_msg_at = user_data.get('lastMessageAt', 0)
        if now_ts - last_msg_at < 1.0:
            raise HTTPException(status_code=429, detail="Please wait before sending another message.")
        
        display_name = user_data.get('displayName', 'Dreamer')
        is_admin = user_data.get('isAdmin', False)
        
        # Update user's last message time
        transaction.update(user_ref, {'lastMessageAt': now_ts})
        
        # Construct message
        new_msg = {
            "text": msg_text,
            "senderUid": uid,
            "senderName": display_name,
            "senderDevice": device,
            "isAdmin": is_admin,
            "timestamp": firestore.SERVER_TIMESTAMP
        }
        
        chat_ref = db.collection('chats').document(region).collection('messages').document()
        transaction.set(chat_ref, new_msg)
        return chat_ref.id

    try:
        msg_id = send_in_transaction(transaction, user_ref, config_ref, message.text, message.senderDevice)
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

if __name__ == "__main__":
    import uvicorn
    # Render provides the PORT environment variable
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)
