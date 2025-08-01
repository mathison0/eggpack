# egg.gd
extends RigidBody2D

# ================================================================
# 플레이어 설정 변수들
# ================================================================
@onready var jet_sound = $AudioStreamPlayer2D
# 제트팩 분사 시 상승하는 힘
var jetpack_thrust_vertical
# 제트팩 분사 시 회전시키는 토크 (힘의 단위)
@export var jetpack_torque_amount = 200.0
# 최대 속도 제한
@export var max_linear_speed = 50.0 # 최대 선형(직선) 속도
@export var max_angular_speed = 70.0 # 최대 각속도 (회전 속도)
@export var max_max_linear_speed = 10000.0
@export var max_both_jetpack_speed = 90
@export var max_sole_jetpack_speed = 140
# 충돌 판정 관련 변수
@export var impact_damage_threshold_speed: float = 120.0 # 이 속도 이상으로 충돌 시 강한 충돌로 간주

# ================================================================
# 세이브 포인트 및 리스폰 변수
# ================================================================
var last_save_point_pos: Vector2 = Vector2.ZERO # 최신 세이브 포인트 위치
@export var default_spawn_pos: Vector2 = Vector2(200, 5000) # 초기 스폰 위치 (세이브 포인트 없을 경우)
@export var respawn_delay: float = 3.0 # 리스폰까지 대기 시간 (계란이 깨진 후)
@export var respawn_y_offset: float = -20.0
@export var respawn_invincible_duration: float = 0.5 # 리스폰 후 무적 시간

# ================================================================
# 목숨 시스템 변수
# ================================================================
@export var max_lives: int = 2
var current_lives: int
var isInvincible: bool = false

# 목숨이 변경될 때 알리는 시그널 (UI 업데이트 등에 사용)
signal lives_changed(new_lives)

# ================================================================
# 세이브 포인트 효과
# ================================================================
@onready var firework_manager = $"FireworkManager"

# ================================================================
# 높이 시스템 변수
# ================================================================
var current_height: float = 0.0 # 현재 달걀의 높이 (Y 좌표)
var max_height: float = 0.0     # 기록된 최고 높이
@onready var hud = get_tree().get_root().find_child("HUD", true, false) # HUD CanvasLayer 노드 참조
@onready var current_height_label = hud.find_child("CurrentHeightLabel", true, false) # 현재 높이 Label 참조
@onready var max_height_label = hud.find_child("MaxHeightLabel", true, false)       # 최고 높이 Label 참조

# ================================================================
# 게임 타이머 변수
# ================================================================
var game_timer: float = 0.0 # 게임 시작부터 경과된 시간
var is_game_finished: bool = false # 게임이 종료되었는지 여부
@onready var timer_label = hud.find_child("TimerLabel", true, false) # HUD의 타이머 Label 참조

# ================================================================
# 죽은 횟수 변수
# ================================================================
var death_count: int = 0
@onready var death_count_label = hud.find_child("DeathCountLabel", true, false) # 죽은 횟수 Label 참조

# ================================================================
# 초기 스폰 후 상태 변수
# ================================================================
var has_touched_ground_after_spawn: bool = false # 스폰 후 바닥에 닿았는지 여부
var ground_level_y: float = 0.0 # 달걀이 처음 바닥에 닿았을 때의 Y 좌표 (0m 기준점)
var is_first_spawn_ground_set: bool = false # 최초 스폰 시 0m 기준점이 설정되었는지 여부

# ================================================================
# 달걀 스프라이트 리소스 
# ================================================================
@export var egg_texture: Texture2D = preload("res://assets/graphics/egg/egg_img.png") # 온전한 달걀 이미지 경로
@export var egg_cracked_texture: Texture2D = preload("res://assets/graphics/egg/egg_cracked_img.png") # 금이 간 달걀 이미지 경로
@export var egg_broken_texture: Texture2D = preload("res://assets/graphics/egg/egg_broken_img.png") # 깨진 달걀 이미지 경로
@export var egg_fried_texture: Texture2D = preload("res://assets/graphics/egg/egg_fried.png")# 계란후라이 스프라이트 텍스처

# ================================================================
# 분리될 달걀 껍질 리소스 (새로 추가)
# ================================================================
@export var egg_shell_left_scene: PackedScene  # 왼쪽 달걀 껍질 씬 경로
@export var egg_shell_right_scene: PackedScene # 오른쪽 달걀 껍질 씬 경로

# ================================================================
# 연료 시스템 변수
# ================================================================
@export var max_jetpack_fuel: float = 100.0
@export var jetpack_fuel_consumption_rate: float = 17.0
@export var jetpack_fuel_recharge_rate: float = 30.0

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
# 분리될 제트팩 이미지 리소스
# ================================================================
@export var jetpack_left_broken_scene: PackedScene # 왼쪽 깨진 제트팩 씬 경로
@export var jetpack_right_broken_scene: PackedScene # 오른쪽 깨진 제트팩 씬 경로

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

@onready var jetpack_left_visuals_node = $Visuals/JetpackLeft
@onready var jetpack_right_visuals_node = $Visuals/JetpackRight

@onready var left_jetpack_particles: GPUParticles2D = $Visuals/JetpackLeft/LeftParticles
@onready var right_jetpack_particles: GPUParticles2D = $Visuals/JetpackRight/RightParticles

@onready var jamming_timer = $JammingTimer

@export var interpolation_speed = 15.0

var current_item: String = ""
@onready var item_display = get_tree().get_root().find_child("StatusEffectUi", true, false)

