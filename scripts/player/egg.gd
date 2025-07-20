# egg.gd
extends RigidBody2D

# ================================================================
# 플레이어 설정 변수들
# ================================================================
# 제트팩 분사 시 상승하는 힘
@export var jetpack_thrust_vertical = 1500.0
# 제트팩 분사 시 회전시키는 토크 (힘의 단위)
@export var jetpack_torque_amount = 25000.0
# 최대 속도 제한
@export var max_linear_speed = 1000000.0 # 최대 선형(직선) 속도
@export var max_angular_speed = 3000.0 # 최대 각속도 (회전 속도)
# 충돌 판정 관련 변수
@export var impact_damage_threshold_speed: float = 1200.0 # 이 속도 이상으로 충돌 시 강한 충돌로 간주

# ================================================================
# 목숨 시스템 변수
# ================================================================
@export var max_lives: int = 2
var current_lives: int

# 목숨이 변경될 때 알리는 시그널 (UI 업데이트 등에 사용)
signal lives_changed(new_lives)

# ================================================================
# 달걀 스프라이트 리소스 
# ================================================================
@export var egg_texture: Texture2D = preload("res://assets/graphics/egg/egg_img.png") # 온전한 달걀 이미지 경로
@export var egg_cracked_texture: Texture2D = preload("res://assets/graphics/egg/egg_cracked_img.png") # 금이 간 달걀 이미지 경로
@export var egg_broken_texture: Texture2D = preload("res://assets/graphics/egg/egg_broken_img.png") # 깨진 달걀 이미지 경로

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
@onready var jetpack_left_sprite = $Visuals/JetpackLeft/Sprite2D
@onready var jetpack_right_sprite = $Visuals/JetpackRight/Sprite2D
@onready var left_jetpack_timer = $Visuals/JetpackLeft/AnimationTimer
@onready var right_jetpack_timer = $Visuals/JetpackRight/AnimationTimer
@onready var fuel_bar_left = $Visuals/JetpackLeft/FuelBarLeft
@onready var fuel_bar_right = $Visuals/JetpackRight/FuelBarRight

# 시각 표현 관련 노드
@onready var visuals = $Visuals
# 달걀의 메인 스프라이트 노드 참조
@onready var egg_main_sprite = $Visuals/Sprite2D

@export var interpolation_speed = 15.0


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
	
	# 목숨 초기화 및 초기 달걀 스프라이트 설정
	current_lives = max_lives
	egg_main_sprite.texture = egg_texture # 초기 달걀은 온전한 상태
	lives_changed.emit(current_lives) # UI에 초기 목숨 알림
	
	if get_multiplayer_authority() == multiplayer.get_unique_id():
		# 호스트: 물리 엔진이 완전히 적용되는 Rigid 모드를 사용합니다.
		print("This body is HOST. Mode set to RIGID.")
	else:
		# 클라이언트: 물리 엔진의 영향을 받지 않는 Kinematic 모드로 설정합니다.
		# 이렇게 하면 호스트로부터 받은 위치로만 움직이며, 독자적인 물리 계산을 하지 않습니다.
		print("This body is CLIENT. Mode set to KINEMATIC.")
	add_to_group("Egg")


# ================================================================
# 물리 처리 루프 (매 프레임 실행)
# ================================================================
func _physics_process(delta):
	# is_multiplayer_authority()는 이 노드에 대한 권한이 현재 플레이어에게 있는지 확인합니다.
	# RigidBody2D의 물리 계산은 오직 권한을 가진 플레이어(호스트)만 처리해야 합니다.
	if get_multiplayer_authority() == multiplayer.get_unique_id():
		# --- 호스트(P1) 로직: 입력 처리 및 물리 계산 ---
		
		## 목숨이 0이면 움직임을 멈춤
		#if current_lives <= 0:
			#linear_velocity = Vector2.ZERO
			#angular_velocity = 0.0
			#return # 더 이상 물리 처리 진행 안 함
		
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

		visuals.global_position = global_position
		visuals.global_rotation = global_rotation
	else:
		# --- 클라이언트(P2) 로직: 자신의 입력 상태를 호스트에게 전송 ---
		var right_pressed = Input.is_action_pressed("ui_right")
		# 입력 상태가 이전 프레임과 달라졌을 때만 RPC를 호출하여 네트워크 트래픽을 줄입니다.
		if right_pressed != _client_previous_input_state:
			# rpc_id(1, ...)은 ID가 1인 피어(호스트)에게만 RPC를 보냅니다.
			set_client_jetpack_input.rpc(right_pressed)
			_client_previous_input_state = right_pressed

