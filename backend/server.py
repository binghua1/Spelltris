import asyncio
import json
import uuid
import os
from aiohttp import web

# 儲存連線的玩家 {websocket: player_name}
clients = {}
# 儲存配對狀態 {websocket: opponent_websocket}
matches = {}
# 房間管理 {room_id: host_websocket}
rooms = {}

async def health(request):
    return web.Response(text="ok")

async def websocket_handler(request):
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    
    print("有新連線進入...")
    
    try:
        async for msg in ws:
            if msg.type == web.WSMsgType.TEXT:
                data = json.loads(msg.data)
                
                # 新協議：
                # - "login": 記錄玩家名稱
                # - "create": 建立房間 (可傳 room_id，若無則產生一個)
                # - "join": 使用 room_id 加入並配對
                if data["type"] == "login":
                    player_name = data.get("name")
                    if player_name:
                        clients[ws] = player_name
                        print(f"玩家 {player_name} 已登入")
                        await ws.send_json({"type": "login_success", "name": player_name})
                    else:
                        await ws.send_json({"type": "error", "message": "missing name"})

                elif data["type"] == "create":
                    # 建立房間，回傳 room_id
                    # 需要玩家已登入 (可選)
                    room_id = data.get("room_id")
                    room = data.get("room")
                    if not room_id:
                        room_id = uuid.uuid4().hex[:8]
                    rooms[room_id] = ws
                    room["room_id"] = room_id
                    print(f"玩家 {clients.get(ws)} 建立房間 {room_id}")
                    for player in clients:
                        await player.send_json({"type": "create_success", "room": room})

                elif data["type"] == "join":
                    # 使用 room_id 去加入房間並完成配對
                    room_id = data.get("room_id")
                    if not room_id:
                        await ws.send_json({"type": "error", "message": "missing room_id"})
                    elif room_id not in rooms:
                        await ws.send_json({"type": "error", "message": "room not found"})
                    else:
                        host_ws = rooms.pop(room_id)
                        # 登記配對
                        matches[host_ws] = ws
                        matches[ws] = host_ws

                        # 通知雙方配對成功
                        await host_ws.send_json({
                            "type": "match_success",
                            "opponent_name": clients.get(ws),
                            "role": "host",
                            "room_id": room_id
                        })

                        await ws.send_json({
                            "type": "match_success",
                            "opponent_name": clients.get(host_ws),
                            "role": "client",
                            "room_id": room_id
                        })
                
                # 轉發遊戲同步訊息
                elif data["type"] == "sync_grid":
                    if ws in matches:
                        opponent = matches[ws]
                        # 直接轉發給對手
                        await opponent.send_str(msg.data)

                elif data["type"] == "game_end":
                    if ws in matches:
                        opponent = matches[ws]
                        
                        await opponent.send_json({
                            "type": "win_game"
                        })
            elif msg.type == web.WSMsgType.ERROR:
                print('ws connection closed with exception %s', ws.exception())

    except Exception as e:
        print("連線中斷:", e)
    finally:
        # 如果這連線是某個房間的 host，移除房間
        to_remove = [r for r, w in rooms.items() if w == ws]
        for r in to_remove:
            del rooms[r]

        # 清除配對狀態並可選擇通知對手
        if ws in matches:
            opponent = matches[ws]
            if opponent in matches:
                del matches[opponent]
            del matches[ws]

        if ws in clients:
            del clients[ws]
    
    return ws

app = web.Application()
app.router.add_get("/", health)
app.router.add_get("/ws", websocket_handler)

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8765))
    web.run_app(app, port=port)
