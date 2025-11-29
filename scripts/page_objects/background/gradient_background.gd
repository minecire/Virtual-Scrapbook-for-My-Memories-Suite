extends PageObject

var page_size
var data = null
var aspect_ratio
var path

var canvas_width
var canvas_height

func initialize_variables(_type, data_, path_, page_size_, _page_type, canvas_width_, canvas_height_, _section_index):
	
	page_size = page_size_
	data = data_
	path = path_
	
	canvas_width = canvas_width_
	canvas_height = canvas_height_
	aspect_ratio = canvas_height / canvas_width

func _ready():
	$Texture.texture = util_Color.getGradient(data["GradientDefinition"], canvas_width / 5., canvas_height / 5.)
	$Texture.size = page_size
	
	if(data.has("imageopacity")):
		$Texture.self_modulate.a = data["imageopacity"].to_float()
	