@export var barrier_effect_scene: PackedScene = preload("res://scenes/player/barrier_effect.tscn")
@export var barrier_duration: float = 4.0
@export var barrier_blink_duration: float = 2.0
var is_barrier_active: bool = false
var barrier_effect_instance: Node2D
@onready var barrier_timer: Timer = $BarrierTimer

# ================================================================
# 내부 상태 변수
# ================================================================
@export var ice_physics_material: PhysicsMaterial

@onready var tileMap = get_tree().current_scene.find_child("platformTileMap", true, false)
var is_on_ice: bool = false
var dealt_damage_this_frame: bool = false
var is_on_ground: bool = false
var can_use_jump_pad: bool = true
var is_broken: bool = false # 달걀이 완전히 깨졌는지 여부 플래그

# --- 애니메이션 상태 ---
var left_jetpack_anim_state = false
var right_jetpack_anim_state = false

# --- 네트워크 관련 상태 변수 ---
# 클라이언트(P2)의 입력 상태를 호스트(P1)에 저장하기 위한 변수
var client_right_jetpack_active = false
# 클라이언트(P2)가 자신의 이전 입력 상태를 기억하여, 상태가 바뀔 때만 RPC를 보내도록 하기 위한 변수
var _client_previous_input_state = false

# ================================================================
# Collision Layer Indices (프로젝트 설정에 따라 숫자가 다를 수 있음)
const LAYER_SAVEPOINTS_NODAMAGE = 1 << 4 # LAYER 5
const LAYER_ENDING_LANDING_ZONE = 1 << 5 # LAYER 6

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
	gravity_scale = 0.6
	sleeping = false
	
	# 초기 스폰 후 바닥 닿음 상태 초기화
	has_touched_ground_after_spawn = false
	
	# 초기 세이브 포인트는 기본 스폰 위치로 설정 (호스트만 초기화)
	if get_multiplayer_authority() == multiplayer.get_unique_id():
		game_timer = 0.0
		is_game_finished = false
		update_timer_rpc.rpc(game_timer, is_game_finished) # 초기 상태 동기화
		
		last_save_point_pos = default_spawn_pos
		# 클라이언트에게도 초기 스폰 위치와 빈 노드 경로를 동기화
		update_save_point_rpc.rpc(default_spawn_pos)
	

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
	body_entered.connect(_on_any_body_entered)
	body_exited.connect(_on_body_exited)
	
	jamming_timer.timeout.connect(_on_jamming_timer_timeout)
	barrier_timer.timeout.connect(_on_barrier_timer_timeout)
	
	# 목숨 초기화 및 초기 달걀 스프라이트 설정
	current_lives = max_lives
	egg_main_sprite.texture = egg_texture # 초기 달걀은 온전한 상태
	lives_changed.emit(current_lives) # UI에 초기 목숨 알림
	
	add_to_group("Egg")	
	
	## 계란판과의 충돌 감지 신호 연결
	#body_entered.connect(_on_body_entered_egg_carton) # 새로운 함수 연결
	#
	## area2D (엔딩 착륙 지점)와의 충돌 감지 신호 연결
	## RigidBody2D가 Area2D에 들어갔을 때도 'body_entered' 시그널이 발생합니다.
	#body_entered.connect(_on_body_entered_area) # <--- 새로운 시그널 연결!
	
	# 디버깅을 위해 현재 권한과 피어 ID를 출력합니다.
	print("Egg node's multiplayer_authority: ", get_multiplayer_authority())
	print("Current peer unique ID: ", multiplayer.get_unique_id())
	
	if get_multiplayer_authority() == multiplayer.get_unique_id():
		# 호스트: 물리 엔진이 완전히 적용되는 Rigid 모드를 사용합니다.
		print("This body is HOST. Mode set to RIGID.")
	else:
		# 클라이언트: 물리 엔진의 영향을 받지 않는 Kinematic 모드로 설정합니다.
		# 이렇게 하면 호스트로부터 받은 위치로만 움직이며, 독자적인 물리 계산을 하지 않습니다.
		print("This body is CLIENT. Mode set to KINEMATIC.")
	


