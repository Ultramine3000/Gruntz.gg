extends Node3D

## ADS MOVEMENT SETTINGS ##
@export_category("ADS Movement")
@export var player_ctrl_port: int = 0
@export var idle_position: Vector3 = Vector3.ZERO  # Custom idle position offset from starting position
@export var ads_position: Vector3 = Vector3(0, -0.05, 0.1)  # ADS position offset from starting position
@export var use_animation: bool = true
@export var animation_duration: float = 0.3

## SCOPE SETTINGS ##
@export_category("Scope Settings")
@export var is_sniper: bool = false  # Check this box for sniper weapons
@export var scope_transition_delay := 0.15  # Delay before showing scope (to sync with weapon movement)

## RECOIL SETTINGS ##
@export_category("Recoil Settings")
@export var recoil_enabled := true  # Master toggle for all recoil
@export_range(-1.0, 1.0) var recoil_kick_amount := 0.027  # How far the weapon kicks back (Z-axis)
@export_range(0.0, 5.0) var recoil_rotation_pitch := 0.8  # Upward rotation per shot (degrees)
@export_range(0.0, 2.0) var recoil_horizontal_intensity := 0.4  # Horizontal drift intensity (left/right spray)
@export_range(0.0, 20.0) var recoil_recovery_speed := 1.4  # How fast weapon returns to normal
@export_range(0.0, 1.0) var recoil_ads_multiplier := 0.5  # Recoil reduction when ADS (50% reduction)

## SCOPE RECOIL SETTINGS ##
@export_category("Scope Recoil Settings")
@export_range(0.0, 200.0) var scope_recoil_kick := 80.0  # How far the scope kicks up (pixels)
@export_range(0.0, 100.0) var scope_recoil_sway := 25.0  # Horizontal sway amount (pixels)
@export_range(0.0, 20.0) var scope_recoil_recovery := 8.0  # How fast scope returns to center
@export_range(0.0, 1.0) var scope_recoil_damping := 0.85  # Dampening for smooth settling

## FIGURE-8 ROTATION SETTINGS ##
@export_category("Figure-8 Settings")
@export_range(0.0, 2.0) var rotation_speed := 0.65  # Speed of the figure-8 motion
@export_range(0.0, 0.1) var horizontal_amplitude := 0.2  # Horizontal sway amount (very small)
@export_range(0.0, 0.1) var vertical_amplitude := 0.1  # Vertical sway amount (very small)
@export_range(0.0, 0.1) var roll_amplitude := 0.05  # Roll rotation amount (tiny)

## SPRINT ANIMATION SETTINGS ##
@export_category("Sprint Animation")
@export var sprint_position: Vector3 = Vector3(0, -0.1, 0.05)  # Position offset when sprinting
@export var sprint_rotation: Vector3 = Vector3(-10, 5, -15)  # Rotation offset when sprinting (degrees)
@export_range(0.0, 1.0) var sprint_transition_speed := 8.0  # How quickly sprint animation blends in/out

## CS:GO-STYLE INPUT RESPONSE SETTINGS ##
@export_category("CS:GO Input Response")
@export_range(0.0, 5.0) var look_lag_amount := 1.2  # How much the weapon lags behind camera (CS:GO feel)
@export_range(0.0, 30.0) var look_lag_speed := 15.0  # Speed of lag catchup (higher = snappier, CS:GO ~12-15)
@export_range(0.0, 3.0) var look_tilt_amount := 0.6  # Side tilt when turning (subtle CS:GO roll)
@export_range(0.0, 30.0) var look_tilt_speed := 12.0  # Speed of tilt response
@export_range(0.0, 1.0) var ads_sway_multiplier := 0.15  # Reduce sway when ADS (85% reduction)
@export_range(0.0, 1.0) var sprint_sway_multiplier := 0.4  # Reduce sway when sprinting
@export_range(0.0, 0.01) var mouse_sensitivity_scale := 0.0015  # Mouse sensitivity multiplier
@export_range(0.0, 1.0) var mouse_smoothing := 0.25  # Mouse movement smoothing (higher = smoother but more lag)

