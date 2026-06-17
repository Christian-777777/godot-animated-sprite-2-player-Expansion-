@tool
extends EditorInspectorPlugin

const NodeSelectorProperty = preload("./NodeSelectorProperty.gd")

var node_selector: NodeSelectorProperty

# Properties
var anim_player: AnimationPlayer

# UI controls
var _checkbox_container: VBoxContainer
var _checkboxes: Array[CheckBox] = []

# Signals
signal animation_updated(animation_player: AnimationPlayer)

func _can_handle(object):
	if object is AnimationPlayer:
		anim_player = object
		return true
	return false


## Create UI here
func _parse_end(object: Object):
	var header = CustomEditorInspectorCategory.new("Import AnimatedSprite2D/3D")

	# AnimatedSprite2D Node selector
	node_selector = NodeSelectorProperty.new(anim_player)
	node_selector.label = "AnimatedSprite2D/3D Node"

	node_selector.animation_updated.connect(
		_on_animation_updated,
		CONNECT_DEFERRED
	)
	# Rebuild animation checkbox list when switching sprite node
	node_selector.sprite_node_changed.connect(_rebuild_animation_list)

	# Select All / Deselect All buttons
	var select_all := Button.new()
	select_all.text = "Select All"
	select_all.button_down.connect(_on_select_all)

	var deselect_all := Button.new()
	deselect_all.text = "Deselect All"
	deselect_all.button_down.connect(_on_deselect_all)

	var btn_row := HBoxContainer.new()
	btn_row.add_child(select_all)
	btn_row.add_child(deselect_all)

	# Scrollable animation checkbox list
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 150)
	_checkbox_container = VBoxContainer.new()
	scroll.add_child(_checkbox_container)

	# Import button
	var button := Button.new()
	button.text = "Import"
	button.get_minimum_size().y = 26
	button.button_down.connect(_on_import_pressed)

	var buttonstyle = StyleBoxFlat.new()
	buttonstyle.bg_color = Color8(32, 37, 49)
	button.set("custom_styles/normal", buttonstyle)

	# Assemble layout
	var container := VBoxContainer.new()
	container.add_spacer(true)

	container.add_child(header)
	container.add_child(node_selector)
	container.add_spacer(false)
	container.add_child(btn_row)
	container.add_child(scroll)
	container.add_spacer(false)
	container.add_child(button)

	add_custom_control(container)

	# Populate checkbox list on first load
	_rebuild_animation_list.call_deferred()


## Rebuild the animation checkbox list: reads current SpriteFrames animation names,
## creates one checkbox per animation, marks existing ones with " (exists)"
func _rebuild_animation_list() -> void:
	# Clear old list
	for cb in _checkboxes:
		_checkbox_container.remove_child(cb)
		cb.queue_free()
	_checkboxes.clear()

	var anim_names := node_selector.get_animation_list()
	if anim_names.is_empty():
		var label := Label.new()
		label.text = "(no animations)"
		_checkbox_container.add_child(label)
		return

	var existing := node_selector.get_existing_animations()

	for anim_name in anim_names:
		var cb := CheckBox.new()
		if anim_name in existing:
			cb.text = "%s (exists)" % anim_name
		else:
			cb.text = anim_name
		cb.button_pressed = true  # checked by default
		_checkbox_container.add_child(cb)
		_checkboxes.append(cb)


## Import button click: collect checked animation names, call selective import
func _on_import_pressed() -> void:
	var selected: Array = []
	for cb in _checkboxes:
		if cb.button_pressed:
			# Extract animation name from checkbox text (strip " (exists)" suffix)
			var name := cb.text
			var suffix_idx := name.find(" (exists)")
			if suffix_idx >= 0:
				name = name.substr(0, suffix_idx)
			selected.append(name)

	if selected.is_empty():
		print("[AS2P] No animations selected.")
		return

	node_selector.convert_selected(selected)


func _on_select_all() -> void:
	for cb in _checkboxes:
		cb.button_pressed = true


func _on_deselect_all() -> void:
	for cb in _checkboxes:
		cb.button_pressed = false


func _on_animation_updated():
	emit_signal("animation_updated", anim_player)
	# Refresh list after import so "exists" labels update
	_rebuild_animation_list()


# Nested class for the inspector category header
class CustomEditorInspectorCategory extends Control:
	var title: String = ""
	var icon: Texture2D = null

	func _init(p_title: String, p_icon: Texture2D = null):
		title = p_title
		icon = p_icon
		tooltip_text = "AnimatedSprite to AnimationPlayer Plugin"

	func _get_minimum_size() -> Vector2:
		var font := get_theme_font(&"bold", &"EditorFonts");
		var font_size := get_theme_font_size(&"bold_size", &"EditorFonts");

		var ms: Vector2
		ms.y = font.get_height(font_size);
		if icon:
			ms.y = max(icon.get_height(), ms.y);

		ms.y += get_theme_constant(&"v_separation", &"Tree");

		return ms;

	func _draw() -> void:
		var sb := get_theme_stylebox(&"bg", &"EditorInspectorCategory")
		draw_style_box(sb, Rect2(Vector2.ZERO, size))

		var font := get_theme_font(&"bold", &"EditorFonts")
		var font_size := get_theme_font_size(&"bold_size", &"EditorFonts")

		var hs := get_theme_constant(&"h_separation", &"Tree")

		var w: int = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x;
		if icon:
			w += hs + icon.get_width();

		var ofs := (get_size().x - w) / 2;

		if icon:
			draw_texture(icon, Vector2(ofs, (get_size().y - icon.get_height()) / 2).floor())
			ofs += hs + icon.get_width()

		var color := get_theme_color(&"font_color", &"Tree")
		draw_string(font, Vector2(ofs, font.get_ascent(font_size) + (get_size().y - font.get_height(font_size)) / 2).floor(), title, HORIZONTAL_ALIGNMENT_LEFT, get_size().x, font_size, color);
