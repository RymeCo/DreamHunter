import os
import json
import time
from datetime import datetime, timezone
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


# --- In-Memory State ---

# Tracks the last time a user sent a message (for spam protection)
last_message_times = {}


# --- Helper Functions ---

def enforce_chat_lifecycle(region: str):
    """
    Background task to enforce the 100-message cap per region and 
    handle togglable archival.
    """
    try:
        messages_ref = db.collection('chats').document(region).collection('messages')
        # Get all messages ordered by timestamp descending
        query = messages_ref.order_by("timestamp", direction=firestore.Query.DESCENDING)
        docs = list(query.stream())
        
        if len(docs) > 100:
            # We have more than 100 messages.
            docs_to_remove = docs[100:]
            
            # Check archival config
            config_ref = db.collection('metadata').document('chat_config')
            config_doc = config_ref.get()
            archive_messages = False
            if config_doc.exists:
                archive_messages = config_doc.to_dict().get('archiveMessages', False)
                
            batch = db.batch()
            
            for doc in docs_to_remove:
                if archive_messages:
                    # Move to archives
                    # e.g., chat_archives/{region}/messages/{doc_id}
                    archive_ref = db.collection('chat_archives').document(region).collection('messages').document(doc.id)
                    batch.set(archive_ref, doc.to_dict())
                # Delete from active stream
                batch.delete(doc.reference)
                
            batch.commit()
    except Exception as e:
        print(f"Error enforcing chat lifecycle: {e}")


class ChatConfigUpdate(BaseModel):
    archiveMessages: Optional[bool] = None
    moderationTier: Optional[str] = None

# --- Endpoints ---

@app.get("/")
async def root():
    return {"message": "DreamHunter API is running!", "status": "online"}

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
    
    # MIGRATION LOGIC: Check for legacy document keyed by displayName
    legacy_ref = db.collection('users').document(display_name)
    legacy_doc = legacy_ref.get()
    
    if legacy_doc.exists:
        legacy_data = legacy_doc.to_dict()
        user_ref.set(legacy_data)
        legacy_ref.delete()
        return legacy_data

    # NEW USER: Create a default profile
    now = datetime.now(timezone.utc)
    default_profile = {
        "uid": uid,
        "email": email,
        "displayName": display_name,
        "playerNumber": None,
        "createdAt": now.isoformat()
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

@app.post("/chat/{region}/send")
async def send_chat_message(
    region: str, 
    message: ChatMessage, 
    background_tasks: BackgroundTasks,
    decoded_token: dict = Depends(verify_firebase_token)
):
    """
    Sends a message to the specified regional chat.
    Enforces a 1-second spam cooldown.
    """
    uid = decoded_token['uid']
    
    # Fetch user's profile to get their current display name
    user_doc = db.collection('users').document(uid).get()
    display_name = user_doc.to_dict().get('displayName', 'Dreamer') if user_doc.exists else 'Dreamer'

    # Spam Protection Check
    current_time = time.time()
    last_time = last_message_times.get(uid, 0)
    if current_time - last_time < 1.0:
        raise HTTPException(status_code=429, detail="Please wait before sending another message.")
    
    last_message_times[uid] = current_time

    # Construct the message
    new_msg = {
        "text": message.text,
        "senderUid": uid,
        "senderName": display_name,
        "senderDevice": message.senderDevice,
        "timestamp": firestore.SERVER_TIMESTAMP
    }

    # Moderate message based on tier (Placeholder for Phase 4)
    # config_doc = db.collection('metadata').document('chat_config').get()
    # tier = config_doc.to_dict().get('moderationTier', 'None') if config_doc.exists else 'None'
    # if tier == 'Aggressive' and contains_profanity(message.text):
    #     raise HTTPException(status_code=403, detail="Message blocked by auto-moderator.")
    
    # Save to Firestore
    chat_ref = db.collection('chats').document(region).collection('messages')
    _, doc_ref = chat_ref.add(new_msg)

    # Trigger lifecycle enforcement in the background
    background_tasks.add_task(enforce_chat_lifecycle, region)

    return {"status": "success", "messageId": doc_ref.id}

@app.post("/chat/report")
async def report_chat_message(report: ReportRequest):
    """
    Public endpoint to submit a chat report. 
    Accepts reports from both logged-in users and guests.
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
    decoded_token: dict = Depends(verify_firebase_token)
):
    """
    Admin endpoint to update chat configuration (Archival and Moderation).
    Requires a valid Firebase token (you may want to add an admin check here later).
    """
    # TODO: Add logic to verify decoded_token['uid'] belongs to an admin
    
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


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)
