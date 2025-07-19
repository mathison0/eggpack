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
var users = {}
var lobbies = {}

const LOBBY_TIMEOUT = 300 * 1000 # 300초 (1000은 밀리초 계산)

var Characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"

@export var hostPort = 8915

func _ready():
	# 서버 모드로 실행 되었을 때만
	if "--server" in OS.get_cmdline_args():
		print("hosting on " + str(hostPort))
		peer.create_server(hostPort)
		
	peer.connect("peer_connected", peer_connected)
	peer.connect("peer_disconnected", peer_disconnected)

func _process(delta):
	peer.poll()
	
	#_check_stale_lobbies()
	
	if peer.get_available_packet_count() > 0:
		var packet = peer.get_packet()
		if packet != null:
			var dataString = packet.get_string_from_utf32()
			var data = JSON.parse_string(dataString)
			print(data)
			
			if data.message == Message.lobby:
				JoinLobby(data)
			
			# pass data to other users (relay message to other peer)
			if data.message == Message.offer || data.message == Message.answer || data.message == Message.candidate:
				print("source id is " + str(data.orgPeer))
				sendToPlayer(data.peer, data)
			if data.message == Message.removeLobby:
				if lobbies.has(data.lobbyID):
					lobbies.erase(data.lobbyID)

func peer_connected(id):
	print("Peer Connected: " + str(id))
	users[id] = {
		"id" : id,
		"message" : Message.id,
	}
	# get_peer(id)로 peer를 id로 특정한 후, 그 peer에게만 packet을 전송
	peer.get_peer(id).put_packet(JSON.stringify(users[id]).to_utf32_buffer())

func peer_disconnected(id):
	pass

func JoinLobby(user):
	# 로비 생성 및 플레이어 생성
	var result = ""
	if user.lobbyValue == "":
		user.lobbyValue = generateRandomString()
		print(user.lobbyValue)
		lobbies[user.lobbyValue] = Lobby.new(user.id)
	var player = lobbies[user.lobbyValue].AddPlayer(user.id, user.name)
	
	for p in lobbies[user.lobbyValue].Players:
		
		var data = {
			"message" : Message.userConnected,
			"id" : user.id
		}
		sendToPlayer(p, data)
		
		var data2 = {
			"message" : Message.userConnected,
			"id" : p
		}
		sendToPlayer(user.id, data2)
		
		var lobbyInfo = {
			"message" : Message.lobby,
			"players" : JSON.stringify(lobbies[user.lobbyValue].Players),
			"lobbyValue" : user.lobbyValue
		}
		sendToPlayer(p, lobbyInfo)
	
	# 플레이어에게 전송
	var data = {
		"message" : Message.userConnected,
		"id" : user.id,
		"host" : lobbies[user.lobbyValue].HostID,
		"player" : lobbies[user.lobbyValue].Players[user.id],
		"lobbyValue" : user.lobbyValue
	}
	sendToPlayer(user.id, data)

func sendToPlayer(userid, data):
	peer.get_peer(userid).put_packet(JSON.stringify(data).to_utf32_buffer())

func generateRandomString():
	var result = ""
	for i in range(32):
		var index = randi() % Characters.length()
		result += Characters[index]
	return result

func startServer():
	peer.create_server(8915)
	print("Started Server")

func _on_start_server_button_down() -> void:
	startServer()

func _check_stale_lobbies():
	var current_time = Time.get_ticks_msec()
	var lobbies_to_remove = []

	for lobby in lobbies:
		if current_time - lobby.creation_time > LOBBY_TIMEOUT:
			lobbies_to_remove.append(lobby)
	
	for lobby_id in lobbies_to_remove:
		print("stale lobby removed by timeout: " + lobby_id)
		lobbies.erase(lobby_id)
