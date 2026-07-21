extends Control

@export var mini_size: Vector2 = Vector2(180, 180)
@export var full_size: Vector2 = Vector2(0, 0)
@export var zoom: float = 0.15
@export var minimap_opacity: float = 0.75

var _viewport: SubViewport
var _camera: Camera3D
var _is_mini: bool = true
var _track_node: Node3D = null
var _car_nodes: Array[Node3D] = []
var _player_car: Node3D = null

var _zoom_min: float = 20.0
var _zoom_max: float = 120.0
var _zoom_step: float = 5.0

const BG_COLOR: Color = Color(0.05, 0.08, 0.15, 0.75)
const PLAYER_COLOR: Color = Color(0.1, 0.8, 0.2)
const BOT_COLOR: Color = Color(0.9, 0.3, 0.1)
const CHECKPOINT_COLOR: Color = Color(0.2, 0.6, 1.0, 0.8)
const TRACK_COLOR: Color = Color(0.4, 0.4, 0.5, 0.6)
const CARDINAL_COLOR: Color = Color(0.6, 0.6, 0.7, 0.8)
const CARDINAL_NORTH_COLOR: Color = Color(1.0, 0.85, 0.2, 1.0)


func _ready() -> void:
	custom_minimum_size = mini_size
	_setup_viewport()
	_find_track_and_cars()
	_apply_mode()


func _process(_delta: float) -> void:
	if _player_car and _camera:
		var pos: Vector3 = _player_car.global_position
		_camera.global_position = Vector3(pos.x, pos.y + 40.0, pos.z)
		_camera.global_transform = _camera.global_transform.looking_at(pos)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_camera(-_zoom_step)
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_camera(_zoom_step)
				get_viewport().set_input_as_handled()


func _zoom_camera(delta_zoom: float) -> void:
	if not _camera:
		return
	_camera.size = clampf(_camera.size + delta_zoom, _zoom_min, _zoom_max)


func set_mode(mini: bool) -> void:
	_is_mini = mini
	_apply_mode()


func toggle_mode() -> void:
	_is_mini = not _is_mini
	_apply_mode()


func is_mini() -> bool:
	return _is_mini


func set_minimap_size(new_size: float) -> void:
	mini_size = Vector2(new_size, new_size)
	if _is_mini:
		_apply_mode()


func set_opacity(new_opacity: float) -> void:
	minimap_opacity = clampf(new_opacity, 0.3, 1.0)
	queue_redraw()


func set_zoom_value(new_zoom: float) -> void:
	if _camera:
		_camera.size = clampf(new_zoom, _zoom_min, _zoom_max)


func get_zoom_value() -> float:
	return _camera.size if _camera else 60.0


func _apply_mode() -> void:
	if _is_mini:
		custom_minimum_size = mini_size
		size = mini_size
		anchor_right = 1.0
		anchor_bottom = 1.0
		offset_left = -mini_size.x - 10
		offset_top = 10.0
		offset_right = -10.0
		offset_bottom = mini_size.y + 10.0
	else:
		var viewport_size: Vector2 = get_viewport_rect().size
		custom_minimum_size = viewport_size
		size = viewport_size
		anchor_left = 0.0
		anchor_top = 0.0
		anchor_right = 1.0
		anchor_bottom = 1.0
		offset_left = 0.0
		offset_top = 0.0
		offset_right = 0.0
		offset_bottom = 0.0
	if _viewport:
		_viewport.size = Vector2i(int(custom_minimum_size.x), int(custom_minimum_size.y))


func _setup_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "MapViewport"
	_viewport.size = Vector2i(int(mini_size.x), int(mini_size.y))
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.handle_input_locally = false
	add_child(_viewport)

	_camera = Camera3D.new()
	_camera.name = "TopDownCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 60.0
	_camera.position = Vector3(0, 40, 0)
	_camera.rotation_degrees.x = -90.0
	_camera.current = false
	_viewport.add_child(_camera)


func _find_track_and_cars() -> void:
	_track_node = get_tree().current_scene.get_node_or_null("TestTrack")
	if _track_node:
		_spawn_track_outline()
	_refresh_car_nodes()


