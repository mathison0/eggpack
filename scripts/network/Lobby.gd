extends Node
class_name Lobby

var HostID : int
var Players : Dictionary = {}
var creation_time : int # 로비의 생성 시간 저장

func _init(id) -> void:
	HostID = id
	self.creation_time = Time.get_ticks_msec()

func AddPlayer(id, name):
	Players[id] = {
		"name" : name,
		"id" : id,
		"index" : Players.size() + 1
	}
	return Players[id]
