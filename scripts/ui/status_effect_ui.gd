extends MarginContainer

@onready var icon_container: HBoxContainer = $IconContainer

const ICON_SHEET = preload("res://assets/graphics/icons/Status.png")
const ICON_SIZE = 64

var STATUS_ICONS: Dictionary = {}

func _ready():
	_setup_status_icons()
	
	GameManager.status_effect_changed.connect(update_display)
	
func _setup_status_icons():
	STATUS_ICONS[GameManager.Status.CONTROL_SWAPPED] = _match_atlas(0, 0)
	STATUS_ICONS[GameManager.Status.SLOWED_DOWN] = _match_atlas(1, 0)

func _match_atlas(x: int, y: int) -> AtlasTexture:
	var icon_atlas = AtlasTexture.new()
	icon_atlas.atlas = ICON_SHEET
	icon_atlas.region = Rect2(x*ICON_SIZE, y*ICON_SIZE, ICON_SIZE, ICON_SIZE)
	return icon_atlas

func update_display(active_status: Array):
	for child in icon_container.get_children():
		child.queue_free()
	
	for status in active_status:
		if STATUS_ICONS.has(status):
			var new_icon = TextureRect.new()
			new_icon.texture = STATUS_ICONS[status]
			new_icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
			new_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_container.add_child(new_icon)
