extends PanelContainer

var _standings: Array = []
var _local_car_id: int = 0

const ROW_HEIGHT: int = 26
const HEADER_HEIGHT: int = 30


func _ready() -> void:
	custom_minimum_size = Vector2(260, 0)
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = -270.0
	offset_top = 80.0
	offset_right = -10.0
	offset_bottom = 10.0
	_local_car_id = multiplayer.get_unique_id()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_style()


func _setup_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.65)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", style)


func update_standings(standings: Array) -> void:
	_standings = standings
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var y_offset: float = 6.0

	draw_string(font, Vector2(8, y_offset + 16), "CLASSIFICAÇÃO", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.8, 0.2))
	y_offset += HEADER_HEIGHT

	draw_line(Vector2(0, y_offset), Vector2(custom_minimum_size.x, y_offset), Color(1, 1, 1, 0.3), 1.0)
	y_offset += 4.0

	if _standings.is_empty():
		draw_string(font, Vector2(8, y_offset + 14), "Aguardando...", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.6, 0.6))
		return

	for i in range(_standings.size()):
		var entry: Dictionary = _standings[i]
		var car_id: int = entry.get("car_id", 0)
		var is_local: bool = (car_id == _local_car_id)
		var pos_text: String = "%dº" % (i + 1)
		var name_text: String = _get_car_name(car_id)
		var lap_text: String = "V%d" % entry.get("lap", 0)
		var best_text: String = units_manager.format_time(entry.get("best_lap_ms", 0))
		var finished: bool = entry.get("finished", false)
		if finished:
			best_text = "FIN"

		var row_color: Color = Color(1, 1, 1, 0.9) if is_local else Color(0.75, 0.75, 0.75, 0.9)
		var pos_color: Color = Color(0.2, 1.0, 0.3) if is_local else Color.WHITE

		var row_y: float = y_offset + ROW_HEIGHT * i
		if is_local:
			draw_rect(Rect2(0, row_y, custom_minimum_size.x, ROW_HEIGHT), Color(1, 1, 1, 0.08), true)

		draw_string(font, Vector2(4, row_y + 18), pos_text, HORIZONTAL_ALIGNMENT_LEFT, 30, 13, pos_color)
		draw_string(font, Vector2(36, row_y + 18), name_text, HORIZONTAL_ALIGNMENT_LEFT, 140, 12, row_color)
		draw_string(font, Vector2(170, row_y + 18), lap_text, HORIZONTAL_ALIGNMENT_LEFT, 40, 11, Color(0.6, 0.8, 1.0))
		draw_string(font, Vector2(210, row_y + 18), best_text, HORIZONTAL_ALIGNMENT_LEFT, 55, 11, Color(0.9, 0.7, 0.3))


func _get_car_name(car_id: int) -> String:
	if car_id == _local_car_id:
		return "Tu"
	for p in globals.players:
		if p.steam_id == car_id:
			return p.name if p.name != "" else "P%d" % car_id
	return "Bot %d" % car_id
