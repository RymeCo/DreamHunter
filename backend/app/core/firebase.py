import os
import json
import firebase_admin
from firebase_admin import credentials, firestore, auth
from .config import settings

def initialize_firebase():
    """Initialize Firebase App and return the firestore client."""
    if firebase_admin._apps:
        return firestore.client()
        
    service_account_env = settings.FIREBASE_SERVICE_ACCOUNT

    if service_account_env:
        try:
            cred_dict = json.loads(service_account_env)
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred)
        except Exception as e:
            print(f"Error initializing Firebase from ENV: {e}")
            firebase_admin.initialize_app()
    elif os.path.exists("serviceAccountKey.json"):
        cred = credentials.Certificate("serviceAccountKey.json")
        firebase_admin.initialize_app(cred)
    else:
        try:
            firebase_admin.initialize_app()
        except Exception as e:
            print(f"Firebase initialization fallback: {e}")

    return firestore.client()

db = initialize_firebase()
