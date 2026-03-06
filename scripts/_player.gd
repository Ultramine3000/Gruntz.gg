extends CharacterBody3D
class_name Player

## NODES ##
var hud: Control
@export var hud_splitscreen: PackedScene
@export var hud_multiplayer: PackedScene
@onready var camera := $camera
@onready var arms_rig := $camera/arms
@onready var body_rig := $body/body_rig
var barrel: Node3D

@onready var current_arm_rig
@onready var body_anim_continue : AnimationPlayer = $body/body_rig/anim_continue
@onready var body_anim_oneshot : AnimationPlayer = $body/body_rig/anim_oneshot

## AUDIO ##
@onready var walk_sound := $walk_sound
@onready var shoot_sound := $shoot_sound
@onready var reload_sound := $reload_sound
@onready var draw_sound := $draw_sound
@onready var holster_sound := $holster_sound

## ADS (AIM DOWN SIGHTS) ##
@export_category("ADS")
@export_range(0.1, 2.0) var ads_zoom_factor := 0.4
@export_range(1.0, 10.0) var ads_transition_speed := 5.0
var is_aiming := false
var default_fov : float
var target_fov : float

## ARM BOBBING ##
@export_category("Arms")
var arm_bob_time := 0.0
@export var bob_speed := 8.0
@export var bob_amount := 0.03

## CONTROLLER ##
@export_category("Controller")
@export_range(0,3) var ctrl_port := 0
var view_layer : int

## CAMERA ##
@export_category("Camera")
@export_range(0.0, 16.0) var camera_sensitivity := 0.0
@export_range(-90.0, 0.0) var camera_min_pitch := -40.0
@export_range(0.0, 90.0) var camera_max_pitch := 60.0

var look_input := Vector2.ZERO
var target_look_input := Vector2.ZERO
@export_range(0.0, 20.0) var look_smoothness := 10.0

## SCOPE SWAY ##
@export_category("Scope Sway")
@export var scope_sway_enabled := true
@export_range(0.0, 0.5) var scope_sway_amount := 0.08
@export_range(0.0, 3.0) var scope_sway_speed := 1.2

var scope_sway_time := 0.0
var scope_shot_sway_intensity := 0.0
var scope_shot_drift := 0.0

## MOVEMENT ##
@export_category("Movement")
@export_range(0.0, 100.0) var max_walk_speed := 0.0
@export_range(0.0, 100.0) var max_sprint_speed := 0.0
@export_range(0.0, 20.0) var accel := 0.0
@export_range(0.0, 20.0) var decel := 0.0
const GRAVITY_COLLIDE := -0.1
var gravity_multiplier = 0.27
var direction : Vector3
var speed := 0.0
var animation_inputs: Dictionary[String, bool]
@export var is_sprinting := false

## JUMPING ##
@export_category("Jumping")
@export_range(0.0, 100.0) var jump_force := 0.0
var is_jumping := false
var jump_queued := false

## SHOOTING ##
@export_category("Shooting")
var shoot_cooldown := 0.0
@export var tracer_scene: PackedScene

## RELOAD ##
var reloading: bool = false

## INSPECT ##
var inspecting: bool = false

## STATS ##
@export_category("Stats")
@export_range(0, 1000) var max_health := 100
var health : int
var current_score := 0
var dead: bool

## INVENTORY ##
@export_category("Inventory")
@export var current_weapon : Weapon
@export var side_weapon : Weapon
var ammo := {}
@export var ammo_default_multiplier := 2

## WEAPON SWITCHING ##
var weapon_switching := false
var switch_cooldown := 0.0
@export var switch_cooldown_time := 0.5

## MISC ##
var enemy_that_killed : Player
var reload_time_remaining := 0.0

var animation_blends = {
	"idle": 0.5,
	"fire_idle": 0.1,
	"reload": 0.0,
	"draw": 0.0,
	"holster": 0.0,
	"inspect": 0.0,
	"melee": 0.1,
}

## ANIMATION BLENDING ##
# Tracks the current blend state between two movement animations
var blend_anim_a := "Idle"
var blend_anim_b := "Idle"
var blend_weight := 0.0          # 0 = full A, 1 = full B
var target_blend_weight := 0.0
var blend_speed := 8.0           # How fast blending transitions

func _ready() -> void:
	if multiplayer.multiplayer_peer is not OfflineMultiplayerPeer:
		set_multiplayer_authority(Multiplayer.player_ids[ctrl_port])
		print("Player ctrl_port ", ctrl_port, " authority set to: ", get_multiplayer_authority())
		print("Local multiplayer ID: ", multiplayer.get_unique_id())
		print("Is authority: ", is_multiplayer_authority())

	if current_weapon:
		current_weapon = current_weapon.duplicate(true)
	if side_weapon:
		side_weapon = side_weapon.duplicate(true)

	if is_instance_valid(Game) and not Game.player_loadouts.is_empty():
		if ctrl_port < Game.player_loadouts.size():
			var loadout = Game.player_loadouts[ctrl_port]
			_apply_loadout(loadout)

	_setup_hud()

	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		view_layer = ctrl_port + 2
	else:
		view_layer = 2

	print("Player ctrl_port ", ctrl_port, " using view_layer: ", view_layer)

	if hud and hud.has_node("player_label"):
		hud.get_node("player_label").text = "Player " + str(ctrl_port + 1)

	if multiplayer.multiplayer_peer is not OfflineMultiplayerPeer:
		if not is_multiplayer_authority():
			if hud:
				hud.hide()

	camera.cull_mask = 1
	camera.set_cull_mask_value(view_layer, true)

	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		_set_arm_vis_recursive(arms_rig)
		_set_body_vis_recursive($body)
	else:
		if is_multiplayer_authority():
			_set_arm_vis_recursive(arms_rig)
			_set_body_vis_recursive($body)
		else:
			_hide_arms_completely(arms_rig)
			_set_body_vis_for_remote_player($body)

	default_fov = camera.fov
	target_fov = default_fov

	if has_node("muzzle_flash"):
		_set_body_vis_recursive(get_node("muzzle_flash"))

	if current_weapon:
		var weapon_key = _get_weapon_key(current_weapon)
		ammo[weapon_key] = current_weapon.max_ammo * ammo_default_multiplier
		current_weapon.current_ammo = current_weapon.max_ammo
	if side_weapon:
		var weapon_key = _get_weapon_key(side_weapon)
		ammo[weapon_key] = side_weapon.max_ammo * ammo_default_multiplier
		side_weapon.current_ammo = side_weapon.max_ammo
	switch_weapon(true)

	animation_inputs = {
		"walk_fw": false,
		"walk_bk": false,
		"walk_lf": false,
		"walk_rt": false,
		"jump": false,
	}

	health = max_health
	if hud:
		hud.health_bar.max_value = max_health
		hud.health_bar.value = health
		hud.update_score()
	body_anim_oneshot.animation_finished.connect(_on_death_anim_done.bind(1))

	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		if ctrl_port == 0:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		if is_multiplayer_authority():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _update_barrel_reference():
	if current_arm_rig and current_arm_rig.has_node("LVA4_Armature/barrel"):
		barrel = current_arm_rig.get_node("LVA4_Armature/barrel")
		print("Barrel reference updated to: ", barrel.get_path())
	else:
		print("Warning: Could not find barrel node in current weapon armature!")
		barrel = null

