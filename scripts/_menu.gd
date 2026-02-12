extends Control

# Menu states
enum MenuState {
	MAIN_MENU,
	MATCH_SETUP,
	MULTIPLAYER_LOBBY
}

var current_state := MenuState.MAIN_MENU

# Core game settings
var selected_map := "map_pit"
var selected_points := 10
var available_maps := ["map_pit", "Map2", "Map3"]
var current_map_index := 0

# Loadout system
@export var available_primary_weapons: Array[Weapon] = []
@export var available_secondary_weapons: Array[Weapon] = []

var p0_loadout := {
	"primary": null,
	"secondary": null
}

var p1_loadout := {
	"primary": null,
	"secondary": null
}

var current_p0_primary_index := 0
var current_p0_secondary_index := 0
var current_p1_primary_index := 0
var current_p1_secondary_index := 0

# Weapon name arrays for display
var primary_weapon_names: Array[String] = []
var secondary_weapon_names: Array[String] = []

# Controller detection textures
@export var controller_detected_texture: Texture2D
@export var controller_not_detected_texture: Texture2D

# UI containers
var main_menu_container: VBoxContainer
var match_setup_container: Control
var multiplayer_lobby_container: Control

# Controller status displays
var p0_controller_icon: TextureRect
var p1_controller_icon: TextureRect

# Focusable items array for navigation (buttons + selectors)
var current_focusable_items: Array = []
var current_focus_index := 0

# All selectors storage
var _all_selectors: Array[FocusableSelector] = []

# Custom focusable item class
class FocusableSelector:
	var container: HBoxContainer
	var value_label: Label
	var left_arrow: Label
	var right_arrow: Label
	var focus_indicator: Label  # NEW: Green arrow
	var on_left: Callable
	var on_right: Callable
	var is_focused := false

func _ready() -> void:
	# Initialize weapon lists from exported arrays
	_initialize_weapon_lists()
	
	# Fill the screen
	anchor_right = 1.0
	anchor_bottom = 1.0
	
	# Setup multiplayer signals
	multiplayer.server_disconnected.connect(_on_lobby_disconnected)
	
	if is_instance_valid(Multiplayer):
		Multiplayer.room_code_updated.connect(_on_room_code_updated)
		Multiplayer.player_ids_updated.connect(_on_lobby_connected)
	
	if is_instance_valid(Game):
		Game.game_starting.connect(func(): queue_free())
	
	# Build all menus
	_build_main_menu()
	_build_match_setup()
	_build_multiplayer_lobby()
	
	# Start at main menu
	_switch_to_state(MenuState.MAIN_MENU)

func _initialize_weapon_lists() -> void:
	# Build name arrays from weapon resources
	primary_weapon_names.clear()
	secondary_weapon_names.clear()
	
	for weapon in available_primary_weapons:
		if weapon:
			# Use resource_name if available, otherwise use resource_path filename
			var display_name = weapon.resource_name if weapon.resource_name else weapon.resource_path.get_file().get_basename()
			primary_weapon_names.append(display_name)
	
	for weapon in available_secondary_weapons:
		if weapon:
			# Use resource_name if available, otherwise use resource_path filename
			var display_name = weapon.resource_name if weapon.resource_name else weapon.resource_path.get_file().get_basename()
			secondary_weapon_names.append(display_name)
	
	# Set default loadouts to first weapons
	if not available_primary_weapons.is_empty():
		p0_loadout["primary"] = available_primary_weapons[0]
		p1_loadout["primary"] = available_primary_weapons[0]
	
	if not available_secondary_weapons.is_empty():
		p0_loadout["secondary"] = available_secondary_weapons[0]
		p1_loadout["secondary"] = available_secondary_weapons[0]

func _process(_delta: float) -> void:
	# Update controller detection
	if current_state == MenuState.MATCH_SETUP:
		_update_controller_status()

func _update_controller_status() -> void:
	if not p0_controller_icon or not p1_controller_icon:
		return
	
	# Check if controllers are connected
	var p0_connected = Input.get_connected_joypads().has(0)
	var p1_connected = Input.get_connected_joypads().has(1)
	
	# Update textures
	if controller_detected_texture and controller_not_detected_texture:
		p0_controller_icon.texture = controller_detected_texture if p0_connected else controller_not_detected_texture
		p1_controller_icon.texture = controller_detected_texture if p1_connected else controller_not_detected_texture

