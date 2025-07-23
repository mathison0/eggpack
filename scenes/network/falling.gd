extends Control

@onready var falling_object_scene = preload("res://scenes/objects/falling.tscn")

func _ready():
	$Timer.timeout.connect(_on_timer_timeout)

func _on_timer_timeout():
	var player_instance = falling_object_scene.instantiate()
	
	var screen_width = get_viewport_rect().size.x
	var spawn_position = Vector2(randf_range(0, screen_width), -100)
	player_instance.rotation_degrees = randf_range(-45, 45)
	var random_scale = randf_range(0.8, 1.5)
	player_instance.scale = Vector2(random_scale, random_scale)
	player_instance.position = spawn_position
	player_instance.linear_velocity.x = randf_range(-100, 100)
	
	add_child(player_instance)
