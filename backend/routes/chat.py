from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
from typing import List, Dict
import datetime
import ujson
from core.firebase import auth_client
from services.settings_service import settings_service

router = APIRouter()

class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, List[WebSocket]] = {}
        self.history: Dict[str, List[dict]] = {}

    async def connect(self, websocket: WebSocket, region: str):
        await websocket.accept()
        print(f"[CHAT] Accepted connection for region: {region}")
        
        if region not in self.active_connections:
            self.active_connections[region] = []
        self.active_connections[region].append(websocket)
        
        if region in self.history:
            print(f"[CHAT] Sending {len(self.history[region])} messages of history to {region}")
            for msg in self.history[region]:
                try:
                    await websocket.send_text(ujson.dumps(msg))
                except Exception as e:
                    print(f"[CHAT] Error sending history: {e}")
                    break
        else:
            print(f"[CHAT] No history found for region: {region}")

    def disconnect(self, websocket: WebSocket, region: str):
        if region in self.active_connections:
            try:
                self.active_connections[region].remove(websocket)
            except ValueError:
                pass

    async def broadcast(self, message: dict, region: str):
        # Handle message deletion/censorship
        if message.get("type") == "delete":
            target_id = message.get("targetId")
            if region in self.history:
                self.history[region] = [m for m in self.history[region] if m.get("id") != target_id]
        else:
            if region not in self.history:
                self.history[region] = []
            
            self.history[region].append(message)
            if len(self.history[region]) > 50:
                self.history[region].pop(0)

        if region in self.active_connections:
            stale_connections = []
            for connection in self.active_connections[region]:
                try:
                    await connection.send_text(ujson.dumps(message))
                except Exception:
                    stale_connections.append(connection)
            
            for stale in stale_connections:
                self.disconnect(stale, region)

manager = ConnectionManager()

@router.websocket("/ws/chat/{region}")
async def websocket_endpoint(websocket: WebSocket, region: str, token: str = Query(...)):
    if not settings_service.is_chat_enabled():
        await websocket.accept() 
        await websocket.close(code=1008, reason="CHAT_DISABLED")
        return

    try:
        decoded_token = auth_client.verify_id_token(token)
        uid = decoded_token['uid']
        
        # Check if user is admin (optional: cache this)
        from core.firebase import db
        user_doc = db.collection("players").document(uid).get()
        is_admin = user_doc.exists and user_doc.to_dict().get("role") == "admin"
        
    except Exception as e:
        print(f"Auth error: {e}")
        await websocket.close(code=1008) # Policy Violation
        return

    await manager.connect(websocket, region)
    try:
        while True:
            data = await websocket.receive_text()
            message_data = ujson.loads(data)
            
            # Security: Only admins can delete/censor
            if message_data.get("type") == "delete" and not is_admin:
                continue

            # Mute/Ban Check (Re-check from DB for every message to be safe)
            user_doc = db.collection("players").document(uid).get()
            if not user_doc.exists:
                continue
            
            p = user_doc.to_dict()
            
            # 1. Check if Banned (Account)
            now = datetime.datetime.now(datetime.timezone.utc).isoformat()
            is_perm_banned = p.get("isBannedPermanent", False)
            ban_until = p.get("banUntil")
            
            if is_perm_banned or (ban_until and ban_until > now):
                await websocket.close(code=1008, reason="ACCOUNT_BANNED")
                break

            # 2. Check if Muted (Chat)
            is_muted_flag = p.get("isBannedFromChat", False)
            mute_until = p.get("muteUntil")
            
            if is_muted_flag or (mute_until and mute_until > now):
                # Optionally send a private system message to the user
                continue

            message_data["senderId"] = uid
            
            message_data["timestamp"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
            if "id" not in message_data:
                message_data["id"] = f"msg_{int(datetime.datetime.now().timestamp() * 1000)}"
            message_data["region"] = region
            
            await manager.broadcast(message_data, region)
    except WebSocketDisconnect:
        manager.disconnect(websocket, region)
    except Exception as e:
        print(f"WebSocket error: {e}")
        manager.disconnect(websocket, region)
