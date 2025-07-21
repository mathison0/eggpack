extends Node

var my_id: int = -1
var host_id: int = -2
var players: Dictionary = {}
var lobby_code: String = ""

func is_host() -> bool:
	return host_id == my_id
