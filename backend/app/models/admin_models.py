from typing import Optional, List
from pydantic import BaseModel

class UserBanRequest(BaseModel):
    isBanned: bool
    isSuperBanned: Optional[bool] = False
    until: Optional[str] = None

class UserMuteRequest(BaseModel):
    durationHours: Optional[int] = None
    until: Optional[str] = None

class UserModeratorRequest(BaseModel):
    isModerator: bool

class UserWarnRequest(BaseModel):
    reason: str

class UserCurrencyRequest(BaseModel):
    dreamCoins: Optional[int] = None
    hellStones: Optional[int] = None

class MaintenanceRequest(BaseModel):
    chatMaintenance: Optional[bool] = None
    shopMaintenance: Optional[bool] = None

class BroadcastRequest(BaseModel):
    message: str
    isPersistent: bool = False

class AutoModConfigRequest(BaseModel):
    autoModEnabled: Optional[bool] = None
    moderationLevel: Optional[str] = None
    decayDays: Optional[int] = None
    bannedWords: Optional[List[str]] = None
    strike1Action: Optional[str] = None
    strike1DurationHours: Optional[int] = None
    strike2Action: Optional[str] = None
    strike2DurationHours: Optional[int] = None
    strike3Action: Optional[str] = None
    strike3DurationHours: Optional[int] = None

class BatchActionRequest(BaseModel):
    uids: List[str]
    action: str 
    params: Optional[dict] = None

class AdminChatMessageRequest(BaseModel):
    region: str
    text: str
    senderName: str
    isGhost: bool = False
    isSystem: bool = False

class MessageActionRequest(BaseModel):
    region: str
    messageId: str
    action: str 
    value: bool

class RouletteReward(BaseModel):
    id: str
    name: str
    type: str 
    itemId: Optional[str] = None
    amount: Optional[int] = None
    weight: int
    color: str 

class RouletteConfigRequest(BaseModel):
    rewards: List[RouletteReward]
    dailyFreeSpins: int = 1
    maxFreeSpins: int = 10
    spinBuyPrice: int = 50
    spinBuyCurrency: str = "dreamCoins"
