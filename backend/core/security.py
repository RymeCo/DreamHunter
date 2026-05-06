from fastapi import HTTPException, Security, status, Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from core.firebase import auth_client, db

security = HTTPBearer()

async def get_current_user(auth: HTTPAuthorizationCredentials = Security(security)):
    """
    Verifies the Firebase ID token passed in the Authorization header.
    Returns the user's UID if valid.
    """
    token = auth.credentials
    try:
        decoded_token = auth_client.verify_id_token(token)
        return decoded_token['uid']
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid authentication credentials: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )

async def get_verified_user(auth: HTTPAuthorizationCredentials = Security(security)):
    """
    Verifies the token AND ensures the email is verified.
    """
    token = auth.credentials
    try:
        decoded_token = auth_client.verify_id_token(token)
        if not decoded_token.get('email_verified', False):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="EMAIL_NOT_VERIFIED"
            )
        return decoded_token['uid']
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid authentication credentials: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )

async def get_admin_user(uid: str = Depends(get_current_user)):
    """
    Verifies that the current user has the 'admin' role.
    """
    doc = db.collection("players").document(uid).get()
    if not doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player not found"
        )
    
    player_data = doc.to_dict()
    if player_data.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin role required"
        )
    
    return uid