# ================================================================
# 물리 처리 루프 (매 프레임 실행)
# ================================================================
func _physics_process(delta):
	# is_multiplayer_authority()는 이 노드에 대한 권한이 현재 플레이어에게 있는지 확인합니다.
	# RigidBody2D의 물리 계산은 오직 권한을 가진 플레이어(호스트)만 처리해야 합니다.
	if get_multiplayer_authority() == multiplayer.get_unique_id():
		# --- 호스트(P1) 로직: 입력 처리 및 물리 계산 ---
		
		# 게임 타이머 업데이트 (호스트에서만 계산)
		if not is_game_finished:
				game_timer += delta
		update_timer_rpc.rpc(game_timer, is_game_finished)
		
		# 바닥에 닿기 전까지는 제트팩 사용 및 높이 업데이트를 막음
		if not has_touched_ground_after_spawn:
			# 제트팩 사용을 막기 위해 연료 소모 및 힘/토크 적용 로직을 건너뜁니다.
			# 하지만 연료 충전은 계속되어야 하므로, 아래에서 별도로 처리합니다.
			
			# 바닥에 닿기 전에는 높이 업데이트를 하지 않습니다.
			# 대신 현재 높이와 최고 높이를 0으로 표시하도록 UI를 업데이트합니다.
			update_height_ui_rpc.rpc(0.0, 0.0) # 초기에는 0으로 표시
			
			# 바닥에 닿기 전에도 연료는 충전되도록 합니다.
			# 이 부분은 기존 연료 충전 로직을 가져와서 여기에 배치합니다.
			var any_jetpack_key_active = Input.is_action_pressed("ui_left") or client_right_jetpack_active
			if is_on_ground and not any_jetpack_key_active:
				current_left_jetpack_fuel += jetpack_fuel_recharge_rate * delta
				current_right_jetpack_fuel += jetpack_fuel_recharge_rate * delta
			elif not any_jetpack_key_active:
				current_left_jetpack_fuel += jetpack_fuel_recharge_rate * delta * 0.1
				current_right_jetpack_fuel += jetpack_fuel_recharge_rate * delta * 0.1
			
			# 연료량 제한
			current_left_jetpack_fuel = clampf(current_left_jetpack_fuel, 0, max_jetpack_fuel)
			current_right_jetpack_fuel = clampf(current_right_jetpack_fuel, 0, max_jetpack_fuel)
			
			# UI 업데이트 (모든 클라이언트에게 동기화) - 제트팩은 꺼진 상태로 보냄
			update_visuals_and_broadcast(current_left_jetpack_fuel, current_right_jetpack_fuel, false, false)
			
			visuals.global_position = global_position
			visuals.global_rotation = global_rotation
			return # 바닥에 닿기 전까지는 더 이상 물리 처리 진행 안 함
		
		## 목숨이 0이면 움직임을 멈춤
		#if current_lives <= 0:
			#linear_velocity = Vector2.ZERO
			#angular_velocity = 0.0
			#return # 더 이상 물리 처리 진행 안 함
		
		# 호스트(P1)는 자신의 입력을 직접 읽습니다.
		var left_key_pressed = Input.is_action_pressed("ui_left")
		# 클라이언트(P2)의 입력은 RPC를 통해 수신한 `client_right_jetpack_active` 변수를 사용합니다.
		var right_key_pressed = client_right_jetpack_active
		
		if Input.is_action_just_pressed("use_item"):
			use_current_item()
		
		var left_jetpack_fire = false
		var right_jetpack_fire = true
		
		if GameManager.is_control_swapped:
			left_jetpack_fire = right_key_pressed
			right_jetpack_fire = left_key_pressed
		else:
			left_jetpack_fire = left_key_pressed
			right_jetpack_fire = right_key_pressed
		
		var total_torque_to_apply = 0.0
		var any_jetpack_key_active = left_key_pressed or right_key_pressed
		
		# --- 연료 소모 및 힘/토크 적용 로직 ---
		var can_use_left_jetpack = current_left_jetpack_fuel > 0
		var can_use_right_jetpack = current_right_jetpack_fuel > 0
		var is_left_on = left_jetpack_fire and can_use_left_jetpack and jamming_timer.time_left == 0
		var is_right_on = right_jetpack_fire and can_use_right_jetpack and jamming_timer.time_left == 0
		
		if is_left_on and is_right_on:
			jetpack_thrust_vertical =  max_both_jetpack_speed
		else:
			jetpack_thrust_vertical = max_sole_jetpack_speed
		if is_left_on:
			current_left_jetpack_fuel -= jetpack_fuel_consumption_rate * delta
			total_torque_to_apply += jetpack_torque_amount
			apply_jetpack_force()
		
		if is_right_on:
			current_right_jetpack_fuel -= jetpack_fuel_consumption_rate * delta
			total_torque_to_apply -= jetpack_torque_amount
			apply_jetpack_force()
		
		# --- 연료 충전 로직 ---
		if is_on_ground and not any_jetpack_key_active:
			current_left_jetpack_fuel += jetpack_fuel_recharge_rate * delta
			current_right_jetpack_fuel += jetpack_fuel_recharge_rate * delta
		elif not any_jetpack_key_active:
			current_left_jetpack_fuel += jetpack_fuel_recharge_rate * delta * 0.1
			current_right_jetpack_fuel += jetpack_fuel_recharge_rate * delta * 0.1
			
		
		# 연료량이 최대/최소를 넘지 않도록 제한
		current_left_jetpack_fuel = clampf(current_left_jetpack_fuel, 0, max_jetpack_fuel)
		current_right_jetpack_fuel = clampf(current_right_jetpack_fuel, 0, max_jetpack_fuel)
		
		

		# 계산된 총 토크를 적용
		if total_torque_to_apply != 0.0:
			apply_torque(total_torque_to_apply)
			
		# 속도 제한
		_limit_velocities()
		
		# 미끄러짐 효과 적용
		if is_on_ice:
			physics_material_override = ice_physics_material
		else:
			physics_material_override = null
			
		# 바람 타일 적용
		var tile_data = tileMap.get_cell_tile_data(tileMap.local_to_map(tileMap.to_local(global_position)))
		
		max_linear_speed = max_max_linear_speed
		var cloud_slow_down = false
		if tile_data:
			if tile_data.get_custom_data("tileType") == "wind":
				var force = tile_data.get_custom_data("wind_power")
				apply_central_force(force)
			
			# 구름 타일 적용
			if tile_data.get_custom_data("tileType") == "cloud":
				var max_speed = tile_data.get_custom_data("max_speed")
				max_linear_speed = max_speed
				cloud_slow_down = true
			
			if tile_data.get_custom_data("tileType") == "dark_cloud":
				jamming_timer.start(1)
				GameManager.add_status(GameManager.Status.JAMMED)
			
			if tile_data.get_custom_data("tileType") == "purifier":
				GameManager.remove_status_all()
		
		if cloud_slow_down:
			GameManager.cloud_slow_down(true)
		else:
			GameManager.cloud_slow_down(false)
			
		# --- 높이 업데이트 로직 (호스트에서만 계산) ---
		# Y값이 작아질수록 (위로 올라갈수록) 높이가 커지도록 계산합니다.
		# ground_level_y를 기준으로 삼아 0m부터 시작하게 합니다.
		current_height = ground_level_y - global_position.y
		
		if current_height < 0: # 0m 아래로 내려가면 음수로 표시하지 않고 0으로 고정
			current_height = 0.0

		if current_height > max_height:
			max_height = current_height

		# UI 업데이트 (모든 클라이언트에게 동기화)
		update_height_ui_rpc.rpc(current_height, max_height)
				
		
		# --- 상태 동기화 ---
		# 호스트에서 계산된 상태(연료, 제트팩 작동여부)를 모든 클라이언트에게 전송합니다.
		# 또한 호스트 자신의 화면에도 즉시 반영합니다.
		update_visuals_and_broadcast(current_left_jetpack_fuel, current_right_jetpack_fuel, is_left_on, is_right_on)

		visuals.global_position = global_position
		visuals.global_rotation = global_rotation
	else:
		# --- 클라이언트(P2) 로직: 자신의 입력 상태를 호스트에게 전송 ---
		# 클라이언트도 바닥에 닿기 전까지는 제트팩 입력을 보내지 않음
		if has_touched_ground_after_spawn: # <--- 이 조건 추가
			var right_pressed = Input.is_action_pressed("ui_right")
			if Input.is_action_just_pressed("use_item"):
				request_use_item_rpc.rpc()
			# 입력 상태가 이전 프레임과 달라졌을 때만 RPC를 호출하여 네트워크 트래픽을 줄입니다.
			if right_pressed != _client_previous_input_state:
				# rpc_id(1, ...)은 ID가 1인 피어(호스트)에게만 RPC를 보냅니다.
				set_client_jetpack_input.rpc(right_pressed)
				_client_previous_input_state = right_pressed
		else: # 바닥에 닿기 전에는 제트팩 입력 상태를 항상 false로 유지
			if _client_previous_input_state: # 이전에 true였다면 false로 변경 RPC 전송
				set_client_jetpack_input.rpc(false)
				_client_previous_input_state = false

