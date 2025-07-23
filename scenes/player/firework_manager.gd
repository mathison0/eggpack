# 이 스크립트는 FireworkManager (Node2D) 노드에 연결됩니다.
extends Node2D

@onready var burst_particles = $GPUParticles2D_Burst   # 폭죽 터짐용 노드 참조

# 폭죽을 터뜨리는 함수
func explode_firework():
	# 파티클 시스템의 위치를 설정 (FireworkManager 노드의 위치를 기준으로)
	burst_particles.global_position = global_position
	
	# 폭죽 터짐 효과 시작 (GPUParticles2D_Burst)
	burst_particles.restart() # 이미 한 번 터졌다면 재시작
	burst_particles.emitting = true

@rpc("any_peer", "call_local")
func explode_firework_rpc(firework_pos: Vector2):
	# RPC로 전달받은 위치로 FireworkManager 노드 자체를 이동시킵니다.
	# 이렇게 하면 모든 클라이언트에서 동일한 위치에 폭죽이 터집니다.
	global_position = firework_pos
	global_rotation = 0.0 
	
	explode_firework() # 실제 애니메이션 시작 함수 호출
