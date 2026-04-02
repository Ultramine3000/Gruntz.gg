extends Node
## Plain simulation: two independent HTTP clients (no NetworkManager autoload).
## Attach to a scene root and run with the backend at Config.BASE_URL_DEV.

class SimClient:
	var player_id: String = ""
	var player_name: String = ""
	var room_id: String = ""
	var _api: ApiClient
	var room_service: RoomService

	func _init(root: Node, base_url: String, chosen_name: String) -> void:
		player_name = chosen_name
		_api = ApiClient.new()
		root.add_child(_api)
		_api.base_url = base_url
		room_service = RoomService.new(_api)


func _ready() -> void:
	await _run_simulation()


func _run_simulation() -> void:
	var base_url := Config.BASE_URL_DEV
	var client_a := SimClient.new(self, base_url, NameGenerator.generate())
	var client_b := SimClient.new(self, base_url, NameGenerator.generate())

	print("[SIM] step 1 — client A creating room")
	var created := await client_a.room_service.create_room(4)
	if created.has("error"):
		_sim_error("client A create_room", created)
		return
	client_a.room_id = str(created.get("id", ""))
	if client_a.room_id.is_empty():
		_sim_error("client A create_room", {"error": {"code": "SIM_INVALID", "message": "missing room id in response"}})
		return

	print("[SIM] step 2 — client A joining room")
	var join_a := await client_a.room_service.join_room(client_a.room_id, client_a.player_name)
	if join_a.has("error"):
		_sim_error("client A join_room", join_a)
		return
	client_a.player_id = str(join_a.get("player_id", ""))
	if client_a.player_id.is_empty():
		_sim_error("client A join_room", {"error": {"code": "SIM_INVALID", "message": "missing player_id in response"}})
		return

	print("[SIM] step 3 — client B joining room")
	var join_b := await client_b.room_service.join_room(client_a.room_id, client_b.player_name)
	if join_b.has("error"):
		_sim_error("client B join_room", join_b)
		return
	client_b.player_id = str(join_b.get("player_id", ""))
	if client_b.player_id.is_empty():
		_sim_error("client B join_room", {"error": {"code": "SIM_INVALID", "message": "missing player_id in response"}})
		return
	client_b.room_id = client_a.room_id

	print("[SIM] step 4 — both clients get_room (expect both players)")
	var room_a := await client_a.room_service.get_room(client_a.room_id)
	if room_a.has("error"):
		_sim_error("client A get_room", room_a)
		return
	var room_b := await client_b.room_service.get_room(client_b.room_id)
	if room_b.has("error"):
		_sim_error("client B get_room", room_b)
		return
	var ids_a := _collect_player_ids(room_a)
	var ids_b := _collect_player_ids(room_b)
	if not client_a.player_id in ids_a or not client_b.player_id in ids_a:
		_sim_error("client A get_room player list", {"error": {"code": "SIM_ASSERT", "message": "expected both players on A view: %s" % ids_a}})
		return
	if not client_a.player_id in ids_b or not client_b.player_id in ids_b:
		_sim_error("client B get_room player list", {"error": {"code": "SIM_ASSERT", "message": "expected both players on B view: %s" % ids_b}})
		return
	print("  [SIM] A sees players: ", ids_a)
	print("  [SIM] B sees players: ", ids_b)

	print("[SIM] step 5 — get_debug_stats")
	var stats := await client_a.room_service.get_debug_stats()
	if stats.has("error"):
		_sim_error("get_debug_stats", stats)
		return
	print("  [SIM] debug stats: ", stats)

	print("[SIM] step 6 — client B leaving room")
	var leave_b := await client_b.room_service.leave_room(client_b.room_id, client_b.player_id)
	if leave_b.has("error"):
		_sim_error("client B leave_room", leave_b)
		return

	print("[SIM] step 7 — client A get_room (expect B gone)")
	var room_a2 := await client_a.room_service.get_room(client_a.room_id)
	if room_a2.has("error"):
		_sim_error("client A get_room after B left", room_a2)
		return
	var ids_a2 := _collect_player_ids(room_a2)
	if client_b.player_id in ids_a2:
		_sim_error("client A get_room after B left", {"error": {"code": "SIM_ASSERT", "message": "B still listed: %s" % ids_a2}})
		return
	if not client_a.player_id in ids_a2:
		_sim_error("client A get_room after B left", {"error": {"code": "SIM_ASSERT", "message": "A missing: %s" % ids_a2}})
		return
	print("  [SIM] A sees players: ", ids_a2)

	print("[SIM] step 8 — client A leaving room")
	var leave_a := await client_a.room_service.leave_room(client_a.room_id, client_a.player_id)
	if leave_a.has("error"):
		_sim_error("client A leave_room", leave_a)
		return

	print("[SIM] step 9 — client A get_room (ROOM_NOT_FOUND or status finished)")
	var final_room := await client_a.room_service.get_room(client_a.room_id)
	if final_room.has("error"):
		var err: Dictionary = final_room["error"]
		var code := str(err.get("code", ""))
		if code != "ROOM_NOT_FOUND":
			_sim_error("client A final get_room (expected ROOM_NOT_FOUND)", final_room)
			return
		print("  [SIM] got expected error: ", code)
	else:
		var st := str(final_room.get("status", ""))
		if st != "finished":
			_sim_error("client A final get_room (expected status finished)", {"error": {"code": "SIM_ASSERT", "message": "status=%s" % st}})
			return
		print("  [SIM] room status: ", st)

	print("[SIM] sequence complete.")


func _collect_player_ids(room_body: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var players: Variant = room_body.get("players", [])
	if players is Array:
		for p in players:
			if p is Dictionary:
				out.append(str(p.get("id", "")))
	return out


func _sim_error(operation: String, res: Dictionary) -> void:
	var msg := str(res)
	if res.has("error") and res["error"] is Dictionary:
		var e: Dictionary = res["error"]
		msg = "%s — %s" % [e.get("code", "?"), e.get("message", "?")]
	print("[SIM][ERROR] ", operation, ": ", msg)
