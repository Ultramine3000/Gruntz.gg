class_name NameGenerator

const NAMES := [
	"Vex", "Kael", "Zorn", "Riva", "Dusk",
	"Marsh", "Sable", "Crix", "Fen", "Thorn"
]


static func generate() -> String:
	return NAMES[randi() % NAMES.size()]