func _input(event: InputEvent) -> void:
	if current_focusable_items.is_empty():
		return
	
	# Navigate with D-pad/analog stick/arrow keys
	if event.is_action_pressed("ui_down"):
		_navigate_menu(1)
		accept_event()
	elif event.is_action_pressed("ui_up"):
		_navigate_menu(-1)
		accept_event()
	
	# Handle left/right for selectors
	elif event.is_action_pressed("ui_left"):
		var item = current_focusable_items[current_focus_index]
		if item is FocusableSelector:
			item.on_left.call()
		accept_event()
	elif event.is_action_pressed("ui_right"):
		var item = current_focusable_items[current_focus_index]
		if item is FocusableSelector:
			item.on_right.call()
		accept_event()
	
	# Select with A button (joy_button_0) or Enter
	elif event.is_action_pressed("ui_accept"):
		var item = current_focusable_items[current_focus_index]
		if item is Button:
			item.emit_signal("pressed")
		accept_event()

func _navigate_menu(direction: int) -> void:
	if current_focusable_items.is_empty():
		return
	
	# Update index
	current_focus_index += direction
	
	# Wrap around at boundaries
	if current_focus_index < 0:
		current_focus_index = current_focusable_items.size() - 1
	elif current_focus_index >= current_focusable_items.size():
		current_focus_index = 0
	
	_update_focus()

func _update_focus() -> void:
	for i in current_focusable_items.size():
		var item = current_focusable_items[i]
		var is_focused = (i == current_focus_index)
		
		if item is Button:
			if is_focused:
				item.grab_focus()
			_highlight_button(item, is_focused)
		elif item is FocusableSelector:
			_highlight_selector(item, is_focused)

func _highlight_button(btn: Button, highlighted: bool) -> void:
	if highlighted:
		btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.0))
		# Add green arrow
		if not btn.text.begins_with("> "):
			btn.text = "> " + btn.text.trim_prefix("> ")
	else:
		btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		# Remove green arrow
		btn.text = btn.text.trim_prefix("> ")

func _highlight_selector(selector: FocusableSelector, highlighted: bool) -> void:
	if highlighted:
		selector.value_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.0))
		selector.left_arrow.add_theme_color_override("font_color", Color(1.0, 0.7, 0.0))
		selector.right_arrow.add_theme_color_override("font_color", Color(1.0, 0.7, 0.0))
		# Show green indicator
		if selector.focus_indicator:
			selector.focus_indicator.visible = true
	else:
		selector.value_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		selector.left_arrow.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		selector.right_arrow.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		# Hide green indicator
		if selector.focus_indicator:
			selector.focus_indicator.visible = false

# ==================== MAIN MENU ====================

func _build_main_menu() -> void:
	main_menu_container = VBoxContainer.new()
	# Position in bottom-left corner like Half-Life
	main_menu_container.anchor_left = 0.0
	main_menu_container.anchor_top = 1.0
	main_menu_container.anchor_right = 0.0
	main_menu_container.anchor_bottom = 1.0
	main_menu_container.offset_left = 60
	main_menu_container.offset_top = -400
	main_menu_container.offset_right = 500
	main_menu_container.offset_bottom = -60
	main_menu_container.add_theme_constant_override("separation", 10)
	add_child(main_menu_container)
	
	# Buttons - simple and clean
	var local_btn = _make_button("LOCAL MATCH")
	local_btn.pressed.connect(func(): _switch_to_state(MenuState.MATCH_SETUP))
	main_menu_container.add_child(local_btn)
	
	var mp_btn = _make_button("MULTIPLAYER")
	mp_btn.pressed.connect(func(): _switch_to_state(MenuState.MULTIPLAYER_LOBBY))
	main_menu_container.add_child(mp_btn)
	
	var exit_btn = _make_button("EXIT")
	exit_btn.pressed.connect(get_tree().quit)
	main_menu_container.add_child(exit_btn)

# ==================== MATCH SETUP ====================

