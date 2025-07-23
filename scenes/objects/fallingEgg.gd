extends RigidBody2D

func _ready():
	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)

func _on_screen_exited():
	queue_free()
