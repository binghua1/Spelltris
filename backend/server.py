import asyncio
import json
import uuid
import os
from aiohttp import web

# 儲存連線的玩家 {websocket: player_name}
clients = {}
# 儲存配對狀態 {websocket: opponent_websocket}
matches = {}
# 房間管理 {room_id: room_info dict (包含公開欄位，以及內部欄位 '_host' 指向 websocket)}
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
                    # rooms 將儲存 room_info dict，內含內部鍵 '_host' 指向 websocket（不會回傳給 client）
                    # 客戶端傳入的 room 會包含 'name' 和 'host'，我們保留這些欄位，只額外加上 'room_id' 與內部 '_host'
                    room = data.get("room") or {}
                    room_id = uuid.uuid4().hex[:8]
                    room["room_id"] = room_id
                    room_info = dict(room)
                    room_info["_host"] = ws
                    rooms[room_id] = room_info
                    # 對外回傳時移除內部欄位
                    print(f"玩家 {clients.get(ws)} 建立房間 {room_id}")
                    for player in clients:
                        await player.send_json({"type": "create_success", "room": room})
                
                # 刪除房間（由 host 執行），用法類似 create，會給 room_id
                elif data["type"] == "delete":
                    room_id = data.get("room_id")
                    if not room_id:
                        await ws.send_json({"type": "error", "message": "missing room_id"})
                    elif room_id not in rooms:
                        await ws.send_json({"type": "error", "message": "room not found"})
                    else:
                        room_info = rooms.get(room_id)
                        # 僅允許房主刪除
                        if room_info.get("_host") != ws:
                            await ws.send_json({"type": "error", "message": "not host"})
                        else:
                            print(f"玩家 {clients.get(ws)} 刪除房間 {room_id}")
                            for player in clients:
                                await player.send_json({"type": "delete_success", "room_id": room_id})

                elif data["type"] == "join":
                    # 使用 room_id 去加入房間並完成配對
                    room_id = data.get("room_id")
                    if not room_id:
                        await ws.send_json({"type": "error", "message": "missing room_id"})
                    elif room_id not in rooms:
                        await ws.send_json({"type": "error", "message": "room not found"})
                    else:
                        host_info = rooms.pop(room_id)
                        host_ws = host_info.get("_host")
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

                # 要求獲取房間清單：直接回傳所有 rooms 的陣列（不需要查 clients）
                elif data["type"] == "room_list_request":
                    public_rooms = [{k: v for k, v in info.items() if k != "_host"} for info in rooms.values()]
                    await ws.send_json({
                        "type": "room_list_respond",
                        "rooms": public_rooms
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
                elif data['type'] == 'attack':
                    if ws in matches:
                        opponent = matches[ws]
                        # 直接轉發給對手
                        await opponent.send_str(msg.data)
                        
            elif msg.type == web.WSMsgType.ERROR:
                print('ws connection closed with exception %s', ws.exception())

    except Exception as e:
        print("連線中斷:", e)
    finally:
        # 如果這連線是某個房間的 host，移除房間
        to_remove = [r for r, info in rooms.items() if info.get("_host") == ws]
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
