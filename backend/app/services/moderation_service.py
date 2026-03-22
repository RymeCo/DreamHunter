from datetime import datetime, timezone
from typing import Optional
from firebase_admin import firestore
from ..core.firebase import db

def log_audit(
    admin_uid: str, 
    action: str, 
    target: Optional[str] = None, 
    details: Optional[str] = None, 
    admin_email: Optional[str] = None,
    target_name: Optional[str] = None,
    target_email: Optional[str] = None
):
    """Log an administrative action to the audit_logs collection."""
    db.collection('audit_logs').add({
        "adminUid": admin_uid or "SYSTEM",
        "adminEmail": admin_email or "N/A",
        "action": action,
        "target": target or "N/A",
        "targetName": target_name or "N/A",
        "targetEmail": target_email or "N/A",
        "details": details or "No details provided",
        "timestamp": firestore.SERVER_TIMESTAMP
    })

def send_urgent_report_email(report_id: str, message_text: str):
    """Placeholder for sending urgent email notifications."""
    print(f"!!! URGENT REPORT [{report_id}] !!!")
    print(f"Message Content: {message_text}")
    print("Action Required: Check Admin Dashboard immediately.")
