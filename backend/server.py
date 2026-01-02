import asyncio
import json
import uuid
import websockets
import os

# 儲存連線的玩家 {websocket: player_name}
clients = {}
# 儲存配對狀態 {websocket: opponent_websocket}
matches = {}
# 房間管理 {room_id: host_websocket}
rooms = {}

async def handler(websocket):
    global waiting_player
    print("有新連線進入...")
    
    try:
        async for message in websocket:
            data = json.loads(message)
            
            # 新協議：
            # - "login": 記錄玩家名稱
            # - "create": 建立房間 (可傳 room_id，若無則產生一個)
            # - "join": 使用 room_id 加入並配對
            if data["type"] == "login":
                player_name = data.get("name")
                if player_name:
                    clients[websocket] = player_name
                    print(f"玩家 {player_name} 已登入")
                    await websocket.send(json.dumps({"type": "login_success", "name": player_name}))
                else:
                    await websocket.send(json.dumps({"type": "error", "message": "missing name"}))

            elif data["type"] == "create":
                # 建立房間，回傳 room_id
                # 需要玩家已登入 (可選)
                room_id = data.get("room_id")
                room = data.get("room")
                if not room_id:
                    room_id = uuid.uuid4().hex[:8]
                rooms[room_id] = websocket
                room["room_id"] = room_id
                print(f"玩家 {clients.get(websocket)} 建立房間 {room_id}")
                for player in clients:
                    await player.send(json.dumps({"type": "create_success", "room": room}))

            elif data["type"] == "join":
                # 使用 room_id 去加入房間並完成配對
                room_id = data.get("room_id")
                if not room_id:
                    await websocket.send(json.dumps({"type": "error", "message": "missing room_id"}))
                elif room_id not in rooms:
                    await websocket.send(json.dumps({"type": "error", "message": "room not found"}))
                else:
                    host_ws = rooms.pop(room_id)
                    # 登記配對
                    matches[host_ws] = websocket
                    matches[websocket] = host_ws

                    # 通知雙方配對成功
                    await host_ws.send(json.dumps({
                        "type": "match_success",
                        "opponent_name": clients.get(websocket),
                        "role": "host",
                        "room_id": room_id
                    }))

                    await websocket.send(json.dumps({
                        "type": "match_success",
                        "opponent_name": clients.get(host_ws),
                        "role": "client",
                        "room_id": room_id
                    }))
            
            # 轉發遊戲同步訊息
            elif data["type"] == "sync_grid":
                if websocket in matches:
                    opponent = matches[websocket]
                    # 直接轉發給對手
                    await opponent.send(message)

            elif data["type"] == "game_end":
                if websocket in matches:
                    opponent = matches[websocket]
                    
                    await opponent.send(json.dumps({
                        "type": "win_game"
                    }))

                    
    except websockets.exceptions.ConnectionClosed:
        print("連線中斷")
    finally:
        # 如果這連線是某個房間的 host，移除房間
        to_remove = [r for r, ws in rooms.items() if ws == websocket]
        for r in to_remove:
            del rooms[r]

        # 清除配對狀態並可選擇通知對手
        if websocket in matches:
            opponent = matches[websocket]
            if opponent in matches:
                del matches[opponent]
            del matches[websocket]

        if websocket in clients:
            del clients[websocket]

async def main():
    port = int(os.environ.get("PORT", 10000))
    print(f"伺服器啟動中，監聽 port {port}...")
    async with websockets.serve(handler, "0.0.0.0", port):
        await asyncio.Future()  # 讓程式持續執行

if __name__ == "__main__":
    asyncio.run(main())
