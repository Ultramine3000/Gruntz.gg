extends Control

## NODES ##
@onready var health_bar := $health/bar
@onready var points_label := $points
@onready var reticle := $reticle
@onready var ammo_counter := $ammo/counter
@onready var ammo_extra := $ammo/extra
@onready var ammo_icon_template := $ammo/counter/_template
@onready var shoot_indicator := $shoot_indicator
@onready var damage_indicator := $damage_indicator

## PAUSE MENU NODES (ADD THESE TO YOUR SCENE) ##
@onready var pause_container := $pause_container
@onready var resume_button := $pause_container/VBoxContainer/resume_button
@onready var settings_button := $pause_container/VBoxContainer/settings_button
@onready var quit_button := $pause_container/VBoxContainer/quit_button

## HEALTH ##
var hp_target = 100
const HP_LERP_RATE = 0.1
const HP_LERP_MARGIN = 2

## AMMO ##
var full_color: Color = Color.WHITE
var empty_color: Color = Color.BLACK
var current_weapon_name := ""

## SHOOT INDICATOR ##
var shoot_indicator_alpha := 0.0
var shoot_indicator_fade_timer := 0.0

## DAMAGE VIGNETTE ##
var heartbeat_time := 0.0
var base_vignette_alpha := 0.0
var target_vignette_alpha := 0.0
var flash_vignette_alpha := 0.0

## PAUSE MENU ##
var is_paused := false
var player_id := 0  # 0 or 1
var current_button_index := 0
var buttons: Array[Button] = []

# Input action names (will be set based on player_id)
var pause_action := "p0_pause"
var up_action := "ui_up"
var down_action := "ui_down"
var select_action := "ui_accept"

func _ready() -> void:
	ammo_counter.remove_child(ammo_icon_template)
	damage_indicator.modulate.a = 0.0
	shoot_indicator.modulate.a = 0.0
	
	print("HUD Ready - Player ID: ", player_id, " Pause Action: ", pause_action)
	
	# Setup pause menu if nodes exist
	if pause_container:
		pause_container.visible = false
		
		# Collect buttons
		buttons = [resume_button, settings_button, quit_button]
		
		# Connect button signals
		resume_button.pressed.connect(_on_resume_pressed)
		settings_button.pressed.connect(_on_settings_pressed)
		quit_button.pressed.connect(_on_quit_pressed)
		
		# Make buttons focusable for controller
		for button in buttons:
			button.focus_mode = Control.FOCUS_ALL
	else:
		print("WARNING: pause_container not found!")

func set_player_id(id: int) -> void:
	"""Call this from your player script to set which player owns this HUD"""
	player_id = id
	print("Setting HUD player_id to: ", id)
	if id == 0:
		pause_action = "p0_pause"
		up_action = "ui_up"
		down_action = "ui_down"
		select_action = "ui_accept"
	else:
		pause_action = "p1_pause"
		up_action = "ui_up"
		down_action = "ui_down"
		select_action = "ui_accept"
	print("Pause action set to: ", pause_action)

func _input(event: InputEvent) -> void:
	# Check if this is the pause action for this player
	if event.is_action_pressed(pause_action):
		print("Player ", player_id, " detected pause action: ", pause_action, " from device: ", event.device)
		# Make sure it's from the correct device
		# Device 0 = gamepad 1 (player 0), Device 1 = gamepad 2 (player 1)
		if event.device == player_id or event.device == -1:  # -1 is keyboard
			print("Device matches! Toggling pause for player ", player_id)
			toggle_pause()
			get_viewport().set_input_as_handled()
		else:
			print("Device mismatch - ignoring (expected device ", player_id, " got ", event.device, ")")
	
	# Handle d-pad navigation when paused (only for this player)
	if is_paused and pause_container:
		if event.device == player_id or event.device == -1:
			if event.is_action_pressed(up_action):
				navigate_up()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed(down_action):
				navigate_down()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed(select_action):
				activate_current_button()
				get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	# Skip gameplay updates when paused
	if is_paused:
		return
	
	# Health
	if abs(hp_target - health_bar.value) > HP_LERP_MARGIN:
		health_bar.value = lerp(health_bar.value, float(hp_target), HP_LERP_RATE)
	else:
		health_bar.value = hp_target
	
	# Shoot indicator fade
	if shoot_indicator_fade_timer > 0.0:
		shoot_indicator_fade_timer -= delta
	elif shoot_indicator_alpha > 0.0:
		shoot_indicator_alpha = max(shoot_indicator_alpha - delta * 2.5, 0.0)
		shoot_indicator.modulate.a = shoot_indicator_alpha
	
	# Update damage vignette with heartbeat effect
	_update_damage_vignette(delta)

