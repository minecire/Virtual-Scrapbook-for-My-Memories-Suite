extends RichTextLabel

static var scrapbookData = []
var section_index
var page_size
var leftPagePos = Vector2(0., 0.)
var rightPagePos = Vector2(0., 0.)

var page_type

func _ready():
	Input.set_custom_mouse_cursor(load("res://icons/cursor.png"), Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(load("res://icons/cursor.png"), Input.CURSOR_POINTING_HAND)
	Input.set_custom_mouse_cursor(load("res://icons/cursor_pointing.png"), Input.CURSOR_CROSS)

func _process(_dt):
	leftPagePos = Vector2(get_viewport().get_visible_rect().size.x / 2.0 - page_size.x, (get_viewport().get_visible_rect().size.y / 2.0 - page_size.y / 2.0) / 2.0)
	rightPagePos = Vector2(get_viewport().get_visible_rect().size.x / 2.0, (get_viewport().get_visible_rect().size.y / 2.0 - page_size.y / 2.0) / 2.0)
func _gui_input(event):
	#emit_signal("input", event.duplicate())
	if(page_type == util_Enums.page_type.LEFT):
		event.position -= leftPagePos
		
		var normalizedPosition = event.position / page_size
		normalizedPosition.y += log(1. - normalizedPosition.x) * 0.004
		
		event.position = normalizedPosition * page_size
	else:
		event.position -= rightPagePos
		
		var normalizedPosition = event.position / page_size
		normalizedPosition.y += log(normalizedPosition.x) * 0.004
		
		event.position = normalizedPosition * page_size

func _has_point(_point):
	if((_point.x < get_viewport().get_visible_rect().size.x / 2) == (page_type == util_Enums.page_type.LEFT)):
		return true
	
	return false
