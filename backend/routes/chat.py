from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from typing import List, Dict
import datetime
import ujson

router = APIRouter()

class ConnectionManager:
    def __init__(self):
        # region -> list of websockets
        self.active_connections: Dict[str, List[WebSocket]] = {}
        # region -> list of recent messages (max 50)
        self.history: Dict[str, List[dict]] = {}

    async def connect(self, websocket: WebSocket, region: str):
        await websocket.accept()
        if region not in self.active_connections:
            self.active_connections[region] = []
        self.active_connections[region].append(websocket)
        
        # Send history to the newly connected client
        if region in self.history:
            for msg in self.history[region]:
                await websocket.send_text(ujson.dumps(msg))

    def disconnect(self, websocket: WebSocket, region: str):
        if region in self.active_connections:
            self.active_connections[region].remove(websocket)

    async def broadcast(self, message: dict, region: str):
        # Update history
        if region not in self.history:
            self.history[region] = []
        
        self.history[region].append(message)
        if len(self.history[region]) > 50:
            self.history[region].pop(0)

        # Broadcast to all active connections in the region
        if region in self.active_connections:
            for connection in self.active_connections[region]:
                try:
                    await connection.send_text(ujson.dumps(message))
                except Exception:
                    # Handle stale connections
                    pass

manager = ConnectionManager()

@router.websocket("/ws/chat/{region}")
async def websocket_endpoint(websocket: WebSocket, region: str):
    await manager.connect(websocket, region)
    try:
        while True:
            data = await websocket.receive_text()
            message_data = ujson.loads(data)
            
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
