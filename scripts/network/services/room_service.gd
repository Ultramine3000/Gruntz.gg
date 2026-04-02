class_name RoomService

var _api: ApiClient


func _init(api: ApiClient) -> void:
	_api = api


func create_room(max_players: int) -> Dictionary:
	var res = await _api.request("POST", ApiRoutes.ROOMS, {"max_players": max_players})
	return res["body"]


func join_room(room_id: String, player_name: String) -> Dictionary:
	var path := ApiRoutes.ROOMS_JOIN % room_id
	var res = await _api.request("POST", path, {"name": player_name})
	return res["body"]


func get_room(room_id: String) -> Dictionary:
	var path := ApiRoutes.ROOMS_GET % room_id
	var res = await _api.request("GET", path)
	return res["body"]


func leave_room(room_id: String, player_id: String) -> Dictionary:
	var path := ApiRoutes.ROOMS_LEAVE % room_id
	var res = await _api.request("POST", path, {"player_id": player_id})
	return res["body"]


func get_debug_stats() -> Dictionary:
	var res = await _api.request("GET", ApiRoutes.DEBUG_STATS)
	return res["body"]
