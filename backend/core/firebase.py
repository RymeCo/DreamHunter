import os
import json
import firebase_admin
from firebase_admin import credentials, firestore, auth
from dotenv import load_dotenv

load_dotenv()

# Firebase Initialization
# In Render, we will set FIREBASE_SERVICE_ACCOUNT_JSON as an env var
service_account_info = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")

if service_account_info:
    try:
        cert_dict = json.loads(service_account_info)
        cred = credentials.Certificate(cert_dict)
        firebase_admin.initialize_app(cred)
    except Exception as e:
        print(f"Error initializing Firebase from JSON env var: {e}")
        # Fallback for local dev if file exists
        if os.path.exists("serviceAccountKey.json"):
            cred = credentials.Certificate("serviceAccountKey.json")
            firebase_admin.initialize_app(cred)
else:
    # Default behavior for local dev
    if os.path.exists("serviceAccountKey.json"):
        cred = credentials.Certificate("serviceAccountKey.json")
        firebase_admin.initialize_app(cred)
    else:
        print("Warning: No Firebase credentials found. Backend will fail to start correctly.")

db = firestore.client()
auth_client = auth
