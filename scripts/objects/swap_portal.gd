extends Area2D

func _ready():
	body_entered.connect(_on_body_entered)
	$AnimatedSprite2D.play("horizontal")

func _on_body_entered(body: Node2D):
	if GameManager.is_host() and body.is_in_group("Egg"):
		GameManager.toggle_control_swap()
