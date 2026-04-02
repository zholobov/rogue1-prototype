class_name SignalingClient
extends Node

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal offer_received(peer_id: int, offer: String)
signal answer_received(peer_id: int, answer: String)
signal candidate_received(peer_id: int, mid: String, index: int, sdp: String)
signal lobby_joined(peer_id: int)
signal lobby_sealed()

var ws := WebSocketPeer.new()
var _connected := false
var _pending_lobby: String = ""

func connect_to_server(url: String) -> Error:
    GameLog.info("[Signaling] Connecting to %s..." % url)
    var err = ws.connect_to_url(url)
    if err != OK:
        GameLog.info("[Signaling] ERROR: connect_to_url failed: %d" % err)
    return err

func poll() -> void:
    ws.poll()
    var state = ws.get_ready_state()
    if state == WebSocketPeer.STATE_OPEN:
        if not _connected:
            _connected = true
            GameLog.info("[Signaling] WebSocket connected")
            if not _pending_lobby.is_empty():
                GameLog.info("[Signaling] Sending join for lobby: %s" % _pending_lobby)
                _send({"type": "join", "lobby": _pending_lobby})
                _pending_lobby = ""
        while ws.get_available_packet_count() > 0:
            var msg = ws.get_packet().get_string_from_utf8()
            GameLog.info("[Signaling] Received: %s" % msg.substr(0, 200))
            _handle_message(msg)
    elif state == WebSocketPeer.STATE_CLOSED:
        if _connected:
            _connected = false
            GameLog.info("[Signaling] WebSocket closed, code=%d reason=%s" % [ws.get_close_code(), ws.get_close_reason()])
    elif state == WebSocketPeer.STATE_CLOSING:
        pass  # waiting for close
    elif state == WebSocketPeer.STATE_CONNECTING:
        pass  # still connecting

func join_lobby(lobby_id: String) -> void:
    if _connected:
        GameLog.info("[Signaling] Already connected, sending join: %s" % lobby_id)
        _send({"type": "join", "lobby": lobby_id})
    else:
        GameLog.info("[Signaling] Not connected yet, queuing lobby: %s" % lobby_id)
        _pending_lobby = lobby_id

func send_offer(peer_id: int, offer: String) -> void:
    _send({"type": "offer", "peer_id": peer_id, "sdp": offer})

func send_answer(peer_id: int, answer: String) -> void:
    _send({"type": "answer", "peer_id": peer_id, "sdp": answer})

func send_candidate(peer_id: int, mid: String, index: int, sdp: String) -> void:
    _send({"type": "candidate", "peer_id": peer_id, "mid": mid, "index": index, "sdp": sdp})

func _send(data: Dictionary) -> void:
    ws.send_text(JSON.stringify(data))

func _handle_message(msg: String) -> void:
    var parsed = JSON.parse_string(msg)
    if parsed == null:
        return
    match parsed.get("type", ""):
        "peer_connected":
            peer_connected.emit(int(parsed["peer_id"]))
        "peer_disconnected":
            peer_disconnected.emit(int(parsed["peer_id"]))
        "offer":
            offer_received.emit(int(parsed["peer_id"]), parsed["sdp"])
        "answer":
            answer_received.emit(int(parsed["peer_id"]), parsed["sdp"])
        "candidate":
            candidate_received.emit(int(parsed["peer_id"]), parsed["mid"], int(parsed["index"]), parsed["sdp"])
        "joined":
            _connected = true
            lobby_joined.emit(int(parsed["peer_id"]))
        "sealed":
            lobby_sealed.emit()

func close() -> void:
    ws.close()
