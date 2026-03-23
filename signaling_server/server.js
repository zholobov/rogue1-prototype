const WebSocket = require("ws");

const PORT = process.env.PORT || 9090;
const wss = new WebSocket.Server({ port: PORT });

// lobby_id -> Map<peer_id, WebSocket>
const lobbies = new Map();
let nextPeerId = 1;

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
      myPeerId = nextPeerId++;
      myLobby = lobbyId;

      if (!lobbies.has(lobbyId)) {
        lobbies.set(lobbyId, new Map());
      }
      const lobby = lobbies.get(lobbyId);

      // Notify existing peers about new peer
      for (const [peerId, peerWs] of lobby) {
        send(peerWs, { type: "peer_connected", peer_id: myPeerId });
        send(ws, { type: "peer_connected", peer_id: peerId });
      }

      lobby.set(myPeerId, ws);
      send(ws, { type: "joined", peer_id: myPeerId });
      console.log(`Peer ${myPeerId} joined lobby ${lobbyId} (${lobby.size} peers)`);
      return;
    }

    // Relay messages to target peer
    if (msg.peer_id != null && myLobby) {
      const lobby = lobbies.get(myLobby);
      if (lobby) {
        const targetWs = lobby.get(msg.peer_id);
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
        lobby.delete(myPeerId);
        for (const [, peerWs] of lobby) {
          send(peerWs, { type: "peer_disconnected", peer_id: myPeerId });
        }
        if (lobby.size === 0) {
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

console.log(`Signaling server listening on port ${PORT}`);