# 클라이언트의 시각 위치 보간
func _process(delta):
	if Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right"):
		if not jet_sound.playing:
			jet_sound.play()
	else:
		jet_sound.stop()
	
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		# 클라이언트에서도 has_touched_ground_after_spawn이 false일 때 높이를 0으로 표시
		if not has_touched_ground_after_spawn:
			if current_height_label:
				current_height_label.text = "현재 높이: %.2f m" % 0.0
			if max_height_label:
				max_height_label.text = "최고 높이: %.2f m" % 0.0
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
@rpc("any_peer", "reliable", "call_local")
func sync_visuals(left_fuel: float, right_fuel: float, left_on: bool, right_on: bool):
	# 호스트가 아닌 클라이언트들만 이 RPC를 통해 상태를 업데이트합니다.
	# (호스트는 이미 `update_visuals_and_broadcast`에서 직접 로컬 함수를 호출했습니다)
	# 연료 상태 업데이트
	current_left_jetpack_fuel = left_fuel
	current_right_jetpack_fuel = right_fuel
	update_fuel_bars()
	
	# 왼쪽 제트팩 시각 효과 업데이트
	if left_on:
		left_jetpack_particles.emitting = true
		_update_jetpack_sprite(jetpack_left_sprite, left_jetpack_timer, left_jetpack_anim_state, jetpack_left_fire_texture, jetpack_left_long_fire_texture)
	else:
		left_jetpack_particles.emitting = false
		_reset_jetpack_state(jetpack_left_sprite, left_jetpack_timer, jetpack_left_idle_texture)
	
	if right_on:
		right_jetpack_particles.emitting = true
		_update_jetpack_sprite(jetpack_right_sprite, right_jetpack_timer, right_jetpack_anim_state, jetpack_right_fire_texture, jetpack_right_long_fire_texture)
	else:
		right_jetpack_particles.emitting = false
		_reset_jetpack_state(jetpack_right_sprite, right_jetpack_timer, jetpack_right_idle_texture)

# ===============================
# RPC - 목숨 동기화
# ===============================
@rpc("any_peer", "reliable")
func sync_lives(lives: int):
	# 클라이언트에서 목숨 상태를 갱신
	current_lives = lives
	update_egg_sprite()
	lives_changed.emit(current_lives)
	
# ===============================
# RPC - 세이브 포인트 동기화
# ===============================
@rpc("any_peer", "reliable")
func update_save_point_rpc(pos: Vector2):
	# 모든 피어에서 세이브 포인트 위치를 업데이트합니다.
	last_save_point_pos = pos
	print("Save point updated to: ", last_save_point_pos, " on peer ", multiplayer.get_unique_id())

