extends Node

@export_category("DEBUG")
@export var skip_menu := false
@export var map_name := ""
@export_range(1, 2) var player_count := 1


func _ready() -> void:
	NetworkManager.room_joined.connect(_on_room_joined)
	NetworkManager.error_occurred.connect(_on_error)
	
	await NetworkManager.create_room(4)
	var room_id = NetworkManager.current_room.room_id
	await NetworkManager.join_room(room_id, "Valentino")
	await NetworkManager.leave_room()
	await NetworkManager.refresh_room()
	
	if skip_menu:
		Game.start_match(map_name, player_count)
		return
	
	var menu = load("res://core/menu.tscn").instantiate()
	add_child(menu)

func _on_room_joined(room: RoomDTO) -> void:
	print("Room joined: ", room)

func _on_error(code: String, message: String) -> void:
	print("Network Error [", code, "]: ", message)