func _setup_hud():
	if has_node("hud"):
		$hud.queue_free()
	var hud_scene: PackedScene
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		hud_scene = hud_splitscreen
	else:
		hud_scene = hud_multiplayer
	if hud_scene:
		hud = hud_scene.instantiate()
		hud.name = "hud"
		add_child(hud)
	else:
		print("Error: HUD scene not assigned!")

func _hide_arms_completely(parent):
	if parent is VisualInstance3D:
		parent.layers = 0
		parent.visible = false
	if parent.get_child_count() > 0:
		for child in parent.get_children():
			_hide_arms_completely(child)

func _set_body_vis_for_remote_player(parent, is_body_node = false):
	if parent.name == "body":
		is_body_node = true
	if parent is VisualInstance3D:
		parent.layers = 0
		parent.set_layer_mask_value(2, true)
		if is_body_node and parent is GeometryInstance3D:
			parent.visibility_range_end = 0.0
			parent.visibility_range_end_margin = 0.0
			parent.ignore_occlusion_culling = true
			parent.extra_cull_margin = 16384.0
	if parent.get_child_count() > 0:
		for child in parent.get_children():
			_set_body_vis_for_remote_player(child, is_body_node)

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_control_process()
		_camera_process(delta)
		_movement_process(delta)
		_ads_process(delta)

	_anim_arms_process()
	_anim_body_process(ctrl_port, delta)

	if shoot_cooldown > 0.0: shoot_cooldown -= delta
	if reload_time_remaining > 0.0: reload_time_remaining -= delta
	if switch_cooldown > 0.0: switch_cooldown -= delta

	_handle_walk_sound()

func _control_process():
	if health <= 0: return

	var controller_prefix = "p0"
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		controller_prefix = "p" + str(ctrl_port)

	if Input.is_action_just_pressed(controller_prefix + "_jump"):
		jump()
	if Input.is_action_just_pressed(controller_prefix + "_switch_weapon"):
		if not weapon_switching and switch_cooldown <= 0.0:
			switch_weapon.rpc()
	if Input.is_action_just_pressed(controller_prefix + "_inspect"):
		inspect_weapon.rpc()
	if Input.is_action_pressed(controller_prefix + "_shoot"):
		shoot.rpc()
	if Input.is_action_just_pressed(controller_prefix + "_reload"):
		reload.rpc()

	if Input.is_action_pressed(controller_prefix + "_sprint"):
		start_sprint()
	else:
		stop_sprint()

	if Input.is_action_pressed(controller_prefix + "_ads") and not is_sprinting:
		if current_weapon and current_weapon.weapon_type == Weapon.WEAPON_TYPES.UNARMED:
			if is_aiming:
				stop_ads()
		elif not is_aiming and not weapon_switching:
			start_ads()
	else:
		if is_aiming:
			stop_ads()

func start_sprint():
	if reloading or inspecting or is_aiming or weapon_switching or dead:
		return
	var controller_prefix = "p0"
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		controller_prefix = "p" + str(ctrl_port)
	if not Input.is_action_pressed(controller_prefix + "_walk_fw"):
		stop_sprint()
		return
	if not is_sprinting:
		is_sprinting = true

func stop_sprint():
	if is_sprinting:
		is_sprinting = false

func _ads_process(delta: float):
	camera.fov = lerp(camera.fov, target_fov, ads_transition_speed * delta)

func start_ads():
	if reloading or inspecting or dead or weapon_switching or is_sprinting:
		return
	if current_weapon and current_weapon.weapon_type == Weapon.WEAPON_TYPES.UNARMED:
		return
	is_aiming = true
	target_fov = default_fov * ads_zoom_factor
	if current_arm_rig and current_arm_rig.has_node("LVA4_Armature"):
		var armature = current_arm_rig.get_node("LVA4_Armature")
		if armature.has_method("set_p0_ads"):
			armature.set_p0_ads(true)

func stop_ads():
	is_aiming = false
	target_fov = default_fov
	if current_arm_rig and current_arm_rig.has_node("LVA4_Armature"):
		var armature = current_arm_rig.get_node("LVA4_Armature")
		if armature.has_method("set_p0_ads"):
			armature.set_p0_ads(false)

func _is_scope_visible() -> bool:
	if hud and hud.has_node("scope"):
		return hud.get_node("scope").visible
	return false

func _camera_process(delta):
	if health <= 0:
		return

	var sensitivity = camera_sensitivity
	if is_aiming:
		sensitivity *= 0.5

	var controller_prefix = "p0"
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		controller_prefix = "p" + str(ctrl_port)

	var controller_input = Vector2(
		-Input.get_axis(controller_prefix + "_cam_lf", controller_prefix + "_cam_rt"),
		Input.get_axis(controller_prefix + "_cam_dn", controller_prefix + "_cam_up")
	)

	var use_mouse = false
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		use_mouse = (ctrl_port == 0)
	else:
		use_mouse = is_multiplayer_authority()

	if use_mouse:
		var mouse_motion = Input.get_last_mouse_velocity()
		var mouse_input = Vector2(-mouse_motion.x, -mouse_motion.y) * sensitivity * 0.001
		target_look_input = mouse_input + controller_input * sensitivity
	else:
		target_look_input = controller_input * sensitivity

	look_input = lerp(look_input, target_look_input, clamp(look_smoothness * delta, 0.0, 1.0))
	rotate_y(deg_to_rad(look_input.x))

	var new_camera_rotation_x = camera.rotation.x + deg_to_rad(look_input.y)
	var min_pitch_rad = deg_to_rad(camera_min_pitch)
	var max_pitch_rad = deg_to_rad(camera_max_pitch)
	new_camera_rotation_x = clamp(new_camera_rotation_x, min_pitch_rad, max_pitch_rad)
	camera.rotation.x = new_camera_rotation_x

	if scope_sway_enabled and _is_scope_visible():
		scope_sway_time += delta * scope_sway_speed
		if scope_shot_sway_intensity > 0.0:
			scope_shot_sway_intensity = max(scope_shot_sway_intensity - delta * 8.0, 0.0)
		var current_sway_amount = scope_sway_amount + (scope_shot_sway_intensity * 0.15)
		var sway_x = sin(scope_sway_time) * current_sway_amount
		var sway_y = sin(scope_sway_time * 0.7) * current_sway_amount * 0.6
		sway_y += scope_shot_drift * 0.02
		if scope_shot_drift > 0.0:
			scope_shot_drift = max(scope_shot_drift - delta * 6.0, 0.0)
		camera.rotation.x = clamp(camera.rotation.x + deg_to_rad(sway_y), min_pitch_rad, max_pitch_rad)
		camera.rotation.y += deg_to_rad(sway_x)

