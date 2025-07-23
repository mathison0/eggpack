extends Area2D

@export var item_type: String = "Barrier"
@export var respawn_cooldown: int = 15
@export var item_icon: Texture2D

@onready var respawn_timer: Timer = $Timer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	body_entered.connect(_on_body_entered)
	respawn_timer.timeout.connect(_respawn)
	$Sprite2D.texture = item_icon

func _on_body_entered(body: Node2D):
	if not GameManager.is_host():
		return

	if body.is_in_group("Egg") and body.has_method("collect_item"):
		if body.collect_item(item_type):
			_hide_item.rpc()

func _respawn():
	_show_item.rpc()

@rpc("any_peer","call_local","reliable")
func _hide_item():
	collision_shape.set_deferred("disabled", true)
	sprite.visible = false
	respawn_timer.start(respawn_cooldown)

@rpc("any_peer","call_local","reliable")
func _show_item():
	collision_shape.disabled = false
	sprite.visible = true
