import os
import json
import firebase_admin
from firebase_admin import credentials, auth, firestore
from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional
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
# On Render, set FIREBASE_SERVICE_ACCOUNT as an environment variable containing the JSON string
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
    # Fallback for local testing if you use the Firebase Emulator or have gcloud auth
    try:
        firebase_admin.initialize_app()
    except Exception as e:
        print("Firebase could not be initialized. Please check your service account configuration.")

db = firestore.client()

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

@app.get("/")
async def root():
    return {"message": "DreamHunter API is running!", "status": "online"}

@app.get("/user/profile")
async def get_user_profile(decoded_token: dict = Depends(verify_firebase_token)):
    """
    Example protected endpoint that fetches user data from Firestore.
    """
    uid = decoded_token['uid']
    user_ref = db.collection('users').document(uid)
    doc = user_ref.get()
    
    if doc.exists:
        return doc.to_dict()
    else:
        # Create a default profile if it doesn't exist
        default_profile = {
            "uid": uid,
            "email": decoded_token.get('email'),
            "display_name": decoded_token.get('name', 'Dreamer'),
            "player_number": None,
            "created_at": firestore.SERVER_TIMESTAMP
        }
        user_ref.set(default_profile)
        return default_profile

@app.post("/user/update_display_name")
async def update_display_name(name: str, decoded_token: dict = Depends(verify_firebase_token)):
    uid = decoded_token['uid']
    db.collection('users').document(uid).update({"display_name": name})
    return {"status": "success", "new_name": name}

if __name__ == "__main__":
    import uvicorn
    # Render provides the PORT environment variable
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)
