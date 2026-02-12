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

func preload_game_systems():
	print("=== PRELOADING GAME SYSTEMS ===")
	
	# Instantiate player offscreen to compile all player-related shaders
	var warmup_player = player_tscn.instantiate()
	warmup_player.global_position = Vector3(10000, 10000, 10000)
	warmup_player.ctrl_port = 0
	add_child(warmup_player)
	
	# Wait for player to fully initialize
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Simulate shooting to compile weapon shaders
	if warmup_player.current_weapon:
		# Trigger muzzle flash
		if warmup_player.has_method("activate_muzzle_flash"):
			warmup_player.activate_muzzle_flash()
			await get_tree().process_frame
			await get_tree().process_frame
		
		# Simulate bullet instantiation
		var bullet = warmup_player.current_weapon.bullet_tscn.instantiate()
		bullet.global_position = Vector3(10000, 10000, 10000)
		add_child(bullet)
		await get_tree().process_frame
		bullet.queue_free()
		
		# Simulate tracer
		if warmup_player.tracer_scene:
			var tracer = warmup_player.tracer_scene.instantiate()
			tracer.global_position = Vector3(10000, 10000, 10000)
			add_child(tracer)
			await get_tree().process_frame
			await get_tree().process_frame
			tracer.queue_free()
	
	# Simulate blood spatter (from bullet hit)
	var blood_scene = load("res://assets/pfx/bloodspatter/blood_spatter.tscn")
	for i in range(2):
		var blood = blood_scene.instantiate()
		blood.global_position = Vector3(10000, 10000, 10000)
		add_child(blood)
		await get_tree().process_frame
		await get_tree().process_frame
		blood.queue_free()
	
	# Simulate bullet decal
	var decal_scene = load("res://assets/bullets/bullet_decal.tscn")
	for i in range(3):
		var decal = decal_scene.instantiate()
		decal.global_position = Vector3(10000, 10000, 10000)
		add_child(decal)
		await get_tree().process_frame
		decal.queue_free()
	
	# Simulate spark effect
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
	
	# Simulate damage on player (triggers HUD effects)
	warmup_player.take_damage(1, "body", warmup_player.get_path(), warmup_player.global_position)
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Extra frames to ensure everything compiles
	for i in range(10):
		await get_tree().process_frame
	
	# Cleanup
	warmup_player.queue_free()
	
	print("=== PRELOAD COMPLETE ===")

@rpc("authority", "call_local", "reliable")
func start_match(map:String, player_count:int, points_to_win:=10):
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
	
	for player in player_roster:
		player.queue_free()
	player_roster = []
	world.queue_free()
	world = null
	
	# Clear loadouts
	player_loadouts = []
	
	var menu = load("res://core/menu.tscn").instantiate()
	add_child(menu)
