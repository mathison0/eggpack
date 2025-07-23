extends Node2D

func _ready():
	$AnimatedSprite2D.hide()

func start_blink():
	$Sprite2D.hide()
	$AnimatedSprite2D.show()
	$AnimatedSprite2D.play("default")
	get_tree().create_timer(1).timeout.connect(func(): $AnimatedSprite2D.speed_scale = 2.0)
