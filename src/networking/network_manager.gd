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

var signaling: SignalingClient
var rtc_mp: WebRTCMultiplayerPeer
var peers: Dictionary = {}  # peer_id -> WebRTCPeerConnection
var my_peer_id: int = 0

var is_host: bool:
    get: return my_peer_id == 1

var is_active: bool:
    get: return multiplayer.has_multiplayer_peer() and multiplayer.get_unique_id() != 0

func _ready() -> void:
    signaling = SignalingClient.new()
    add_child(signaling)
    signaling.peer_connected.connect(_on_signaling_peer_connected)
    signaling.peer_disconnected.connect(_on_signaling_peer_disconnected)
    signaling.offer_received.connect(_on_offer_received)
    signaling.answer_received.connect(_on_answer_received)
    signaling.candidate_received.connect(_on_candidate_received)
    signaling.lobby_joined.connect(_on_lobby_joined)

func join_lobby(lobby_id: String) -> void:
    _init_rtc()
    signaling.connect_to_server(signaling_url)
    signaling.join_lobby(lobby_id)

func _init_rtc() -> void:
    rtc_mp = WebRTCMultiplayerPeer.new()

func _process(_delta: float) -> void:
    if signaling:
        signaling.poll()
    # Log WebRTC peer connection states periodically
    if Engine.get_frames_drawn() % 300 == 0 and peers.size() > 0:
        for peer_id in peers:
            var peer = peers[peer_id]
            print("[Net] Peer %d connection_state: %d" % [peer_id, peer.get_connection_state()])
        if rtc_mp:
            print("[Net] MultiplayerPeer status: %d" % rtc_mp.get_connection_status())

func _create_peer(peer_id: int) -> WebRTCPeerConnection:
    var peer = WebRTCPeerConnection.new()
    var err = peer.initialize({"iceServers": ice_servers})
    print("[Net] WebRTCPeerConnection.initialize() = %d" % err)
    peer.session_description_created.connect(
        func(type: String, sdp: String):
            print("[Net] SDP created: type=%s, len=%d" % [type, sdp.length()])
            peer.set_local_description(type, sdp)
            if type == "offer":
                signaling.send_offer(peer_id, sdp)
            else:
                signaling.send_answer(peer_id, sdp)
    )
    peer.ice_candidate_created.connect(
        func(mid: String, index: int, sdp: String):
            print("[Net] ICE candidate created for peer %d: mid=%s" % [peer_id, mid])
            signaling.send_candidate(peer_id, mid, index, sdp)
    )
    peers[peer_id] = peer
    rtc_mp.add_peer(peer, peer_id)
    return peer

func _on_lobby_joined(peer_id: int) -> void:
    my_peer_id = peer_id
    print("[Net] Joined lobby as peer %d" % peer_id)
    rtc_mp.create_mesh(peer_id)
    multiplayer.multiplayer_peer = rtc_mp
    connection_established.emit()

func _on_signaling_peer_connected(peer_id: int) -> void:
    print("[Net] Signaling: peer %d connected, creating WebRTC peer" % peer_id)
    var peer = _create_peer(peer_id)
    # Higher ID creates the offer
    if my_peer_id > peer_id:
        print("[Net] I'm higher ID (%d > %d), creating offer" % [my_peer_id, peer_id])
        peer.create_offer()
    player_connected.emit(peer_id)

func _on_signaling_peer_disconnected(peer_id: int) -> void:
    if peers.has(peer_id):
        peers[peer_id].close()
        peers.erase(peer_id)
    player_disconnected.emit(peer_id)

func _on_offer_received(peer_id: int, offer: String) -> void:
    print("[Net] Offer received from peer %d, len=%d" % [peer_id, offer.length()])
    if not peers.has(peer_id):
        _create_peer(peer_id)
    peers[peer_id].set_remote_description("offer", offer)

func _on_answer_received(peer_id: int, answer: String) -> void:
    print("[Net] Answer received from peer %d, len=%d" % [peer_id, answer.length()])
    if peers.has(peer_id):
        peers[peer_id].set_remote_description("answer", answer)

func _on_candidate_received(peer_id: int, mid: String, index: int, sdp: String) -> void:
    print("[Net] ICE candidate received from peer %d: mid=%s" % [peer_id, mid])
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
