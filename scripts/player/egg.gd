# egg.gd
extends RigidBody2D

# ================================================================
# 플레이어 설정 변수들
# ================================================================
# 제트팩 분사 시 상승하는 힘
@export var jetpack_thrust_vertical = 1000.0
# 제트팩 분사 시 회전시키는 토크 (힘의 단위)
@export var jetpack_torque_amount = 20000.0
# 최대 속도 제한
@export var max_linear_speed = 1000000.0 # 최대 선형(직선) 속도
@export var max_angular_speed = 3000.0 # 최대 각속도 (회전 속도)
# 충돌 판정 관련 변수
@export var impact_damage_threshold_speed: float = 1200.0 # 이 속도 이상으로 충돌 시 강한 충돌로 간주

# ================================================================
# 목숨 시스템 변수 (향후 사용 가능)
# ================================================================
@export var max_lives: int = 3
var current_lives: int

# ================================================================
# 연료 시스템 변수
# ================================================================
@export var max_jetpack_fuel: float = 100.0
@export var jetpack_fuel_consumption_rate: float = 17.0
@export var jetpack_fuel_recharge_rate: float = 20.0

# 각 제트팩의 현재 연료량. 이 값은 호스트에서 계산되고 클라이언트로 동기화됩니다.
var current_left_jetpack_fuel: float
var current_right_jetpack_fuel: float

# ================================================================
# 제트팩 이미지 리소스
# ================================================================
@export var jetpack_left_fire_texture: Texture2D = preload("res://assets/graphics/jetpack/jetpack_left_with_fire.png")
@export var jetpack_left_long_fire_texture: Texture2D = preload("res://assets/graphics/jetpack/jetpack_left_with_long_fire.png")
@export var jetpack_left_idle_texture: Texture2D = preload("res://assets/graphics/jetpack/jetpack_left.png")
@export var jetpack_right_fire_texture: Texture2D = preload("res://assets/graphics/jetpack/jetpack_right_with_fire.png")
@export var jetpack_right_long_fire_texture: Texture2D = preload("res://assets/graphics/jetpack/jetpack_right_with_long_fire.png")
@export var jetpack_right_idle_texture: Texture2D = preload("res://assets/graphics/jetpack/jetpack_right.png")

# ================================================================
# 노드 참조
# ================================================================
@onready var jetpack_left_sprite = $JetpackLeft/Sprite2D
@onready var jetpack_right_sprite = $JetpackRight/Sprite2D
@onready var left_jetpack_timer = $JetpackLeft/AnimationTimer
@onready var right_jetpack_timer = $JetpackRight/AnimationTimer
@onready var fuel_bar_left = $JetpackLeft/FuelBarLeft
@onready var fuel_bar_right = $JetpackRight/FuelBarRight

# ================================================================
# 내부 상태 변수
# ================================================================
var is_on_ground: bool = false

# --- 애니메이션 상태 ---
var left_jetpack_anim_state = false
var right_jetpack_anim_state = false

# --- 네트워크 관련 상태 변수 ---
# 클라이언트(P2)의 입력 상태를 호스트(P1)에 저장하기 위한 변수
var client_right_jetpack_active = false
# 클라이언트(P2)가 자신의 이전 입력 상태를 기억하여, 상태가 바뀔 때만 RPC를 보내도록 하기 위한 변수
var _client_previous_input_state = false


# ================================================================
# 초기 설정 함수
# ================================================================
func _ready():
	# 초기 텍스처 및 가시성 설정
	jetpack_left_sprite.texture = jetpack_left_idle_texture
	jetpack_right_sprite.texture = jetpack_right_idle_texture
	jetpack_left_sprite.visible = true
	jetpack_right_sprite.visible = true
	
	# 물리 속성 초기화
	gravity_scale = 1.0
	sleeping = false

	# 타이머 신호 연결
	left_jetpack_timer.timeout.connect(_on_left_jetpack_timer_timeout)
	right_jetpack_timer.timeout.connect(_on_right_jetpack_timer_timeout)
	
	# 연료 및 UI 초기화
	current_left_jetpack_fuel = max_jetpack_fuel
	current_right_jetpack_fuel = max_jetpack_fuel
	fuel_bar_left.max_value = max_jetpack_fuel
	fuel_bar_right.max_value = max_jetpack_fuel
	update_fuel_bars() # 초기 연료 값으로 ProgressBar 업데이트
	
	# 충돌 감지 신호 연결
	# RigidBody2D의 Contact Monitor를 true로, Contacts Reported를 1 이상으로 설정해야 합니다.
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