# 클라이언트의 시각 위치 보간
func _process(delta):
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		visuals.global_position = visuals.global_position.lerp(global_position, delta * interpolation_speed)
		visuals.global_rotation = lerp_angle(visuals.global_rotation, global_rotation, delta * interpolation_speed)

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

# ===============================
# NEW: RPC - 목숨 동기화
# ===============================
@rpc("any_peer", "reliable")
func sync_lives(lives: int):
	# 클라이언트에서 목숨 상태를 갱신
	current_lives = lives
	update_egg_sprite()
	lives_changed.emit(current_lives)

# ===============================
# NEW: RPC - 달걀 제거 동기화
# ===============================
@rpc("any_peer", "reliable")
func egg_destroy():
	if get_multiplayer_authority() == multiplayer.get_unique_id():
		# ✅ 오직 호스트만 제거
		queue_free()
	else:
		# ✅ 클라이언트는 스프라이트만 변경
		egg_main_sprite.texture = egg_broken_texture

# ===============================
# NEW: RPC - 물리 비활성화 + 제거
# (선택적으로 쓸 수 있음)
# ===============================
@rpc("any_peer", "reliable")
func disable_physics_and_free():
	self.mode = 1
	set_physics_process(false)
	queue_free()
	
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

# 달걀 스프라이트를 목숨에 따라 업데이트하는 함수
func update_egg_sprite():
	if current_lives == 2: # 목숨이 2개일 때
		egg_main_sprite.texture = egg_texture
	elif current_lives == 1: # 목숨이 1개일 때
		egg_main_sprite.texture = egg_cracked_texture
	elif current_lives <= 0: # 목숨이 0개일 때
		egg_main_sprite.texture = egg_broken_texture

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
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		return
		
	if state.get_contact_count() > 0:
		for i in state.get_contact_count():
			var impulse = state.get_contact_impulse(i)
			var impact_impulse_magnitude = impulse.length()
			
			if impact_impulse_magnitude > 0: # 0이 아닌 임펄스만 처리
				if impact_impulse_magnitude > impact_damage_threshold_speed:
					print("강한 충돌 감지됨! 충돌 임펄스: ", impact_impulse_magnitude)
				
				var lives_lost = 0
				if impact_impulse_magnitude >= 1500 and impact_impulse_magnitude < 3000:
					lives_lost = 1
				elif impact_impulse_magnitude >= 3000:
					lives_lost = 2
				
				if lives_lost > 0 and current_lives > 0:
					current_lives -= lives_lost
					current_lives = max(0, current_lives) # 목숨이 0 미만으로 내려가지 않도록
					print("목숨 ", lives_lost, " 감소! 남은 목숨: ", current_lives)
					
					lives_changed.emit(current_lives) # UI 업데이트용 시그널 발생
					update_egg_sprite() # 달걀 스프라이트 업데이트
					sync_lives.rpc(current_lives)
					
					# 목숨이 0이 되면 게임 오버 처리
					if current_lives <= 0:
						print("목숨이 0이 되어 게임 오버! 달걀이 파괴됩니다.")
						egg_main_sprite.texture = egg_broken_texture # 깨진 달걀 스프라이트 최종 적용
						update_egg_sprite()
						lives_changed.emit(current_lives)
						
						## 물리적인 움직임을 즉시 멈춥니다.
						#linear_velocity = Vector2.ZERO
						#angular_velocity = 0.0
						
						#self.mode = 1 # RigidBody2D.BodyMode.STATIC에 해당하는 정수 값
						## 이 줄을 추가하여 물리 바디를 정적 모드로 변경합니다!
						#set_physics_process(false) # 더 이상 물리 처리 업데이트를 하지 않음
						
						egg_destroy.rpc() # 모든 클라이언트에게도 제거 지시

						# 잠시 후 노드 제거 (애니메이션 등 보여줄 시간 확보)
						#await get_tree().create_timer(3.0).timeout # 3초 대기 후 제거
						#queue_free() # 달걀 노드 제거
						# 여기에 게임 오버 화면 전환, 재시작 로직 등을 추가할 수 있습니다.
						
						break # 한 번의 충돌로 목숨이 줄었으면 더 이상 다른 접촉 임펄스를 확인할 필요 없음
