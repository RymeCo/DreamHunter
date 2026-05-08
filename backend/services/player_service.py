from core.firebase import db, auth_client
from models.player import PlayerModel, LeaderboardEntry, LeaderboardCache
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
        
        # Create or update player if necessary
        user_info = auth_client.get_user(uid)
        
        if doc.exists:
            # Update email if missing (for legacy users)
            player_data = doc.to_dict()
            updates = {}
            if not player_data.get("email") and user_info.email:
                updates["email"] = user_info.email
                player_data["email"] = user_info.email
            
            # Always sync verification status
            if player_data.get("isVerified") != user_info.email_verified:
                updates["isVerified"] = user_info.email_verified
                player_data["isVerified"] = user_info.email_verified
            
            if updates:
                db.collection("players").document(uid).update(updates)
                
            return PlayerModel(**player_data)
        
        # Create new player if doesn't exist
        new_player = PlayerModel(
            uid=uid,
            name=user_info.display_name or "Dreamer",
            email=user_info.email,
            isVerified=user_info.email_verified,
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
    def clear_leaderboard(metric: str) -> dict:
        """
        Resets the specified leaderboard list in the cache document.
        """
        doc_ref = db.collection("system").document("leaderboard")
        doc = doc_ref.get()
        
        data = doc.to_dict() if doc.exists else {
            "lastUpdated": "",
            "topLevels": [],
            "topCoins": []
        }
        
        if metric == "level":
            data["topLevels"] = []
        elif metric == "coins":
            data["topCoins"] = []
            
        data["lastUpdated"] = datetime.now().isoformat()
        doc_ref.set(data)
        return data

    @staticmethod
    def refresh_leaderboards():
        """
        Scans all players and updates the cached leaderboard document.
        Criteria: Level >= 50, Coins >= 30,000. Verified only.
        Tie-breaker: Older account (earlier createdAt) wins.
        """
        from services.settings_service import settings_service
        if settings_service.get_settings().get("leaderboard_paused", False):
            print("[LEADERBOARD] Refresh skipped: Leaderboard is PAUSED.")
            return PlayerService.get_leaderboard_cache()

        now = datetime.now().isoformat()

        # 1. Fetch Top Levels (Level >= 50)
        # We fetch more to allow for tie-breaking and filtering in Python
        level_query = db.collection("players")\
            .where("isVerified", "==", True)\
            .where("level", ">=", 50)\
            .order_by("level", direction="DESCENDING")\
            .order_by("createdAt", direction="ASCENDING")\
            .limit(100).stream()

        top_levels = []
        for doc in level_query:
            p = doc.to_dict()
            
            # Filter out banned/hidden users
            if p.get("isBannedFromLeaderboard", False): continue
            hide_until = p.get("leaderboardHideUntil")
            if hide_until and hide_until > now: continue
            if p.get("isBannedPermanent", False): continue
            ban_until = p.get("banUntil")
            if ban_until and ban_until > now: continue

            top_levels.append({
                "uid": p.get("uid", ""),
                "name": p.get("name", "Unknown"),
                "value": p.get("level", 0),
                "level": p.get("level", 0),
                "createdAt": p.get("createdAt", "")
            })
            if len(top_levels) >= 50: break

        # 2. Fetch Top Coins (Coins >= 30,000)
        coin_query = db.collection("players")\
            .where("isVerified", "==", True)\
            .where("coins", ">=", 30000)\
            .order_by("coins", direction="DESCENDING")\
            .order_by("createdAt", direction="ASCENDING")\
            .limit(100).stream()

        top_coins = []
        for doc in coin_query:
            p = doc.to_dict()
            
            # Filter out banned/hidden users
            if p.get("isBannedFromLeaderboard", False): continue
            hide_until = p.get("leaderboardHideUntil")
            if hide_until and hide_until > now: continue
            if p.get("isBannedPermanent", False): continue
            ban_until = p.get("banUntil")
            if ban_until and ban_until > now: continue

            top_coins.append({
                "uid": p.get("uid", ""),
                "name": p.get("name", "Unknown"),
                "value": p.get("coins", 0),
                "level": p.get("level", 0),
                "createdAt": p.get("createdAt", "")
            })
            if len(top_coins) >= 50: break

        # 3. Save to Cache
        cache_data = {
            "lastUpdated": datetime.now().isoformat(),
            "topLevels": top_levels,
            "topCoins": top_coins
        }
        db.collection("system").document("leaderboard").set(cache_data)
        return cache_data
