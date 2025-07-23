extends Control

enum Message {
	id,
	join,
	userConnected,
	userDisconnected,
	lobby,
	candidate,
	offer,
	answer,
	removeLobby,
	checkIn
}

@onready var start_game_button = $StartGame
@onready var line_edit = $LobbyPanel/LineEdit
@onready var code_label = $LobbyPanel/CodeLabel
@onready var connection_panel = $ConnectionPanel
@onready var lobby_panel = $LobbyPanel
@onready var create_lobby = $LobbyPanel/CreateLobby
@onready var join_lobby = $LobbyPanel/JoinLobby

var peer = WebSocketMultiplayerPeer.new()
var id = 0
# 연결을 직접적으로 다룸
var rtcPeer : WebRTCMultiplayerPeer = WebRTCMultiplayerPeer.new() 
var lobbyValue = ""
var host_id = 0

func _ready():
	multiplayer.connected_to_server.connect(RTCServerConnected)
	multiplayer.peer_connected.connect(RTCPeerConnected)
	multiplayer.peer_disconnected.connect(RTCPeerDisconnected)
	
	start_game_button.disabled = true
	line_edit.editable = true
	lobby_panel.hide()

func RTCServerConnected():
	print("RTC server connected")

func RTCPeerConnected(id):
	print("RTC peer connected " + str(id))
	create_lobby.disabled = true
	join_lobby.disabled = true
	if GameManager.is_host():
		start_game_button.disabled = false
	#else:
		#start_game_button.text = "호스트만 게임을 시작할 수 있습니다!"

func RTCPeerDisconnected(id):
	print("RTC peer disconnected " + str(id))

func _process(delta):
	peer.poll()
	if peer.get_available_packet_count() > 0:
		var packet = peer.get_packet()
		if packet != null:
			var dataString = packet.get_string_from_utf32()
			var data = JSON.parse_string(dataString)
			if data.message == Message.id:
				id = data.id
				GameManager.my_id = id
				connected(id)
			
			if data.message == Message.userConnected:
				# 서버가 나에게만 보내주는 상세 정보 패킷인지 확인합니다.
				if data.has("player") and data.id == self.id:
				# 전역 변수에 나의 플레이어 인덱스를 저장합니다.
					GameManager.host_id = data.host
					print("Host id is: ", GameManager.host_id)
					host_id = data.host
					
					if GameManager.my_id == GameManager.host_id:
						start_game_button.show()
				createPeer(data.id)
			
			if data.message == Message.lobby:
				var players = JSON.parse_string(data.players)
				lobbyValue = data.lobbyValue
				GameManager.lobby_code = data.lobbyValue
				# ----------- Put GameManger gathering player Info here!!! -----------*=
				print("player infos: ", players)
				print("Lobby code: ", GameManager.lobby_code)
				code_label.text = "로비 코드 (친구와 공유해 보세요!):\n" + str(GameManager.lobby_code)
				create_lobby.disabled = true
				join_lobby.disabled = true
				line_edit.editable = false
				code_label.show()
			
			if data.message == Message.candidate:
				if rtcPeer.has_peer(data.orgPeer):
					print("Got Candidate: " + str(data.orgPeer) + " my id is " + str(id))
					rtcPeer.get_peer(data.orgPeer).connection.add_ice_candidate(data.mid, data.index, data.sdp)
			if data.message == Message.offer:
				if rtcPeer.has_peer(data.orgPeer):
					rtcPeer.get_peer(data.orgPeer).connection.set_remote_description("offer", data.data)
			if data.message == Message.answer:
				if rtcPeer.has_peer(data.orgPeer):
					rtcPeer.get_peer(data.orgPeer).connection.set_remote_description("answer", data.data)

func connected(id):
	rtcPeer.create_mesh(id)
	multiplayer.multiplayer_peer = rtcPeer

