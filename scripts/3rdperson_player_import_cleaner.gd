@tool
extends EditorScript

func _run():
	var lower_bones = [
		"mixamorig_Hips",
		"mixamorig_Spine",
		"mixamorig_LeftUpLeg",
		"mixamorig_LeftLeg",
		"mixamorig_LeftFoot",
		"mixamorig_LeftToeBase",
		"mixamorig_LeftToe_End",
		"mixamorig_RightUpLeg",
		"mixamorig_RightLeg",
		"mixamorig_RightFoot",
		"mixamorig_RightToeBase",
		"mixamorig_RightToe_End",
	]

	var leg_anims = [
		"Idle", "MoveForward", "MoveBack", "MoveLeft", "MoveRight",
		"Sprint", "Jump",
	]

	var upper_anims = [
		"RifleUpperIdle", "PistolUpperIdle", "UnarmedUpperIdle", "UnarmedUpperPunch",
		"PistolReload", "RifleReload", "PistolInspect", "RifleInspect", "UnarmedInspect"
	]

	var anim_library = load("res://assets/rigs/full_body/3rdperson_omni.glb")
	if not anim_library:
		print("Could not load file!")
		return

	var instance = anim_library.instantiate()
	var anim_player = instance.find_child("AnimationPlayer", true, false)
	if not anim_player:
		print("Could not find AnimationPlayer!")
		return

	print("Found AnimationPlayer, animations: ", anim_player.get_animation_list())

	# Leg anims — remove upper bone tracks, keep lower only
	for anim_name in leg_anims:
		if not anim_player.has_animation(anim_name):
			print("Skipping missing: ", anim_name)
			continue
		var anim = anim_player.get_animation(anim_name)
		var tracks_to_remove = []
		for i in range(anim.get_track_count()):
			var path = str(anim.track_get_path(i))
			var keep = false
			for bone in lower_bones:
				if bone in path:
					keep = true
					break
			if not keep:
				tracks_to_remove.append(i)
		tracks_to_remove.reverse()
		for i in tracks_to_remove:
			anim.remove_track(i)
		print("Leg cleaned: ", anim_name, " removed ", tracks_to_remove.size(), " tracks")

	# Upper anims — remove lower bone tracks, keep upper only
	for anim_name in upper_anims:
		if not anim_player.has_animation(anim_name):
			print("Skipping missing: ", anim_name)
			continue
		var anim = anim_player.get_animation(anim_name)
		var tracks_to_remove = []
		for i in range(anim.get_track_count()):
			var path = str(anim.track_get_path(i))
			var remove = false
			for bone in lower_bones:
				if bone in path:
					remove = true
					break
			if remove:
				tracks_to_remove.append(i)
		tracks_to_remove.reverse()
		for i in tracks_to_remove:
			anim.remove_track(i)
		print("Upper cleaned: ", anim_name, " removed ", tracks_to_remove.size(), " tracks")

	# Save as .res so reimporting the glb doesn't overwrite our work
	var save_result = ResourceSaver.save(anim_library, "res://assets/rigs/full_body/3rdperson_omni_cleaned.res")
	if save_result == OK:
		print("Saved to 3rdperson_omni_cleaned.res!")
	else:
		print("Save failed!")

	print("Done!")
