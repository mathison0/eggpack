extends Node

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

var peer = WebSocketMultiplayerPeer.new()
var id = 0
# 연결을 직접적으로 다룸
var rtcPeer : WebRTCMultiplayerPeer = WebRTCMultiplayerPeer.new() 
var lobbyValue = ""

func _ready():
	multiplayer.connected_to_server.connect(RTCServerConnected)
	multiplayer.peer_connected.connect(RTCPeerConnected)
	multiplayer.peer_disconnected.connect(RTCPeerDisconnected)

func RTCServerConnected():
	print("RTC server connected")

func RTCPeerConnected(id):
	print("RTC peer connected " + str(id))

func RTCPeerDisconnected(id):
	print("RTC peer disconnected " + str(id))

func _process(delta):
	peer.poll()
	if peer.get_available_packet_count() > 0:
		var packet = peer.get_packet()
		if packet != null:
			var dataString = packet.get_string_from_utf32()
			var data = JSON.parse_string(dataString)
			print(data)
			if data.message == Message.id:
				id = data.id
				connected(id)
			
			if data.message == Message.userConnected:
				createPeer(data.id)
			
			if data.message == Message.lobby:
				var players = JSON.parse_string(data.players)
				lobbyValue = data.lobbyValue
				# ----------- Put GameManger gathering player Info here!!! -----------*=
				print("player infos: ", players)
			
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

func connectToServer(ip):
	peer.create_client("ws://3.27.86.38:8915")
	print("client created")

func _on_start_client_button_down() -> void:
	connectToServer("")

func _on_join_lobby_button_down() -> void:
	var message = {
		"id" : id,
		"message" : Message.lobby,
		"name" : "",
		"lobbyValue" : $LineEdit.text
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
