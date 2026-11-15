extends SubViewportContainer

## Small rotating GLB preview. Drag horizontally to inspect the avatar from every side.
var avatar_model: Node3D
var _dragging := false
var _touch_index := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_dragging = true
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_dragging = false
		accept_event()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_rotate_avatar(event.relative.x)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_rotate_avatar(event.relative.x)
		accept_event()

func _process(delta: float) -> void:
	if avatar_model != null and not _dragging:
		avatar_model.rotate_y(delta * 0.22)

func _rotate_avatar(horizontal_motion: float) -> void:
	if avatar_model != null:
		avatar_model.rotate_y(horizontal_motion * 0.012)
