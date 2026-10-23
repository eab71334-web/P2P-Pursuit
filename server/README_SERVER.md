# Online server

One headless process = one room (mode fixed by the command line):
- `--teams=1`  co-op (2 players)   - default port 24570
- `--teams=2`  team race (4)       - 24571
- `--ffa=4`    free for all (4)    - 24572
- `--squads=2 --ffa=6` squads mode, `--port=N` custom port.

Matchmaking is automatic: players join, the countdown starts when the room is full (8 s) or has the minimum
(2 players, 30 s wait for more), the race runs on the server, then the room reopens by itself after 12 s.
Nobody presses READY online.

Run: build the "Online Server (Linux)" GitHub action, download `rally-server`, copy to a Linux machine,
open UDP 24570-24572, run `./run_server.sh`. In the game: PLAY > Online > type the server IP.

Limits (honest): one room per mode per server; no accounts/anti-cheat; tested only locally (1 server + 2 clients
on one machine), never across the internet.