# WebRTC connection
func createPeer(id):
	if id != self.id:
		# 아래는 연결된 peer에 대한 정보를 다룸
		var peer : WebRTCPeerConnection = WebRTCPeerConnection.new()
		peer.initialize({
			"iceServers" : [{ "urls": ["stun:stun.l.google.com:19302"] }]
		})
		print("binding id " + str(id) + "my id is " + str(self.id))
		
		peer.session_description_created.connect(self.offerCreated.bind(id))
		peer.ice_candidate_created.connect(self.iceCandidateCreated.bind(id))
		# peer와 id를 엮어 연결 
		rtcPeer.add_peer(peer, id)
		
		# 연결 수 조절?
		if id < rtcPeer.get_unique_id():
			peer.create_offer()
	pass

func offerCreated(type, data, id):
	if !rtcPeer.has_peer(id):
		return
	
	rtcPeer.get_peer(id).connection.set_local_description(type, data)
	
	if type == "offer":
		sendOffer(id, data)
	else:
		sendAnswer(id, data)
	pass

# 내가 남에게 보내는 요청
func sendOffer(id, data):
	var message = {
		"peer" : id,
		"orgPeer" : self.id,
		"message" : Message.offer,
		"data" : data,
		"lobby" : lobbyValue
	}
	peer.put_packet(JSON.stringify(message).to_utf32_buffer())
	pass

# 내게 보내온 것에 대답
func sendAnswer(id, data):
	var message = {
		"peer" : id,
		"orgPeer" : self.id,
		"message" : Message.answer,
		"data" : data,
		"lobby" : lobbyValue
	}
	peer.put_packet(JSON.stringify(message).to_utf32_buffer())
	pass

func iceCandidateCreated(midName, indexName, sdpName, id):
	var message = {
		"peer" : id,
		"orgPeer" : self.id,
		"message" : Message.candidate,
		"mid" : midName,
		"index" : indexName,
		"sdp" : sdpName,
		"lobby" : lobbyValue
	}
	peer.put_packet(JSON.stringify(message).to_utf32_buffer())
	pass

#3.27.86.38:8915
func connectToServer(ip):
	peer.create_client("ws://3.27.86.38:8915")
	print("client created")

func _on_start_client_button_down() -> void:
	connection_panel.hide()
	connectToServer("")
	lobby_panel.show()

func _on_join_lobby_button_down() -> void:
	if line_edit.text != null and line_edit.text != "":
		var message = {
			"id" : id,
			"message" : Message.lobby,
			"name" : "",
			"lobbyValue" : line_edit.text
		}
		peer.put_packet(JSON.stringify(message).to_utf32_buffer())

func deleteLobby():
	var message = {
		"message" : Message.removeLobby,
		"lobbyID" : lobbyValue
	}
	peer.put_packet(JSON.stringify(message).to_utf32_buffer())

# ----- 메인으로 돌아갈 함수 -----

func _on_button_button_down() -> void:
	ping.rpc()

@rpc("any_peer")
func ping():
	print("ping from " + str(multiplayer.get_remote_sender_id()))
	
# 서버로부터 "게임 시작!" 신호를 받는 RPC 함수입니다.
@rpc("any_peer", "call_local")
func start_game_scene():
	get_tree().change_scene_to_file("res://scenes/levels/GameWorld.tscn")


func _on_start_game_button_down() -> void:
	if GameManager.my_id != GameManager.host_id:
		return
	# 나 자신(호스트)을 포함한 모든 연결된 클라이언트에게 게임을 시작하라고 알립니다.
	start_game_scene.rpc()

@rpc("any_peer", "reliable")
func egg_destroy():
	var egg = get_tree().get_first_node_in_group("Egg")
	if egg:
		# 모든 클라이언트에게 시각적인 파괴 처리만 요청
		egg_break_only.rpc()

		# 내 ID가 호스트일 경우에만 실제 queue_free() 처리
		if GameManager.my_id == GameManager.host_id:
			await get_tree().create_timer(3.0).timeout
			#egg.queue_free()
			
@rpc("any_peer", "call_local")
func egg_break_only():
	var egg = get_tree().get_first_node_in_group("Egg")
	if egg:
		egg.egg_main_sprite.texture = egg.egg_broken_texture
		egg.update_egg_sprite()
		egg.lives_changed.emit(egg.current_lives)


func _on_create_lobby_button_down() -> void:
	var message = {
		"id" : id,
		"message" : Message.lobby,
		"name" : "",
		"lobbyValue" : ""
	}
	peer.put_packet(JSON.stringify(message).to_utf32_buffer())
