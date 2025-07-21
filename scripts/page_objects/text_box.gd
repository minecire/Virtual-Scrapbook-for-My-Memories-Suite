extends RichTextLabel

static var scrapbookData = []
var sectionIndex
var pageSize
var leftPagePos = Vector2(0., 0.)
var rightPagePos = Vector2(0., 0.)

var pageType

func _ready():
	Input.set_custom_mouse_cursor(load("res://cursor.png"), Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(load("res://cursor.png"), Input.CURSOR_POINTING_HAND)
	Input.set_custom_mouse_cursor(load("res://cursor_pointing.png"), Input.CURSOR_CROSS)

func _process(_dt):
	leftPagePos = Vector2(get_viewport().get_visible_rect().size.x / 2.0 - pageSize.x, (get_viewport().get_visible_rect().size.y / 2.0 - pageSize.y / 2.0) / 2.0)
	rightPagePos = Vector2(get_viewport().get_visible_rect().size.x / 2.0, (get_viewport().get_visible_rect().size.y / 2.0 - pageSize.y / 2.0) / 2.0)
func _gui_input(event):
	if(pageType == util_Enums.pageType.LEFT):
		event.position -= leftPagePos
		
		var normalizedPosition = event.position / pageSize
		normalizedPosition.y += log(1. - normalizedPosition.x) * 0.004
		
		event.position = normalizedPosition * pageSize
	else:
		event.position -= rightPagePos
		
		var normalizedPosition = event.position / pageSize
		normalizedPosition.y += log(normalizedPosition.x) * 0.004
		
		event.position = normalizedPosition * pageSize
		

func _has_point(_point):
	if((_point.x < get_viewport().get_visible_rect().size.x / 2) == (pageType == util_Enums.pageType.LEFT)):
		return true
	
	return false
