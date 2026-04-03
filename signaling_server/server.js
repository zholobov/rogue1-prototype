const http = require("http");
const WebSocket = require("ws");

const PORT = process.env.PORT || 3000;
const HTTP_PEER_TIMEOUT_MS = 60000;   // Remove HTTP peers that haven't polled in 60s
const LOBBY_IDLE_TIMEOUT_MS = 300000; // Remove lobbies idle for 5 minutes
const MAX_QUEUE_SIZE = 100;           // Max queued messages per HTTP peer
const SWEEP_INTERVAL_MS = 30000;      // Run cleanup every 30s

// lobby_id -> { peers: Map<peer_id, { ws?, queue?, lastPoll? }>, nextId: number, lastActivity: number }
const lobbies = new Map();

// HTTP polling: pending long-poll responses waiting for messages
// peer_key -> { res, timer }
const pendingPolls = new Map();

function peerKey(lobbyId, peerId) {
  return `${lobbyId}:${peerId}`;
}

function now() {
  return Date.now();
}

// Deliver a message to a peer (WebSocket or queue for HTTP polling)
function deliverToPeer(lobbyId, peerId, data) {
  const lobby = lobbies.get(lobbyId);
  if (!lobby) return;
  const peer = lobby.peers.get(peerId);
  if (!peer) return;
  lobby.lastActivity = now();

  if (peer.ws) {
    // WebSocket peer
    if (peer.ws.readyState === WebSocket.OPEN) {
      peer.ws.send(JSON.stringify(data));
    }
  } else if (peer.queue) {
    // HTTP polling peer — queue the message (cap size)
    peer.queue.push(data);
    if (peer.queue.length > MAX_QUEUE_SIZE) {
      peer.queue.splice(0, peer.queue.length - MAX_QUEUE_SIZE);
    }
    // If there's a pending long-poll, resolve it immediately
    const key = peerKey(lobbyId, peerId);
    const pending = pendingPolls.get(key);
    if (pending) {
      clearTimeout(pending.timer);
      pendingPolls.delete(key);
      const messages = peer.queue.splice(0);
      pending.res.writeHead(200, { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" });
      pending.res.end(JSON.stringify(messages));
    }
  }
}

// Remove a peer from their lobby and notify others
function removePeer(lobbyId, peerId) {
  const lobby = lobbies.get(lobbyId);
  if (!lobby) return;
  lobby.peers.delete(peerId);
  for (const [pid] of lobby.peers) {
    deliverToPeer(lobbyId, pid, { type: "peer_disconnected", peer_id: peerId });
  }
  if (lobby.peers.size === 0) {
    lobbies.delete(lobbyId);
  }
  // Clean up any pending poll
  const key = peerKey(lobbyId, peerId);
  const pending = pendingPolls.get(key);
  if (pending) {
    clearTimeout(pending.timer);
    pendingPolls.delete(key);
    pending.res.writeHead(200, { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" });
    pending.res.end("[]");
  }
  console.log(`Peer ${peerId} left lobby ${lobbyId}`);
}

// Periodic cleanup: remove stale HTTP peers and idle lobbies
function sweep() {
  const t = now();
  for (const [lobbyId, lobby] of lobbies) {
    // Remove HTTP peers that haven't polled recently
    for (const [peerId, peer] of lobby.peers) {
      if (peer.queue && peer.lastPoll && (t - peer.lastPoll > HTTP_PEER_TIMEOUT_MS)) {
        console.log(`[Sweep] Removing stale HTTP peer ${peerId} from lobby ${lobbyId} (${t - peer.lastPoll}ms idle)`);
        removePeer(lobbyId, peerId);
      }
    }
    // Remove idle lobbies
    if (lobby.peers.size === 0) {
      lobbies.delete(lobbyId);
    } else if (t - lobby.lastActivity > LOBBY_IDLE_TIMEOUT_MS) {
      console.log(`[Sweep] Removing idle lobby ${lobbyId} (${lobby.peers.size} peers, ${t - lobby.lastActivity}ms idle)`);
      // Notify remaining peers before removing
      for (const [peerId] of lobby.peers) {
        const key = peerKey(lobbyId, peerId);
        const pending = pendingPolls.get(key);
        if (pending) {
          clearTimeout(pending.timer);
          pendingPolls.delete(key);
          pending.res.writeHead(200, { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" });
          pending.res.end("[]");
        }
      }
      lobbies.delete(lobbyId);
    }
  }
}

setInterval(sweep, SWEEP_INTERVAL_MS);

// ==================== HTTP Server ====================

const httpServer = http.createServer((req, res) => {
  // CORS headers for all responses
  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    });
    res.end();
    return;
  }

  const url = new URL(req.url, `http://${req.headers.host}`);
  const path = url.pathname;

  // Health check
  if (path === "/" || path === "/health") {
    res.writeHead(200, { "Content-Type": "text/plain", "Access-Control-Allow-Origin": "*" });
    res.end("ok");
    return;
  }

  // ---- HTTP Polling API ----

  if (path === "/api/join" && req.method === "POST") {
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      let data;
      try { data = JSON.parse(body); } catch { res.writeHead(400); res.end(); return; }
      const lobbyId = data.lobby || "default";
      if (!lobbies.has(lobbyId)) {
        lobbies.set(lobbyId, { peers: new Map(), nextId: 1, lastActivity: now() });
      }
      const lobby = lobbies.get(lobbyId);
      lobby.lastActivity = now();
      const peerId = lobby.nextId++;
      lobby.peers.set(peerId, { queue: [], lastPoll: now() });

      // Notify existing peers and queue notifications for the new peer
      const peer = lobby.peers.get(peerId);
      for (const [pid] of lobby.peers) {
        if (pid !== peerId) {
          deliverToPeer(lobbyId, pid, { type: "peer_connected", peer_id: peerId });
          peer.queue.push({ type: "peer_connected", peer_id: pid });
        }
      }

      console.log(`[HTTP] Peer ${peerId} joined lobby ${lobbyId} (${lobby.peers.size} peers)`);
      res.writeHead(200, { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" });
      res.end(JSON.stringify({ peer_id: peerId, lobby: lobbyId }));
    });
    return;
  }

  if (path === "/api/send" && req.method === "POST") {
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      let data;
      try { data = JSON.parse(body); } catch { res.writeHead(400); res.end(); return; }
      const lobbyId = data.lobby;
      const fromPeerId = data.from_peer_id;
      const targetPeerId = data.peer_id;
      if (!lobbyId || !fromPeerId || targetPeerId == null) {
        res.writeHead(400);
        res.end();
        return;
      }
      // Replace peer_id with sender's ID (same as WebSocket relay)
      const relay = Object.assign({}, data);
      delete relay.lobby;
      delete relay.from_peer_id;
      relay.peer_id = fromPeerId;
      deliverToPeer(lobbyId, targetPeerId, relay);
      res.writeHead(200, { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" });
      res.end("{}");
    });
    return;
  }

  if (path === "/api/poll" && req.method === "GET") {
    const lobbyId = url.searchParams.get("lobby");
    const peerId = parseInt(url.searchParams.get("peer_id"));
    if (!lobbyId || isNaN(peerId)) {
      res.writeHead(400, { "Access-Control-Allow-Origin": "*" });
      res.end();
      return;
    }
    const lobby = lobbies.get(lobbyId);
    if (!lobby || !lobby.peers.has(peerId)) {
      res.writeHead(404, { "Access-Control-Allow-Origin": "*" });
      res.end();
      return;
    }
    const peer = lobby.peers.get(peerId);
    if (!peer.queue) {
      res.writeHead(400, { "Access-Control-Allow-Origin": "*" });
      res.end();
      return;
    }

    // Update last poll time
    peer.lastPoll = now();
    lobby.lastActivity = now();

    // If messages are already queued, return immediately
    if (peer.queue.length > 0) {
      const messages = peer.queue.splice(0);
      res.writeHead(200, { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" });
      res.end(JSON.stringify(messages));
      return;
    }

    // Long-poll: hold the request open for up to 25 seconds
    const key = peerKey(lobbyId, peerId);
    // Cancel any existing poll for this peer
    if (pendingPolls.has(key)) {
      const old = pendingPolls.get(key);
      clearTimeout(old.timer);
      old.res.writeHead(200, { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" });
      old.res.end("[]");
    }
    const timer = setTimeout(() => {
      pendingPolls.delete(key);
      res.writeHead(200, { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" });
      res.end("[]");
    }, 25000);
    pendingPolls.set(key, { res, timer });
    return;
  }

  if (path === "/api/leave" && req.method === "POST") {
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      let data;
      try { data = JSON.parse(body); } catch { res.writeHead(400); res.end(); return; }
      removePeer(data.lobby, data.peer_id);
      res.writeHead(200, { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" });
      res.end("{}");
    });
    return;
  }

  // Unknown route
  res.writeHead(404, { "Access-Control-Allow-Origin": "*" });
  res.end();
});

// ==================== WebSocket Server ====================

const wss = new WebSocket.Server({ server: httpServer });

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
        lobbies.set(lobbyId, { peers: new Map(), nextId: 1, lastActivity: now() });
      }
      const lobby = lobbies.get(lobbyId);
      lobby.lastActivity = now();
      myPeerId = lobby.nextId++;

      // Send joined first so the client creates the mesh before adding peers
      lobby.peers.set(myPeerId, { ws });
      deliverToPeer(lobbyId, myPeerId, { type: "joined", peer_id: myPeerId });

      // Then notify about existing peers (both directions)
      for (const [peerId] of lobby.peers) {
        if (peerId !== myPeerId) {
          deliverToPeer(lobbyId, peerId, { type: "peer_connected", peer_id: myPeerId });
          deliverToPeer(lobbyId, myPeerId, { type: "peer_connected", peer_id: peerId });
        }
      }
      console.log(`[WS] Peer ${myPeerId} joined lobby ${lobbyId} (${lobby.peers.size} peers)`);
      return;
    }

    // Relay messages to target peer
    if (msg.peer_id != null && myLobby) {
      const lobby = lobbies.get(myLobby);
      if (lobby) {
        lobby.lastActivity = now();
        const targetPeerId = msg.peer_id;
        msg.peer_id = myPeerId; // Replace with sender's ID
        deliverToPeer(myLobby, targetPeerId, msg);
      }
    }
  });

  ws.on("close", () => {
    if (myLobby && myPeerId != null) {
      removePeer(myLobby, myPeerId);
    }
  });
});

httpServer.listen(PORT, () => {
  console.log(`Signaling server listening on port ${PORT}`);
});
