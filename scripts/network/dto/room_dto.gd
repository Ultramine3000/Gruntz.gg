class_name RoomDTO

var room_id:     String = ""
var max_players: int    = 0
var status:      String = ""
var players:     Array  = []


static func from_dict(data: Dictionary) -> RoomDTO:
	var dto         := RoomDTO.new()
	dto.room_id     = data.get("id", "")
	dto.max_players = data.get("max_players", 0)
	dto.status      = data.get("status", "")
	dto.players     = data.get("players", [])
	return dto
