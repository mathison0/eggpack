extends CanvasLayer

@onready var screen_effect = $ScreenEffect

func _on_player_health_updated(current_health: int):
	if current_health == 1:
		cracked_effect.show()
