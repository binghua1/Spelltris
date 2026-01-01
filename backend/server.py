import asyncio
import json
import os
from aiohttp import web

# 玩家管理
clients = {}
matches = {}
waiting_player = None

async def health(request):
    return web.Response(text="ok")

async def websocket_handler(request):
    global waiting_player
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    print("WebSocket 連線進來...")

    try:
        async for msg in ws:
            if msg.type != web.WSMsgType.TEXT:
                continue
            data = json.loads(msg.data)

            if data["type"] == "join":
                player_name = data["name"]
                clients[ws] = player_name
                print(f"玩家 {player_name} 請求加入")

                if waiting_player and waiting_player not in clients:
                    waiting_player = None

                if waiting_player and waiting_player != ws:
                    print(f"配對成功！ {clients[waiting_player]} vs {player_name}")
                    matches[waiting_player] = ws
                    matches[ws] = waiting_player

                    await waiting_player.send_json({
                        "type": "match_success",
                        "opponent_name": player_name,
                        "role": "host"
                    })
                    await ws.send_json({
                        "type": "match_success",
                        "opponent_name": clients[waiting_player],
                        "role": "client"
                    })
                    waiting_player = None
                else:
                    print(f"玩家 {player_name} 進入等待列...")
                    waiting_player = ws

            elif data["type"] == "sync_grid":
                if ws in matches:
                    opponent = matches[ws]
                    await opponent.send_str(msg.data)

    except Exception as e:
        print("連線中斷:", e)
    finally:
        if waiting_player == ws:
            waiting_player = None
        if ws in matches:
            opponent = matches[ws]
            if opponent in matches:
                del matches[opponent]
            del matches[ws]
        if ws in clients:
            del clients[ws]

    return ws

app = web.Application()
app.router.add_get("/", health)        # Render Health Check
app.router.add_get("/ws", websocket_handler)  # Godot WebSocket

PORT = int(os.environ.get("PORT", 10000))
web.run_app(app, port=PORT)

