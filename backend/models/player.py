from pydantic import BaseModel, Field
from typing import List, Map, Optional
from datetime import datetime

class PlayerModel(BaseModel):
    uid: str
    name: str
    createdAt: str
    banned: List[str] = []
    
    # Progression
    level: int = 1
    xp: int = 0
    totalGameTime: int = 0
    
    # Economy
    coins: int = 100
    stones: int = 0
    
    # Inventory: Map of Item ID -> Amount
    inventory: dict = {}

    class Config:
        populate_by_name = True