func _movement_process(delta):
	var controller_prefix = "p0"
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		controller_prefix = "p" + str(ctrl_port)

	var input_dir = Input.get_vector(
		controller_prefix + "_walk_lf", controller_prefix + "_walk_rt",
		controller_prefix + "_walk_fw", controller_prefix + "_walk_bk")
	if health <= 0:
		input_dir = Vector2.ZERO

	var target_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var acceleration = accel * delta
	var deceleration = decel * delta
	var friction = deceleration if is_on_floor() else deceleration * 0.5

	if input_dir != Vector2.ZERO:
		direction = direction.lerp(target_direction, acceleration)
	else:
		direction = direction.lerp(Vector3.ZERO, friction)
	if direction.length() > 1.0:
		direction = direction.normalized()

	var true_max_speed = max_sprint_speed if is_sprinting else max_walk_speed
	if is_aiming:
		true_max_speed *= 0.6

	if input_dir != Vector2.ZERO:
		speed = move_toward(speed, true_max_speed, accel * delta)
	else:
		speed = move_toward(speed, 0.0, decel * delta)

	var gravity := velocity.y
	var world_gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * delta * gravity_multiplier
	if not is_on_floor():
		gravity -= world_gravity
	else:
		gravity = GRAVITY_COLLIDE

	velocity = direction * speed
	if not jump_queued:
		velocity.y = gravity
	else:
		velocity.y = jump_force
		jump_queued = false
	move_and_slide()

func _anim_arms_process():
	if not current_arm_rig or not is_instance_valid(current_arm_rig):
		return
	if not current_arm_rig.has_node("anim_continue"):
		return
	var continue_player: AnimationPlayer = current_arm_rig.get_node("anim_continue")
	var anim_to_play := "idle"
	var custom_blend = animation_blends.get(anim_to_play, 0.1)
	if continue_player.current_animation != anim_to_play:
		if continue_player.has_animation(anim_to_play):
			continue_player.play(anim_to_play, custom_blend, 1.0)

# Returns the two cardinal animations to blend between and the weight (0=full a, 1=full b)
# based on a 2D movement input vector
func _get_blend_anims(move_vec: Vector2) -> Array:
	# move_vec: x = strafe (-1 left, 1 right), y = forward/back (-1 back, 1 forward)
	if move_vec.length() < 0.01:
		return ["Idle", "Idle", 0.0]

	if is_sprinting:
		# Sprint only goes forward, blend left/right
		if move_vec.x < -0.1:
			# Blend Sprint -> SprintLeft if you have it, otherwise just Sprint
			return ["Sprint", "Sprint", 0.0]
		elif move_vec.x > 0.1:
			return ["Sprint", "Sprint", 0.0]
		else:
			return ["Sprint", "Sprint", 0.0]

	# Get the angle of movement (0 = forward, 90 = right, 180 = back, -90 = left)
	var angle = rad_to_deg(atan2(move_vec.x, move_vec.y))

	# Cardinal directions and their angles
	# Forward = 0, Right = 90, Back = 180/-180, Left = -90
	if angle >= -45.0 and angle < 45.0:
		# Mostly forward — blend between MoveLeft/MoveRight
		var t = inverse_lerp(-45.0, 45.0, angle)  # 0=left, 0.5=forward, 1=right
		if angle < 0.0:
			# Forward-left: blend MoveLeft (t=0) -> MoveForward (t=0.5 mapped to 1.0)
			var w = inverse_lerp(-45.0, 0.0, angle)
			return ["MoveLeft", "MoveForward", w]
		else:
			# Forward-right: blend MoveForward -> MoveRight
			var w = inverse_lerp(0.0, 45.0, angle)
			return ["MoveForward", "MoveRight", w]

	elif angle >= 45.0 and angle < 135.0:
		# Mostly right — blend between MoveForward and MoveBack
		var w = inverse_lerp(45.0, 135.0, angle)
		return ["MoveForward", "MoveBack", w] # wrong — fix below
		# Actually blend MoveRight with forward or back component
	elif angle >= 135.0 or angle < -135.0:
		# Mostly back
		var normalized = angle if angle > 0 else angle + 360.0
		if angle > 0:
			# Back-right: blend MoveRight -> MoveBack
			var w = inverse_lerp(135.0, 180.0, angle)
			return ["MoveRight", "MoveBack", w]
		else:
			# Back-left: blend MoveBack -> MoveLeft
			var w = inverse_lerp(-180.0, -135.0, angle)
			return ["MoveBack", "MoveLeft", w]
	else:
		# Mostly left (-135 to -45)
		var w = inverse_lerp(-135.0, -45.0, angle)
		return ["MoveBack", "MoveLeft", w] # fix below

	return ["Idle", "Idle", 0.0]

# Clean version of blend logic
func _get_movement_blend(move_vec: Vector2) -> Array:
	if move_vec.length() < 0.01:
		return ["Idle", "Idle", 0.0]

	if is_sprinting:
		return ["Sprint", "Sprint", 0.0]

	if is_jumping and not is_on_floor():
		return ["Jump", "Jump", 0.0]

	# angle: 0=forward, 90=right, 180=back, -90=left (in degrees)
	var angle = rad_to_deg(atan2(move_vec.x, move_vec.y))

	# Normalize to 0-360
	if angle < 0:
		angle += 360.0

	# Map angle to blend between the 4 cardinals
	# 0=Forward, 90=Right, 180=Back, 270=Left
	if angle < 90.0:
		# Forward to Right quadrant
		var w = angle / 90.0
		return ["MoveForward", "MoveRight", w]
	elif angle < 180.0:
		# Right to Back quadrant
		var w = (angle - 90.0) / 90.0
		return ["MoveRight", "MoveBack", w]
	elif angle < 270.0:
		# Back to Left quadrant
		var w = (angle - 180.0) / 90.0
		return ["MoveBack", "MoveLeft", w]
	else:
		# Left to Forward quadrant
		var w = (angle - 270.0) / 90.0
		return ["MoveLeft", "MoveForward", w]

