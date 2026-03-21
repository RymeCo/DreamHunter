from datetime import datetime, timezone
from firebase_admin import firestore
from ..core.firebase import db

async def get_or_create_user_profile(uid: str, display_name: str, email: str | None):
    """Fetches user data from Firestore using UID or creates a default one."""
    user_ref = db.collection('users').document(uid)
    doc = user_ref.get()
    
    if doc.exists:
        data = doc.to_dict()
        now = datetime.now(timezone.utc)
        last_grant_str = data.get('lastFreeSpinGrant')
        needs_update = False
        
        config_ref = db.collection('metadata').document('roulette_config').get()
        config = config_ref.to_dict() if config_ref.exists else {}
        daily_grant = config.get('dailyFreeSpins', 1)
        max_spins = config.get('maxFreeSpins', 10)
        
        if last_grant_str:
            try:
                clean_last_grant = last_grant_str.replace('Z', '+00:00')
                last_grant = datetime.fromisoformat(clean_last_grant)
                if now.date() > last_grant.date():
                    current_spins = data.get('freeSpins', 0)
                    new_spins = min(max_spins, current_spins + daily_grant)
                    data['freeSpins'] = new_spins
                    data['lastFreeSpinGrant'] = now.isoformat()
                    needs_update = True
            except Exception as e:
                print(f"Error parsing lastFreeSpinGrant: {e}")
        else:
            data['freeSpins'] = data.get('freeSpins', daily_grant)
            data['lastFreeSpinGrant'] = now.isoformat()
            needs_update = True
            
        if needs_update:
            user_ref.update({
                'freeSpins': data['freeSpins'],
                'lastFreeSpinGrant': data['lastFreeSpinGrant']
            })

        if 'uid' not in data:
            data['uid'] = doc.id
        
        # Ensure xp and level exist for existing users (lazy migration)
        if 'xp' not in data or 'level' not in data:
            data['xp'] = data.get('xp', 0)
            data['level'] = data.get('level', 1)
            user_ref.update({
                'xp': data['xp'],
                'level': data['level']
            })
            
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
        "xp": 0,
        "level": 1,
        "playtime": 0,
        "lastKnownDreamCoins": 0,
        "lastKnownHellStones": 0,
        "lastSyncTimestamp": now.isoformat(),
        "inventory": [],
        "processedTransactionIds": [],
        "freeSpins": 1,
        "lastFreeSpinGrant": now.isoformat()
    }
    
    db_profile = default_profile.copy()
    db_profile["createdAt"] = firestore.SERVER_TIMESTAMP
    user_ref.set(db_profile)
    
    return default_profile