func _build_match_setup() -> void:
	match_setup_container = Control.new()
	match_setup_container.anchor_right = 1.0
	match_setup_container.anchor_bottom = 1.0
	add_child(match_setup_container)
	
	# Panel in bottom-left
	var panel = VBoxContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 60
	panel.offset_top = -700  # Increased height for loadouts
	panel.offset_right = 600
	panel.offset_bottom = -60
	panel.add_theme_constant_override("separation", 10)
	match_setup_container.add_child(panel)
	
	# Title
	var title = Label.new()
	title.text = "MATCH SETUP"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.0))
	panel.add_child(title)
	
	# Separator
	var sep1 = HSeparator.new()
	sep1.add_theme_constant_override("separation", 10)
	panel.add_child(sep1)
	
	# Controller status section - compact
	var controller_container = HBoxContainer.new()
	controller_container.add_theme_constant_override("separation", 50)
	
	# P0 Controller
	var p0_hbox = HBoxContainer.new()
	p0_hbox.add_theme_constant_override("separation", 15)
	var p0_label = Label.new()
	p0_label.text = "P1:"
	p0_label.add_theme_font_size_override("font_size", 24)
	p0_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	p0_hbox.add_child(p0_label)
	
	p0_controller_icon = TextureRect.new()
	p0_controller_icon.custom_minimum_size = Vector2(48, 48)
	p0_controller_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	p0_controller_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if controller_not_detected_texture:
		p0_controller_icon.texture = controller_not_detected_texture
	p0_hbox.add_child(p0_controller_icon)
	controller_container.add_child(p0_hbox)
	
	# P1 Controller
	var p1_hbox = HBoxContainer.new()
	p1_hbox.add_theme_constant_override("separation", 15)
	var p1_label = Label.new()
	p1_label.text = "P2:"
	p1_label.add_theme_font_size_override("font_size", 24)
	p1_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	p1_hbox.add_child(p1_label)
	
	p1_controller_icon = TextureRect.new()
	p1_controller_icon.custom_minimum_size = Vector2(48, 48)
	p1_controller_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	p1_controller_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if controller_not_detected_texture:
		p1_controller_icon.texture = controller_not_detected_texture
	p1_hbox.add_child(p1_controller_icon)
	controller_container.add_child(p1_hbox)
	
	panel.add_child(controller_container)
	
	# Separator
	var sep2 = HSeparator.new()
	sep2.add_theme_constant_override("separation", 10)
	panel.add_child(sep2)
	
	# === P1 LOADOUT ===
	var p1_loadout_label = Label.new()
	p1_loadout_label.text = "PLAYER 1 LOADOUT"
	p1_loadout_label.add_theme_font_size_override("font_size", 22)
	p1_loadout_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.0))
	panel.add_child(p1_loadout_label)
	
	var p1_primary_selector = _make_weapon_selector("PRIMARY:", primary_weapon_names, 0)
	p1_primary_selector.on_left = func(): _change_weapon(-1, p1_primary_selector, primary_weapon_names, "p0_primary")
	p1_primary_selector.on_right = func(): _change_weapon(1, p1_primary_selector, primary_weapon_names, "p0_primary")
	_all_selectors.append(p1_primary_selector)
	panel.add_child(p1_primary_selector.container)
	
	var p1_secondary_selector = _make_weapon_selector("SECONDARY:", secondary_weapon_names, 0)
	p1_secondary_selector.on_left = func(): _change_weapon(-1, p1_secondary_selector, secondary_weapon_names, "p0_secondary")
	p1_secondary_selector.on_right = func(): _change_weapon(1, p1_secondary_selector, secondary_weapon_names, "p0_secondary")
	_all_selectors.append(p1_secondary_selector)
	panel.add_child(p1_secondary_selector.container)
	
	# Separator
	var sep_p1 = HSeparator.new()
	sep_p1.add_theme_constant_override("separation", 10)
	panel.add_child(sep_p1)
	
	# === P2 LOADOUT ===
	var p2_loadout_label = Label.new()
	p2_loadout_label.text = "PLAYER 2 LOADOUT"
	p2_loadout_label.add_theme_font_size_override("font_size", 22)
	p2_loadout_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.0))
	panel.add_child(p2_loadout_label)
	
	var p2_primary_selector = _make_weapon_selector("PRIMARY:", primary_weapon_names, 0)
	p2_primary_selector.on_left = func(): _change_weapon(-1, p2_primary_selector, primary_weapon_names, "p1_primary")
	p2_primary_selector.on_right = func(): _change_weapon(1, p2_primary_selector, primary_weapon_names, "p1_primary")
	_all_selectors.append(p2_primary_selector)
	panel.add_child(p2_primary_selector.container)
	
	var p2_secondary_selector = _make_weapon_selector("SECONDARY:", secondary_weapon_names, 0)
	p2_secondary_selector.on_left = func(): _change_weapon(-1, p2_secondary_selector, secondary_weapon_names, "p1_secondary")
	p2_secondary_selector.on_right = func(): _change_weapon(1, p2_secondary_selector, secondary_weapon_names, "p1_secondary")
	_all_selectors.append(p2_secondary_selector)
	panel.add_child(p2_secondary_selector.container)
	
	# Separator
	var sep_p2 = HSeparator.new()
	sep_p2.add_theme_constant_override("separation", 10)
	panel.add_child(sep_p2)
	
	# Map selector
	var map_selector = _make_map_selector()
	_all_selectors.append(map_selector)
	panel.add_child(map_selector.container)
	
	# Points selector
	var pts_selector = _make_selector("POINTS:", selected_points, 5, 100, 5)
	pts_selector.on_left = func(): _change_points(-5, pts_selector)
	pts_selector.on_right = func(): _change_points(5, pts_selector)
	_all_selectors.append(pts_selector)
	panel.add_child(pts_selector.container)
	
	# Separator
	var sep3 = HSeparator.new()
	sep3.add_theme_constant_override("separation", 10)
	panel.add_child(sep3)
	
	# Start button
	var start_btn = _make_button("START MATCH")
	start_btn.pressed.connect(_start_local_match)
	panel.add_child(start_btn)
	
	# Back button
	var back_btn = _make_button("BACK")
	back_btn.pressed.connect(func(): _switch_to_state(MenuState.MAIN_MENU))
	panel.add_child(back_btn)