func _anim_body_process(player_id, delta: float):
	if not body_rig or not is_instance_valid(body_rig):
		return
	if not body_rig.has_node("anim_continue"):
		return

	var continue_player: AnimationPlayer = body_rig.get_node("anim_continue")

	if dead:
		return
	if not current_weapon or not is_instance_valid(current_weapon):
		return

	var controller_prefix = "p0"
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		controller_prefix = "p%d" % player_id

	if is_multiplayer_authority():
		animation_inputs = {
			"walk_fw": Input.is_action_pressed(controller_prefix + "_walk_fw"),
			"walk_bk": Input.is_action_pressed(controller_prefix + "_walk_bk"),
			"walk_lf": Input.is_action_pressed(controller_prefix + "_walk_lf"),
			"walk_rt": Input.is_action_pressed(controller_prefix + "_walk_rt"),
			"jump": Input.is_action_pressed(controller_prefix + "_jump"),
		}

	# Handle jump separately — full override
	if is_jumping and not is_on_floor():
		if continue_player.current_animation != "Jump":
			if continue_player.has_animation("Jump"):
				continue_player.play("Jump", 0.1, 1.0)
		return
	else:
		if is_on_floor() and is_jumping:
			is_jumping = false

	# Build movement vector from inputs
	# x = strafe (negative=left, positive=right), y = forward/back (positive=forward)
	var move_x := 0.0
	var move_y := 0.0
	if animation_inputs["walk_fw"]: move_y += 1.0
	if animation_inputs["walk_bk"]: move_y -= 1.0
	if animation_inputs["walk_rt"]: move_x += 1.0
	if animation_inputs["walk_lf"]: move_x -= 1.0
	var move_vec := Vector2(move_x, move_y)

	# Get the two animations to blend and the weight
	var blend_result = _get_movement_blend(move_vec)
	var anim_a: String = blend_result[0]
	var anim_b: String = blend_result[1]
	var target_weight: float = blend_result[2]

	# If the animation pair changed, swap smoothly
	if anim_a != blend_anim_a or anim_b != blend_anim_b:
		blend_anim_a = anim_a
		blend_anim_b = anim_b
		blend_weight = target_weight

		# Start playing anim_a as the base
		if continue_player.has_animation(anim_a):
			continue_player.play(anim_a, 0.15, 1.0)
	else:
		# Smoothly lerp the blend weight toward target
		blend_weight = lerp(blend_weight, target_weight, blend_speed * delta)

	# If weight is near 0 or 1, just play the dominant animation cleanly
	if blend_weight < 0.05:
		if continue_player.current_animation != anim_a:
			if continue_player.has_animation(anim_a):
				continue_player.play(anim_a, 0.15, 1.0)
	elif blend_weight > 0.95:
		if continue_player.current_animation != anim_b:
			if continue_player.has_animation(anim_b):
				continue_player.play(anim_b, 0.15, 1.0)
	else:
		# True blend: play anim_a at full speed, queue anim_b blended on top
		# AnimationPlayer doesn't natively blend two at once, so we use
		# play_with_blend_time to crossfade based on weight
		# The cleanest approach: sync playback positions and crossfade
		if continue_player.has_animation(anim_a) and continue_player.has_animation(anim_b):
			var current = continue_player.current_animation
			if current != anim_a and current != anim_b:
				continue_player.play(anim_a, 0.15, 1.0)
			elif current == anim_a and blend_weight > 0.5:
				# Transition to b
				var anim_len = continue_player.current_animation_length
				var anim_pos = continue_player.current_animation_position
				continue_player.play(anim_b, 0.2, 1.0)
				# Sync position so feet don't pop
				if continue_player.has_animation(anim_b):
					var b_len = continue_player.get_animation(anim_b).length
					continue_player.seek(anim_pos * (b_len / max(anim_len, 0.001)), true)
			elif current == anim_b and blend_weight < 0.5:
				# Transition back to a
				var anim_len = continue_player.current_animation_length
				var anim_pos = continue_player.current_animation_position
				continue_player.play(anim_a, 0.2, 1.0)
				if continue_player.has_animation(anim_a):
					var a_len = continue_player.get_animation(anim_a).length
					continue_player.seek(anim_pos * (a_len / max(anim_len, 0.001)), true)

func jump():
	if not is_on_floor():
		return
	jump_queued = true
	is_jumping = true
	stop_sprint()

