extends Control

@export var mini_size: Vector2 = Vector2(180, 180)
@export var full_size: Vector2 = Vector2(0, 0)
@export var zoom: float = 0.15

var _viewport: SubViewport
var _camera: Camera3D
var _is_mini: bool = true
var _track_node: Node3D = null
var _car_nodes: Array[Node3D] = []
var _player_car: Node3D = null

const MINI_BG_COLOR: Color = Color(0.05, 0.08, 0.15, 0.75)
const PLAYER_DOT_COLOR: Color = Color(0.1, 0.8, 0.2)
const BOT_DOT_COLOR: Color = Color(0.9, 0.3, 0.1)
const CHECKPOINT_COLOR: Color = Color(0.2, 0.6, 1.0, 0.8)


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


func set_mode(mini: bool) -> void:
	_is_mini = mini
	_apply_mode()


func toggle_mode() -> void:
	_is_mini = not _is_mini
	_apply_mode()


func is_mini() -> bool:
	return _is_mini


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
		line.default_color = Color(0.4, 0.4, 0.5, 0.6)
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
	draw_rect(Rect2(Vector2.ZERO, custom_minimum_size), MINI_BG_COLOR, true)


func _process_car_dots() -> void:
	if not _viewport or not _player_car:
		return
	for child in _viewport.get_children():
		if child is Polygon2D or child is ColorRect:
			if child.name.begins_with("CarDot"):
				child.queue_free()
	var player_pos: Vector3 = _player_car.global_position
	var cam_pos: Vector3 = _camera.global_position if _camera else Vector3.ZERO
	var view_half: float = _camera.size * 0.5 if _camera else 30.0
	var vp_size: Vector2 = custom_minimum_size
	for car in _car_nodes:
		var dot := Polygon2D.new()
		dot.name = "CarDot_%s" % car.name
		var rel: Vector3 = car.global_position - cam_pos
		var dot_x: float = (rel.x / view_half) * (vp_size.x * 0.5) + vp_size.x * 0.5
		var dot_y: float = (rel.z / view_half) * (vp_size.y * 0.5) + vp_size.y * 0.5
		var is_player: bool = (car == _player_car)
		dot.color = PLAYER_DOT_COLOR if is_player else BOT_DOT_COLOR
		var circle_points: PackedVector2Array = PackedVector2Array()
		var radius: float = 6.0 if is_player else 4.0
		for i in range(16):
			var angle: float = TAU * i / 16.0
			circle_points.append(Vector2(dot_x, dot_y) + Vector2(cos(angle), sin(angle)) * radius)
		dot.polygon = circle_points
		_viewport.add_child(dot)


func _physics_process(_delta: float) -> void:
	_process_car_dots()
