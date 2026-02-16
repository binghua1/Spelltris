# Spelltris

A multiplayer Tetris game built with Godot Engine.

## Play Online

**[https://people.cs.nycu.edu.tw/~chenbh1010/spelltris/game/](https://people.cs.nycu.edu.tw/~chenbh1010/spelltris/game/)**

## Features

- Classic Tetris gameplay with multiplayer support
- Room-based matchmaking system
- Skill selection mechanics
- Real-time WebSocket communication
- Web-based, no installation required

## Tech Stack

### Frontend
- Godot 4.x engine
- GDScript
- Compiled to WebAssembly for browser deployment

### Backend
- Python with aiohttp
- WebSocket protocol
- Deployed on Render

## Project Structure

```
spelltris/
├── game/                 # Godot game project
│   ├── board.gd         # Game board logic
│   ├── game.gd          # Main game logic
│   ├── login.gd         # Login system
│   ├── lobby.gd         # Lobby system
│   ├── skill_select.gd  # Skill selection
│   ├── Network.gd       # Network module
│   ├── Global.gd        # Global state
│   └── index.html       # Web entry point
├── backend/             # Python backend server
│   ├── server.py        # WebSocket server
│   ├── requirements.txt # Dependencies
│   └── render.yaml      # Render deployment config
└── README.md
```

## How to Play

1. Enter your player name
2. Create a room or join an existing room with room ID
3. Select your skill
4. Play against your opponent
5. First player to fill the board loses

## Local Development

### Backend

```bash
cd backend
pip install -r requirements.txt
python server.py
```

Server runs on `http://localhost:8080`

### Frontend

1. Open `game/` folder in Godot Editor
2. Open `project.godot`
3. Press F5 to run
4. Export as HTML5 for web deployment

## License

Educational project.