func _refresh_car_nodes() -> void:
	_car_nodes.clear()
	for car in get_tree().get_nodes_in_group("race_car"):
		_car_nodes.append(car)
		if car.has_method("is_local") and car.is_local():
			_player_car = car
		elif _player_car == null and car.has_method("_is_local") and car._is_local():
			_player_car = car
	if _player_car == null and _car_nodes.size() > 0:
		_player_car = _car_nodes[0]


func _spawn_track_outline() -> void:
	if not _track_node:
		return
	var racing_line: Path3D = _track_node.get_node_or_null("RacingLine")
	if racing_line and racing_line.curve and racing_line.curve.get_point_count() > 1:
		var points_2d: PackedVector2Array = PackedVector2Array()
		for i in range(racing_line.curve.get_point_count()):
			var p3d: Vector3 = racing_line.curve.get_point_position(i)
			points_2d.append(Vector2(p3d.x, p3d.z))
		var line := Line2D.new()
		line.name = "TrackLine"
		line.width = 3.0
		line.default_color = TRACK_COLOR
		line.points = points_2d
		line.closed = true
		_viewport.add_child(line)
	else:
		var track_meshes: Node3D = _track_node.get_node_or_null("TrackPieces")
		if track_meshes:
			for child in track_meshes.get_children():
				if child is MeshInstance3D:
					_add_mesh_outline(child)


func _add_mesh_outline(mesh_instance: MeshInstance3D) -> void:
	var mesh: Mesh = mesh_instance.mesh
	if mesh == null:
		return
	var faces: PackedVector3Array = mesh.get_faces()
	if faces.size() == 0:
		return
	var line := Line2D.new()
	line.name = "TrackOutline_%s" % mesh_instance.name
	line.width = 2.0
	line.default_color = Color(0.4, 0.4, 0.5, 0.5)
	var seen_edges: Dictionary = {}
	var edge_list: Array = []
	for i in range(0, faces.size(), 3):
		for j in range(3):
			var v1: Vector3 = faces[i + j] * mesh_instance.global_transform
			var v2: Vector3 = faces[i + (j + 1) % 3] * mesh_instance.global_transform
			var key1: String = "%.1f_%.1f_%.1f|%.1f_%.1f_%.1f" % [v1.x, v1.y, v1.z, v2.x, v2.y, v2.z]
			var key2: String = "%.1f_%.1f_%.1f|%.1f_%.1f_%.1f" % [v2.x, v2.y, v2.z, v1.x, v1.y, v1.z]
			if not seen_edges.has(key1) and not seen_edges.has(key2):
				seen_edges[key1] = true
				edge_list.append(Vector2(v1.x, v1.z))
				edge_list.append(Vector2(v2.x, v2.z))
	if edge_list.size() > 0:
		line.points = edge_list
	_viewport.add_child(line)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, custom_minimum_size)
	draw_rect(rect, Color(BG_COLOR.r, BG_COLOR.g, BG_COLOR.b, BG_COLOR.a * minimap_opacity), true)

	draw_cardinal_directions()

	if _camera and _player_car and is_instance_valid(_player_car):
		_draw_player_arrow()
		_draw_bot_markers()
		_draw_offscreen_markers()


func draw_cardinal_directions() -> void:
	var vp_size: Vector2 = custom_minimum_size
	var font := ThemeDB.fallback_font
	var font_size: int = 10
	var label_offset: float = 4.0

	var north_pos := Vector2(vp_size.x * 0.5, label_offset)
	draw_string(font, north_pos, "N", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, CARDINAL_NORTH_COLOR)

	var south_pos := Vector2(vp_size.x * 0.5, vp_size.y - label_offset - font_size)
	draw_string(font, south_pos, "S", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, CARDINAL_COLOR)

	var west_pos := Vector2(label_offset, vp_size.y * 0.5 - font_size * 0.5)
	draw_string(font, west_pos, "W", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, CARDINAL_COLOR)

	var east_pos := Vector2(vp_size.x - label_offset - font_size * 0.5, vp_size.y * 0.5 - font_size * 0.5)
	draw_string(font, east_pos, "E", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, CARDINAL_COLOR)