func _make_selector(label_text: String, initial_value: int, min_val: int, max_val: int, step: int) -> FocusableSelector:
	var selector = FocusableSelector.new()
	
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 20)
	
	# GREEN INDICATOR
	var indicator = Label.new()
	indicator.text = ">"
	indicator.custom_minimum_size = Vector2(20, 0)
	indicator.add_theme_font_size_override("font_size", 28)
	indicator.add_theme_color_override("font_color", Color(0.0, 1.0, 0.0))
	indicator.visible = false
	container.add_child(indicator)
	
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(150, 0)
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	container.add_child(lbl)
	
	var left_arrow = Label.new()
	left_arrow.text = "<"
	left_arrow.custom_minimum_size = Vector2(30, 0)
	left_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_arrow.add_theme_font_size_override("font_size", 28)
	left_arrow.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	container.add_child(left_arrow)
	
	var value_label = Label.new()
	value_label.text = str(initial_value)
	value_label.custom_minimum_size = Vector2(100, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 24)
	value_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	container.add_child(value_label)
	
	var right_arrow = Label.new()
	right_arrow.text = ">"
	right_arrow.custom_minimum_size = Vector2(30, 0)
	right_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_arrow.add_theme_font_size_override("font_size", 28)
	right_arrow.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	container.add_child(right_arrow)
	
	selector.container = container
	selector.value_label = value_label
	selector.left_arrow = left_arrow
	selector.right_arrow = right_arrow
	selector.focus_indicator = indicator
	
	return selector

