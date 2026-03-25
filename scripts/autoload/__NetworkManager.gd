extends Node

signal room_updated(room)
signal room_joined(room)
signal room_left()
signal error_occurred(message)

var api: ApiClient
var room_service: RoomService

var current_room = null
var player_id: String = ""


func _ready() -> void:
	api = ApiClient.new()
	add_child(api)

	api.base_url = Config.BASE_URL_DEV

	room_service = RoomService.new(api)


# -------------------
# Public API
# -------------------

# Response: RoomResponse (direct)
func create_room(max_players: int = 4) -> void:
	var res = await room_service.create_room(max_players)

	if res.has("error"):
		_emit_error(res)
		return

	current_room = res
	player_id = ""

	emit_signal("room_updated", RoomDTO.from_dict(current_room))


# Response: { "room": RoomResponse, "player_id": String }
func join_room(room_id: String, player_name: String) -> void:
	var res = await room_service.join_room(room_id, player_name)

	if res.has("error"):
		_emit_error(res)
		return

	current_room = res.get("room", {})
	player_id = res.get("player_id", "")

	emit_signal("room_joined", RoomDTO.from_dict(current_room))


# Response: { "room": RoomResponse }
func leave_room() -> void:
	if current_room == null or player_id == "":
		return

	var room_id := current_room["id"] as String
	var res = await room_service.leave_room(room_id, player_id)

	if res.has("error"):
		_emit_error(res)
		return

	current_room = null
	player_id = ""

	emit_signal("room_left")


# Response: RoomResponse (direct)
func refresh_room() -> void:
	if current_room == null:
		return

	var room_id := current_room["id"] as String
	var res = await room_service.get_room(room_id)

	if res.has("error"):
		_emit_error(res)
		return

	current_room = res
	emit_signal("room_updated", RoomDTO.from_dict(current_room))


# -------------------
# Internal
# -------------------

func _emit_error(res: Dictionary) -> void:
	var msg := "Unknown error"

	if res.has("error") and res["error"] is Dictionary:
		msg = res["error"].get("message", msg)

	emit_signal("error_occurred", msg)