@rpc("authority", "call_local", "reliable")
func switch_weapon(update_only: bool = false) -> void:
	if weapon_switching or inspecting or switch_cooldown > 0.0:
		return
	if not current_weapon:
		print("ERROR: No current weapon!")
		return

	weapon_switching = true
	switch_cooldown = switch_cooldown_time

	if is_aiming:
		stop_ads()
	if is_sprinting:
		stop_sprint()

	if not update_only:
		if holster_sound and current_weapon and current_weapon.holster_sound:
			holster_sound.stream = current_weapon.holster_sound
			holster_sound.play()
		if current_arm_rig:
			var arms_anim: AnimationPlayer = current_arm_rig.get_node("anim_oneshot")
			if arms_anim.has_animation("holster"):
				arms_anim.play("holster", animation_blends.get("holster", 0.1), 1.0)
				await arms_anim.animation_finished
		var hold = current_weapon
		current_weapon = side_weapon
		side_weapon = hold

	if not current_weapon:
		weapon_switching = false
		return

	if current_weapon.fire_sound:
		shoot_sound.stream = current_weapon.fire_sound
	if current_weapon.reload_sound:
		reload_sound.stream = current_weapon.reload_sound

	for rig in arms_rig.get_children():
		rig.hide()

	if is_inside_tree() and skeleton:
		var right_hand_bone_idx = skeleton.find_bone("mixamorig_RightHand")
		if right_hand_bone_idx != -1:
			for child in skeleton.get_children():
				if child is BoneAttachment3D and child.bone_name == "mixamorig_RightHand":
					for weapon_mesh in child.get_children():
						if weapon_mesh.name == "muzzle_flash":
							continue
						weapon_mesh.hide()

	if not arms_rig.has_node(current_weapon.name):
		print("Error: Weapon rig not found for ", current_weapon.name)
		weapon_switching = false
		return

	current_arm_rig = arms_rig.get_node(current_weapon.name)
	_update_barrel_reference()

	var continue_anim: AnimationPlayer = current_arm_rig.get_node("anim_continue")
	var oneshot_anim: AnimationPlayer = current_arm_rig.get_node("anim_oneshot")
	continue_anim.stop()
	oneshot_anim.stop()
	oneshot_anim.seek(0, true)
	current_arm_rig.hide()

	if is_inside_tree():
		await get_tree().process_frame
		await get_tree().process_frame

	current_arm_rig.show()

	if is_inside_tree() and skeleton:
		var right_hand_bone_idx = skeleton.find_bone("mixamorig_RightHand")
		if right_hand_bone_idx != -1:
			for child in skeleton.get_children():
				if child is BoneAttachment3D and child.bone_name == "mixamorig_RightHand":
					for weapon_mesh in child.get_children():
						if weapon_mesh.name == "muzzle_flash":
							continue
						if weapon_mesh.name == current_weapon.name:
							weapon_mesh.show()
							print("Showing body weapon mesh: ", weapon_mesh.name)

	if current_arm_rig.has_node("LVA4_Armature"):
		var armature = current_arm_rig.get_node("LVA4_Armature")
		if "player_ctrl_port" in armature:
			armature.player_ctrl_port = ctrl_port
		if armature.has_method("set_p0_ads"):
			armature.set_p0_ads(true if is_aiming else false)

	if draw_sound and current_weapon.draw_sound:
		draw_sound.stream = current_weapon.draw_sound
		draw_sound.play()

	if oneshot_anim.has_animation("draw"):
		oneshot_anim.play("draw", 0.0, 1.0)
		await oneshot_anim.animation_finished

	shoot_cooldown = 0.0
	reload_time_remaining = 0.0
	reloading = false
	inspecting = false
	weapon_switching = false

	# Pose upper body for this weapon
	var upper_idle = ""
	match current_weapon.weapon_type:
		Weapon.WEAPON_TYPES.PISTOL:
			upper_idle = "PistolUpperIdle"
		Weapon.WEAPON_TYPES.RIFLE:
			upper_idle = "RifleUpperIdle"
		Weapon.WEAPON_TYPES.UNARMED:
			upper_idle = "UnarmedUpperIdle"
	play_oneshot_anim_body(upper_idle, 0.2, 1.0)

	if hud:
		hud.update_ammo()

@rpc("authority", "call_local", "reliable")
func inspect_weapon():
	if reloading or inspecting or shoot_cooldown > 0.0 or is_aiming or is_sprinting or weapon_switching:
		return
	if not current_weapon or not is_instance_valid(current_weapon):
		return

	inspecting = true
	play_oneshot_anim_arms("inspect")

	var inspect_anim = ""
	match current_weapon.weapon_type:
		Weapon.WEAPON_TYPES.PISTOL:
			inspect_anim = "PistolInspect"
		Weapon.WEAPON_TYPES.RIFLE:
			inspect_anim = "RifleInspect"
		Weapon.WEAPON_TYPES.UNARMED:
			inspect_anim = "UnarmedInspect"
	play_oneshot_anim_body(inspect_anim, 0.1, 1.0)

	var arms_anim: AnimationPlayer = current_arm_rig.get_node("anim_oneshot")
	if not arms_anim.animation_finished.is_connected(_on_inspect_finished):
		arms_anim.animation_finished.connect(_on_inspect_finished, CONNECT_ONE_SHOT)

func _on_inspect_finished(anim_name: StringName):
	if anim_name == "inspect":
		inspecting = false
		var upper_idle = ""
		match current_weapon.weapon_type:
			Weapon.WEAPON_TYPES.PISTOL:
				upper_idle = "PistolUpperIdle"
			Weapon.WEAPON_TYPES.RIFLE:
				upper_idle = "RifleUpperIdle"
			Weapon.WEAPON_TYPES.UNARMED:
				upper_idle = "UnarmedUpperIdle"
		play_oneshot_anim_body(upper_idle, 0.2, 1.0)

@rpc("authority", "call_local", "reliable")
func reload():
	if shoot_cooldown > 0.0:
		return
	if reload_time_remaining > 0.0:
		return
	if not current_weapon or not is_instance_valid(current_weapon):
		return
	if current_weapon.weapon_type == Weapon.WEAPON_TYPES.UNARMED:
		return
	if current_weapon.current_ammo >= current_weapon.max_ammo:
		return
	if inspecting or is_aiming or is_sprinting or weapon_switching:
		return

	var weapon_key = _get_weapon_key(current_weapon)
	if ammo.get(weapon_key, 0) <= 0:
		return

	reloading = true

	if current_arm_rig and current_arm_rig.has_node("LVA4_Armature"):
		var armature = current_arm_rig.get_node("LVA4_Armature")
		if armature.has_method("set_p1_ads"):
			armature.set_p1_ads(true)

	if reload_sound and reload_sound.stream:
		var new_reload_sound = reload_sound.duplicate()
		add_child(new_reload_sound)
		new_reload_sound.play()
		new_reload_sound.finished.connect(new_reload_sound.queue_free)

	var extra_ammo = ammo[weapon_key]
	if extra_ammo <= 0:
		return
	if current_weapon.max_ammo <= extra_ammo:
		extra_ammo -= (current_weapon.max_ammo - current_weapon.current_ammo)
		current_weapon.current_ammo = current_weapon.max_ammo
	else:
		current_weapon.current_ammo += extra_ammo
		extra_ammo = 0
		if current_weapon.current_ammo > current_weapon.max_ammo:
			extra_ammo = current_weapon.current_ammo - current_weapon.max_ammo
			current_weapon.current_ammo = current_weapon.max_ammo
	ammo[weapon_key] = extra_ammo

	play_oneshot_anim_arms("reload")

	var arms_anim: AnimationPlayer = current_arm_rig.get_node("anim_oneshot")
	if not arms_anim.animation_finished.is_connected(_on_reload_finished):
		arms_anim.animation_finished.connect(_on_reload_finished, CONNECT_ONE_SHOT)

	var reload_anim = ""
	match current_weapon.weapon_type:
		Weapon.WEAPON_TYPES.PISTOL:
			reload_anim = "PistolReload"
		Weapon.WEAPON_TYPES.RIFLE:
			reload_anim = "RifleReload"
	play_oneshot_anim_body(reload_anim, 0.1, 1.0)

	if hud:
		hud.update_ammo()
	reload_time_remaining = current_weapon.reload_time