# ===============================
# RPC - 제트백 스폰, 이 RPC는 호스트 달걀에 의해 호출되며, 모든 피어에서 제트팩을 스폰하도록 합니다.
# ===============================
@rpc("any_peer", "reliable", "call_local")
func command_egg_destroy_and_spawn_jetpacks(egg_global_pos: Vector2, egg_linear_vel: Vector2, egg_angular_vel: float):
	# 모든 피어에서 이 함수를 실행하지만,
	# 제트팩 스폰 요청은 이 함수를 호출한 호스트의 정보를 사용합니다.
	
	# 달걀 파괴 시각 효과 (모든 피어에서 동일하게 실행)
	is_broken = true # 달걀 깨짐 상태 플래그 설정
	set_physics_process(false) # 물리 처리 중지
	egg_main_sprite.texture = egg_broken_texture
	jetpack_left_visuals_node.visible = false
	jetpack_right_visuals_node.visible = false
	
	# 제트팩 스폰 (모든 피어에서 실행)
	# 호스트는 이 값을 이용하여 제트팩의 초기 위치/속도를 설정하고,
	# 클라이언트는 호스트가 보낸 값으로 제트팩을 스폰합니다.
	_spawn_jetpack_local(true, egg_global_pos, egg_linear_vel, egg_angular_vel) # 왼쪽 제트팩 스폰
	_spawn_jetpack_local(false, egg_global_pos, egg_linear_vel, egg_angular_vel) # 오른쪽 제트팩 스폰
	
	# 달걀 껍질 스폰
	_spawn_egg_shell_local(true, egg_global_pos, egg_linear_vel, egg_angular_vel) # 왼쪽 달걀 껍질 스폰
	_spawn_egg_shell_local(false, egg_global_pos, egg_linear_vel, egg_angular_vel) # 오른쪽 달걀 껍질 스폰
	
	# 달걀 노드 자체는 파괴된 후 잠시 후 리스폰
	await get_tree().create_timer(respawn_delay).timeout # 설정된 리스폰 대기 시간만큼 대기
	
	# --- 리스폰 로직 (모든 피어에서 실행) ---
	respawn_egg_local()
	
# ================================================================
#  RPC - 계란후라이 스프라이트 동기화
# ================================================================
@rpc("any_peer", "reliable", "call_local")
func change_to_egg_fried_sprite():
	# 모든 피어에서 달걀 스프라이트를 계란후라이로 변경
	if egg_fried_texture:
		egg_main_sprite.texture = egg_fried_texture
		jetpack_left_visuals_node.visible = false
		jetpack_right_visuals_node.visible = false
		print("Egg sprite changed to Fried Egg on peer ", multiplayer.get_unique_id())
	else:
		print("Fried Egg Texture is not assigned!")
		
# ===============================
# RPC - 높이 UI 동기화
# ===============================
@rpc("any_peer", "reliable", "call_local")
func update_height_ui_rpc(current_h: float, max_h: float):
	# 모든 피어에서 UI 업데이트
	if current_height_label: # 노드가 있는지 안전하게 확인
		current_height_label.text = "현재 높이: %.2f m" %(current_h / 100.0)
	if max_height_label: # 노드가 있는지 안전하게 확인
		max_height_label.text = "최고 높이: %.2f m" % (max_h / 100.0)
		
# ===============================
# RPC - 죽은 횟수 동기화
# ===============================
@rpc("any_peer", "reliable", "call_local")
func sync_death_count_rpc(count: int):
	# 모든 피어에서 UI 업데이트
	if death_count_label: # 노드가 있는지 안전하게 확인
		death_count_label.text = "깨진 횟수: %d번" % count
		
# ===============================
# RPC - 스폰 후 바닥 닿음 상태 동기화
# ===============================
@rpc("any_peer", "reliable", "call_local")
func sync_has_touched_ground_rpc(state: bool):
	has_touched_ground_after_spawn = state
	print("Peer ", multiplayer.get_unique_id(), " has_touched_ground_after_spawn set to: ", state)
	
	# ===============================
# RPC - 타이머 동기화 (새로 추가)
# ===============================
@rpc("any_peer", "reliable", "call_local")
func update_timer_rpc(time: float, finished: bool):
	# 모든 피어에서 타이머 값과 상태를 갱신
	game_timer = time
	is_game_finished = finished

	if timer_label: # 노드가 있는지 안전하게 확인
		var minutes = floor(game_timer / 60)
		var seconds = fmod(game_timer, 60)
		var milliseconds = fmod(game_timer * 1000, 1000)
		timer_label.text = "시간: %02d:%02d.%03d" % [minutes, seconds, milliseconds]
	
# ===============================
# 리스폰 로직
# ===============================
func respawn_egg_local():
	print("Respawning egg on peer ", multiplayer.get_unique_id(), " at ", last_save_point_pos)
	isInvincible = true

	jetpack_left_visuals_node.visible = true # 제트팩 시각 다시 활성화
	jetpack_right_visuals_node.visible = true
	current_left_jetpack_fuel = max_jetpack_fuel # 연료 초기화
	current_right_jetpack_fuel = max_jetpack_fuel
	update_fuel_bars()

	# 위치와 물리 상태 초기화
	global_position = last_save_point_pos + Vector2(0, respawn_y_offset)
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	rotation = 0.0
	
	# 달걀의 시각적 및 물리적 상태 초기화
	is_broken = false
	current_lives = max_lives # 목숨 초기화
	lives_changed.emit(current_lives) # UI 업데이트
	update_egg_sprite() # 온전한 달걀 스프라이트로 변경
	
	# 리스폰 후 바닥 닿음 상태 초기화
	has_touched_ground_after_spawn = true
	
	set_physics_process(true)
	
	await get_tree().create_timer(respawn_invincible_duration).timeout
	isInvincible = false
	
# ================================================================
# 헬퍼(도우미) 함수들
# ================================================================

