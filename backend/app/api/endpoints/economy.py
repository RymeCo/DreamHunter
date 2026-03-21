from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException
from firebase_admin import firestore
from ...core.firebase import db
from ...core.config import settings
from ..dependencies import verify_firebase_token
from ...models.economy_models import SyncRequest, ReconcileRequest, ReconcileResponse, ConversionResponse
from ...services.moderation_service import log_audit
from ...services.user_service import progress_daily_task

router = APIRouter(prefix="/economy", tags=["Economy"])

def calculate_level(xp: int) -> int:
    """Calculates player level based on total XP using the formula: XP_next = 100 * Level^1.5"""
    # Inverse formula to find Level from XP: Level = (XP / 100)^(1/1.5)
    if xp <= 0:
        return 1
    level = int((xp / 100)**(1/1.5)) + 1
    return max(1, level)

@router.post("/sync")
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
        
        max_allowed = last_dream + int(settings.MAX_DREAM_COINS_PER_HOUR * time_delta_hours)
        
        if req.dreamCoins > (max_allowed + 500):
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

@router.post("/reconcile", response_model=ReconcileResponse)
async def reconcile_economy(req: ReconcileRequest, decoded_token: dict = Depends(verify_firebase_token)):
    uid = decoded_token['uid']
    user_ref = db.collection('users').document(uid)
    doc = user_ref.get()
    
    if not doc.exists:
        raise HTTPException(status_code=404, detail="User not found")
        
    data = doc.to_dict()
    current_dream = data.get('dreamCoins', 0)
    current_hell = data.get('hellStones', 0)
    current_playtime = data.get('playtime', 0)
    current_free_spins = data.get('freeSpins', 0)
    current_xp = data.get('xp', 0)
    current_level = data.get('level', 1)
    inventory = data.get('inventory', [])
    processed_ids = set(data.get('processedTransactionIds', []))
    
    # Sort transactions by timestamp
    transactions = sorted(req.transactions, key=lambda t: t.timestamp)
    
    # Process each transaction
    gameplay_earned = 0
    newly_processed = []
    spin_count = 0
    total_playtime_delta = 0
    
    for t in transactions:
        if t.id in processed_ids:
            continue
            
        if t.type == 'EARN':
            if t.dreamDelta < 0 or t.hellDelta != 0:
                raise HTTPException(status_code=400, detail="Invalid EARN transaction deltas")
            gameplay_earned += t.dreamDelta
            # Minor XP for playing (1% of earned DC)
            current_xp += max(1, t.dreamDelta // 100)
            
        elif t.type == 'CONVERSION':
            if t.hellDelta >= 0 or t.dreamDelta != abs(t.hellDelta) * settings.HELL_TO_DREAM_RATE:
                 raise HTTPException(status_code=400, detail="Invalid CONVERSION rate or deltas")
            # XP for conversion: 50 XP per Hell Stone
            current_xp += abs(t.hellDelta) * 50
                 
        elif t.type == 'IAP_PURCHASE':
            # Major XP for supporting the game
            current_xp += 500
                 
        elif t.type in ['PURCHASE', 'ROULETTE_SPIN', 'BUY_SPIN']:
            if t.dreamDelta > 0 or t.hellDelta > 0 or t.freeSpinDelta > 0:
                raise HTTPException(status_code=400, detail=f"Positive delta not allowed for {t.type}")
            
            if t.type == 'PURCHASE':
                # XP = 10% of DC spent
                current_xp += abs(t.dreamDelta) // 10
            elif t.type == 'ROULETTE_SPIN':
                # XP = 25 per spin
                current_xp += 25
                spin_count += 1
        
        elif t.type == 'ROULETTE_REWARD':
            if t.dreamDelta < 0:
                raise HTTPException(status_code=400, detail="Negative delta not allowed for ROULETTE_REWARD")
            gameplay_earned += t.dreamDelta

        if (t.type == 'PURCHASE' or t.type == 'ROULETTE_REWARD') and t.itemId:
            if t.itemId not in inventory:
                inventory.append(t.itemId)

        if t.type == 'PLAYTIME':
            current_playtime += t.playtimeDelta
            total_playtime_delta += t.playtimeDelta
            
        current_free_spins += t.freeSpinDelta
        current_dream += t.dreamDelta
        current_hell += t.hellDelta
        
        if current_dream < 0 or current_hell < 0 or current_free_spins < 0:
            raise HTTPException(status_code=400, detail=f"Insufficient funds during reconciliation at {t.timestamp}")

        processed_ids.add(t.id)
        newly_processed.append(t.id)

    if spin_count > 0:
        await progress_daily_task(uid, "spin", amount=spin_count)

    if total_playtime_delta > 0:
        # Convert seconds to minutes for task progress (every 60s = 1m)
        minutes = total_playtime_delta // 60
        if minutes > 0:
            await progress_daily_task(uid, "playtime", amount=minutes)

    # Recalculate level
    new_level = calculate_level(current_xp)
    leveled_up = new_level > current_level

    if gameplay_earned > 15000:
        log_audit(
            admin_uid="SYSTEM_SECURITY",
            action="ECONOMY_RECONCILE_ANOMALY",
            target=uid,
            details=f"Large gameplay earn in batch: {gameplay_earned}. Flagging for review.",
            target_name=data.get('displayName'),
            target_email=data.get('email')
        )

    now = datetime.now(timezone.utc)
    user_ref.update({
        "dreamCoins": current_dream,
        "hellStones": current_hell,
        "playtime": current_playtime,
        "freeSpins": current_free_spins,
        "xp": current_xp,
        "level": new_level,
        "lastKnownDreamCoins": current_dream,
        "lastKnownHellStones": current_hell,
        "lastSyncTimestamp": now.isoformat(),
        "inventory": inventory,
        "processedTransactionIds": firestore.ArrayUnion(newly_processed)
    })
    
    return {
        "status": "success", 
        "dreamCoins": current_dream, 
        "hellStones": current_hell,
        "xp": current_xp,
        "level": new_level,
        "levelUp": leveled_up,
        "playtime": current_playtime,
        "freeSpins": current_free_spins,
        "inventory": inventory
    }

@router.post("/convert", response_model=ConversionResponse)
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
    current_xp = data.get('xp', 0)
    current_level = data.get('level', 1)
    
    if current_hell < hell_stones:
        raise HTTPException(status_code=400, detail="Insufficient Hell Stones")
        
    new_hell = current_hell - hell_stones
    new_dream = current_dream + (hell_stones * settings.HELL_TO_DREAM_RATE)
    
    # Award XP for conversion (50 XP per Hell Stone)
    new_xp = current_xp + (hell_stones * 50)
    new_level = calculate_level(new_xp)
    leveled_up = new_level > current_level
    
    user_ref.update({
        "hellStones": new_hell,
        "dreamCoins": new_dream,
        "xp": new_xp,
        "level": new_level,
        "lastKnownDreamCoins": new_dream,
        "lastKnownHellStones": new_hell,
        "lastSyncTimestamp": datetime.now(timezone.utc).isoformat()
    })
    
    return {
        "status": "success", 
        "dreamCoins": new_dream, 
        "hellStones": new_hell,
        "xp": new_xp,
        "level": new_level,
        "levelUp": leveled_up
    }
