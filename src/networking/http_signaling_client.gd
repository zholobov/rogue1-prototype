class_name HTTPSignalingClient
extends Node

## HTTP long-polling signaling client — same interface as SignalingClient
## Used as fallback when WebSocket is blocked.

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal offer_received(peer_id: int, offer: String)
signal answer_received(peer_id: int, answer: String)
signal candidate_received(peer_id: int, mid: String, index: int, sdp: String)
signal lobby_joined(peer_id: int)
signal lobby_sealed()

var _base_url: String = ""
var _peer_id: int = 0
var _lobby_id: String = ""
var _connected := false
var _polling := false
var _pending_lobby: String = ""

func connect_to_server(url: String) -> Error:
    # Convert wss://host to https://host for HTTP API
    _base_url = url.replace("wss://", "https://").replace("ws://", "http://")
    GameLog.info("[HTTPSignaling] Using base URL: %s" % _base_url)
    _connected = true
    if not _pending_lobby.is_empty():
        _join(_pending_lobby)
        _pending_lobby = ""
    return OK

func poll() -> void:
    pass  # HTTP client uses HTTPRequest callbacks, no frame-based polling needed

func join_lobby(lobby_id: String) -> void:
    if _connected:
        _join(lobby_id)
    else:
        _pending_lobby = lobby_id

func send_offer(peer_id: int, offer: String) -> void:
    _send_message({"type": "offer", "peer_id": peer_id, "sdp": offer})

func send_answer(peer_id: int, answer: String) -> void:
    _send_message({"type": "answer", "peer_id": peer_id, "sdp": answer})

func send_candidate(peer_id: int, mid: String, index: int, sdp: String) -> void:
    _send_message({"type": "candidate", "peer_id": peer_id, "mid": mid, "index": index, "sdp": sdp})

func close() -> void:
    _polling = false
    if _peer_id > 0 and _lobby_id != "":
        var req = HTTPRequest.new()
        add_child(req)
        req.request(_base_url + "/api/leave",
            ["Content-Type: application/json"], HTTPClient.METHOD_POST,
            JSON.stringify({"lobby": _lobby_id, "peer_id": _peer_id}))
        req.request_completed.connect(func(_r, _c, _h, _b): req.queue_free())
    _peer_id = 0
    _lobby_id = ""
    _connected = false

func _join(lobby_id: String) -> void:
    _lobby_id = lobby_id
    GameLog.info("[HTTPSignaling] Joining lobby: %s" % lobby_id)
    var req = HTTPRequest.new()
    add_child(req)
    req.request_completed.connect(_on_join_response.bind(req))
    req.request(_base_url + "/api/join",
        ["Content-Type: application/json"], HTTPClient.METHOD_POST,
        JSON.stringify({"lobby": lobby_id}))

func _on_join_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, req: HTTPRequest) -> void:
    req.queue_free()
    if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        GameLog.info("[HTTPSignaling] Join failed: result=%d code=%d" % [result, response_code])
        return
    var parsed = JSON.parse_string(body.get_string_from_utf8())
    if not parsed:
        GameLog.info("[HTTPSignaling] Join response parse failed")
        return
    _peer_id = int(parsed["peer_id"])
    _lobby_id = parsed["lobby"]
    GameLog.info("[HTTPSignaling] Joined as peer %d in lobby %s" % [_peer_id, _lobby_id])
    lobby_joined.emit(_peer_id)
    # Start polling for messages
    _polling = true
    _start_poll()

func _send_message(data: Dictionary) -> void:
    data["lobby"] = _lobby_id
    data["from_peer_id"] = _peer_id
    var req = HTTPRequest.new()
    add_child(req)
    req.request_completed.connect(func(_r, _c, _h, _b): req.queue_free())
    req.request(_base_url + "/api/send",
        ["Content-Type: application/json"], HTTPClient.METHOD_POST,
        JSON.stringify(data))

func _start_poll() -> void:
    if not _polling or _peer_id == 0:
        return
    var req = HTTPRequest.new()
    req.timeout = 30.0
    add_child(req)
    req.request_completed.connect(_on_poll_response.bind(req))
    req.request(_base_url + "/api/poll?lobby=%s&peer_id=%d" % [_lobby_id, _peer_id])

func _on_poll_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, req: HTTPRequest) -> void:
    req.queue_free()
    if not _polling:
        return
    if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
        var text = body.get_string_from_utf8()
        if text != "" and text != "[]":
            var messages = JSON.parse_string(text)
            if messages is Array:
                for msg in messages:
                    _handle_message(msg)
    # Continue polling
    _start_poll()

func _handle_message(parsed: Dictionary) -> void:
    var msg_type = parsed.get("type", "")
    match msg_type:
        "peer_connected":
            GameLog.info("[HTTPSignaling] Peer connected: %d" % int(parsed["peer_id"]))
            peer_connected.emit(int(parsed["peer_id"]))
        "peer_disconnected":
            peer_disconnected.emit(int(parsed["peer_id"]))
        "offer":
            GameLog.info("[HTTPSignaling] Offer from peer %d" % int(parsed["peer_id"]))
            offer_received.emit(int(parsed["peer_id"]), parsed["sdp"])
        "answer":
            GameLog.info("[HTTPSignaling] Answer from peer %d" % int(parsed["peer_id"]))
            answer_received.emit(int(parsed["peer_id"]), parsed["sdp"])
        "candidate":
            candidate_received.emit(int(parsed["peer_id"]), parsed["mid"], int(parsed["index"]), parsed["sdp"])
        "joined":
            lobby_joined.emit(int(parsed["peer_id"]))
        "sealed":
            lobby_sealed.emit()