func _on_reload_finished(anim_name: StringName):
	if anim_name == "reload":
		reloading = false
		if current_arm_rig and current_arm_rig.has_node("LVA4_Armature"):
			var armature = current_arm_rig.get_node("LVA4_Armature")
			if armature.has_method("set_p1_ads"):
				armature.set_p1_ads(false)
			if armature.has_method("set_p0_ads"):
				armature.set_p0_ads(true if is_aiming else false)
		var upper_idle = ""
		match current_weapon.weapon_type:
			Weapon.WEAPON_TYPES.PISTOL:
				upper_idle = "PistolUpperIdle"
			Weapon.WEAPON_TYPES.RIFLE:
				upper_idle = "RifleUpperIdle"
			Weapon.WEAPON_TYPES.UNARMED:
				upper_idle = "UnarmedUpperIdle"
		play_oneshot_anim_body(upper_idle, 0.2, 1.0)

@rpc("authority", "call_local", "reliable")
func shoot():
	if shoot_cooldown > 0.0:
		return
	if reload_time_remaining > 0.0:
		return
	if reloading or inspecting or is_sprinting or weapon_switching:
		return
	if not current_weapon or not is_instance_valid(current_weapon):
		print("ERROR: No current weapon!")
		return

	if current_weapon.weapon_type == Weapon.WEAPON_TYPES.UNARMED:
		melee.rpc()
		return

	if current_weapon.current_ammo <= 0:
		reload()
		return
	if not barrel:
		print("Error: Barrel node not found! Cannot shoot.")
		return

	if shoot_sound and shoot_sound.stream:
		var new_shoot_sound = shoot_sound.duplicate()
		add_child(new_shoot_sound)
		new_shoot_sound.pitch_scale = randf_range(0.99, 1.00)
		new_shoot_sound.play()
		new_shoot_sound.finished.connect(new_shoot_sound.queue_free)

	var bullet = current_weapon.bullet_tscn.instantiate()
	bullet.user = self
	get_parent().add_child(bullet)
	bullet.global_transform = barrel.global_transform
	bullet.connect("bullet_hit", move_tracer)

	play_oneshot_anim_arms_force("fire_idle")
	activate_muzzle_flash()

	if current_arm_rig and current_arm_rig.has_node("LVA4_Armature"):
		var armature = current_arm_rig.get_node("LVA4_Armature")
		if armature.has_method("apply_recoil"):
			armature.apply_recoil()

	shoot_cooldown = current_weapon.cooldown
	current_weapon.current_ammo -= 1
	if hud:
		hud.update_ammo()
		hud.flash_shoot_indicator()

	if _is_scope_visible():
		scope_shot_sway_intensity = 1.0
		scope_shot_drift += 3.9

@rpc("authority", "call_local", "reliable")
func melee():
	if shoot_cooldown > 0.0 or reloading or inspecting or weapon_switching or dead:
		return
	if not current_weapon or not is_instance_valid(current_weapon):
		return
	if current_weapon.weapon_type != Weapon.WEAPON_TYPES.UNARMED:
		return

	shoot_cooldown = current_weapon.cooldown

	if shoot_sound and shoot_sound.stream:
		var new_shoot_sound = shoot_sound.duplicate()
		add_child(new_shoot_sound)
		new_shoot_sound.pitch_scale = randf_range(0.95, 1.05)
		new_shoot_sound.play()
		new_shoot_sound.finished.connect(new_shoot_sound.queue_free)

	play_oneshot_anim_arms_force("fire_idle")
	play_oneshot_anim_body("UnarmedUpperPunch", 0.1, 1.0)

	if hud:
		hud.flash_shoot_indicator()

	var space = get_world_3d().direct_space_state
	var from = camera.global_position
	var to = from + (-camera.global_transform.basis.z * 0.5)
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	var result = space.intersect_ray(query)
	if result and result.collider is Player:
		result.collider.take_damage.rpc_id(
			result.collider.get_multiplayer_authority(),
			25, "body", get_path(), result.position
		)

func play_oneshot_anim_arms_force(anim_name: String, custom_blend: float = -1.0, custom_speed: float = 1.0, from_end: bool = false):
	if not current_arm_rig or not is_instance_valid(current_arm_rig):
		return
	var arms_anim: AnimationPlayer = current_arm_rig.get_node("anim_oneshot")
	if not arms_anim.has_animation(anim_name):
		return
	if custom_blend == -1.0 and anim_name in animation_blends:
		custom_blend = animation_blends[anim_name]
	elif custom_blend == -1.0:
		custom_blend = 0.1
	arms_anim.stop()
	arms_anim.play(anim_name, custom_blend, custom_speed, from_end)

func move_tracer(hit_position: Vector3):
	if tracer_scene == null:
		print("Error: Tracer scene not assigned!")
		return
	if not barrel:
		print("Error: Barrel node not found! Cannot create tracer.")
		return

	var tracer = tracer_scene.instantiate()
	get_parent().add_child(tracer)
	tracer.global_transform = barrel.global_transform
	tracer.visible = true
	tracer.global_transform = Transform3D(barrel.global_transform.basis, barrel.global_transform.origin)

	var tracer_speed = 65.0
	var distance = barrel.global_transform.origin.distance_to(hit_position)
	var travel_time = distance / tracer_speed

	var tween = create_tween()
	tween.tween_property(tracer, "global_transform:origin", hit_position, travel_time)\
		.set_trans(Tween.TRANS_LINEAR)\
		.set_ease(Tween.EASE_IN_OUT)

	await get_tree().create_timer(travel_time).timeout
	tracer.queue_free()

