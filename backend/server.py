import asyncio
import json
import websockets
import os

# 儲存連線的玩家 {websocket: player_name}
clients = {}
# 儲存配對狀態 {websocket: opponent_websocket}
matches = {}
# 等待配對中的玩家
waiting_player = None

async def handler(websocket):
    global waiting_player
    print("有新連線進入...")
    
    try:
        async for message in websocket:
            data = json.loads(message)
            
            if data["type"] == "join":
                player_name = data["name"]
                clients[websocket] = player_name
                print(f"玩家 {player_name} 請求加入")
                
                # 簡單的配對邏輯：如果有因為人在等，就配對
                # 防呆：如果 waiting_player 已經不在 clients 裡 (例如斷線但沒清乾淨)，就重置
                if waiting_player and waiting_player not in clients:
                    waiting_player = None

                if waiting_player and waiting_player != websocket:
                    print(f"配對成功！ {clients[waiting_player]} vs {player_name}")
                    
                    # 記錄配對
                    matches[waiting_player] = websocket
                    matches[websocket] = waiting_player
                    
                    # 通知第一位玩家 (waiting_player)
                    await waiting_player.send(json.dumps({
                        "type": "match_success",
                        "opponent_name": player_name,
                        "role": "host" # 或是 p1
                    }))
                    
                    # 通知第二位玩家 (目前的 websocket)
                    await websocket.send(json.dumps({
                        "type": "match_success",
                        "opponent_name": clients[waiting_player],
                        "role": "client" # 或是 p2
                    }))
                    
                    # 清空等待者
                    waiting_player = None
                else:
                    print(f"玩家 {player_name} 進入等待列...")
                    waiting_player = websocket
            
            # 轉發遊戲同步訊息
            elif data["type"] == "sync_grid":
                if websocket in matches:
                    opponent = matches[websocket]
                    # 直接轉發給對手
                    await opponent.send(message)
                    
    except websockets.exceptions.ConnectionClosed:
        print("連線中斷")
    finally:
        # 確保無論如何都清除等待狀態
        if waiting_player == websocket:
            waiting_player = None
        
        # 清除配對狀態
        if websocket in matches:
            opponent = matches[websocket]
            if opponent in matches:
                del matches[opponent]
                # 可以選擇通知對手對方斷線了
            del matches[websocket]
            
        if websocket in clients:
            del clients[websocket]

async def main():
    PORT = int(os.environ.get("PORT", 8765))
    print(f"伺服器啟動中，監聽 port {PORT}...")
    async with websockets.serve(handler, "0.0.0.0", PORT):
        await asyncio.Future()
    #print("伺服器啟動中，監聽 port 8765...")
    #async with websockets.serve(handler, "0.0.0.0", 8765):
    #    await asyncio.Future()  # 讓程式持續執行

if __name__ == "__main__":
    asyncio.run(main())
