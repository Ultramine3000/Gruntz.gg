@tool
extends Node

# Node references - drag and drop in inspector
@export var sky_mesh: MeshInstance3D:
	set(value):
		sky_mesh = value
		_find_material()

@export var world_environment: WorldEnvironment
@export var sun_light: DirectionalLight3D  # Optional - will auto-create if not assigned

# Time settings - ALL CONTROLLED HERE
@export_range(0.0, 1.0) var start_time: float = 0.5
@export var time_scale: float = 1.0
@export var day_length: float = 120.0
@export var time_paused: bool = false

# Current time - visible in inspector and readable by other scripts
@export_range(0.0, 1.0) var current_time: float = 0.5:
	set(value):
		current_time = value
		_update_shader_time()

# Ambient light settings
@export var day_ambient_energy: float = 1.0
@export var night_ambient_energy: float = 0.05
@export var day_ambient_color: Color = Color(0.8, 0.8, 0.9)
@export var night_ambient_color: Color = Color(0.05, 0.05, 0.15)

# Ambient fade timing
@export var ambient_fade_start: float = -0.2
@export var ambient_fade_end: float = 0.2

# Sun light settings
@export var auto_create_sun_light: bool = true
@export var sun_light_energy: float = 1.0
@export var sun_light_color: Color = Color(1.0, 0.95, 0.9)

# Internal vars
var sky_material: ShaderMaterial
var game_start_time: float = 0.0
var last_logged_hour: int = -1  # Track last logged hour

func _find_material():
	sky_material = null
	
	if not sky_mesh:
		print("SKY DEBUG: No sky_mesh assigned")
		return
	
	# Try surface override material first
	if sky_mesh.get_surface_override_material_count() > 0:
		var mat = sky_mesh.get_surface_override_material(0)
		if mat is ShaderMaterial:
			sky_material = mat
			print("SKY DEBUG: Found material via surface override")
	
	# Fall back to mesh material
	if sky_material == null and sky_mesh.mesh != null:
		var mat = sky_mesh.mesh.surface_get_material(0)
		if mat is ShaderMaterial:
			sky_material = mat
			print("SKY DEBUG: Found material via mesh")
	
	if sky_material == null:
		print("SKY DEBUG: Could not find ShaderMaterial!")
	else:
		print("SKY DEBUG: Material found successfully")
		_update_shader_time()

func _update_shader_time():
	if sky_material == null:
		return
	
	sky_material.set_shader_parameter("current_time", current_time)
	
	if Engine.is_editor_hint():
		_update_sun_and_environment()

func _ready():
	print("SKY DEBUG: _ready called, is_editor_hint=", Engine.is_editor_hint())
	
	_find_material()
	
	# Auto-create sun light if needed
	if auto_create_sun_light and sun_light == null:
		sun_light = DirectionalLight3D.new()
		sun_light.name = "SunLight"
		sun_light.light_energy = sun_light_energy
		sun_light.light_color = sun_light_color
		sun_light.shadow_enabled = true
		add_child(sun_light)
		if Engine.is_editor_hint():
			sun_light.owner = get_tree().edited_scene_root
		print("SKY DEBUG: Auto-created DirectionalLight3D")
	
	# Setup environment
	if world_environment:
		if world_environment.environment == null:
			world_environment.environment = Environment.new()
		world_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	
	# In editor, just set initial time
	if Engine.is_editor_hint():
		if sky_material:
			sky_material.set_shader_parameter("current_time", current_time)
		return
	
	# Runtime initialization
	game_start_time = Time.get_ticks_msec() / 1000.0
	current_time = start_time
	
	# Set initial shader time
	if sky_material:
		sky_material.set_shader_parameter("current_time", current_time)

func _update_sun_and_environment():
	if sky_material == null:
		return
	
	# Calculate sun direction (matching shader calculation)
	var shader_sun_rise = sky_material.get_shader_parameter("sun_rise_angle")
	var shader_sun_tilt = sky_material.get_shader_parameter("sun_tilt")
	if shader_sun_rise == null:
		shader_sun_rise = 0.0
	if shader_sun_tilt == null:
		shader_sun_tilt = 0.2
	
	var angle = current_time * PI * 2.0
	var rise_rad = deg_to_rad(shader_sun_rise)
	var base_x = cos(angle)
	var base_y = sin(angle)
	
	var sun_direction = Vector3(
		base_x * cos(rise_rad) - shader_sun_tilt * sin(rise_rad),
		base_y,
		base_x * sin(rise_rad) + shader_sun_tilt * cos(rise_rad)
	).normalized()
	
	# Update DirectionalLight3D rotation
	# Time 0 (sunrise) = -170 degrees, Time 0.5 (sunset) = -10 degrees
	if sun_light:
		var rotation_x = lerp(-170.0, -10.0, current_time * 2.0)  # 0 to 0.5 maps to -170 to -10
		if current_time > 0.5:  # After sunset, continue rotating
			rotation_x = lerp(-10.0, 10.0, (current_time - 0.5) * 2.0)  # 0.5 to 1.0 maps to -10 to 10
		
		sun_light.rotation_degrees.x = rotation_x
		
		# Fade light energy based on sun height (day/night)
		var day_night = smoothstep(ambient_fade_start, ambient_fade_end, sun_direction.y)
		sun_light.light_energy = sun_light_energy * day_night
	
	# Update environment
	update_environment(sun_direction)

func _process(delta):
	if sky_material == null:
		return
	
	# In editor, manual control is handled by the setter
	if Engine.is_editor_hint():
		return
	
	# Runtime behavior
	if not time_paused:
		var elapsed_time = Time.get_ticks_msec() / 1000.0 - game_start_time
		current_time = fmod(start_time + (elapsed_time * time_scale / day_length), 1.0)
	# else: current_time stays frozen
	
	# Update shader with OUR calculated time
	sky_material.set_shader_parameter("current_time", current_time)
	
	# Log time every in-game hour (1/24th of the day)
	var current_hour = int(current_time * 24.0)
	if current_hour != last_logged_hour:
		last_logged_hour = current_hour
		print("Time: %02d:00 (%.3f)" % [current_hour, current_time])
	
	# Update sun and environment
	_update_sun_and_environment()

func update_environment(sun_direction: Vector3):
	if world_environment == null or world_environment.environment == null:
		return
	
	# Calculate ambient day/night
	var day_night = smoothstep(ambient_fade_start, ambient_fade_end, sun_direction.y)
	
	# Set ambient lighting
	world_environment.environment.ambient_light_energy = lerp(night_ambient_energy, day_ambient_energy, day_night)
	world_environment.environment.ambient_light_color = night_ambient_color.lerp(day_ambient_color, day_night)

func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