# 호스트가 자신의 화면을 업데이트하고, 모든 클라이언트에게 상태를 전송하는 함수
func update_visuals_and_broadcast(left_fuel: float, right_fuel: float, left_on: bool, right_on: bool):
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
# 달걀 파괴 및 제트팩 분리 함수
# ================================================================
# 이 함수는 RPC에 의해 모든 피어에서 실행되지만, 제트팩 스폰 명령은 호스트에서만 시작됩니다.
func _spawn_jetpack_local(is_left: bool, egg_global_pos: Vector2, egg_linear_vel: Vector2, egg_angular_vel: float):
	var jetpack_scene: PackedScene = null
	var spawn_offset: Vector2 = Vector2.ZERO
	var initial_velocity_offset: Vector2 = Vector2.ZERO

	if is_left:
		jetpack_scene = jetpack_left_broken_scene
		spawn_offset = Vector2(-15, 0) # 달걀 중심에서 왼쪽으로 약간 떨어진 위치
		initial_velocity_offset = Vector2(-randf_range(10, 30), randf_range(-10, -30)) # 왼쪽 위로 분산되는 속도
	else:
		jetpack_scene = jetpack_right_broken_scene
		spawn_offset = Vector2(15, 0) # 달걀 중심에서 오른쪽으로 약간 떨어진 위치
		initial_velocity_offset = Vector2(randf_range(10, 30), randf_range(-10, -30)) # 오른쪽 위로 분산되는 속도

	if jetpack_scene:
		var jetpack_instance = jetpack_scene.instantiate()
		get_tree().get_root().add_child(jetpack_instance) # 씬 트리의 루트에 추가

		# 중요: 스폰된 제트팩의 네트워크 권한을 호스트에게 부여합니다.
		# 모든 피어가 로컬로 제트팩을 생성하지만, 물리 시뮬레이션은 호스트만 담당합니다.
		jetpack_instance.set_multiplayer_authority(GameManager.host_id)
		
		# 전달받은 초기 위치, 속도, 각속도 적용
		jetpack_instance.global_position = egg_global_pos + spawn_offset
		jetpack_instance.linear_velocity = egg_linear_vel + initial_velocity_offset
		jetpack_instance.angular_velocity = egg_angular_vel + randf_range(-3, 3) # 약간의 무작위 각속도 추가

		print("Spawned jetpack (is_left: ", is_left, ") on peer ID: ", multiplayer.get_unique_id(), ", Authority: ", jetpack_instance.get_multiplayer_authority())

		# 일정 시간 후 제트팩 제거 (메모리 관리)
		var timer = Timer.new()
		timer.wait_time = 8.0 # 8초 후 제거
		timer.one_shot = true
		jetpack_instance.add_child(timer)
		timer.timeout.connect(jetpack_instance.queue_free)
		timer.start()

# ================================================================
# 달걀 껍질 파편 분리 함수 (새로 추가)
# ================================================================
func _spawn_egg_shell_local(is_left: bool, egg_global_pos: Vector2, egg_linear_vel: Vector2, egg_angular_vel: float):
	var shell_scene: PackedScene = null
	var spawn_offset: Vector2 = Vector2.ZERO
	var initial_velocity_offset: Vector2 = Vector2.ZERO

	if is_left:
		shell_scene = egg_shell_left_scene
		# 달걀 중심에서 왼쪽으로 약간 떨어진 위치
		spawn_offset = Vector2(-5, 0) # 제트팩과 겹치지 않게 조절 필요
		# 왼쪽 위로 분산되는 속도 (제트팩과 다르게 설정 가능)
		initial_velocity_offset = Vector2(-randf_range(20, 50), randf_range(-20, -60))
	else:
		shell_scene = egg_shell_right_scene
		# 달걀 중심에서 오른쪽으로 약간 떨어진 위치
		spawn_offset = Vector2(5, 0) # 제트팩과 겹치지 않게 조절 필요
		# 오른쪽 위로 분산되는 속도 (제트팩과 다르게 설정 가능)
		initial_velocity_offset = Vector2(randf_range(20, 50), randf_range(-20, -60))

	if shell_scene:
		var shell_instance = shell_scene.instantiate()
		get_tree().get_root().add_child(shell_instance) # 씬 트리의 루트에 추가

		# 중요: 스폰된 껍질의 네트워크 권한을 호스트에게 부여합니다.
		shell_instance.set_multiplayer_authority(GameManager.host_id)
		
		# 전달받은 초기 위치, 속도, 각속도 적용
		shell_instance.global_position = egg_global_pos + spawn_offset
		shell_instance.linear_velocity = egg_linear_vel * 0.5 + initial_velocity_offset # 달걀의 속도를 덜 받도록
		shell_instance.angular_velocity = egg_angular_vel + randf_range(-5, 5) # 약간의 무작위 각속도 추가

		print("Spawned egg shell (is_left: ", is_left, ") on peer ID: ", multiplayer.get_unique_id(), ", Authority: ", shell_instance.get_multiplayer_authority())

		# 일정 시간 후 껍질 제거 (메모리 관리)
		var timer = Timer.new()
		timer.wait_time = 8.0
		timer.one_shot = true
		shell_instance.add_child(timer)
		timer.timeout.connect(shell_instance.queue_free)
		timer.start()

	
# ================================================================
# 신호 처리 함수들
# ================================================================

# 타이머 타임아웃 신호 처리 (애니메이션 상태 변경)
func _on_left_jetpack_timer_timeout():
	left_jetpack_anim_state = not left_jetpack_anim_state

func _on_right_jetpack_timer_timeout():
	right_jetpack_anim_state = not right_jetpack_anim_state

