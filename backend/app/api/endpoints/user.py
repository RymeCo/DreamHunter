from datetime import datetime, timezone
from fastapi import APIRouter, Depends, Body
from ...core.firebase import db
from ..dependencies import verify_firebase_token
from ...services.user_service import get_or_create_user_profile, claim_daily_task

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

@router.post("/register")
async def register_user(decoded_token: dict = Depends(verify_firebase_token)):
    """
    Explicitly registers a new user, initializes their profile with a unique playerNumber.
    This replaces direct client-side writes for security.
    """
    uid = decoded_token['uid']
    display_name = decoded_token.get('name', 'Dreamer')
    email = decoded_token.get('email')
    
    # Check if user already exists
    user_ref = db.collection('users').document(uid)
    if user_ref.get().exists:
        return await get_or_create_user_profile(uid, display_name, email)

    # Transaction for playerNumber and profile creation
    def create_profile_transaction(transaction, user_ref, counter_ref):
        counter_doc = counter_ref.get(transaction=transaction)
        new_player_number = 1
        if counter_doc.exists:
            new_player_number = (counter_doc.to_dict().get('totalPlayers') or 0) + 1
        
        transaction.set(counter_ref, {'totalPlayers': new_player_number}, merge=True)
        
        now = datetime.now(timezone.utc).isoformat()
        profile = {
            "uid": uid,
            "email": email,
            "displayName": display_name,
            "playerNumber": new_player_number,
            "createdAt": now,
            "isBanned": False,
            "isAdmin": False,
            "isModerator": False,
            "dreamCoins": 500, # Starting bonus
            "hellStones": 10,  # Starting bonus
            "xp": 0,
            "level": 1,
            "playtime": 0,
            "lastKnownDreamCoins": 500,
            "lastKnownHellStones": 10,
            "lastSyncTimestamp": now,
            "inventory": [],
            "processedTransactionIds": [],
            "freeSpins": 1,
            "lastFreeSpinGrant": now,
            "avatarId": 0
        }
        transaction.set(user_ref, profile)
        return profile

    counter_ref = db.collection('metadata').document('counters')
    transaction = db.transaction()
    profile = create_profile_transaction(transaction, user_ref, counter_ref)
    
    return profile

@router.patch("/display-name")
async def patch_user_display_name(name: str, decoded_token: dict = Depends(verify_firebase_token)):
    uid = decoded_token['uid']
    db.collection('users').document(uid).update({"displayName": name})
    return {"status": "success", "displayName": name}

@router.patch("/avatar")
async def patch_user_avatar(avatar_id: int = Body(..., embed=True), decoded_token: dict = Depends(verify_firebase_token)):
    uid = decoded_token['uid']
    db.collection('users').document(uid).update({"avatarId": avatar_id})
    return {"status": "success", "avatarId": avatar_id}

@router.post("/sync-progress")
async def sync_progress(req: dict = Body(...), decoded_token: dict = Depends(verify_firebase_token)):
    """
    Updates user progress and inventory from the local cache.
    """
    uid = decoded_token['uid']
    db.collection('users').document(uid).update({
        "progress": req.get('progress'),
        "inventory": req.get('inventory'),
        "lastSyncTimestamp": datetime.now(timezone.utc).isoformat()
    })
    return {"status": "success"}

@router.post("/tasks/{task_id}/claim")
async def post_claim_task(task_id: str, decoded_token: dict = Depends(verify_firebase_token)):
    uid = decoded_token['uid']
    result = await claim_daily_task(uid, task_id)
    if not result:
        return {"status": "error", "message": "Task not found, not completed, or already claimed."}
    return {"status": "success", **result}