# ================================================================
# 물리 처리 루프 (매 프레임 실행)
# ================================================================
func _physics_process(delta):
	# is_multiplayer_authority()는 이 노드에 대한 권한이 현재 플레이어에게 있는지 확인합니다.
	# RigidBody2D의 물리 계산은 오직 권한을 가진 플레이어(호스트)만 처리해야 합니다.
	if get_multiplayer_authority() == multiplayer.get_unique_id():
		# --- 호스트(P1) 로직: 입력 처리 및 물리 계산 ---
		
		# 호스트(P1)는 자신의 입력을 직접 읽습니다.
		var left_key_pressed = Input.is_action_pressed("ui_left")
		# 클라이언트(P2)의 입력은 RPC를 통해 수신한 `client_right_jetpack_active` 변수를 사용합니다.
		var right_key_pressed = client_right_jetpack_active
		
		var total_torque_to_apply = 0.0
		var any_jetpack_key_active = left_key_pressed or right_key_pressed
		
		# --- 연료 소모 및 힘/토크 적용 로직 ---
		var can_use_left_jetpack = current_left_jetpack_fuel > 0
		if left_key_pressed and can_use_left_jetpack:
			current_left_jetpack_fuel -= jetpack_fuel_consumption_rate * delta
			total_torque_to_apply += jetpack_torque_amount
			apply_jetpack_force()
		
		var can_use_right_jetpack = current_right_jetpack_fuel > 0
		if right_key_pressed and can_use_right_jetpack:
			current_right_jetpack_fuel -= jetpack_fuel_consumption_rate * delta
			total_torque_to_apply -= jetpack_torque_amount
			apply_jetpack_force()
		
		# --- 연료 충전 로직 ---
		if is_on_ground and not any_jetpack_key_active:
			current_left_jetpack_fuel += jetpack_fuel_recharge_rate * delta
			current_right_jetpack_fuel += jetpack_fuel_recharge_rate * delta
		
		# 연료량이 최대/최소를 넘지 않도록 제한
		current_left_jetpack_fuel = clampf(current_left_jetpack_fuel, 0, max_jetpack_fuel)
		current_right_jetpack_fuel = clampf(current_right_jetpack_fuel, 0, max_jetpack_fuel)

		# 계산된 총 토크를 적용
		if total_torque_to_apply != 0.0:
			apply_torque(total_torque_to_apply)
			
		# 속도 제한
		_limit_velocities()
		
		# --- 상태 동기화 ---
		# 호스트에서 계산된 상태(연료, 제트팩 작동여부)를 모든 클라이언트에게 전송합니다.
		# 또한 호스트 자신의 화면에도 즉시 반영합니다.
		update_visuals_and_broadcast(current_left_jetpack_fuel, current_right_jetpack_fuel, left_key_pressed and can_use_left_jetpack, right_key_pressed and can_use_right_jetpack)

	else:
		# --- 클라이언트(P2) 로직: 자신의 입력 상태를 호스트에게 전송 ---
		var right_pressed = Input.is_action_pressed("ui_right")
		# 입력 상태가 이전 프레임과 달라졌을 때만 RPC를 호출하여 네트워크 트래픽을 줄입니다.
		if right_pressed != _client_previous_input_state:
			# rpc_id(1, ...)은 ID가 1인 피어(호스트)에게만 RPC를 보냅니다.
			set_client_jetpack_input.rpc(right_pressed)
			_client_previous_input_state = right_pressed


# ================================================================
# RPC (원격 프로시저 호출) 함수들
# ================================================================

# 클라이언트(P2)가 호출하며, 호스트(P1)에서 실행됩니다.
@rpc("any_peer", "reliable")
func set_client_jetpack_input(is_active: bool):
	# 클라이언트의 입력 상태를 호스트의 변수에 저장합니다.
	client_right_jetpack_active = is_active

# 호스트(P1)가 호출하며, 모든 플레이어(호스트 포함)에게서 실행됩니다.
@rpc("any_peer", "reliable")
func sync_visuals(left_fuel: float, right_fuel: float, left_on: bool, right_on: bool):
	# 호스트가 아닌 클라이언트들만 이 RPC를 통해 상태를 업데이트합니다.
	# (호스트는 이미 `update_visuals_and_broadcast`에서 직접 로컬 함수를 호출했습니다)
	if not $MultiplayerSynchronizer.get_multiplayer_authority() == 1:
		# 연료 상태 업데이트
		current_left_jetpack_fuel = left_fuel
		current_right_jetpack_fuel = right_fuel
		update_fuel_bars()
		
		# 왼쪽 제트팩 시각 효과 업데이트
		if left_on:
			_update_jetpack_sprite(jetpack_left_sprite, left_jetpack_timer, left_jetpack_anim_state, jetpack_left_fire_texture, jetpack_left_long_fire_texture)
		else:
			_reset_jetpack_state(jetpack_left_sprite, left_jetpack_timer, jetpack_left_idle_texture)
		
		# 오른쪽 제트팩 시각 효과 업데이트
		if right_on:
			_update_jetpack_sprite(jetpack_right_sprite, right_jetpack_timer, right_jetpack_anim_state, jetpack_right_fire_texture, jetpack_right_long_fire_texture)
		else:
			_reset_jetpack_state(jetpack_right_sprite, right_jetpack_timer, jetpack_right_idle_texture)


