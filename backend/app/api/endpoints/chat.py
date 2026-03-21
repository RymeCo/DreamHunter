import re
from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, Depends, HTTPException
from firebase_admin import firestore
from ...core.firebase import db
from ..dependencies import verify_firebase_token
from ...models.economy_models import ChatMessage, ReportRequest
from ...services.moderation_service import log_audit, send_urgent_report_email

router = APIRouter(tags=["Chat & Social"])

@router.post("/chats/{region}/messages")
async def post_chat_message(region: str, msg: ChatMessage, decoded_token: dict = Depends(verify_firebase_token)):
    uid = decoded_token['uid']
    now = datetime.now(timezone.utc)
    
    user_ref = db.collection('users').document(uid)
    user_doc = user_ref.get()
    
    if not user_doc.exists:
        raise HTTPException(status_code=404, detail="User not found")
    
    user_data = user_doc.to_dict()
    
    # Check if banned
    if user_data.get('isBanned'):
        banned_until = user_data.get('bannedUntil')
        if not banned_until or banned_until.replace(tzinfo=timezone.utc) > now:
            detail = "You are permanently banned."
            if banned_until:
                diff = banned_until.replace(tzinfo=timezone.utc) - now
                hours, remainder = divmod(int(diff.total_seconds()), 3600)
                minutes, _ = divmod(remainder, 60)
                detail = f"You are banned for {hours}h {minutes}m."
            raise HTTPException(status_code=403, detail=detail)
            
    # Check if muted
    muted_until = user_data.get('mutedUntil')
    if muted_until:
        if isinstance(muted_until, str):
            muted_until = datetime.fromisoformat(muted_until.replace('Z', '+00:00'))
        
        if muted_until.replace(tzinfo=timezone.utc) > now:
            diff = muted_until.replace(tzinfo=timezone.utc) - now
            hours, remainder = divmod(int(diff.total_seconds()), 3600)
            minutes, _ = divmod(remainder, 60)
            raise HTTPException(status_code=403, detail=f"You are muted for {hours}h {minutes}m.")

    # --- Auto-Mod Logic ---
    config_doc = db.collection('metadata').document('moderation_config').get()
    config = config_doc.to_dict() if config_doc.exists else {}
    
    banned_words = config.get('bannedWords', [])
    text = msg.text
    censored_text = text
    hit_blacklist = False
    
    for word in banned_words:
        if word.lower() in text.lower():
            hit_blacklist = True
            censored_text = re.sub(re.escape(word), '*' * len(word), censored_text, flags=re.IGNORECASE)

    if hit_blacklist:
        warnings = user_data.get('warnings', [])
        decay_days = config.get('decayDays', 30)
        valid_warnings = []
        for w in warnings:
            w_time = datetime.fromisoformat(w['timestamp'].replace('Z', '+00:00'))
            if (now - w_time).days < decay_days:
                valid_warnings.append(w)
        
        new_warning = {
            "reason": "Automod: Blacklisted word used.",
            "timestamp": now.isoformat(),
            "adminUid": "SYSTEM_AUTOMOD"
        }
        valid_warnings.append(new_warning)
        user_ref.update({"warnings": valid_warnings})
        
        strike_count = len(valid_warnings)
        if strike_count >= 3:
            action = config.get('strike3Action', 'mute')
            duration = config.get('strike3DurationHours', 24)
            until = now + timedelta(hours=duration)
            
            if action == 'ban':
                user_ref.update({"isBanned": True, "bannedUntil": until})
                log_audit(
                    admin_uid="SYSTEM_AUTOMOD",
                    action="AUTOMOD_BAN",
                    target=uid,
                    details=f"User reached {strike_count} strikes. Auto-banned for {duration}h.",
                    target_name=user_data.get('displayName'),
                    target_email=user_data.get('email')
                )
            else:
                user_ref.update({"mutedUntil": until})
                log_audit(
                    admin_uid="SYSTEM_AUTOMOD",
                    action="AUTOMOD_MUTE",
                    target=uid,
                    details=f"User reached {strike_count} strikes. Auto-muted for {duration}h.",
                    target_name=user_data.get('displayName'),
                    target_email=user_data.get('email')
                )
                
    message_data = {
        "text": censored_text,
        "senderUid": uid,
        "senderName": user_data.get('displayName', 'Dreamer'),
        "senderDevice": msg.senderDevice,
        "timestamp": firestore.SERVER_TIMESTAMP,
        "isAdmin": user_data.get('isAdmin', False),
        "isModerator": user_data.get('isModerator', False),
        "region": region
    }
    
    db.collection('chats').document(region).collection('messages').add(message_data)
    
    response_data = {"status": "success", "censored": hit_blacklist}
    if hit_blacklist:
        response_data["warning"] = f"Watch your language! (Warning {len(valid_warnings)}/3)"
        if strike_count >= 3:
            action = config.get('strike3Action', 'mute')
            duration = config.get('strike3DurationHours', 24)
            response_data["isMuted"] = (action == 'mute')
            response_data["isBanned"] = (action == 'ban')
            response_data["muteMessage"] = f"You have been {'banned' if action == 'ban' else 'muted'} for {duration}h due to repeated warnings."
            
    return response_data

@router.post("/reports")
async def report_content(report: ReportRequest):
    if report.reporterId == report.senderId:
        raise HTTPException(status_code=400, detail="You cannot report your own messages.")

    existing_reports = db.collection('reports') \
        .where("reportedMessageId", "==", report.reportedMessageId) \
        .where("reporterId", "==", report.reporterId) \
        .limit(1).get()
    
    if len(existing_reports) > 0:
        return {"status": "success", "message": "Report already received. Thank you!"}

    total_reporters = db.collection('reports') \
        .where("reportedMessageId", "==", report.reportedMessageId) \
        .get()
    
    unique_count = len(total_reporters) + 1
    is_urgent = unique_count >= 5

    now = datetime.now(timezone.utc)
    report_data = report.model_dump()
    report_data["reportTimestamp"] = now.isoformat()
    report_data["status"] = "pending"
    report_data["isUrgent"] = is_urgent
    report_data["reporterCount"] = unique_count
    
    new_report_ref = db.collection('reports').document()
    new_report_ref.set(report_data)

    if is_urgent:
        send_urgent_report_email(new_report_ref.id, report.originalMessageText)
    
    return {"status": "success", "message": "Report submitted successfully.", "urgent": is_urgent}

@router.get("/shop")
async def get_shop_items():
    items = db.collection('shop_items').stream()
    return [item.to_dict() for item in items]
