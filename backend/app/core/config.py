import os
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "DreamHunter API"
    FIREBASE_SERVICE_ACCOUNT: str | None = os.getenv("FIREBASE_SERVICE_ACCOUNT")
    ADMIN_UIDS: list[str] = os.getenv("ADMIN_UIDS", "").split(",")
    
    # Economy Constants
    MAX_DREAM_COINS_PER_HOUR: int = 5000
    HELL_TO_DREAM_RATE: int = 100
    
    # Moderation
    AUTO_MOD_ENABLED: bool = True
    
    class Config:
        env_file = ".env"

settings = Settings()