# ================================================================
# 헬퍼(도우미) 함수들
# ================================================================

# 호스트가 자신의 화면을 업데이트하고, 모든 클라이언트에게 상태를 전송하는 함수
func update_visuals_and_broadcast(left_fuel: float, right_fuel: float, left_on: bool, right_on: bool):
	# 1. 호스트 자신의 화면을 즉시 업데이트
	update_fuel_bars()
	if left_on:
		_update_jetpack_sprite(jetpack_left_sprite, left_jetpack_timer, left_jetpack_anim_state, jetpack_left_fire_texture, jetpack_left_long_fire_texture)
	else:
		_reset_jetpack_state(jetpack_left_sprite, left_jetpack_timer, jetpack_left_idle_texture)
	
	if right_on:
		_update_jetpack_sprite(jetpack_right_sprite, right_jetpack_timer, right_jetpack_anim_state, jetpack_right_fire_texture, jetpack_right_long_fire_texture)
	else:
		_reset_jetpack_state(jetpack_right_sprite, right_jetpack_timer, jetpack_right_idle_texture)
		
	# 2. 모든 클라이언트에게 상태를 동기화하라고 알림
	sync_visuals.rpc(left_fuel, right_fuel, left_on, right_on)

# 제트팩 추진력을 적용하는 함수 (호스트에서만 호출)
func apply_jetpack_force():
	# apply_central_force는 질량 중심에 힘을 가하여 토크를 발생시키지 않습니다.
	# 힘의 방향은 달걀의 로컬 '위' 방향(-transform.y)입니다.
	apply_central_force(-transform.y * jetpack_thrust_vertical)

# 제트팩 스프라이트와 애니메이션 타이머를 업데이트하는 함수
func _update_jetpack_sprite(sprite: Sprite2D, timer: Timer, anim_state: bool, fire_texture: Texture2D, long_fire_texture: Texture2D):
	if timer.time_left <= 0:
		timer.start()
	
	sprite.texture = long_fire_texture if anim_state else fire_texture

# 제트팩을 끈 상태로 되돌리는 함수
func _reset_jetpack_state(sprite: Sprite2D, timer: Timer, idle_texture: Texture2D):
	sprite.texture = idle_texture
	if timer.time_left > 0:
		timer.stop()

# 연료 바 UI를 업데이트하는 함수
func update_fuel_bars():
	fuel_bar_left.value = current_left_jetpack_fuel
	fuel_bar_right.value = current_right_jetpack_fuel

# 속도를 제한하는 함수 (호스트에서만 호출)
func _limit_velocities():
	if linear_velocity.length() > max_linear_speed:
		linear_velocity = linear_velocity.normalized() * max_linear_speed
	if abs(angular_velocity) > max_angular_speed:
		angular_velocity = sign(angular_velocity) * max_angular_speed


# ================================================================
# 신호 처리 함수들
# ================================================================

# 타이머 타임아웃 신호 처리 (애니메이션 상태 변경)
func _on_left_jetpack_timer_timeout():
	left_jetpack_anim_state = not left_jetpack_anim_state

func _on_right_jetpack_timer_timeout():
	right_jetpack_anim_state = not right_jetpack_anim_state

# 바닥 충돌 감지
func _on_body_entered(body: Node2D):
	if body.is_in_group("Ground"):
		is_on_ground = true

func _on_body_exited(body: Node2D):
	if body.is_in_group("Ground"):
		is_on_ground = false

# 강한 충돌 감지 (물리 엔진 콜백, 호스트에서만 실행됨)
func _integrate_forces(state: PhysicsDirectBodyState2D):
	if state.get_contact_count() > 0:
		for i in state.get_contact_count():
			var impulse = state.get_contact_impulse(i)
			if impulse.length() > impact_damage_threshold_speed:
				print("강한 충돌 감지됨! 충돌 임펄스: ", impulse.length())
				# 여기에 데미지 처리 로직 추가
				break
