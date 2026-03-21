class_name PlayerDTO

var id:        String = ""
var name:      String = ""
var is_leader: bool   = false


static func from_dict(data: Dictionary) -> PlayerDTO:
	var dto       := PlayerDTO.new()
	dto.id        = data.get("id", "")
	dto.name      = data.get("name", "")
	dto.is_leader = data.get("is_leader", false)
	return dto
