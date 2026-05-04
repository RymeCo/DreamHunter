from core.firebase import db, auth_client
from models.player import PlayerModel, LeaderboardEntry, LeaderboardCache
from datetime import datetime
from google.cloud.firestore_v1.base_query import FieldFilter

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
        
        # Use set with merge=True so it works even if doc doesn't exist
        doc_ref.set(data, merge=True)
        return PlayerService.get_player(uid)

    @staticmethod
    def get_leaderboard_cache() -> dict:
        """Fetches the pre-calculated leaderboard from the cache document."""
        doc = db.collection("system").document("leaderboard").get()
        if doc.exists:
            return doc.to_dict()
        return {"lastUpdated": "", "topLevels": [], "topCoins": []}

    @staticmethod
    def refresh_leaderboards():
        """
        Scans all players and updates the cached leaderboard document.
        Rules:
        - Level: 50+, Top 50, tie-break by older account.
        - Coins: 30k+, Top 50, tie-break by older account.
        """
        # 1. Fetch Top Levels (Level >= 50)
        level_query = db.collection("players")\
            .where(filter=FieldFilter("level", ">=", 50))\
            .order_by("level", direction="DESCENDING")\
            .order_by("createdAt", direction="ASCENDING")\
            .limit(50).stream()

        top_levels = []
        for doc in level_query:
            p = doc.to_dict()
            top_levels.append({
                "uid": p.get("uid", ""),
                "name": p.get("name", "Unknown"),
                "value": p.get("level", 0),
                "level": p.get("level", 0),
                "createdAt": p.get("createdAt", "")
            })

        # 2. Fetch Top Coins (Coins >= 30,000)
        coin_query = db.collection("players")\
            .where(filter=FieldFilter("coins", ">=", 30000))\
            .order_by("coins", direction="DESCENDING")\
            .order_by("createdAt", direction="ASCENDING")\
            .limit(50).stream()

        top_coins = []
        for doc in coin_query:
            p = doc.to_dict()
            top_coins.append({
                "uid": p.get("uid", ""),
                "name": p.get("name", "Unknown"),
                "value": p.get("coins", 0),
                "level": p.get("level", 0),
                "createdAt": p.get("createdAt", "")
            })

        # 3. Save to Cache
        cache_data = {
            "lastUpdated": datetime.now().isoformat(),
            "topLevels": top_levels,
            "topCoins": top_coins
        }
        db.collection("system").document("leaderboard").set(cache_data)
        return cache_data
