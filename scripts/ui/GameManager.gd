extends Node

var my_id: int = -1
var host_id: int = -2
var players: Dictionary = {}
var lobby_code: String = ""

var is_control_swapped: bool = false
enum Status {
	CONTROL_SWAPPED,
	SLOWED_DOWN,
	JAMMED
}
var active_status: Array[Status] = []

signal status_effect_changed(active_status: Array)

func is_host() -> bool:
	return host_id == my_id

func add_status(status_effect: Status):
	if not active_status.has(status_effect):
		active_status.append(status_effect)
		status_effect_changed.emit(active_status)
		sync_status_update.rpc(active_status)

func remove_status(status_effect: Status):
	if active_status.has(status_effect):
		active_status.erase(status_effect)
		status_effect_changed.emit(active_status)
		sync_status_update.rpc(active_status)

# 입려 뒤집기 상태 전환
func toggle_control_swap():
	if not GameManager.is_host():
		return
	
	is_control_swapped = not is_control_swapped
	
	if is_control_swapped:
		add_status(Status.CONTROL_SWAPPED)
	else:
		remove_status(Status.CONTROL_SWAPPED)

# 구름 감속
func cloud_slow_down(state_bool: bool):
	if not GameManager.is_host():
		return
	
	if state_bool:
		add_status(Status.SLOWED_DOWN)
	else:
		remove_status(Status.SLOWED_DOWN)

# 먹구름 재밍
func dark_cloud_jam():
	if not GameManager.is_host():
		return
	
	

@rpc("any_peer", "reliable")
func sync_status_update(changed_status: Array[Status]):
	active_status = changed_status
	status_effect_changed.emit(active_status)
