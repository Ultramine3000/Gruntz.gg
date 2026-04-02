extends Node

signal room_updated(room)
signal room_joined(room)
signal room_left()
signal error_occurred(code: String, message: String)
signal stats_received(stats: Dictionary)

var api: ApiClient
var room_service: RoomService

var current_room: RoomDTO = null
var player_id: String = ""
var player_name: String = ""

var _poll_timer: Timer


func _ready() -> void:
	player_name = NameGenerator.generate()

	api = ApiClient.new()
	add_child(api)

	api.base_url = Config.BASE_URL_DEV

	room_service = RoomService.new(api)

	_poll_timer = Timer.new()
	_poll_timer.one_shot = false
	_poll_timer.timeout.connect(_on_poll_timer_timeout)
	add_child(_poll_timer)


# -------------------
# Public API
# -------------------

# Response: RoomResponse (direct)
func create_room(max_players: int = 4) -> void:
	var res = await room_service.create_room(max_players)

	if res.has("error"):
		_emit_error(res)
		return

	current_room = RoomDTO.from_dict(res)
	player_id = ""

	emit_signal("room_updated", current_room)


# Response: { "room": RoomResponse, "player_id": String }
func join_room(room_id: String, player_name: String = "") -> void:
	var name_for_join := player_name if not player_name.is_empty() else self.player_name
	if name_for_join.is_empty():
		name_for_join = NameGenerator.generate()
	var res = await room_service.join_room(room_id, name_for_join)

	if res.has("error"):
		_emit_error(res)
		return

	current_room = RoomDTO.from_dict(res.get("room", {}))
	player_id = res.get("player_id", "")
	self.player_name = name_for_join

	emit_signal("room_joined", current_room)


# Response: { "room": RoomResponse }
func leave_room() -> void:
	if current_room == null or player_id == "":
		return

	var room_id := current_room.room_id
	var res = await room_service.leave_room(room_id, player_id)

	if res.has("error"):
		_emit_error(res)
		return

	current_room = null
	player_id = ""
	player_name = ""

	emit_signal("room_left")


# Response: RoomResponse (direct)
func refresh_room() -> void:
	if current_room == null:
		return

	var room_id := current_room.room_id
	var res = await room_service.get_room(room_id)

	if res.has("error"):
		_emit_error(res)
		return

	current_room = RoomDTO.from_dict(res)
	emit_signal("room_updated", current_room)


func start_polling(interval: float) -> void:
	_poll_timer.wait_time = interval
	_poll_timer.start()


func stop_polling() -> void:
	_poll_timer.stop()


func get_debug_stats() -> void:
	var res = await room_service.get_debug_stats()

	if res.has("error"):
		_emit_error(res)
		return

	emit_signal("stats_received", res)


# -------------------
# Internal
# -------------------

func _on_poll_timer_timeout() -> void:
	if current_room != null:
		refresh_room()


func _emit_error(res: Dictionary) -> void:
	var code := "UNKNOWN"
	var msg := "Unknown error"

	if res.has("error") and res["error"] is Dictionary:
		var err: Dictionary = res["error"]
		code = str(err.get("code", code))
		msg = str(err.get("message", msg))

	emit_signal("error_occurred", code, msg)
