from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
from typing import List, Dict
import datetime
import ujson
from core.firebase import auth_client

router = APIRouter()

class ConnectionManager:
    def __init__(self):
        # region -> list of websockets
        self.active_connections: Dict[str, List[WebSocket]] = {}
        # region -> list of recent messages (max 50)
        self.history: Dict[str, List[dict]] = {}

    async def connect(self, websocket: WebSocket, region: str):
        await websocket.accept()
        print(f"[CHAT] Accepted connection for region: {region}")
        
        if region not in self.active_connections:
            self.active_connections[region] = []
        self.active_connections[region].append(websocket)
        
        # Send history to the newly connected client
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
        # Update history
        if region not in self.history:
            self.history[region] = []
        
        self.history[region].append(message)
        if len(self.history[region]) > 50:
            self.history[region].pop(0)

        # Broadcast to all active connections in the region
        if region in self.active_connections:
            stale_connections = []
            for connection in self.active_connections[region]:
                try:
                    await connection.send_text(ujson.dumps(message))
                except Exception:
                    stale_connections.append(connection)
            
            # Clean up stale connections
            for stale in stale_connections:
                self.disconnect(stale, region)

manager = ConnectionManager()

@router.websocket("/ws/chat/{region}")
async def websocket_endpoint(websocket: WebSocket, region: str, token: str = Query(...)):
    # 1. Verify Identity (Security Gap Fix)
    try:
        decoded_token = auth_client.verify_id_token(token)
        uid = decoded_token['uid']
    except Exception as e:
        print(f"Auth error: {e}")
        await websocket.close(code=1008) # Policy Violation
        return

    await manager.connect(websocket, region)
    try:
        while True:
            data = await websocket.receive_text()
            message_data = ujson.loads(data)
            
            # 2. Prevent Impersonation (Security Gap Fix)
            # Override senderId with the verified UID from the token
            message_data["senderId"] = uid
            
            # Add server-side timestamp and ID
            message_data["timestamp"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
            message_data["id"] = f"msg_{int(datetime.datetime.now().timestamp() * 1000)}"
            message_data["region"] = region
            
            await manager.broadcast(message_data, region)
    except WebSocketDisconnect:
        manager.disconnect(websocket, region)
    except Exception as e:
        print(f"WebSocket error: {e}")
        manager.disconnect(websocket, region)