func _make_map_selector() -> FocusableSelector:
	var selector = FocusableSelector.new()
	
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 20)
	
	# GREEN INDICATOR
	var indicator = Label.new()
	indicator.text = ">"
	indicator.custom_minimum_size = Vector2(20, 0)
	indicator.add_theme_font_size_override("font_size", 28)
	indicator.add_theme_color_override("font_color", Color(0.0, 1.0, 0.0))
	indicator.visible = false
	container.add_child(indicator)
	
	var lbl = Label.new()
	lbl.text = "MAP:"
	lbl.custom_minimum_size = Vector2(150, 0)
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	container.add_child(lbl)
	
	var left_arrow = Label.new()
	left_arrow.text = "<"
	left_arrow.custom_minimum_size = Vector2(30, 0)
	left_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_arrow.add_theme_font_size_override("font_size", 28)
	left_arrow.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	container.add_child(left_arrow)
	
	var map_label = Label.new()
	map_label.text = selected_map
	map_label.custom_minimum_size = Vector2(150, 0)
	map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_label.add_theme_font_size_override("font_size", 24)
	map_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	container.add_child(map_label)
	
	var right_arrow = Label.new()
	right_arrow.text = ">"
	right_arrow.custom_minimum_size = Vector2(30, 0)
	right_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_arrow.add_theme_font_size_override("font_size", 28)
	right_arrow.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	container.add_child(right_arrow)
	
	selector.container = container
	selector.value_label = map_label
	selector.left_arrow = left_arrow
	selector.right_arrow = right_arrow
	selector.focus_indicator = indicator
	selector.on_left = func(): _change_map(-1, selector)
	selector.on_right = func(): _change_map(1, selector)
	
	return selector

