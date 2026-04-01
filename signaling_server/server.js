const http = require("http");
const WebSocket = require("ws");

const PORT = process.env.PORT || 3000;

// HTTP health-check for Cloudflare tunnel monitoring
const httpServer = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/plain" });
  res.end("ok");
});

const wss = new WebSocket.Server({ server: httpServer });

// lobby_id -> { peers: Map<peer_id, WebSocket>, nextId: number }
const lobbies = new Map();

wss.on("connection", (ws) => {
  let myPeerId = null;
  let myLobby = null;

  ws.on("message", (data) => {
    let msg;
    try {
      msg = JSON.parse(data);
    } catch {
      return;
    }

    if (msg.type === "join") {
      const lobbyId = msg.lobby || "default";
      myLobby = lobbyId;

      if (!lobbies.has(lobbyId)) {
        lobbies.set(lobbyId, { peers: new Map(), nextId: 1 });
      }
      const lobby = lobbies.get(lobbyId);
      myPeerId = lobby.nextId++;

      // Send joined first so the client creates the mesh before adding peers
      lobby.peers.set(myPeerId, ws);
      send(ws, { type: "joined", peer_id: myPeerId });

      // Then notify about existing peers (both directions)
      for (const [peerId, peerWs] of lobby.peers) {
        if (peerId !== myPeerId) {
          send(peerWs, { type: "peer_connected", peer_id: myPeerId });
          send(ws, { type: "peer_connected", peer_id: peerId });
        }
      }
      console.log(`Peer ${myPeerId} joined lobby ${lobbyId} (${lobby.peers.size} peers)`);
      return;
    }

    // Relay messages to target peer
    if (msg.peer_id != null && myLobby) {
      const lobby = lobbies.get(myLobby);
      if (lobby) {
        const targetWs = lobby.peers.get(msg.peer_id);
        if (targetWs) {
          msg.peer_id = myPeerId; // Replace with sender's ID
          send(targetWs, msg);
        }
      }
    }
  });

  ws.on("close", () => {
    if (myLobby && myPeerId != null) {
      const lobby = lobbies.get(myLobby);
      if (lobby) {
        lobby.peers.delete(myPeerId);
        for (const [, peerWs] of lobby.peers) {
          send(peerWs, { type: "peer_disconnected", peer_id: myPeerId });
        }
        if (lobby.peers.size === 0) {
          lobbies.delete(myLobby);
        }
        console.log(`Peer ${myPeerId} left lobby ${myLobby}`);
      }
    }
  });
});

function send(ws, data) {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(data));
  }
}

httpServer.listen(PORT, () => {
  console.log(`Signaling server listening on port ${PORT}`);
});
