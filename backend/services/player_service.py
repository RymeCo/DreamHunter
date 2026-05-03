from core.firebase import db, auth_client
from models.player import PlayerModel
from datetime import datetime

class PlayerService:
    @staticmethod
    def get_player(uid: str) -> PlayerModel:
        doc_ref = db.collection("players").document(uid)
        doc = doc_ref.get()
        if doc.exists:
            return PlayerModel(**doc.to_dict())
        return None

    @staticmethod
    def sync_player(uid: str) -> PlayerModel:
        """
        Ensures a player document exists in Firestore.
        If not, creates one with default values.
        """
        doc_ref = db.collection("players").document(uid)
        doc = doc_ref.get()
        
        if doc.exists:
            return PlayerModel(**doc.to_dict())
        
        # Create new player if doesn't exist
        user_info = auth_client.get_user(uid)
        
        new_player = PlayerModel(
            uid=uid,
            name=user_info.display_name or "Dreamer",
            createdAt=datetime.now().isoformat(),
        )
        
        doc_ref.set(new_player.dict())
        return new_player

    @staticmethod
    def update_player(uid: str, data: dict) -> PlayerModel:
        doc_ref = db.collection("players").document(uid)
        # We don't want to overwrite the UID
        if "uid" in data:
            del data["uid"]
        
        doc_ref.update(data)
        return PlayerService.get_player(uid)
