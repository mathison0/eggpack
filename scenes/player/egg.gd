# egg.gd
extends RigidBody2D

# ======= 플레이어 설정 변수들 =======
# 제트팩 분사 시 상승하는 힘
@export var jetpack_thrust_vertical = 1000.0 # 인스펙터에서 조절 가능 (값을 다시 원래대로 돌려놓습니다)
# 제트팩 분사 시 회전시키는 토크 (힘의 단위)
@export var jetpack_torque_amount = 20000.0 # 인스펙터에서 조절 가능 (큰 값으로 시작)
# 최대 낙하 속도 (선택 사항: RigidBody2D는 힘에 의해 가속되므로 속도가 무한정 증가할 수 있습니다.)
@export var max_linear_speed = 30000.0 # 최대 선형(직선) 속도
@export var max_angular_speed = 3000.0 # 최대 각속도 (회전 속도, 라디안/초)
# 충돌 판정 관련 변수
@export var impact_damage_threshold_speed: float = 1000.0 # 이 속도 이상으로 충돌 시 강한 충돌로 간주

# ======= 연료 시스템 변수 (제트팩별로 분리) =======
@export var max_jetpack_fuel: float = 100.0 # 각 제트팩의 최대 연료량
@export var jetpack_fuel_consumption_rate: float = 17.0 # 초당 연료 소모량 (단위: 연료/초)
@export var jetpack_fuel_recharge_rate: float = 20.0 # 초당 연료 충전량 (단위: 연료/초)

var current_left_jetpack_fuel: float # 현재 왼쪽 제트팩 연료량
var current_right_jetpack_fuel: float # 현재 오른쪽 제트팩 연료량

var is_on_ground: bool = false # 달걀이 바닥에 닿아있는지 여부


# ======= 제트팩 이미지 리소스 =======
# 왼쪽 제트팩 이미지
@export var jetpack_left_fire_texture: Texture2D = preload("res://assets/graphics/jetpack/jetpack_left_with_fire.png")
@export var jetpack_left_long_fire_texture: Texture2D = preload("res://assets/graphics/jetpack/jetpack_left_with_long_fire.png")
@export var jetpack_left_idle_texture: Texture2D = preload("res://assets/graphics/jetpack/jetpack_left.png")

# 오른쪽 제트팩 이미지
@export var jetpack_right_fire_texture: Texture2D = preload("res://assets/graphics/jetpack/jetpack_right_with_fire.png")
@export var jetpack_right_long_fire_texture: Texture2D = preload("res://assets/graphics/jetpack/jetpack_right_with_long_fire.png")
@export var jetpack_right_idle_texture: Texture2D = preload("res://assets/graphics/jetpack/jetpack_right.png")

# ======= 노드 참조 =======
@onready var jetpack_left_sprite = $JetpackLeft/Sprite2D
@onready var jetpack_right_sprite = $JetpackRight/Sprite2D

# 각 제트팩 애니메이션 타이머 참조
@onready var left_jetpack_timer = $JetpackLeft/AnimationTimer
@onready var right_jetpack_timer = $JetpackRight/AnimationTimer

# ProgressBar 노드 참조
@onready var fuel_bar_left = $JetpackLeft/FuelBarLeft
@onready var fuel_bar_right = $JetpackRight/FuelBarRight

# 현재 제트팩 불꽃 애니메이션 상태 (true: 긴 불꽃, false: 일반 불꽃)
var left_jetpack_anim_state = false
var right_jetpack_anim_state = false

# 각 제트팩의 로컬 상대 위치 (Egg 중심 기준)
# 이 위치는 Godot 에디터에서 JetpackLeft/JetpackRight 노드의 Position을 보고 설정합니다.
# 이 값은 실험을 통해 정확하게 맞춰야 합니다. (예: Vector2(-50, 0), Vector2(50, 0) 등)
@export var jetpack_left_offset: Vector2 = Vector2(-150,80)
@export var jetpack_right_offset: Vector2 = Vector2(150, 80)