func _make_weapon_selector(label_text: String, weapons_list: Array, initial_index: int) -> FocusableSelector:
	var selector = FocusableSelector.new()
	
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 20)
	
	# GREEN INDICATOR
	var indicator = Label.new()
	indicator.text = ">"
	indicator.custom_minimum_size = Vector2(20, 0)
	indicator.add_theme_font_size_override("font_size", 24)
	indicator.add_theme_color_override("font_color", Color(0.0, 1.0, 0.0))
	indicator.visible = false
	container.add_child(indicator)
	
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(130, 0)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	container.add_child(lbl)
	
	var left_arrow = Label.new()
	left_arrow.text = "<"
	left_arrow.custom_minimum_size = Vector2(30, 0)
	left_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_arrow.add_theme_font_size_override("font_size", 24)
	left_arrow.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	container.add_child(left_arrow)
	
	var value_label = Label.new()
	if weapons_list.is_empty():
		value_label.text = "NONE"
	else:
		value_label.text = weapons_list[initial_index]
	value_label.custom_minimum_size = Vector2(120, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	container.add_child(value_label)
	
	var right_arrow = Label.new()
	right_arrow.text = ">"
	right_arrow.custom_minimum_size = Vector2(30, 0)
	right_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_arrow.add_theme_font_size_override("font_size", 24)
	right_arrow.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	container.add_child(right_arrow)
	
	selector.container = container
	selector.value_label = value_label
	selector.left_arrow = left_arrow
	selector.right_arrow = right_arrow
	selector.focus_indicator = indicator
	
	return selector

func _change_points(direction: int, selector: FocusableSelector) -> void:
	selected_points = clamp(selected_points + direction, 5, 100)
	selector.value_label.text = str(selected_points)

func _change_map(direction: int, selector: FocusableSelector) -> void:
	current_map_index = (current_map_index + direction + available_maps.size()) % available_maps.size()
	selected_map = available_maps[current_map_index]
	selector.value_label.text = selected_map

func _change_weapon(direction: int, selector: FocusableSelector, weapons_list: Array, loadout_key: String) -> void:
	if weapons_list.is_empty():
		return
	
	var current_index = weapons_list.find(selector.value_label.text)
	current_index = (current_index + direction + weapons_list.size()) % weapons_list.size()
	var new_weapon_name = weapons_list[current_index]
	selector.value_label.text = new_weapon_name
	
	# Get the actual weapon resource
	var weapon_resource = null
	match loadout_key:
		"p0_primary", "p1_primary":
			weapon_resource = available_primary_weapons[current_index]
		"p0_secondary", "p1_secondary":
			weapon_resource = available_secondary_weapons[current_index]
	
	# Update the appropriate loadout
	match loadout_key:
		"p0_primary":
			p0_loadout["primary"] = weapon_resource
			current_p0_primary_index = current_index
		"p0_secondary":
			p0_loadout["secondary"] = weapon_resource
			current_p0_secondary_index = current_index
		"p1_primary":
			p1_loadout["primary"] = weapon_resource
			current_p1_primary_index = current_index
		"p1_secondary":
			p1_loadout["secondary"] = weapon_resource
			current_p1_secondary_index = current_index

# ==================== MULTIPLAYER LOBBY ====================

var room_code_label: Label
var leader_label: Label
var lobby_buttons: Dictionary = {}

func _build_multiplayer_lobby() -> void:
	multiplayer_lobby_container = Control.new()
	multiplayer_lobby_container.anchor_right = 1.0
	multiplayer_lobby_container.anchor_bottom = 1.0
	add_child(multiplayer_lobby_container)
	
	# Panel in bottom-left
	var panel = VBoxContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 60
	panel.offset_top = -550
	panel.offset_right = 600
	panel.offset_bottom = -60
	panel.add_theme_constant_override("separation", 12)
	multiplayer_lobby_container.add_child(panel)
	
	# Title
	var title = Label.new()
	title.text = "MULTIPLAYER"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.0))
	panel.add_child(title)
	
	# Separator
	var sep1 = HSeparator.new()
	panel.add_child(sep1)
	
	# Leader indicator
	leader_label = Label.new()
	leader_label.text = "★ LOBBY LEADER"
	leader_label.add_theme_font_size_override("font_size", 20)
	leader_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.0))
	leader_label.visible = false
	panel.add_child(leader_label)
	
	# Room code display
	room_code_label = Label.new()
	room_code_label.text = "ROOM: ------"
	room_code_label.add_theme_font_size_override("font_size", 26)
	room_code_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	room_code_label.visible = false
	panel.add_child(room_code_label)
	
	# Separator
	var sep2 = HSeparator.new()
	panel.add_child(sep2)
	
	# Create lobby button
	var create_btn = _make_button("CREATE LOBBY")
	create_btn.pressed.connect(_create_lobby)
	lobby_buttons["create"] = create_btn
	panel.add_child(create_btn)
	
	# Join lobby input
	var join_label = Label.new()
	join_label.text = "ENTER ROOM CODE:"
	join_label.add_theme_font_size_override("font_size", 20)
	join_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	lobby_buttons["join_label"] = join_label
	panel.add_child(join_label)
	
	var room_input = LineEdit.new()
	room_input.placeholder_text = "Room Code"
	room_input.custom_minimum_size = Vector2(0, 40)
	room_input.add_theme_font_size_override("font_size", 22)
	lobby_buttons["room_input"] = room_input
	panel.add_child(room_input)
	
	var join_btn = _make_button("JOIN LOBBY")
	join_btn.pressed.connect(func(): _join_lobby(room_input.text))
	lobby_buttons["join"] = join_btn
	panel.add_child(join_btn)
	
	# Start game button (hidden until in lobby)
	var start_btn = _make_button("START GAME")
	start_btn.pressed.connect(_start_multiplayer_match)
	start_btn.visible = false
	lobby_buttons["start"] = start_btn
	panel.add_child(start_btn)
	
	# Leave lobby button (hidden until in lobby)
	var leave_btn = _make_button("LEAVE LOBBY")
	leave_btn.pressed.connect(_leave_lobby)
	leave_btn.visible = false
	lobby_buttons["leave"] = leave_btn
	panel.add_child(leave_btn)
	
	# Separator
	var sep3 = HSeparator.new()
	panel.add_child(sep3)
	
	# Back button
	var back_btn = _make_button("BACK")
	back_btn.pressed.connect(func(): _switch_to_state(MenuState.MAIN_MENU))
	lobby_buttons["back"] = back_btn
	panel.add_child(back_btn)

# ==================== BUTTON CREATION ====================

func _make_button(text: String, highlight: bool = false) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 40)
	btn.focus_mode = Control.FOCUS_ALL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Transparent background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_left = 0
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	
	return btn

# ==================== STATE MANAGEMENT ====================

func _switch_to_state(new_state: MenuState) -> void:
	current_state = new_state
	
	# Hide all containers
	main_menu_container.visible = false
	match_setup_container.visible = false
	multiplayer_lobby_container.visible = false
	
	# Clear current items
	current_focusable_items.clear()
	
	# Show appropriate container and populate items
	match new_state:
		MenuState.MAIN_MENU:
			main_menu_container.visible = true
			_populate_focusable_items(main_menu_container)
		MenuState.MATCH_SETUP:
			match_setup_container.visible = true
			_populate_focusable_items(match_setup_container)
		MenuState.MULTIPLAYER_LOBBY:
			multiplayer_lobby_container.visible = true
			_populate_focusable_items(multiplayer_lobby_container)
	
	# Focus first item
	current_focus_index = 0
	if not current_focusable_items.is_empty():
		_update_focus()

