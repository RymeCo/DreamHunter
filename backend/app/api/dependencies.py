from typing import Optional
from fastapi import Header, HTTPException, Depends
from firebase_admin import auth, firestore
from ..core.firebase import db
from ..core.config import settings

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

async def optional_firebase_token(authorization: Optional[str] = Header(None)):
    """
    Optional dependency to verify the Firebase ID Token.
    Returns decoded token if valid, otherwise returns None.
    """
    if not authorization or not authorization.startswith("Bearer "):
        return None
    
    token = authorization.split("Bearer ")[1]
    try:
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except Exception:
        return None

async def verify_admin(decoded_token: dict = Depends(verify_firebase_token)):
    """
    Dependency to check if the user is an admin.
    """
    uid = decoded_token['uid']
    
    # Check environment variable
    if uid in settings.ADMIN_UIDS:
        return decoded_token
        
    # Check Firestore
    user_doc = db.collection('users').document(uid).get()
    if user_doc.exists and user_doc.to_dict().get('isAdmin', False):
        return decoded_token
        
    raise HTTPException(status_code=403, detail="Admin privileges required")
