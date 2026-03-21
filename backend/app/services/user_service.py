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
            needs_update = True

        # Ensure avatarId exists
        if 'avatarId' not in data:
            data['avatarId'] = 0
            needs_update = True
            
        # Ensure dailyTasks exists
        if 'dailyTasks' not in data:
            data['dailyTasks'] = _get_default_daily_tasks()
            needs_update = True
        else:
            # Check if tasks need reset (if lastReset is from a previous day)
            last_reset_str = data['dailyTasks'].get('lastReset')
            if last_reset_str:
                try:
                    clean_last_reset = last_reset_str.replace('Z', '+00:00')
                    last_reset = datetime.fromisoformat(clean_last_reset)
                    if now.date() > last_reset.date():
                        data['dailyTasks'] = _get_default_daily_tasks()
                        needs_update = True
                except:
                    data['dailyTasks'] = _get_default_daily_tasks()
                    needs_update = True
            
        if needs_update:
            user_ref.update({
                'xp': data.get('xp', 0),
                'level': data.get('level', 1),
                'avatarId': data.get('avatarId', 0),
                'dailyTasks': data.get('dailyTasks')
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
        "lastFreeSpinGrant": now.isoformat(),
        "avatarId": 0,
        "dailyTasks": _get_default_daily_tasks()
    }
    
    db_profile = default_profile.copy()
    db_profile["createdAt"] = firestore.SERVER_TIMESTAMP
    user_ref.set(db_profile)
    
    return default_profile

async def progress_daily_task(uid: str, task_type: str, amount: int = 1):
    """Updates progress for a specific type of daily task and grants rewards if completed."""
    user_ref = db.collection('users').document(uid)
    doc = user_ref.get()
    if not doc.exists:
        return None
    
    data = doc.to_dict()
    daily_tasks = data.get('dailyTasks')
    if not daily_tasks or 'tasks' not in daily_tasks:
        return None
    
    updated = False
    rewards_to_grant = 0
    
    for task in daily_tasks['tasks']:
        if task['type'] == task_type and not task['completed']:
            task['progress'] += amount
            if task['progress'] >= task['target']:
                task['progress'] = task['target']
                task['completed'] = True
                rewards_to_grant += task.get('reward', 0)
            updated = True
            
    if updated:
        update_payload = {'dailyTasks': daily_tasks}
        if rewards_to_grant > 0:
            update_payload['dreamCoins'] = data.get('dreamCoins', 0) + rewards_to_grant
            
        user_ref.update(update_payload)
        return {
            "dailyTasks": daily_tasks,
            "grantedReward": rewards_to_grant
        }
        
    return None

def _get_default_daily_tasks():
    now = datetime.now(timezone.utc)
    return {
        "lastReset": now.isoformat(),
        "tasks": [
            {
                "id": "daily_login",
                "title": "Daily Login",
                "description": "Log in to the game today.",
                "progress": 1,
                "target": 1,
                "reward": 50,
                "completed": True, # Automatically completed if you get here
                "type": "login"
            },
            {
                "id": "send_messages",
                "title": "Chatterbox",
                "description": "Send 5 messages in global chat.",
                "progress": 0,
                "target": 5,
                "reward": 100,
                "completed": False,
                "type": "chat"
            },
            {
                "id": "spin_roulette",
                "title": "Lucky Spinner",
                "description": "Spin the Lucky Roulette twice.",
                "progress": 0,
                "target": 2,
                "reward": 150,
                "completed": False,
                "type": "spin"
            },
            {
                "id": "playtime_task",
                "title": "Time Traveler",
                "description": "Play for 10 minutes.",
                "progress": 0,
                "target": 10,
                "reward": 200,
                "completed": False,
                "type": "playtime"
            }
        ]
    }