# ======= 초기 설정 =======
func _ready():
	# 게임 시작 시 제트팩 스프라이트의 초기 텍스처를 불이 나오지 않는 상태로 설정
	jetpack_left_sprite.texture = jetpack_left_idle_texture
	jetpack_right_sprite.texture = jetpack_right_idle_texture
	
	# 제트팩 스프라이트가 항상 보이도록 설정합니다.
	jetpack_left_sprite.visible = true
	jetpack_right_sprite.visible = true
	
	gravity_scale = 1.0 # 중력의 영향을 받도록 다시 1.0으로 설정 (기본값)
	sleeping = false # 잠자는 상태에서 깨어나 물리 시뮬레이션에 참여

	# 타이머 신호 연결 (GDScript에서 직접 연결)
	left_jetpack_timer.timeout.connect(_on_left_jetpack_timer_timeout)
	right_jetpack_timer.timeout.connect(_on_right_jetpack_timer_timeout)
	
	# 각 제트팩의 연료를 최대로 채웁니다.
	current_left_jetpack_fuel = max_jetpack_fuel
	current_right_jetpack_fuel = max_jetpack_fuel
	
	# ProgressBar의 최대값을 설정합니다.
	fuel_bar_left.max_value = max_jetpack_fuel
	fuel_bar_right.max_value = max_jetpack_fuel
	# 초기 연료 값으로 ProgressBar를 업데이트합니다.
	fuel_bar_left.value = current_left_jetpack_fuel
	fuel_bar_right.value = current_right_jetpack_fuel
	
	# 달걀이 다른 오브젝트와 충돌했는지 감지하기 위해 body_entered 시그널 연결
	# 달걀 노드의 `Contact Monitor`를 `Enabled`로 설정하고 `Contacts Reported`를 1 이상으로 설정해야 함
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# ======= 게임 루프 함수 =======
func _physics_process(delta):
	var total_torque_to_apply = 0.0
	
	var left_key_pressed = Input.is_action_pressed("ui_left")
	var right_key_pressed = Input.is_action_pressed("ui_right")

	# 제트팩 키를 누르고 있는지 여부 (충전 로직에 사용)
	var any_jetpack_key_active = (left_key_pressed or right_key_pressed)
	
	# === 연료 소모 로직 (각 제트팩별로) ===
	var can_use_left_jetpack = current_left_jetpack_fuel > 0
	var can_use_right_jetpack = current_right_jetpack_fuel > 0

	# 왼쪽 제트팩 처리
	if left_key_pressed and can_use_left_jetpack:
		current_left_jetpack_fuel -= jetpack_fuel_consumption_rate * delta # 왼쪽 연료 소모
		#current_left_jetpack_fuel = clampi(current_left_jetpack_fuel, 0, max_jetpack_fuel)
		
		total_torque_to_apply += jetpack_torque_amount # 시계 방향 회전
		_apply_jetpack_force(jetpack_left_sprite, left_jetpack_timer, left_jetpack_anim_state, jetpack_left_fire_texture, jetpack_left_long_fire_texture)
	else:
		_reset_jetpack_state(jetpack_left_sprite, left_jetpack_timer, jetpack_left_idle_texture, left_jetpack_anim_state)

	# 오른쪽 제트팩 처리
	if right_key_pressed and can_use_right_jetpack: # Input.is_action_pressed("ui_right")와 동일. can_use_jetpack 조건 추가
		current_right_jetpack_fuel -= jetpack_fuel_consumption_rate * delta # 오른쪽 연료 소모
		#current_right_jetpack_fuel = clampi(current_right_jetpack_fuel, 0, max_jetpack_fuel)
		# 오른쪽 제트팩은 달걀을 반시계 방향으로 회전시킵니다 (토크).
		total_torque_to_apply -= jetpack_torque_amount # 반시계 방향 회전 (음수 토크)
		# _apply_jetpack_force를 호출하여 달걀의 로컬 '위' 방향으로 추진력을 줍니다.
		# 이제 _apply_jetpack_force는 apply_central_force를 사용하므로, 토크에 간섭하지 않습니다.
		_apply_jetpack_force(jetpack_right_sprite, right_jetpack_timer, right_jetpack_anim_state, jetpack_right_fire_texture, jetpack_right_long_fire_texture)
	else:
		_reset_jetpack_state(jetpack_right_sprite, right_jetpack_timer, jetpack_right_idle_texture, right_jetpack_anim_state)
		
	# === 연료 충전 로직 (두 제트팩 동시 충전) ===
	# 달걀이 바닥에 닿아있고, 어떤 제트팩 키도 누르지 않을 때
	if is_on_ground and not any_jetpack_key_active:
		# 왼쪽 제트팩 연료 충전
		if current_left_jetpack_fuel < max_jetpack_fuel:
			current_left_jetpack_fuel += jetpack_fuel_recharge_rate * delta
		
		# 오른쪽 제트팩 연료 충전
		if current_right_jetpack_fuel < max_jetpack_fuel:
			current_right_jetpack_fuel += jetpack_fuel_recharge_rate * delta

	# --- ProgressBar 업데이트 (각 제트팩 연료에 따라) ---
	fuel_bar_left.value = current_left_jetpack_fuel
	fuel_bar_right.value = current_right_jetpack_fuel
	
	# 계산된 총 토크를 RigidBody2D에 적용합니다.
	if total_torque_to_apply != 0.0:
		apply_torque(total_torque_to_apply)
		
	# 속도 및 각속도 제한
	_limit_velocities()	

