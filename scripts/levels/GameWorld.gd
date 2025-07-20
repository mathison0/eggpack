# GameWorld.gd
extends Node2D

const PLAYER_OBJECT_SCENE = preload("res://scenes/player/egg.tscn")

func _ready() -> void:
	print("I am the host, spawning shared object")
	var player_object = PLAYER_OBJECT_SCENE.instantiate()
	player_object.name = "SharedObject"
	
	player_object.set_multiplayer_authority(GameManager.host_id)
	
	add_child(player_object)
