extends Camera2D

@onready var player: RigidBody2D = get_parent()

# 에디터에서 쉽게 조절할 수 있는 변수들
@export_group("Dynamic Zoom Settings")
## 줌 효과가 적용되기 시작할 플레이어의 최소 속도
@export var min_speed: float = 300.0
## 줌이 최대로 적용될 플레이어의 최대 속도
@export var max_speed: float = 600.0
## 플레이어가 정지하거나 느릴 때의 기본 줌 (예: 1.0은 줌 없음)
@export var min_zoom: float = 1.0
## 플레이어가 최대 속도일 때의 최대 줌 아웃 값 (값이 낮을 수록 줌 아웃 많이됨)
@export var max_zoom: float = 0.7
## 줌이 얼마나 부드럽게 변할지 결정하는 값 (작을수록 부드러움)
@export var smoothness: float = 0.1

# ==================================================
# Look Ahead Settings
# ==================================================
@export_group("Look Ahead")
## 카메라가 플레이어로부터 최대로 벗어날 거리 (픽셀 단위)
@export var offset_max_distance: float = 200.0
## 오프셋이 적용되기 시작하는 최소 속도
@export var offset_min_speed: float = 30.0
## 오프셋이 최대 거리에 도달하는 속도
@export var offset_max_speed: float = 300.0
## 카메라 오프셋이 얼마나 부드럽게 움직일지 결정하는 값
@export var offset_smoothness: float = 0.5

func _process(delta):
	var current_speed = player.linear_velocity.length()
	
	var target_zoom_value = clamp(remap(current_speed, min_speed, max_speed, min_zoom, max_zoom), max_zoom, min_zoom)
	var target_zoom = Vector2(target_zoom_value, target_zoom_value)
	zoom = lerp(zoom, target_zoom, smoothness * delta)
	
	var dynamic_offset_distance = clamp(remap(current_speed, offset_min_speed, offset_max_speed, 0.0, offset_max_distance), 0.0, offset_max_distance)
	var target_offset = Vector2.ZERO
	if current_speed > 5.0:
		target_offset = player.linear_velocity.normalized() * dynamic_offset_distance
	offset = lerp(offset, target_offset, offset_smoothness * delta)