## INTERNAL VARIABLES ##
var is_ads: bool = false
var is_sprinting: bool = false
var tween: Tween
var starting_position: Vector3
var starting_rotation: Vector3

# Figure-8 sway
var time_elapsed := 0.0
var player_reference : Player

# CS:GO-style input tracking
var look_input_velocity := Vector2.ZERO  # Current camera movement velocity
var smoothed_look_velocity := Vector2.ZERO  # Smoothed version for mouse
var weapon_lag_rotation := Vector3.ZERO  # Weapon lag behind camera
var weapon_tilt_rotation := Vector3.ZERO  # Banking/tilt when turning
var last_look_input := Vector2.ZERO

# Sprint animation
var current_sprint_intensity := 0.0
var target_sprint_intensity := 0.0
var current_sprint_position_offset := Vector3.ZERO
var current_sprint_rotation_offset := Vector3.ZERO

# Recoil
var current_recoil_position := Vector3.ZERO
var target_recoil_position := Vector3.ZERO
var current_recoil_rotation := Vector3.ZERO
var target_recoil_rotation := Vector3.ZERO

# Scope
var scope_node: Node = null
var scope_recoil_offset := Vector2.ZERO
var scope_recoil_velocity := Vector2.ZERO
var scope_original_position := Vector2.ZERO

func _ready():
	print("ADS Script _ready() called")
	
	starting_position = transform.origin
	starting_rotation = rotation_degrees
	print("Starting position: ", starting_position)
	
	_find_parent_player()
	print("Player reference found: ", player_reference)
	
	_initialize_scope()
	
	var idle_pos = starting_position + idle_position
	transform.origin = idle_pos
	print("ADS Script initialization complete")

func _find_parent_player():
	print("Looking for parent player...")
	var current_node = self
	while current_node != null:
		current_node = current_node.get_parent()
		print("Checking node: ", current_node)
		if current_node is Player:
			player_reference = current_node
			player_ctrl_port = current_node.ctrl_port
			print("Found Player! ctrl_port: ", player_ctrl_port)
			break
	
	if not player_reference:
		print("ERROR: Could not find Player parent!")

func _initialize_scope():
	print("ADS Script: Looking for scope node...")
	if player_reference and player_reference.hud:
		print("ADS Script: Player HUD found, looking for scope node...")
		if player_reference.hud.has_node("scope"):
			scope_node = player_reference.hud.get_node("scope")
			print("ADS Script: Scope node found: ", scope_node)
			if scope_node:
				scope_node.visible = false
				if scope_node is Control:
					scope_original_position = scope_node.position
				print("ADS Script: Scope node visibility set to false")
		else:
			print("ADS Script: Scope node not found in HUD! Available children:")
			for child in player_reference.hud.get_children():
				print("  - ", child.name)
	else:
		print("ADS Script: Player reference or HUD not found")

func _process(delta: float):
	time_elapsed += delta * rotation_speed
	
	_update_sprint_state(delta)
	_update_csgo_weapon_sway(delta)
	_update_recoil_recovery(delta)
	_update_scope_recoil(delta)
	
	# Create base figure-8 pattern (reduced when sprinting)
	var figure8_intensity = 1.0 - (current_sprint_intensity * 0.8)
	var horizontal_sway = sin(time_elapsed) * horizontal_amplitude * figure8_intensity
	var vertical_sway = sin(time_elapsed * 2.0) * vertical_amplitude * figure8_intensity
	var roll_sway = sin(time_elapsed * 0.5) * roll_amplitude * figure8_intensity
	
	var figure8_rotation = Vector3(
		vertical_sway,
		horizontal_sway,
		roll_sway
	)
	
	# Combine: base + figure-8 + CS:GO lag + tilt + sprint
	rotation_degrees = starting_rotation + figure8_rotation + weapon_lag_rotation + weapon_tilt_rotation + current_sprint_rotation_offset
	
	# Add recoil on top
	rotation_degrees.x += current_recoil_rotation.x
	rotation_degrees.y += current_recoil_rotation.y
	
	_update_position_with_sprint_and_recoil()