@rpc("any_peer", "call_local", "reliable")
func take_damage(damage: int, type: String, enemy_source_path: NodePath, hit_position: Vector3):
	if dead or health <= 0:
		return
	var enemy_source := get_node_or_null(enemy_source_path)
	if enemy_source == null:
		return
	if enemy_source and enemy_source.has_method("get_multiplayer_authority"):
		if enemy_source.get_multiplayer_authority() != multiplayer.get_remote_sender_id():
			return
	health -= damage
	if hud:
		hud.hp_target = health
		hud.flash_damage_indicator()
	sync_health.rpc(health)
	if has_node("take_damage_sound"):
		var sound = $take_damage_sound.duplicate()
		add_child(sound)
		sound.pitch_scale = 1.0 + randf_range(-0.1, 0.1)
		sound.play()
		sound.finished.connect(sound.queue_free)
	_camera_flinch()
	var hit_indicator_scene = preload("res://assets/pfx/bloodspatter/blood_spatter.tscn")
	var hit_indicator = hit_indicator_scene.instantiate()
	get_parent().add_child(hit_indicator)
	var direction_to_enemy = (enemy_source.global_position - hit_position).normalized()
	hit_indicator.global_position = hit_position
	hit_indicator.look_at(hit_position + direction_to_enemy, Vector3.UP)
	if health <= 0:
		die.rpc(0, enemy_source_path)
	match type:
		"head":
			print("Headshot!")
		"body":
			print("Body shot.")
		"legs":
			print("Leg shot.")

