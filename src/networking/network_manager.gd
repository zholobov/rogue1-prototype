class_name NetworkManager
extends Node

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_established()
@warning_ignore("unused_signal")
signal connection_failed()

@export var signaling_url: String = "wss://server.zholobov.org"
@export var ice_servers: Array[Dictionary] = [
    {"urls": ["stun:stun.l.google.com:19302"]}
]

var signaling: Node  # SignalingClient or HTTPSignalingClient
var rtc_mp: WebRTCMultiplayerPeer
var peers: Dictionary = {}  # peer_id -> WebRTCPeerConnection
var my_peer_id: int = 0
var _ws_timeout_timer: Timer
var _pending_lobby_id: String = ""

enum TransportMode { AUTOMATIC, HTTP_POLLING }
var transport_mode: int = TransportMode.AUTOMATIC

var is_host: bool:
    get: return my_peer_id == 1

var is_active: bool:
    get: return multiplayer.has_multiplayer_peer() and multiplayer.get_unique_id() != 0

func _ready() -> void:
    _setup_signaling(SignalingClient.new())

func _setup_signaling(client: Node) -> void:
    if signaling:
        signaling.queue_free()
    signaling = client
    add_child(signaling)
    signaling.peer_connected.connect(_on_signaling_peer_connected)
    signaling.peer_disconnected.connect(_on_signaling_peer_disconnected)
    signaling.offer_received.connect(_on_offer_received)
    signaling.answer_received.connect(_on_answer_received)
    signaling.candidate_received.connect(_on_candidate_received)
    signaling.lobby_joined.connect(_on_lobby_joined)

func join_lobby(lobby_id: String) -> void:
    GameLog.info("[Net] join_lobby(%s) called, url=%s, transport=%d" % [lobby_id, signaling_url, transport_mode])
    _pending_lobby_id = lobby_id
    _init_rtc()

    if transport_mode == TransportMode.HTTP_POLLING:
        GameLog.info("[Net] Using HTTP polling (forced)")
        _setup_signaling(HTTPSignalingClient.new())
        signaling.connect_to_server(signaling_url)
        signaling.join_lobby(lobby_id)
    else:
        signaling.connect_to_server(signaling_url)
        signaling.join_lobby(lobby_id)
        # Start WebSocket timeout — fall back to HTTP if WS doesn't connect in 5s
        _ws_timeout_timer = Timer.new()
        _ws_timeout_timer.one_shot = true
        _ws_timeout_timer.wait_time = 5.0
        _ws_timeout_timer.timeout.connect(_on_ws_timeout)
        add_child(_ws_timeout_timer)
        _ws_timeout_timer.start()

func _init_rtc() -> void:
    rtc_mp = WebRTCMultiplayerPeer.new()

func _process(_delta: float) -> void:
    if signaling:
        signaling.poll()

func _create_peer(peer_id: int) -> WebRTCPeerConnection:
    var peer = WebRTCPeerConnection.new()
    peer.initialize({"iceServers": ice_servers})
    peer.session_description_created.connect(
        func(type: String, sdp: String):
            GameLog.info("[Net] SDP created: type=%s len=%d" % [type, sdp.length()])
            peer.set_local_description(type, sdp)
            if type == "offer":
                signaling.send_offer(peer_id, sdp)
            else:
                signaling.send_answer(peer_id, sdp)
    )
    peer.ice_candidate_created.connect(
        func(mid: String, index: int, sdp: String):
            GameLog.info("[Net] ICE candidate for peer %d" % peer_id)
            signaling.send_candidate(peer_id, mid, index, sdp)
    )
    peers[peer_id] = peer
    rtc_mp.add_peer(peer, peer_id)
    return peer

func _on_ws_timeout() -> void:
    if my_peer_id > 0:
        return  # Already connected, ignore
    GameLog.info("[Net] WebSocket timeout — falling back to HTTP polling")
    signaling.close()
    _setup_signaling(HTTPSignalingClient.new())
    signaling.connect_to_server(signaling_url)
    signaling.join_lobby(_pending_lobby_id)

func _on_lobby_joined(peer_id: int) -> void:
    # Cancel WS timeout if still running
    if _ws_timeout_timer and is_instance_valid(_ws_timeout_timer):
        _ws_timeout_timer.stop()
        _ws_timeout_timer.queue_free()
        _ws_timeout_timer = null
    my_peer_id = peer_id
    GameLog.info("[Net] Joined lobby as peer %d (via %s)" % [peer_id, signaling.get_class()])
    rtc_mp.create_mesh(peer_id)
    multiplayer.multiplayer_peer = rtc_mp
    connection_established.emit()

func _on_signaling_peer_connected(peer_id: int) -> void:
    GameLog.info("[Net] Signaling: peer %d connected (my_id=%d), creating WebRTC peer" % [peer_id, my_peer_id])
    var peer = _create_peer(peer_id)
    if my_peer_id > peer_id:
        GameLog.info("[Net] Creating offer (I'm %d, peer is %d)" % [my_peer_id, peer_id])
        peer.create_offer()
    else:
        GameLog.info("[Net] Waiting for offer from peer %d" % peer_id)
    player_connected.emit(peer_id)

func _on_signaling_peer_disconnected(peer_id: int) -> void:
    GameLog.info("[Net] Signaling: peer %d disconnected" % peer_id)
    if peers.has(peer_id):
        peers[peer_id].close()
        peers.erase(peer_id)
    player_disconnected.emit(peer_id)

func _on_offer_received(peer_id: int, offer: String) -> void:
    GameLog.info("[Net] Offer received from peer %d, len=%d" % [peer_id, offer.length()])
    if not peers.has(peer_id):
        _create_peer(peer_id)
    peers[peer_id].set_remote_description("offer", offer)

func _on_answer_received(peer_id: int, answer: String) -> void:
    GameLog.info("[Net] Answer received from peer %d, len=%d" % [peer_id, answer.length()])
    if peers.has(peer_id):
        peers[peer_id].set_remote_description("answer", answer)

func _on_candidate_received(peer_id: int, mid: String, index: int, sdp: String) -> void:
    if peers.has(peer_id):
        peers[peer_id].add_ice_candidate(mid, index, sdp)

func disconnect_all() -> void:
    for peer in peers.values():
        peer.close()
    peers.clear()
    if signaling:
        signaling.close()
    if rtc_mp:
        rtc_mp.close()