func _update_csgo_weapon_sway(delta: float):
	"""CS:GO-style weapon lag and tilt - smooth, realistic, weighted feel"""
	if player_reference == null:
		return
	
	# Don't process when paused
	if player_reference.hud and player_reference.hud.is_paused:
		weapon_lag_rotation = weapon_lag_rotation.lerp(Vector3.ZERO, look_lag_speed * delta)
		weapon_tilt_rotation = weapon_tilt_rotation.lerp(Vector3.ZERO, look_tilt_speed * delta)
		look_input_velocity = Vector2.ZERO
		smoothed_look_velocity = Vector2.ZERO
		return
	
	# Get raw camera input
	var horizontal_input := 0.0
	var vertical_input := 0.0
	
	if player_ctrl_port == 0:
		# Player 1: controller + mouse
		horizontal_input = Input.get_axis("p0_cam_lf", "p0_cam_rt")
		vertical_input = Input.get_axis("p0_cam_dn", "p0_cam_up")
		
		# Add mouse input with smoothing
		var mouse_motion = Input.get_last_mouse_velocity()
		horizontal_input += mouse_motion.x * mouse_sensitivity_scale
		vertical_input += mouse_motion.y * mouse_sensitivity_scale
	else:
		# Other players: controller only
		horizontal_input = Input.get_axis("p" + str(player_ctrl_port) + "_cam_lf", "p" + str(player_ctrl_port) + "_cam_rt")
		vertical_input = Input.get_axis("p" + str(player_ctrl_port) + "_cam_dn", "p" + str(player_ctrl_port) + "_cam_up")
	
	var current_look_input = Vector2(horizontal_input, vertical_input)
	
	# RAW velocity (for immediate response)
	look_input_velocity = current_look_input
	
	# SMOOTHED velocity (for weapon sway calculations)
	# This prevents choppy mouse movement from causing jittery weapon sway
	smoothed_look_velocity = smoothed_look_velocity.lerp(look_input_velocity, mouse_smoothing)
	
	# Calculate state-based multiplier
	var sway_multiplier = 1.0
	if player_reference.is_aiming:
		sway_multiplier = ads_sway_multiplier
	elif current_sprint_intensity > 0.01:
		sway_multiplier = lerp(1.0, sprint_sway_multiplier, current_sprint_intensity)
	
	# === WEAPON LAG (CS:GO inertia effect) ===
	# Use SMOOTHED velocity for weapon calculations to prevent choppy mouse movement
	var target_lag = Vector3(
		-smoothed_look_velocity.y * look_lag_amount * sway_multiplier,  # Pitch opposite to vertical look
		-smoothed_look_velocity.x * look_lag_amount * sway_multiplier,  # Yaw opposite to horizontal look
		0.0
	)
	
	# Spring-like interpolation for smooth lag
	weapon_lag_rotation = weapon_lag_rotation.lerp(target_lag, look_lag_speed * delta)
	
	# === WEAPON TILT (CS:GO banking effect) ===
	# Use SMOOTHED velocity here too
	var target_tilt = Vector3(
		0.0,
		0.0,
		smoothed_look_velocity.x * look_tilt_amount * sway_multiplier  # Roll with horizontal movement
	)
	
	weapon_tilt_rotation = weapon_tilt_rotation.lerp(target_tilt, look_tilt_speed * delta)
	
	last_look_input = current_look_input
	
	# Clamp to prevent extreme values
	weapon_lag_rotation.x = clamp(weapon_lag_rotation.x, -look_lag_amount * 3.0, look_lag_amount * 3.0)
	weapon_lag_rotation.y = clamp(weapon_lag_rotation.y, -look_lag_amount * 3.0, look_lag_amount * 3.0)
	weapon_tilt_rotation.z = clamp(weapon_tilt_rotation.z, -look_tilt_amount * 3.0, look_tilt_amount * 3.0)