# 모든 body_entered 시그널을 처리할 범용 함수
func _on_any_body_entered(body: Node2D):
	# 일반 바닥 충돌 감지
	if body.is_in_group("Ground"):
		is_on_ground = true
		# 스폰 후 첫 바닥 접촉 감지 (호스트만 처리)
		if get_multiplayer_authority() == multiplayer.get_unique_id():
			if not has_touched_ground_after_spawn:
				has_touched_ground_after_spawn = true
				sync_has_touched_ground_rpc.rpc(true) # 모든 피어에 동기화
				# --- 최초 스폰 시에만 0m 기준점 설정 ---
				if not is_first_spawn_ground_set: # <--- 이 조건 덕분에 딱 한 번만 실행됩니다.
					ground_level_y = global_position.y
					is_first_spawn_ground_set = true
					print("Initial Ground level set at Y: ", ground_level_y)
					update_height_ui_rpc.rpc(0.0, 0.0)

	# 계란판(세이브 포인트) 충돌 감지
	
	if body.is_in_group("save_points") and get_multiplayer_authority() == multiplayer.get_unique_id():
		var entered_carton = body
		var new_save_pos = entered_carton.global_position

		if last_save_point_pos != new_save_pos:
			print("Host Egg reached new save point: ", new_save_pos)
			last_save_point_pos = new_save_pos
			update_save_point_rpc.rpc(last_save_point_pos)
			
			if firework_manager: # firework_manager 노드가 유효한지 확인
				firework_manager.explode_firework_rpc.rpc(new_save_pos)
			
		# --- 리스폰 후 세이브 포인트에 닿았을 때 움직임 활성화 및 기준점 설정 ---
		# 호스트가 save_points에 닿았을 때 has_touched_ground_after_spawn 활성화
		if not has_touched_ground_after_spawn:
			has_touched_ground_after_spawn = true
			sync_has_touched_ground_rpc.rpc(true) # 모든 피어에 동기화
			
			# --- 최초 스폰 시에만 0m 기준점 설정 ---
			if not is_first_spawn_ground_set:
				ground_level_y = global_position.y
				is_first_spawn_ground_set = true
				print("Initial Ground level set at Y (via save point): ", ground_level_y)
				update_height_ui_rpc.rpc(0.0, 0.0)

	# 엔딩 착륙 지점(Area2D)과의 충돌 감지
	# `Area2D` 타입이면서 EndingLandingZone 레이어에 속하고, 현재 달걀이 호스트의 권한을 가질 때
	# Note: `body`는 Area2D일 수도, PhysicsBody2D일 수도 있음. Area2D를 기대한다면 `body is Area2D` 확인.
	#if body is Area2D:
		#print("Area2D")
	#if body is StaticBody2D:
		#print("StaticBody")
	if body is StaticBody2D and (body.collision_layer & LAYER_ENDING_LANDING_ZONE) and get_multiplayer_authority() == multiplayer.get_unique_id():
		print("Egg entered the Ending Landing Zone!")
		change_to_egg_fried_sprite.rpc()
		set_physics_process(false)
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		rotation = 0.0
		
		# 게임 종료 플래그 설정 및 최종 시간 동기화 (호스트만)
		is_game_finished = true
		update_timer_rpc.rpc(game_timer, is_game_finished) # 최종 시간 동기화
		print("Game Finished! Elapsed Time: ", game_timer)


func _on_body_exited(body: Node2D):
	if body.is_in_group("Ground"):
		is_on_ground = false
		

# 강한 충돌 감지 (물리 엔진 콜백, 호스트에서만 실행됨)
func _integrate_forces(state: PhysicsDirectBodyState2D):
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		return
	
	is_on_ice = false
	dealt_damage_this_frame = false
		
	if is_broken:
		return
			
	if state.get_contact_count() > 0:
		for i in range(state.get_contact_count()):
			# 타일 타입 가져오기
			var collider = state.get_contact_collider_object(i)
			var tile_type = ""
			var tile_data
			if collider is TileMapLayer:
				var contact_pos_in_px = state.get_contact_local_position(i)
				var map_coordinates = collider.local_to_map(contact_pos_in_px)
				tile_data = collider.get_cell_tile_data(map_coordinates)
				if tile_data and tile_data.has_custom_data("tileType"):
					tile_type = tile_data.get_custom_data("tileType")
			
			if dealt_damage_this_frame:
				continue
			# spike 타일의 경우 닿자마자 데미지 (충돌 무관)
			if tile_type == "spike":
				apply_damage(2)
				continue
			
			# soft 타일의 경우 충돌 판정 스킵
			elif tile_type == "soft":
				continue
			
			# ice 타일의 경우 미끄러운 상태로 만듬
			elif tile_type == "ice":
				is_on_ice = true
				
			if can_use_jump_pad and tile_type == "jump_pad" and not isInvincible:
				var direction = tile_data.get_custom_data("launch_direction")
				var power = tile_data.get_custom_data("launch_power")
				
				state.linear_velocity = state.linear_velocity * 0.2
				
				state.apply_central_impulse(direction.normalized() * power * -1)
				
				state.angular_velocity = state.angular_velocity * 0.2
				
				can_use_jump_pad = false
				get_tree().create_timer(0.1).timeout.connect(func(): can_use_jump_pad = true)
				
				continue
			elif tile_type == "jump_pad":
				continue
				
				
			# --- 충돌한 객체가 계란판(SavePoints_NoDamage) 레이어에 있는지 확인 ---
			# 만약 충돌한 객체가 SavePoints_NoDamage 레이어에 있다면, 데미지 계산을 건너_integrate_forces니다.
			if collider is not TileMapLayer:	
				if collider and ((collider.collision_layer & LAYER_SAVEPOINTS_NODAMAGE) or (collider.collision_layer & LAYER_ENDING_LANDING_ZONE)):
					#print("Collided with a SavePoint_NoDamage (EggCarton). No damage applied.")
					continue # 다음 충돌 지점으로 넘어감 (이 충돌에 대해서는 데미지 계산 건너뛰기)

			var impulse = state.get_contact_impulse(i)
			var impact_impulse_magnitude = impulse.length()
			
			if impact_impulse_magnitude > 0: # 0이 아닌 임펄스만 처리
				if impact_impulse_magnitude > impact_damage_threshold_speed:
					print("강한 충돌 감지됨! 충돌 임펄스: ", impact_impulse_magnitude)
				
				if impact_impulse_magnitude >= 120 and impact_impulse_magnitude < 200:
					apply_damage(1)
				elif impact_impulse_magnitude >= 200:
					apply_damage(2)

