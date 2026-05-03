from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes import auth, profile

app = FastAPI(title="DreamHunter API", version="1.0.0")

# Configure CORS for Flutter (Web, Mobile, Desktop)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your actual domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Routers
app.include_router(auth.router, prefix="/api")
app.include_router(profile.router, prefix="/api")

@app.get("/")
async def root():
    return {"message": "Welcome to the DreamHunter API", "status": "online"}