func _update_scope_recoil(delta: float):
	if not scope_node or not scope_node.visible or not scope_node is Control:
		return
	
	var spring_force = -scope_recoil_offset * scope_recoil_recovery
	var damping_force = -scope_recoil_velocity * (1.0 - scope_recoil_damping) * 10.0
	
	scope_recoil_velocity += (spring_force + damping_force) * delta
	scope_recoil_offset += scope_recoil_velocity * delta
	
	scope_node.position = scope_original_position + scope_recoil_offset
	
	if scope_recoil_offset.length() < 0.5 and scope_recoil_velocity.length() < 1.0:
		scope_recoil_offset = Vector2.ZERO
		scope_recoil_velocity = Vector2.ZERO
		scope_node.position = scope_original_position

func apply_scope_recoil():
	if not is_sniper or not is_ads or not scope_node or not scope_node.visible:
		return
	
	var horizontal_variation = randf_range(-scope_recoil_sway, scope_recoil_sway)
	
	scope_recoil_velocity += Vector2(
		horizontal_variation,
		-scope_recoil_kick
	)
	
	print("Scope recoil applied - velocity: ", scope_recoil_velocity)

func _update_recoil_recovery(delta: float):
	current_recoil_position = current_recoil_position.lerp(Vector3.ZERO, recoil_recovery_speed * delta)
	current_recoil_rotation = current_recoil_rotation.lerp(Vector3.ZERO, recoil_recovery_speed * delta)
	
	if current_recoil_position.length() < 0.0001:
		current_recoil_position = Vector3.ZERO
	if current_recoil_rotation.length() < 0.01:
		current_recoil_rotation = Vector3.ZERO

func apply_recoil():
	if not recoil_enabled:
		return
	
	apply_scope_recoil()
	
	var multiplier = recoil_ads_multiplier if is_ads else 1.0
	
	current_recoil_position += Vector3(
		0.0,
		0.0,
		recoil_kick_amount * multiplier
	)
	
	var pitch_variation = randf_range(0.9, 1.1)
	var yaw_variation = randf_range(-recoil_horizontal_intensity, recoil_horizontal_intensity)
	
	current_recoil_rotation += Vector3(
		recoil_rotation_pitch * multiplier * pitch_variation,
		yaw_variation * multiplier,
		0.0
	)

func _update_sprint_state(delta: float):
	if player_reference:
		target_sprint_intensity = 1.0 if player_reference.is_sprinting else 0.0
	else:
		target_sprint_intensity = 0.0
	
	current_sprint_intensity = lerp(current_sprint_intensity, target_sprint_intensity, sprint_transition_speed * delta)
	
	current_sprint_position_offset = sprint_position * current_sprint_intensity
	current_sprint_rotation_offset = sprint_rotation * current_sprint_intensity

func _update_position_with_sprint_and_recoil():
	var target_pos: Vector3
	
	if is_ads:
		target_pos = starting_position + ads_position
	else:
		target_pos = starting_position + idle_position
	
	target_pos += current_sprint_position_offset
	target_pos += current_recoil_position
	
	if use_animation and not is_equal_approx(transform.origin.distance_to(target_pos), 0.0):
		animate_to_position(target_pos)
	else:
		transform.origin = target_pos

