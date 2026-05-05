from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

class PlayerModel(BaseModel):
    uid: str
    name: str
    email: Optional[str] = None
    createdAt: str
    banned: List[str] = []
    
    isBannedPermanent: bool = False
    isBannedFromLeaderboard: bool = False
    isBannedFromChat: bool = False
    muteUntil: Optional[str] = None
    role: str = "player"

    level: int = 1
    xp: int = 0
    totalGameTime: int = 0
    
    coins: int = 100
    stones: int = 0
    selectedCharacterId: str = "char_max"
    
    inventory: dict = {}

    roulette: dict = {}

    class Config:
        populate_by_name = True

class LeaderboardEntry(BaseModel):
    uid: str
    name: str
    value: int
    level: int
    createdAt: str

class LeaderboardCache(BaseModel):
    lastUpdated: str
    topLevels: List[LeaderboardEntry]
    topCoins: List[LeaderboardEntry]