func _draw_player_arrow() -> void:
	if not _player_car or not is_instance_valid(_player_car):
		return

	var vp_size: Vector2 = custom_minimum_size
	var center := vp_size * 0.5

	var car_fwd: Vector3 = -_player_car.global_transform.basis.z
	var angle_2d: float = atan2(car_fwd.x, car_fwd.z)

	var arrow_size: float = 12.0
	var tip := center + Vector2(sin(angle_2d), -cos(angle_2d)) * arrow_size
	var left := center + Vector2(sin(angle_2d + 2.5), -cos(angle_2d + 2.5)) * arrow_size * 0.6
	var right := center + Vector2(sin(angle_2d - 2.5), -cos(angle_2d - 2.5)) * arrow_size * 0.6

	var shadow_offset := Vector2(1.5, 1.5)
	draw_colored_polygon(
		PackedVector2Array([tip + shadow_offset, left + shadow_offset, right + shadow_offset]),
		Color(0, 0, 0, 0.4)
	)

	draw_colored_polygon(
		PackedVector2Array([tip, left, right]),
		PLAYER_COLOR
	)

	draw_circle(center, 3.0, Color(1, 1, 1, 0.8))


func _draw_bot_markers() -> void:
	if not _camera or not _player_car:
		return

	var vp_size: Vector2 = custom_minimum_size
	var cam_pos: Vector3 = _camera.global_position
	var view_half: float = _camera.size * 0.5

	for car in _car_nodes:
		if car == _player_car:
			continue
		if not is_instance_valid(car):
			continue

		var rel: Vector3 = car.global_position - cam_pos
		var screen_x: float = (rel.x / view_half) * (vp_size.x * 0.5) + vp_size.x * 0.5
		var screen_y: float = (rel.z / view_half) * (vp_size.y * 0.5) + vp_size.y * 0.5

		var in_bounds: bool = (screen_x >= 0 and screen_x <= vp_size.x and screen_y >= 0 and screen_y <= vp_size.y)
		if not in_bounds:
			continue

		var dot_pos := Vector2(screen_x, screen_y)
		draw_circle(dot_pos, 4.0, BOT_COLOR)
		draw_circle(dot_pos, 2.0, Color(1, 1, 1, 0.6))


func _draw_offscreen_markers() -> void:
	if not _camera or not _player_car:
		return

	var vp_size: Vector2 = custom_minimum_size
	var center := vp_size * 0.5
	var cam_pos: Vector3 = _camera.global_position
	var view_half: float = _camera.size * 0.5
	var margin: float = 12.0

	for car in _car_nodes:
		if car == _player_car:
			continue
		if not is_instance_valid(car):
			continue

		var rel: Vector3 = car.global_position - cam_pos
		var screen_x: float = (rel.x / view_half) * (vp_size.x * 0.5) + vp_size.x * 0.5
		var screen_y: float = (rel.z / view_half) * (vp_size.y * 0.5) + vp_size.y * 0.5

		var in_bounds: bool = (screen_x >= 0 and screen_x <= vp_size.x and screen_y >= 0 and screen_y <= vp_size.y)
		if in_bounds:
			continue

		var to_car: Vector2 = Vector2(screen_x, screen_y) - center
		if to_car.length() < 0.001:
			continue
		var dir: Vector2 = to_car.normalized()

		var min_dim: float = minf(vp_size.x, vp_size.y)
		var clamped_pos: Vector2 = center + dir * (min_dim * 0.5 - margin)

		draw_circle(clamped_pos, 5.0, Color(BOT_COLOR.r, BOT_COLOR.g, BOT_COLOR.b, 0.5))
		draw_circle(clamped_pos, 3.0, Color(1, 1, 1, 0.3))

		var arrow_tip := clamped_pos + dir * 6.0
		var perp := Vector2(-dir.y, dir.x)
		var arrow_left := clamped_pos - dir * 3.0 + perp * 3.0
		var arrow_right := clamped_pos - dir * 3.0 - perp * 3.0
		draw_colored_polygon(
			PackedVector2Array([arrow_tip, arrow_left, arrow_right]),
			Color(BOT_COLOR.r, BOT_COLOR.g, BOT_COLOR.b, 0.5)
		)