## SCOPE MANAGEMENT FUNCTIONS ##
func _show_scope():
	print("ADS Script: _show_scope called - scope_node: ", scope_node, " is_sniper: ", is_sniper)
	
	if scope_node == null:
		print("ADS Script: Scope node is null, attempting to initialize...")
		_initialize_scope()
	
	if scope_node and is_sniper:
		print("ADS Script: Conditions met, waiting for delay...")
		await get_tree().create_timer(scope_transition_delay).timeout
		print("ADS Script: After delay - is_ads: ", is_ads, " is_sniper: ", is_sniper)
		if is_ads and is_sniper:
			scope_node.visible = true
			print("ADS Script: Scope visibility set to TRUE")
			
			scope_recoil_offset = Vector2.ZERO
			scope_recoil_velocity = Vector2.ZERO
			if scope_node is Control:
				scope_node.position = scope_original_position
			
			_hide_weapon()
		else:
			print("ADS Script: Conditions no longer met after delay")
	else:
		print("ADS Script: Conditions not met for showing scope - scope_node: ", scope_node, " is_sniper: ", is_sniper)

func _hide_scope():
	print("ADS Script: _hide_scope called - scope_node: ", scope_node)
	
	if is_sniper:
		_show_weapon()
	
	if scope_node == null:
		print("ADS Script: Scope node is null, attempting to initialize...")
		_initialize_scope()
	
	if scope_node:
		scope_node.visible = false
		scope_recoil_offset = Vector2.ZERO
		scope_recoil_velocity = Vector2.ZERO
		if scope_node is Control:
			scope_node.position = scope_original_position
		print("ADS Script: Scope visibility set to FALSE")

## WEAPON VISIBILITY FUNCTIONS ##
func _hide_weapon():
	print("ADS Script: Hiding weapon model")
	var weapon_node = get_parent()
	if weapon_node:
		weapon_node.visible = false
		print("ADS Script: Weapon hidden: ", weapon_node.name)

func _show_weapon():
	print("ADS Script: Showing weapon model")
	var weapon_node = get_parent()
	if weapon_node:
		weapon_node.visible = true
		print("ADS Script: Weapon shown: ", weapon_node.name)

## ADS MOVEMENT FUNCTIONS ##
func move_to_idle():
	var idle_pos = starting_position + idle_position
	if use_animation:
		animate_to_position(idle_pos)
	else:
		transform.origin = idle_pos

func set_p0_ads(value: bool):
	var was_ads = is_ads
	is_ads = value
	print("ADS Script: set_p0_ads called with value: ", value, " (was_ads: ", was_ads, ")")
	
	if is_sniper:
		print("ADS Script: This is a sniper weapon")
		if is_ads and not was_ads:
			print("ADS Script: Starting ADS transition - calling _show_scope()")
			_show_scope()
		elif not is_ads and was_ads:
			print("ADS Script: Starting transition back to idle - calling _hide_scope()")
			_hide_scope()
	else:
		print("ADS Script: This is NOT a sniper weapon")
	
	update_position()

func set_p1_ads(value: bool):
	pass

func update_position():
	pass

func animate_to_position(pos: Vector3):
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.tween_property(self, "transform:origin", pos, animation_duration)

func test_ads():
	set_p0_ads(true)

func test_idle():
	set_p0_ads(false)

func reset_to_starting():
	transform.origin = starting_position
	rotation_degrees = starting_rotation
	is_ads = false
	current_sprint_intensity = 0.0
	current_sprint_position_offset = Vector3.ZERO
	current_sprint_rotation_offset = Vector3.ZERO
	current_recoil_position = Vector3.ZERO
	target_recoil_position = Vector3.ZERO
	current_recoil_rotation = Vector3.ZERO
	target_recoil_rotation = Vector3.ZERO
	scope_recoil_offset = Vector2.ZERO
	scope_recoil_velocity = Vector2.ZERO
	weapon_lag_rotation = Vector3.ZERO
	weapon_tilt_rotation = Vector3.ZERO
	look_input_velocity = Vector2.ZERO
	smoothed_look_velocity = Vector2.ZERO
	last_look_input = Vector2.ZERO
	_hide_scope()