func apply_damage(amount: int):
	if current_lives <= 0 or dealt_damage_this_frame or isInvincible:
		return
	
	current_lives -= amount
	current_lives = max(0, current_lives) # 목숨이 0 미만으로 내려가지 않도록
	dealt_damage_this_frame = true
	print("목숨 ", amount, " 감소! 남은 목숨: ", current_lives)
	
	lives_changed.emit(current_lives) # UI 업데이트용 시그널 발생
	update_egg_sprite() # 달걀 스프라이트 업데이트
	sync_lives.rpc(current_lives)
	
	# 목숨이 0이 되면 게임 오버 처리
	if current_lives <= 0:
		print("목숨이 0이 되어 게임 오버! 달걀이 파괴됩니다.")
		update_egg_sprite()
		lives_changed.emit(current_lives)
		
		## 물리적인 움직임을 즉시 멈춥니다.
		#linear_velocity = Vector2.ZERO
		#angular_velocity = 0.0
		GameManager.remove_status_all()
		
		#self.mode = 1 # RigidBody2D.BodyMode.STATIC에 해당하는 정수 값
		## 이 줄을 추가하여 물리 바디를 정적 모드로 변경합니다!
		#set_physics_process(false) # 더 이상 물리 처리 업데이트를 하지 않음
		
		# --- 깨진 횟수 증가 및 동기화 ---
		if get_multiplayer_authority() == multiplayer.get_unique_id(): # 호스트만 카운트 증가
			death_count += 1
			sync_death_count_rpc.rpc(death_count) # 모든 피어에 동기화
		
		command_egg_destroy_and_spawn_jetpacks.rpc(global_position, linear_velocity, angular_velocity)

		# 잠시 후 노드 제거 (애니메이션 등 보여줄 시간 확보)
		#await get_tree().create_timer(3.0).timeout # 3초 대기 후 제거
		#queue_free() # 달걀 노드 제거
		

# 연료 채우기 오브젝트 
func refill_fuel():
	# 호스트에서만 연료 계산을 실행
	if not get_multiplayer_authority() == multiplayer.get_unique_id():
		return

	current_left_jetpack_fuel = max_jetpack_fuel
	current_right_jetpack_fuel = max_jetpack_fuel
	
	# 변경된 연료 상태를 모든 클라이언트에게 동기화
	# 기존에 사용하던 update_visuals_and_broadcast 함수를 재활용할 수 있습니다.
	# 현재 제트팩이 눌렸는지 여부는 false로 보내서 분사 효과가 나가지 않게 합니다.
	var left_key_pressed = Input.is_action_pressed("ui_left")
	var right_key_pressed = client_right_jetpack_active
	var can_use_left_jetpack = current_left_jetpack_fuel > 0
	var can_use_right_jetpack = current_right_jetpack_fuel > 0
	
	update_visuals_and_broadcast(current_left_jetpack_fuel, current_right_jetpack_fuel, left_key_pressed and can_use_left_jetpack, right_key_pressed and can_use_right_jetpack)

# 재밍
func _on_jamming_timer_timeout():
	GameManager.remove_status(GameManager.Status.JAMMED)

# 아이템
func collect_item(item_type: String) -> bool:
	if not GameManager.is_host():
		return false
	
	if current_item != "":
		return false
	
	current_item = item_type
	update_item_ui_rpc.rpc(current_item)
	return true

@rpc("any_peer","reliable")
func request_use_item_rpc():
	if GameManager.is_host():
		use_current_item()

func use_current_item():
	if current_item == "" or current_lives <= 0:
		return
	
	match current_item:
		"Barrier":
			if is_barrier_active:
				return
			is_barrier_active = true
			isInvincible = true
			
			barrier_effect.rpc()
	
	current_item = ""
	update_item_ui_rpc.rpc(current_item)

@rpc("any_peer","reliable","call_local")
func barrier_effect():
	barrier_effect_instance = barrier_effect_scene.instantiate()
	add_child(barrier_effect_instance)
	barrier_effect_instance.global_position = global_position
	barrier_effect_instance.visible = true
	
	barrier_timer.wait_time = barrier_duration
	barrier_timer.one_shot = true
	barrier_timer.start()

func _on_barrier_timer_timeout():
	barrier_effect_instance.start_blink()
	get_tree().create_timer(2).timeout.connect(_disable_barrier)
	
func _disable_barrier():
	isInvincible = false
	is_barrier_active = false
	barrier_timer.stop()
	barrier_effect_instance.queue_free()
	barrier_effect_instance = null

@rpc("any_peer","reliable","call_local")
func update_item_ui_rpc(item_name: String):
	if not is_instance_valid(item_display):
		return
	
	item_display.update_item_display(item_name)
		