func _camera_flinch():
	var flinch_strength = 0.05
	var flinch_x = randf_range(-flinch_strength, flinch_strength)
	var flinch_y = randf_range(-flinch_strength, flinch_strength)
	camera.rotation.x += flinch_x
	camera.rotation.y += flinch_y
	var tween = get_tree().create_tween()
	tween.tween_property(camera, "rotation:x", camera.rotation.x - flinch_x, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "rotation:y", camera.rotation.y - flinch_y, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

@rpc("any_peer", "call_local", "reliable")
func die(_func_stage := 0, enemy_source_path := ""):
	match _func_stage:
		0:
			if dead:
				return
			dead = true

			reloading = false
			inspecting = false
			weapon_switching = false
			is_sprinting = false
			if is_aiming:
				stop_ads()

			if current_arm_rig and current_arm_rig.has_node("LVA4_Armature"):
				var armature = current_arm_rig.get_node("LVA4_Armature")
				if armature.has_method("set_p0_ads"):
					armature.set_p0_ads(false)

			body_anim_oneshot.stop()
			body_anim_continue.stop()

			if body_anim_oneshot.has_animation("Death"):
				play_oneshot_anim_body("Death")

			$die_anim.play("die")

			collision_layer = 0
			collision_mask = 2

			var enemy_source := get_node_or_null(enemy_source_path)
			if enemy_source is Player:
				enemy_that_killed = enemy_source
				enemy_source.score_point(1)
			else:
				enemy_that_killed = null
				score_point(-1)

		1:
			await get_tree().create_timer(3.0).timeout

			$die_anim.stop()
			$die_anim.play("RESET")

			health = max_health
			if hud:
				hud.hp_target = max_health
			collision_layer = 1
			collision_mask = 2 | 3
			enemy_that_killed = null

			if current_weapon:
				var weapon_key = _get_weapon_key(current_weapon)
				current_weapon.current_ammo = current_weapon.max_ammo
				ammo[weapon_key] = current_weapon.max_ammo * ammo_default_multiplier
			if side_weapon:
				var weapon_key = _get_weapon_key(side_weapon)
				side_weapon.current_ammo = side_weapon.max_ammo
				ammo[weapon_key] = side_weapon.max_ammo * ammo_default_multiplier

			shoot_cooldown = 0.0
			reload_time_remaining = 0.0
			reloading = false
			inspecting = false
			weapon_switching = false

			Game.world.respawn(self)
			await get_tree().process_frame

			dead = false

			var upper_idle = ""
			match current_weapon.weapon_type:
				Weapon.WEAPON_TYPES.PISTOL:
					upper_idle = "PistolUpperIdle"
				Weapon.WEAPON_TYPES.RIFLE:
					upper_idle = "RifleUpperIdle"
				Weapon.WEAPON_TYPES.UNARMED:
					upper_idle = "UnarmedUpperIdle"
			play_oneshot_anim_body(upper_idle, 0.2, 1.0)

			if hud:
				hud.update_ammo()
				hud.update_score()

func _on_death_anim_done(anim: StringName, _func_stage):
	if not "Death" in anim: return
	if not dead: return
	die(_func_stage)

func score_point(score_change):
	current_score += score_change
	if hud:
		hud.update_score()
	if current_score >= Game.world.target_score:
		Game.world.end_game(self)

func play_oneshot_anim_arms(anim_name: String, custom_blend: float = -1.0, custom_speed: float = 1.0, from_end: bool = false):
	if not current_arm_rig or not is_instance_valid(current_arm_rig):
		return
	var arms_anim: AnimationPlayer = current_arm_rig.get_node("anim_oneshot")
	if not arms_anim.has_animation(anim_name):
		return
	if custom_blend == -1.0 and anim_name in animation_blends:
		custom_blend = animation_blends[anim_name]
	elif custom_blend == -1.0:
		custom_blend = 0.1
	arms_anim.play(anim_name, custom_blend, custom_speed, from_end)

func play_oneshot_anim_body(anim_name: String, custom_blend: float = -1.0, custom_speed: float = 1.0, from_end: bool = false):
	if not body_rig or not is_instance_valid(body_rig):
		return
	var body_anim: AnimationPlayer = body_rig.get_node("anim_oneshot")
	if not body_anim.has_animation(anim_name):
		return
	if custom_blend == -1.0:
		custom_blend = 0.1
	body_anim.play(anim_name, custom_blend, custom_speed, from_end)

func _set_arm_vis_recursive(parent):
	if parent is VisualInstance3D:
		parent.layers = 0
		parent.set_layer_mask_value(view_layer, true)
	if parent.get_child_count() > 0:
		for child in parent.get_children():
			_set_arm_vis_recursive(child)

func _set_body_vis_recursive(parent, is_body_node = false):
	if parent.name == "body":
		is_body_node = true
	if parent is VisualInstance3D:
		parent.layers = 30
		parent.set_layer_mask_value(view_layer, false)
		if is_body_node and parent is GeometryInstance3D:
			parent.visibility_range_end = 0.0
			parent.visibility_range_end_margin = 0.0
			parent.ignore_occlusion_culling = true
			parent.extra_cull_margin = 16384.0
	if parent.get_child_count() > 0:
		for child in parent.get_children():
			_set_body_vis_recursive(child, is_body_node)

@export var player_muzzle_flash: NodePath

func _set_muzzle_flash_vis_recursive(parent):
	if parent is VisualInstance3D:
		parent.layers = 16
		parent.set_layer_mask_value(view_layer, false)
	for child in parent.get_children():
		_set_muzzle_flash_vis_recursive(child)

var last_muzzle_rotation := -999.0
var muzzle_rotation_repeat_count := 0
var active_muzzle_flashes := 0  # Track how many flash coroutines are active

func activate_muzzle_flash():
	var is_scoped_ads = false
	if current_arm_rig and current_arm_rig.has_node("LVA4_Armature"):
		var armature = current_arm_rig.get_node("LVA4_Armature")
		if "is_sniper" in armature and "is_ads" in armature:
			is_scoped_ads = armature.is_sniper and armature.is_ads

	# Always show before hiding previous frame's flash
	if not is_scoped_ads and current_arm_rig and current_arm_rig.has_node("LVA4_Armature/muzzle_flash"):
		_activate_muzzle_meshes(current_arm_rig.get_node("LVA4_Armature/muzzle_flash"))

	if has_node(player_muzzle_flash):
		_activate_muzzle_meshes(get_node(player_muzzle_flash))

	# Increment counter and start hide timer
	active_muzzle_flashes += 1
	var flash_id = active_muzzle_flashes
	
	await get_tree().create_timer(0.08).timeout
	
	# Only hide if this is still the most recent flash
	if flash_id == active_muzzle_flashes:
		if not is_scoped_ads and current_arm_rig and current_arm_rig.has_node("LVA4_Armature/muzzle_flash"):
			_deactivate_muzzle_meshes(current_arm_rig.get_node("LVA4_Armature/muzzle_flash"))

		if has_node(player_muzzle_flash):
			_deactivate_muzzle_meshes(get_node(player_muzzle_flash))

func _activate_muzzle_meshes(flash_node: Node3D):
	_activate_meshes_recursive(flash_node)
	if flash_node.has_node("omni_light"):
		flash_node.get_node("omni_light").visible = true

func _activate_meshes_recursive(node: Node):
	if node is MeshInstance3D:
		node.visible = true
		if node.name == "MuzzleCone":
			node.rotation.z = deg_to_rad(_get_next_muzzle_rotation())
	for child in node.get_children():
		_activate_meshes_recursive(child)

func _deactivate_muzzle_meshes(flash_node: Node3D):
	_deactivate_meshes_recursive(flash_node)
	if flash_node.has_node("omni_light"):
		flash_node.get_node("omni_light").visible = false

func _deactivate_meshes_recursive(node: Node):
	if node is MeshInstance3D:
		node.visible = false
	for child in node.get_children():
		_deactivate_meshes_recursive(child)

func _get_next_muzzle_rotation() -> float:
	var possible_rotations = [0.0, 90.0, 180.0, 270.0]
	if muzzle_rotation_repeat_count >= 2:
		possible_rotations.erase(last_muzzle_rotation)
		muzzle_rotation_repeat_count = 0
	var new_rotation = possible_rotations[randi() % possible_rotations.size()]
	if new_rotation == last_muzzle_rotation:
		muzzle_rotation_repeat_count += 1
	else:
		muzzle_rotation_repeat_count = 1
	last_muzzle_rotation = new_rotation
	return new_rotation

var target_bob_offset := 0.0
var current_bob_offset := 0.0

func _handle_arms_bob(delta: float) -> void:
	if not arms_rig:
		return
	if speed > 0.1 and is_on_floor():
		var bob_speed_multiplier = 1.5 if is_sprinting else 1.0
		arm_bob_time += delta * bob_speed * bob_speed_multiplier
		target_bob_offset = sin(arm_bob_time) * bob_amount
		if is_aiming:
			target_bob_offset *= 0.3
		elif is_sprinting:
			target_bob_offset *= 1.3
	else:
		target_bob_offset = 0.0
	current_bob_offset = lerp(current_bob_offset, target_bob_offset, delta * 8.0)
	arms_rig.transform.origin.y = current_bob_offset

func _handle_walk_sound():
	if not walk_sound:
		return
	if speed > 0.0 and is_on_floor():
		if not walk_sound.playing:
			walk_sound.play()
		var speed_ratio = clamp(speed / max_walk_speed, 1.0, 5.5)
		walk_sound.pitch_scale = speed_ratio * 1.15 if is_sprinting else speed_ratio
	else:
		walk_sound.stop()

## Spine Bend with Camera ##
@onready var spine = $spine
@onready var look_object = $"camera/look_object"
@onready var skeleton = $body/body_rig/Armature/Skeleton3D
var new_rotation
var max_horizontal_angle = 5
var max_vertical_angle = 45
var bonesmoothrot = 0.0

func look_at_object(delta):
	if not skeleton:
		return
	var spine_bone = skeleton.find_bone("mixamorig_Spine")
	if spine_bone == -1:
		print("Spine bone not found!")
		return
	look_object.global_position = camera.global_position + camera.global_transform.basis.z * -2.0
	spine.look_at(look_object.global_position, Vector3.UP, true)
	var spine_rotation_degrees = spine.rotation_degrees
	spine_rotation_degrees.x = clamp(spine_rotation_degrees.x, -max_vertical_angle, max_vertical_angle)
	spine_rotation_degrees.y = clamp(spine_rotation_degrees.y, -max_horizontal_angle, max_horizontal_angle)
	bonesmoothrot = lerp_angle(bonesmoothrot, deg_to_rad(spine_rotation_degrees.x), 8 * delta)
	var downward_offset = deg_to_rad(7.0)
	var new_rotation = Quaternion.from_euler(Vector3(bonesmoothrot + downward_offset, 0, 0))
	var current_pose = skeleton.get_bone_global_pose(spine_bone)
	current_pose.basis = Basis(new_rotation) * current_pose.basis.orthonormalized()
	skeleton.set_bone_global_pose_override(spine_bone, current_pose, 0.5, true)

@rpc("any_peer", "call_remote", "unreliable")
func sync_health(value: int):
	if not is_multiplayer_authority():
		health = value
		if hud:
			hud.hp_target = value

func _process(delta: float) -> void:
	look_at_object(delta)
	_handle_arms_bob(delta)

func _get_weapon_key(weapon: Weapon) -> String:
	if weapon.resource_name and not weapon.resource_name.is_empty():
		return weapon.resource_name
	else:
		return weapon.resource_path.get_file().get_basename()

func _apply_loadout(loadout: Dictionary) -> void:
	if loadout.has("primary") and loadout["primary"]:
		current_weapon = loadout["primary"].duplicate(true)
		print("Loaded primary weapon: ", _get_weapon_key(current_weapon))
	if loadout.has("secondary") and loadout["secondary"]:
		side_weapon = loadout["secondary"].duplicate(true)
		print("Loaded secondary weapon: ", _get_weapon_key(side_weapon))
