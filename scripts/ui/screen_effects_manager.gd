extends Node

var effects: Dictionary = {}

@onready var animation_player = $AnimationPlayer

func _ready():
	for child in get_children():
		if child is CanvasItem:
			effects[child.name] = child
			child.hide()

func show_effect(effect_name: String):
	if effects.has(effect_name):
		var animation_name = effect_name + "_FadeIn"
		if animation_player.has_animation(animation_name):
			animation_player.play(animation_name)
		effects[effect_name].show()

func hide_effect(effect_name: String):
	if effects.has(effect_name):
		var animation_name = effect_name + "_FadeIn"
		if animation_player.has_animation(animation_name):
			animation_player.stop()
		effects[effect_name].hide()
		
func hide_all_effect():
	for effect_name in effects:
		hide_effect(effect_name)

func _on_player_health_updated(current_health: int):
	if current_health == 1:
		show_effect("CrackedBorder")
	else:
		hide_effect("CrackedBorder")
