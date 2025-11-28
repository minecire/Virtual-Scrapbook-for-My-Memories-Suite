extends PageObject

var page_size
var data = null

func initialize_variables(_type, data_, _path, page_size_, _page_type, _canvas_width, _canvas_height, _section_index):

	page_size = page_size_
	data = data_

func _ready():
	if(data == null):
		return
	var color_data = data["fillColor"]
	
	var _opacity = 1
	if(data.has("imageopacity")):
		_opacity = data["imageopacity"].to_float()
	
	$ColorPanel.color = util_Color.get_color_from_negative(color_data.to_int())
	$ColorPanel.size = page_size
	$ColorPanel.position = Vector2(0, 0)
