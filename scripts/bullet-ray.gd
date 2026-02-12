@tool
extends BulletBase
class_name RayBullet

## NODES ##
@onready var hit_ray := $hit_ray
@onready var trail := $trail

var active_shot := true
var just_added := true

signal bullet_hit(hit_position)

func _ready() -> void:
	if Engine.is_editor_hint():
		if get_child_count() > 0:
			return

		var new_ray = RayCast3D.new()
		new_ray.name = "hit_ray"
		add_child(new_ray)
		new_ray.set_owner(get_tree().edited_scene_root)
		return

	randomize() # Ensure randomness on each run
	super._ready()

	remove_child(trail)
	trail.mesh = trail.mesh.duplicate()
	trail.mesh.material = trail.mesh.material.duplicate()
	trail.show()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	super._physics_process(delta)
	if active_shot and hit_ray.is_colliding():
		var target = hit_ray.get_collider()
		if target == user:
			return
		var hit_position = hit_ray.get_collision_point()
		var hit_normal = hit_ray.get_collision_normal().normalized()
		if get_parent().has_method("move_tracer"):
			get_parent().move_tracer(hit_position)
		if target.has_method("apply_damage"):
			target.apply_damage(damage, user, hit_position)
			print("Bullet hit a hitbox: ", target.name)
		elif target.is_in_group("terrain"):
			print("Bullet hit terrain: ", target.name)
		if target.name not in ["HeadHitBox", "BodyHitBox", "LegsHitBox"]:
			# === Spawn decal ===
			var bullet_hole_scene = preload("res://assets/bullets/bullet_decal.tscn")
			var bullet_hole = bullet_hole_scene.instantiate()
			target.add_child(bullet_hole)
			
			# Set position with offset towards player to prevent clipping
			var offset_distance = 0.001  # Adjust this value as needed (smaller = less offset)
			bullet_hole.global_position = hit_position + (hit_normal * offset_distance)
			
			# Face the surface (flush with surface)
			var up_dir = Vector3.UP
			if abs(hit_normal.dot(up_dir)) > 0.99:
				up_dir = Vector3.FORWARD  # Avoid gimbal lock if surface is vertical
			bullet_hole.look_at(hit_position - hit_normal, up_dir)
			
			# Random spin around normal (in local space)
			var random_spin = randf() * TAU
			bullet_hole.rotate_object_local(Vector3(0, 0, 1), random_spin)
			
			# Scale decal
			bullet_hole.scale = Vector3(0.02, 0.02, 0.02)
			
			# === Spawn spark ===
			var spark_scene = preload("res://addons/MrMinimal'sVFX/game/entities/vfx/sparks_metal/sparks_metal.tscn")
			var spark = spark_scene.instantiate()
			target.add_child(spark)
			spark.global_position = hit_position
			spark.look_at(hit_position + hit_normal, Vector3.UP)
			# Trigger spark
			if spark is GPUParticles3D or spark is CPUParticles3D:
				spark.emitting = true
				spark.call_deferred("restart")
		emit_signal("bullet_hit", hit_position)
		queue_free()
		active_shot = false
