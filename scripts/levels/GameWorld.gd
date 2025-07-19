extends Node2D

@onready var spawner = $MultiplayerSpawner

func _ready():
	# 서버만 플레이어 접속 신호를 감지하여 스폰을 담당합니다.
	if multiplayer.is_server():
		# 이미 접속해 있는 모든 플레이어를 위해 캐릭터를 스폰합니다.
		for id in multiplayer.get_peer_ids():
			_spawn_player(id)
		# 방금 접속한 호스트(서버) 자신을 위해 캐릭터를 스폰합니다.
		_spawn_player(1)

		# 앞으로 새로 접속하는 플레이어를 위해 신호를 연결합니다.
		multiplayer.peer_connected.connect(_spawn_player)

# 플레이어를 스폰하는 함수 (서버에서만 호출됨)
func _spawn_player(id):
	# spawn() 함수 안에 아무것도 넣지 않아도 됩니다.
	# 스포너가 Spawn Path에 있는 첫 번째 노드(Player)를 알아서 스폰합니다.
	var player_instance = spawner.spawn() 

	player_instance.name = str(id)
	player_instance.get_node("MultiplayerSynchronizer").set_network_master(id)
	print("Spawned player for " + str(id))
