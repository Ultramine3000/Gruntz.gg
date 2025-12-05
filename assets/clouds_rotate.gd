extends Node3D

# Rotation speed in radians per second
@export var rotation_speed: float = 0.2

func _process(delta: float) -> void:
	# Rotate on the Y axis
	rotate_y(rotation_speed * delta)
