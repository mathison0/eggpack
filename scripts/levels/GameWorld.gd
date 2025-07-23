# GameWorld.gd
extends Node2D

const PLAYER_OBJECT_SCENE = preload("res://scenes/player/egg.tscn")

@onready var screen_effects_manager = $"Effect UI/ScreenEffectsManager"

func _ready() -> void:
	var player_object = PLAYER_OBJECT_SCENE.instantiate()
	player_object.name = "SharedObject"
	
	player_object.set_multiplayer_authority(GameManager.host_id)
	player_object.lives_changed.connect(screen_effects_manager._on_player_health_updated)
	
	add_child(player_object)
	