## 헬퍼 함수
# _apply_jetpack_force 함수의 offset 인자는 이제 사용되지 않습니다. (apply_central_force 때문)
# 그러나 다른 용도로 사용될 가능성을 고려하여 일단 제거하지는 않겠습니다.
func _apply_jetpack_force(sprite: Sprite2D, timer: Timer, anim_state: bool, fire_texture: Texture2D, long_fire_texture: Texture2D):
	# 변경된 부분: apply_force 대신 apply_central_force를 사용하여 순수 선형 힘 적용
	# 힘의 방향: 달걀의 로컬 '위' 방향 (-transform.y)
	# 힘의 크기: jetpack_thrust_vertical
	
	# apply_central_force는 질량 중심에 힘을 가하여 토크를 발생시키지 않습니다.
	# 따라서, 달걀이 어떤 각도로 회전하든, 항상 달걀의 로컬 '위' 방향으로 순수하게 추진됩니다.
	apply_central_force(-transform.y * jetpack_thrust_vertical)
	
	if timer.time_left <= 0: # 타이머가 멈춰있거나 시작되지 않았다면
		timer.start() # 타이머 시작
	
	# 현재 애니메이션 상태에 따라 텍스처 업데이트
	if anim_state:
		sprite.texture = long_fire_texture
	else:
		sprite.texture = fire_texture

func _reset_jetpack_state(sprite: Sprite2D, timer: Timer, idle_texture: Texture2D, anim_state_ref: bool):
	sprite.texture = idle_texture
	if timer.time_left > 0: # 타이머가 실행 중이라면
		timer.stop() # 타이머 정지
	# 애니메이션 상태를 false로 초기화합니다.
	# (참고: `anim_state_ref = false`와 같이 직접 대입하는 방식은 GDScript에서 `var` 변수를 참조로 전달하지 않으므로,
	# 외부 변수의 값을 직접 변경하지 않습니다. 따라서 `_on_..._timeout`에서 값을 토글하는 방식이 유효합니다.)
	# 이 부분에서는 `_on_..._timeout` 함수가 다시 호출되기 전까지는 애니메이션 상태가 즉시 리셋되지 않을 수 있습니다.
	# 하지만 키를 뗄 때 idle 텍스처로 즉시 변경되므로 시각적으로는 문제가 없습니다.

func _limit_velocities():
	# 선형 속도 (직선 이동 속도) 제한
	if linear_velocity.length() > max_linear_speed:
		linear_velocity = linear_velocity.normalized() * max_linear_speed

	# 각속도 (회전 속도) 제한
	if abs(angular_velocity) > max_angular_speed:
		angular_velocity = sign(angular_velocity) * max_angular_speed

# ======= 타이머 신호 처리 함수 =======
func _on_left_jetpack_timer_timeout():
	# 왼쪽 제트팩 애니메이션 상태를 토글
	left_jetpack_anim_state = not left_jetpack_anim_state
	# _process 함수에서 이 상태에 따라 텍스처가 업데이트될 것입니다.

func _on_right_jetpack_timer_timeout():
	# 오른쪽 제트팩 애니메이션 상태를 토글
	right_jetpack_anim_state = not right_jetpack_anim_state
	# _process 함수에서 이 상태에 따라 텍스처가 업데이트될 것입니다.

# ======= 바닥 감지 함수 =======
# 달걀이 다른 물리 오브젝트(바닥)와 충돌했을 때 호출
func _on_body_entered(body: Node2D):
	# 충돌한 오브젝트가 'Ground' 그룹에 속하는지 확인
	# (사용자님은 'Ground' 그룹을 바닥 노드에 할당해야 합니다)
	if body.is_in_group("Ground"):
		is_on_ground = true

# 달걀이 다른 물리 오브젝트에서 떨어졌을 때 호출
func _on_body_exited(body: Node2D):
	if body.is_in_group("Ground"):
		is_on_ground = false