func _update_damage_vignette(delta: float):
	var player = get_parent()
	if not player or not player.has_method("get"):
		return
	
	# Calculate health percentage
	var health_percent = float(player.health) / float(player.max_health)
	
	# Calculate base vignette alpha based on missing health
	if health_percent > 0.7:
		target_vignette_alpha = 0.0  # No vignette above 70% health
	elif health_percent > 0.4:
		# Subtle vignette between 40-70% health
		target_vignette_alpha = (0.7 - health_percent) * 0.7  # Scales from 0 to ~0.21
	else:
		# Strong vignette below 40% health
		target_vignette_alpha = 0.25 + (0.4 - health_percent) * 1.2  # Scales from 0.25 to ~0.73
	
	# Smooth transition to target alpha
	base_vignette_alpha = lerp(base_vignette_alpha, target_vignette_alpha, delta * 3.0)
	
	# Add heartbeat pulse effect when health is low
	var pulse_intensity = 0.0
	if health_percent < 0.4:
		# Heartbeat gets faster and stronger as health decreases
		var heartbeat_speed = 1.8 + (0.4 - health_percent) * 4.0  # Speed: 1.8 to 3.4 Hz
		heartbeat_time += delta * heartbeat_speed
		
		# Create double-pulse heartbeat pattern (thump-thump)
		var beat1 = sin(heartbeat_time * PI)
		var beat2 = sin((heartbeat_time * PI) + PI * 0.5) * 0.4  # Secondary beat offset
		var combined_beat = max(0.0, beat1) + max(0.0, beat2)
		
		# Pulse intensity increases as health drops
		pulse_intensity = combined_beat * 0.15 * (0.4 - health_percent) * 3.0
	
	# Fade out flash effect
	if flash_vignette_alpha > 0.0:
		flash_vignette_alpha = max(flash_vignette_alpha - delta * 2.0, 0.0)
	
	# Apply combined alpha (base + pulse + flash)
	var final_alpha = clamp(base_vignette_alpha + pulse_intensity + flash_vignette_alpha, 0.0, 0.85)
	damage_indicator.modulate.a = final_alpha

## PAUSE MENU FUNCTIONS ##
func toggle_pause() -> void:
	is_paused = not is_paused
	
	if pause_container:
		pause_container.visible = is_paused
	
	if is_paused:
		# Don't pause the tree - just set the flag
		# Your player script should check get_parent().hud.is_paused
		current_button_index = 0
		update_button_focus()
		
		# Optionally hide reticle when paused
		if reticle:
			reticle.visible = false
	else:
		# Show reticle when unpaused
		if reticle:
			reticle.visible = true

func navigate_up() -> void:
	current_button_index -= 1
	if current_button_index < 0:
		current_button_index = buttons.size() - 1
	update_button_focus()

func navigate_down() -> void:
	current_button_index += 1
	if current_button_index >= buttons.size():
		current_button_index = 0
	update_button_focus()

func update_button_focus() -> void:
	for i in range(buttons.size()):
		if i == current_button_index:
			buttons[i].grab_focus()
		else:
			buttons[i].release_focus()

func activate_current_button() -> void:
	if current_button_index >= 0 and current_button_index < buttons.size():
		buttons[current_button_index].emit_signal("pressed")

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_settings_pressed() -> void:
	print("Settings pressed for Player ", player_id)
	# Add your settings logic here

func _on_quit_pressed() -> void:
	print("Quit pressed")
	get_tree().quit()

## EXISTING HUD FUNCTIONS ##
func update_ammo():
	var weapon: Weapon = get_parent().current_weapon
	var weapon_name = weapon.resource_name if (weapon.resource_name and not weapon.resource_name.is_empty()) else weapon.resource_path.get_file().get_basename()
	
	if not current_weapon_name == weapon_name:
		# Switching weapons: clear icons
		for bullet in ammo_counter.get_children():
			bullet.name += "F"
			bullet.queue_free()
		for index in range(0, weapon.max_ammo):
			var bullet = ammo_icon_template.duplicate()
			bullet.name = str(index + 1)
			bullet.texture = weapon.ammo_icon
			ammo_counter.add_child(bullet)
		current_weapon_name = weapon_name
	
	# Update current ammo icons
	for bullet in ammo_counter.get_children():
		var curr_count = bullet.name.to_int()
		bullet.modulate = empty_color
		if curr_count <= weapon.current_ammo:
			bullet.modulate = full_color
	
	var weapon_key = weapon.resource_name if (weapon.resource_name and not weapon.resource_name.is_empty()) else weapon.resource_path.get_file().get_basename()
	ammo_extra.text = str(get_parent().ammo.get(weapon_key, 0))

func update_score():
	points_label.text = str(get_parent().current_score)

func fade_reticle(show: bool) -> void:
	var target_alpha = 1.0 if show else 0.0
	var tween = create_tween()
	tween.tween_property(reticle, "modulate:a", target_alpha, 0.2)

func flash_damage_indicator():
	flash_vignette_alpha = 0.5

func flash_shoot_indicator():
	shoot_indicator_alpha = 0.4
	shoot_indicator_fade_timer = 0.25
	shoot_indicator.modulate.a = shoot_indicator_alpha
