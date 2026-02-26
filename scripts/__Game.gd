extends Node

signal game_starting

## NODES ##
@onready var player_tscn := preload("res://core/player.tscn")
@onready var player_roster := [] 
@onready var world_tscn := preload("res://core/world.tscn")
@onready var world : Node3D
@onready var load_screen_tscn := preload("res://core/load_screen.tscn")

# Loadout system
var player_loadouts := []

var capture_mouse := false
var in_match := false

func _ready() -> void:
	get_viewport().focus_entered.connect(_on_focus_entered)

func _on_focus_entered() -> void:
	if capture_mouse and in_match:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if not in_match:
		return
	
	if event is InputEventMouseButton and event.pressed:
		if not capture_mouse:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			capture_mouse = true
		elif capture_mouse and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if event.is_action_pressed("ui_cancel"):
		if capture_mouse:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			capture_mouse = false

func preload_game_systems():
	print("=== PRELOADING GAME SYSTEMS ===")
	
	var warmup_player = player_tscn.instantiate()
	warmup_player.global_position = Vector3(10000, 10000, 10000)
	warmup_player.ctrl_port = 0
	add_child(warmup_player)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	if warmup_player.current_weapon:
		if warmup_player.has_method("activate_muzzle_flash"):
			warmup_player.activate_muzzle_flash()
			await get_tree().process_frame
			await get_tree().process_frame
		
		var bullet = warmup_player.current_weapon.bullet_tscn.instantiate()
		bullet.global_position = Vector3(10000, 10000, 10000)
		add_child(bullet)
		await get_tree().process_frame
		bullet.queue_free()
		
		if warmup_player.tracer_scene:
			var tracer = warmup_player.tracer_scene.instantiate()
			tracer.global_position = Vector3(10000, 10000, 10000)
			add_child(tracer)
			await get_tree().process_frame
			await get_tree().process_frame
			tracer.queue_free()
	
	var blood_scene = load("res://assets/pfx/bloodspatter/blood_spatter.tscn")
	for i in range(2):
		var blood = blood_scene.instantiate()
		blood.global_position = Vector3(10000, 10000, 10000)
		add_child(blood)
		await get_tree().process_frame
		await get_tree().process_frame
		blood.queue_free()
	
	var decal_scene = load("res://assets/bullets/bullet_decal.tscn")
	for i in range(3):
		var decal = decal_scene.instantiate()
		decal.global_position = Vector3(10000, 10000, 10000)
		add_child(decal)
		await get_tree().process_frame
		decal.queue_free()
	
	var spark_scene = load("res://addons/MrMinimal'sVFX/game/entities/vfx/sparks_metal/sparks_metal.tscn")
	for i in range(2):
		var spark = spark_scene.instantiate()
		spark.global_position = Vector3(10000, 10000, 10000)
		add_child(spark)
		if spark is GPUParticles3D:
			spark.emitting = true
			spark.restart()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		spark.queue_free()
	
	warmup_player.take_damage(1, "body", warmup_player.get_path(), warmup_player.global_position)
	await get_tree().process_frame
	await get_tree().process_frame
	
	for i in range(10):
		await get_tree().process_frame
	
	warmup_player.queue_free()
	
	print("=== PRELOAD COMPLETE ===")

@rpc("authority", "call_local", "reliable")
func start_match(map:String, player_count:int, points_to_win:=10):
	in_match = true
	capture_mouse = false
	game_starting.emit()
	player_roster = []
	for index in range(0, player_count):
		var player = player_tscn.instantiate()
		player.ctrl_port = index
		player_roster.append(player)
	
	if world: world.queue_free()
	world = world_tscn.instantiate()
	world.current_map = load("res://assets/maps/"+map+".tscn").instantiate()
	world.target_score = points_to_win
	add_child(world)

func end_match():
	if not is_instance_valid(world):
		return
	
	in_match = false
	capture_mouse = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	for player in player_roster:
		player.queue_free()
	player_roster = []
	world.queue_free()
	world = null
	
	player_loadouts = []
	
	var menu = load("res://core/menu.tscn").instantiate()
	add_child(menu)