func _populate_focusable_items(container: Node) -> void:
	for child in _get_all_children(container):
		if child is Button and child.visible:
			current_focusable_items.append(child)
		elif child is HBoxContainer:
			# Check if this is a selector container
			var selector = _find_selector_for_container(child)
			if selector:
				current_focusable_items.append(selector)

func _find_selector_for_container(container: HBoxContainer) -> FocusableSelector:
	for selector in _all_selectors:
		if selector.container == container:
			return selector
	return null

func _get_all_children(node: Node) -> Array:
	var children = []
	for child in node.get_children():
		children.append(child)
		children.append_array(_get_all_children(child))
	return children

# ==================== GAME LOGIC ====================

func _start_local_match() -> void:
	if not is_instance_valid(Game):
		push_error("Game autoload not found")
		return
	
	var load_screen = preload("res://core/load_screen.tscn").instantiate()
	get_tree().root.add_child(load_screen)
	
	var sprite_node = load_screen.get_node_or_null(selected_map)
	if sprite_node and sprite_node is Sprite2D:
		sprite_node.visible = true
	
	var timer = Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	add_child(timer)
	timer.start()
	
	timer.timeout.connect(func():
		# Pass loadouts to Game
		Game.player_loadouts = [p0_loadout, p1_loadout]
		Game.start_match(selected_map, 2, selected_points)
		load_screen.queue_free()
		queue_free()
	)

func _create_lobby() -> void:
	if not is_instance_valid(Matchmaking):
		push_error("Matchmaking autoload not found")
		return
	
	Matchmaking.queued_request = Matchmaking.create_lobby_request.rpc_id.bind(1)
	Matchmaking.start_client(Multiplayer.MASTERSERVER_IP, Multiplayer.MASTERSERVER_PORT)

func _join_lobby(room_code: String) -> void:
	if not is_instance_valid(Matchmaking):
		push_error("Matchmaking autoload not found")
		return
	
	if room_code.strip_edges().is_empty():
		return
	
	Matchmaking.queued_request = Matchmaking.join_lobby_request.rpc_id.bind(1, room_code)
	Matchmaking.start_client(Multiplayer.MASTERSERVER_IP, Multiplayer.MASTERSERVER_PORT)

func _start_multiplayer_match() -> void:
	if not is_instance_valid(Multiplayer):
		return
	
	Multiplayer.start_game_request.rpc_id(1, selected_map, selected_points)

func _leave_lobby() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.disconnect_peer(1)

# ==================== MULTIPLAYER CALLBACKS ====================

func _on_lobby_connected() -> void:
	var is_leader := false
	if is_instance_valid(Multiplayer) and not Multiplayer.player_ids.is_empty():
		if Multiplayer.player_ids[0] == multiplayer.get_unique_id():
			is_leader = true
	
	leader_label.visible = is_leader
	room_code_label.visible = true
	
	lobby_buttons["create"].hide()
	lobby_buttons["join_label"].hide()
	lobby_buttons["room_input"].hide()
	lobby_buttons["join"].hide()
	lobby_buttons["start"].visible = is_leader
	lobby_buttons["leave"].show()
	
	# Update items list for navigation
	if current_state == MenuState.MULTIPLAYER_LOBBY:
		_populate_focusable_items(multiplayer_lobby_container)
		_update_focus()

func _on_lobby_disconnected() -> void:
	leader_label.hide()
	room_code_label.hide()
	
	lobby_buttons["create"].show()
	lobby_buttons["join_label"].show()
	lobby_buttons["room_input"].show()
	lobby_buttons["join"].show()
	lobby_buttons["start"].hide()
	lobby_buttons["leave"].hide()
	
	# Update items list for navigation
	if current_state == MenuState.MULTIPLAYER_LOBBY:
		_populate_focusable_items(multiplayer_lobby_container)
		_update_focus()

func _on_room_code_updated() -> void:
	if is_instance_valid(Multiplayer):
		room_code_label.text = "ROOM: " + Multiplayer.room_code
