from typing import List, Optional
from pydantic import BaseModel

class ChatMessage(BaseModel):
    text: str
    senderDevice: str

class ReportRequest(BaseModel):
    reportedMessageId: str
    originalMessageText: str
    senderId: str
    senderDevice: str
    reporterId: str
    messageTimestamp: str
    categories: List[str]
    reporterEmail: Optional[str] = None

class SyncRequest(BaseModel):
    dreamCoins: int
    hellStones: int

class OfflineTransaction(BaseModel):
    id: str
    type: str # PURCHASE, CONVERSION, EARN, PLAYTIME, ROULETTE_SPIN, BUY_SPIN, ROULETTE_REWARD
    itemId: Optional[str] = None
    dreamDelta: int = 0
    hellDelta: int = 0
    playtimeDelta: int = 0 # In seconds
    freeSpinDelta: int = 0 
    timestamp: str

class ReconcileRequest(BaseModel):
    transactions: List[OfflineTransaction]

class ShopItemRequest(BaseModel):
    name: str
    type: str # character, powerup, item
    price: int
    currencyType: str # coins, tokens
    assetPath: str
    description: str
