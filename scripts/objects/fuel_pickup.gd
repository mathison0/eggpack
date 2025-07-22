# fuel_pickup.gd
extends Area2D

# 인스펙터에서 재생성 시간을 쉽게 조절할 수 있도록 @export 변수 사용
@export var respawn_time: float = 5.0

# 자식 노드들을 미리 참조해 둡니다.
@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D
@onready var timer = $Timer

var isCollectable: bool = true

func _ready():
	# 신호를 스크립트에 연결
	body_entered.connect(_on_body_entered)
	timer.timeout.connect(_on_timer_timeout)

func _on_body_entered(body: Node2D):
	# 호스트에서만 로직 실행, 그리고 콜리전이 활성화된 상태일 때만 실행 (중복 방지)
	if not GameManager.is_host():
		return
	
	if body.is_in_group("Egg") and body.has_method("refill_fuel") and isCollectable:
		body.refill_fuel()
		hide_item.rpc()

# 모든 플레이어에게 아이템을 숨기라고 지시하는 RPC
@rpc("any_peer", "call_local", "reliable")
func hide_item():
	# 아이템의 시각적 요소와 충돌 감지 기능을 비활성화합니다.
	sprite.visible = false
	isCollectable = false
	
	# 오직 호스트만 재생성 타이머를 시작합니다.
	if GameManager.is_host():
		timer.start(respawn_time)

# 타이머가 끝나면 호스트에서만 이 함수가 호출됩니다.
func _on_timer_timeout():
	# 모든 플레이어에게 아이템을 다시 '보여주라'고 지시합니다.
	show_item.rpc()

# 모든 플레이어에게 아이템을 다시 보여주는 RPC
@rpc("any_peer", "call_local", "reliable")
func show_item():
	# 비활성화했던 시각적 요소와 충돌 감지 기능을 다시 활성화합니다.
	sprite.visible = true
	isCollectable = true
