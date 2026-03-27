class_name NetworkManager
extends Node

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_established()
signal _connection_failed()

@export var signaling_url: String = "ws://localhost:9090"
@export var ice_servers: Array[Dictionary] = [
	{"urls": ["stun:stun.l.google.com:19302"]}
]

var signaling: SignalingClient
var rtc_mp: WebRTCMultiplayerPeer
var peers: Dictionary = {}  # peer_id -> WebRTCPeerConnection
var my_peer_id: int = 0

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

func _create_peer(peer_id: int) -> WebRTCPeerConnection:
	var peer = WebRTCPeerConnection.new()
	peer.initialize({"iceServers": ice_servers})
	peer.session_description_created.connect(
		func(type: String, sdp: String):
			peer.set_local_description(type, sdp)
			if type == "offer":
				signaling.send_offer(peer_id, sdp)
			else:
				signaling.send_answer(peer_id, sdp)
	)
	peer.ice_candidate_created.connect(
		func(mid: String, index: int, sdp: String):
			signaling.send_candidate(peer_id, mid, index, sdp)
	)
	peers[peer_id] = peer
	rtc_mp.add_peer(peer, peer_id)
	return peer

func _on_lobby_joined(peer_id: int) -> void:
	my_peer_id = peer_id
	rtc_mp.create_mesh(peer_id)
	multiplayer.multiplayer_peer = rtc_mp
	connection_established.emit()

func _on_signaling_peer_connected(peer_id: int) -> void:
	var peer = _create_peer(peer_id)
	# Higher ID creates the offer
	if my_peer_id > peer_id:
		peer.create_offer()
	player_connected.emit(peer_id)

func _on_signaling_peer_disconnected(peer_id: int) -> void:
	if peers.has(peer_id):
		peers[peer_id].close()
		peers.erase(peer_id)
	player_disconnected.emit(peer_id)

func _on_offer_received(peer_id: int, offer: String) -> void:
	if not peers.has(peer_id):
		_create_peer(peer_id)
	peers[peer_id].set_remote_description("offer", offer)

func _on_answer_received(peer_id: int, answer: String) -> void:
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
