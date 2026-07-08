extends Node

enum TransitionType { FADE_BLACK, FADE_WHITE, INSTANT }

var _loading_scene_path: String = ""
var _overlay: ColorRect = null
var _tween: Tween = null
var _current_scene: Node = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_overlay()
	_current_scene = get_tree().root.get_child(get_tree().root.get_child_count() - 1)

func goto_scene(path: String, transition: TransitionType = TransitionType.FADE_BLACK):
	if transition == TransitionType.INSTANT:
		_swap_scene(path)
		return
	_start_transition(path, transition)

func reload_current_scene(transition: TransitionType = TransitionType.FADE_BLACK):
	goto_scene(_current_scene.scene_file_path, transition)

func _create_overlay():
	_overlay = ColorRect.new()
	_overlay.name = "__SceneTransitionOverlay"
	_overlay.color = Color.BLACK
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = 999
	var canvas = CanvasLayer.new()
	canvas.add_child(_overlay)
	get_tree().root.add_child.call_deferred(canvas)
	_overlay.hide()

func _start_transition(path: String, type: TransitionType):
	var target_color := Color.WHITE if type == TransitionType.FADE_WHITE else Color.BLACK
	_overlay.color = target_color
	_overlay.modulate = Color.TRANSPARENT
	_overlay.show()
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_overlay, "modulate", Color.WHITE, 0.15)
	_tween.tween_callback(_swap_scene.bind(path))
	_tween.tween_interval(0.05)
	_tween.tween_property(_overlay, "modulate", Color.TRANSPARENT, 0.15)
	_tween.tween_callback(_overlay.hide)

func _swap_scene(path: String):
	var new_scene = load(path)
	if new_scene == null:
		return
	var instance = new_scene.instantiate()
	get_tree().root.add_child(instance)
	if _current_scene:
		_current_scene.queue_free()
	_current_scene = instance
	get_tree().current_scene = instance
