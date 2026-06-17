@tool
extends EditorProperty
## Inspector property for selecting the AnimatedSprite2D/3D node,
## and handles the animation import process.
##
## Enhanced from the original AS2P with:
## - Selective import (checkbox-based animation list)
## - Existing animation detection (skip already-imported animations)

var anim_player: AnimationPlayer
var drop_down := OptionButton.new()

signal animation_updated()
## Emitted when the user switches the AnimatedSprite2D node in the dropdown,
## so InspectorConvertor can refresh the animation checkbox list
signal sprite_node_changed()

func get_animatedsprite():
	var root = get_tree().edited_scene_root
	return _get_animated_sprites(root)[drop_down.selected]

func _get_animated_sprites(root: Node) -> Array:
	var asNodes := []

	if root is AnimatedSprite2D or root is AnimatedSprite3D:
		asNodes.append(root)

	for child in root.get_children():
		asNodes += _get_animated_sprites(child)

	return asNodes

func _init(_anim_player):
	anim_player = _anim_player

	drop_down.clip_text = true
	# Add the control as a direct child of EditorProperty node.
	add_child(drop_down)
	# Make sure the control is able to retain the focus.
	add_focusable(drop_down)

	drop_down.clear()


func _ready():
	get_items()
	# When dropdown selection changes, signal InspectorConvertor to refresh list
	drop_down.item_selected.connect(_on_item_selected)


func _on_item_selected(_idx: int):
	sprite_node_changed.emit()


func get_items():
	drop_down.clear()

	var root = get_tree().edited_scene_root
	var anim_sprites := _get_animated_sprites(root)

	for i in range(len(anim_sprites)):
		var anim_sprite = anim_sprites[i]

		drop_down.add_item(anim_player.get_path_to(anim_sprite), i)


## Returns all animation names from the currently selected AnimatedSprite2D
func get_animation_list() -> Array[String]:
	var animated_sprite = get_animatedsprite()
	if not animated_sprite or not animated_sprite.sprite_frames:
		return []
	var names: Array[String] = []
	for anim in animated_sprite.sprite_frames.get_animation_names():
		if not anim.is_empty():
			names.append(anim)
	return names


## Returns which animations in the list already exist in the AnimationLibrary
func get_existing_animations() -> Array[String]:
	var lib := _get_global_library()
	if not lib:
		return []
	var existing: Array[String] = []
	for anim_name in get_animation_list():
		var sanitized := anim_name.replace(":", "_").replace("[", "_")
		if lib.has_animation(sanitized):
			existing.append(anim_name)
	return existing


## Gets or creates the global AnimationLibrary (keyed with empty string "")
func _get_global_library() -> AnimationLibrary:
	if anim_player.has_animation_library(&""):
		return anim_player.get_animation_library(&"")
	var lib := AnimationLibrary.new()
	anim_player.add_animation_library(&"", lib)
	return lib


## Selective import: only converts animations listed in selected_names.
## If selected_names is empty, behaves like the old convert_sprites() (full import).
func convert_selected(selected_names: Array = []):
	var animated_sprite = get_node(get_animatedsprite().get_path())

	var count := 0
	var updated_count := 0
	var skipped_count := 0

	var sprite_frames = animated_sprite.sprite_frames

	if not sprite_frames:
		print("[AS2P] Selected AnimatedSprite2D has no frames!")
		return

	for anim in sprite_frames.get_animation_names():
		if anim.is_empty():
			printerr("[AS2P] SpriteFrames on AnimatedSprite2D '%s' has an \
animation named empty string '', it will be ignored" % animated_sprite.name)
			continue

		# If a selection list was provided, only process listed animations; otherwise process all
		if not selected_names.is_empty() and anim not in selected_names:
			skipped_count += 1
			continue

		var updated = add_animation(
				anim_player.get_node(anim_player.root_node).get_path_to(animated_sprite),
				anim,
				sprite_frames
			)

		count += 1

		if updated:
			updated_count += 1

	if skipped_count > 0:
		print("[AS2P] Skipped %d animations (not selected)." % skipped_count)
	if count - updated_count > 0:
		print("[AS2P] Added %d animations!" % [count - updated_count])
	if updated_count > 0:
		print("[AS2P] Updated %d animations!" % updated_count)

	emit_signal("animation_updated")


## Legacy compatibility: full import, delegates to convert_selected([])
func convert_sprites():
	convert_selected([])


func add_animation(anim_sprite: NodePath, anim: String, sprite_frames: SpriteFrames):
	var frame_count = sprite_frames.get_frame_count(anim)
	var fps = sprite_frames.get_animation_speed(anim)
	var looping = sprite_frames.get_animation_loop(anim)
	# Determine the total animation duration in seconds. First sum the duration
	# of each frame, then divide duration by FPS to get the length in seconds.
	var duration: float = 0
	for i in range(frame_count):
		duration += sprite_frames.get_frame_duration(anim, i)
	duration = duration / fps

	# We add the converted animation to the [Global] animation library,
	# which corresponds to the empty string "" key
	var global_animation_library := _get_global_library()

	# SpriteFrames allow characters ":" and "[" in animation names, but not
	# AnimationPlayer library, so sanitize the name
	var sanitized_anim_name = anim.replace(":", "_")
	sanitized_anim_name = sanitized_anim_name.replace("[", "_")

	var updated := false
	var animation: Animation = null

	if global_animation_library.has_animation(sanitized_anim_name):
		animation = global_animation_library.get_animation(sanitized_anim_name)
		updated = true
	else:
		animation = Animation.new()
		global_animation_library.add_animation(sanitized_anim_name, animation)

	var spf = 1/fps
	animation.length = duration

	# SpriteFrames only supports linear looping (not ping-pong),
	# so set loop mode to either None or Linear
	animation.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE

	# Remove existing tracks
	var animation_name_path := "%s:animation" % anim_sprite
	var frame_path := "%s:frame" % anim_sprite

	var anim_track: int = animation.find_track(animation_name_path, Animation.TYPE_VALUE)
	var frame_track: int = animation.find_track(frame_path, Animation.TYPE_VALUE)

	if frame_track >= 0:
		animation.remove_track(anim_track)
	if anim_track >= 0:
		animation.remove_track(frame_track)

	# Add and create tracks
	frame_track = animation.add_track(Animation.TYPE_VALUE, 0)
	anim_track = animation.add_track(Animation.TYPE_VALUE, 1)

	animation.track_set_path(anim_track, animation_name_path)

	# Use the original animation name from SpriteFrames here,
	# since the track expects a SpriteFrames animation key for the AnimatedSprite2D
	animation.track_insert_key(anim_track, 0, anim)

	animation.track_set_path(frame_track, frame_path)

	animation.value_track_set_update_mode(frame_track, Animation.UPDATE_DISCRETE)
	animation.value_track_set_update_mode(anim_track, Animation.UPDATE_DISCRETE)

	# Initialize first sprite key time
	var next_key_time := 0.0

	for i in range(frame_count):
		# Insert key at next key time
		animation.track_insert_key(frame_track, next_key_time, i)

		# Prepare key time for next sprite by adding duration of current sprite
		# including Frame Duration multiplier
		var frame_duration_multiplier = sprite_frames.get_frame_duration(anim, i)
		next_key_time += frame_duration_multiplier * spf

	global_animation_library.add_animation(sanitized_anim_name, animation)

	return updated


func get_tooltip_text():
	return "AnimationSprite node to import frames from."
