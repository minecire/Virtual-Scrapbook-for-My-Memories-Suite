extends PageObject

var data
var page_size
var canvas_width
var canvas_height

signal reload_text

func initialize_variables(_type, data_, _path, page_size_, _page_type, canvas_width_, canvas_height_, _section_index):
	data = data_
	page_size = page_size_
	canvas_width = canvas_width_
	canvas_height = canvas_height_

func _ready():
	# Set up basic position scale and rotation, rescaling from the canvas scale to page scale
	$LineTexture.position = Vector2(data["startX"].to_int(), data["startY"].to_int()) * page_size.y / canvas_height
	$LineTexture.size = Vector2(data["width"].to_int(), data["height"].to_int()) * page_size.y / canvas_height
	if(data.has("rotation")):
		$LineTexture.rotation_degrees = data["rotation"].to_int()
		$LineTexture.pivot_offset = $LineTexture.size / 2.
	
	
	var svg_file = FileAccess.open("res://Shapes/line_svg.txt", FileAccess.READ)
	var svg_data = svg_file.get_as_text() # Loading in the line svg template (see Shapes/line_svg.txt)
	var col = Color.BLACK
	if(data.has("fillColor")):
		var color_value = data["fillColor"].to_int()
		if(color_value < 0):
			col = util_Color.getColorFromNegative(color_value)
		else: # Sometimes the number *is* stored as an unsigned integer when it has alpha, so we gotta do this
			col = util_Color.getColorFromNegative(-16777216+(color_value % (256 * 256 * 256)))
			col.a = float(color_value) / (256 * 256 * 256 * 256)
	var new_svg_data = svg_data.replace( # Replace each element in the template with the proper value
		"{IMAGE_WIDTH}", data["width"]).replace(
		"{IMAGE_HEIGHT}", data["height"]).replace(
		"{STROKE_WEIGHT}", str(data["outlineThickness"].to_int())).replace(
		"{STROKE_COLOR}", "#" + col.to_html(false)).replace(
		"{LINE_DATA}", data["svgPathData"])
	var img = Image.new()
	# Now we need to load in the SVG
	# This essentially rasterizes it to a normal texture
	img.load_svg_from_string(new_svg_data, 1.0)
	img.load_svg_from_string(new_svg_data, $LineTexture.size.x / img.get_width())
	var tex = ImageTexture.create_from_image(img)
	$LineTexture.texture = tex
	$LineTexture.self_modulate.a = col.a
	
	if(data.has("id")): # Text can also be attached to line objects, in which case it follows a curve
		var held_text_instance = util_Preloader.heldTextInstances[data["id"]].duplicate()
		# Set held text instance data
		held_text_instance.page_size = page_size
		held_text_instance.data = util_Preloader.heldTextInstances[data["id"]].data.duplicate()
		held_text_instance.canvas_width = canvas_width
		held_text_instance.canvas_height = canvas_height
		held_text_instance.path = util_Preloader.heldTextInstances[data["id"]].path
		held_text_instance.shapedata = util_Preloader.heldTextInstances[data["id"]].shapedata
		add_child(held_text_instance)
		
		# Silly signal method to reload the text
		reload_text.connect(held_text_instance.reload)
		emit_signal("reload_text")
		reload_text.disconnect(held_text_instance.reload)
