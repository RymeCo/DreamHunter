from fastapi import APIRouter, Depends
from ...core.firebase import db
from ..dependencies import verify_firebase_token
from ...services.user_service import get_or_create_user_profile

router = APIRouter(prefix="/user", tags=["Users"])

@router.get("/profile")
async def get_user_profile_data(decoded_token: dict = Depends(verify_firebase_token)):
    """
    Fetches user data from Firestore using UID. 
    """
    uid = decoded_token['uid']
    display_name = decoded_token.get('name', 'Dreamer')
    email = decoded_token.get('email')
    
    return await get_or_create_user_profile(uid, display_name, email)

@router.patch("/display-name")
async def patch_user_display_name(name: str, decoded_token: dict = Depends(verify_firebase_token)):
    uid = decoded_token['uid']
    db.collection('users').document(uid).update({"displayName": name})
    return {"status": "success", "displayName": name}
