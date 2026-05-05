from core.firebase import db
import threading

class SettingsService:
    _instance = None
    _lock = threading.Lock()
    _settings = {
        "chat_enabled": True,
        "maintenance_mode": False,
        "leaderboard_paused": False,
    }

    def __new__(cls):
        with cls._lock:
            if cls._instance is None:
                cls._instance = super(SettingsService, cls).__new__(cls)
                cls._instance._start_listener()
            return cls._instance

    def _start_listener(self):
        """Starts a real-time listener on the system/config document."""
        print("[SETTINGS] Starting Firestore listener for system/config...")
        doc_ref = db.collection("system").document("config")
        
        # Ensure document exists
        if not doc_ref.get().exists:
            print("[SETTINGS] system/config not found. Initializing with defaults.")
            doc_ref.set(self._settings)

        def on_snapshot(doc_snapshot, changes, read_time):
            for doc in doc_snapshot:
                if doc.exists:
                    new_settings = doc.to_dict()
                    print(f"[SETTINGS] Update received: {new_settings}")
                    with self._lock:
                        self._settings.update(new_settings)

        doc_ref.on_snapshot(on_snapshot)

    def get_settings(self):
        with self._lock:
            return self._settings.copy()

    def is_chat_enabled(self):
        with self._lock:
            return self._settings.get("chat_enabled", True)

settings_service = SettingsService()
