extends SubViewport

# This file handles the rendering of a single page
# This is the heart of the My Memories Suite techical debt jank

@export var path: String;
@export var file: String;
@export var page_name: String;
@export var page_size: Vector2;
@export var pos: Vector2;

var page_index = 0
var section_index = 0

#Preload scenes to be used later
var image_background_scene = preload("res://scenes/pageobjects/image_background.tscn")
var color_background_scene = preload("res://scenes/pageobjects/color_background.tscn")
var image_scene = preload("res://scenes/pageobjects/image.tscn")
var text_scene = preload("res://scenes/pageobjects/j_word_text.tscn")
var line_scene = preload("res://scenes/pageobjects/line.tscn")
var word_art_scene = preload("res://scenes/pageobjects/word_art.tscn")

var aspect_ratio: float;

var max_output_width: int; #Variables used for calculations later
var max_output_height: int;

#Size that MMS considers the page to be
# (This is very different from the actual size of the page, which is dependent on window size)
var canvas_width: int;
var canvas_height: int;

var num_pages = -1

var page_type : util_Enums.page_type;

signal go_to_section # Emitted to tell the book to go to a section
signal reload_text # Used to refresh textboxes

#object types: background, image, jwordtext, textart, line, calendar, shape
#    todo: 
#word art
#calendar(low priority)
#images(low priority): shadow resize, mask subtexture bullshit, shape rotation, fix bug with multiple shapes with different stretch on one page
#text(low priority): a few missing fonts, bold/italics failing on some fonts, rotation on curves

var id;

func _ready():
	set_canvas_cull_mask_bit(2, false);


func load_page(): # Called to reload a page
	parse_full_page() # Loops through to add elements
	
	if get_children().size() == 0: 
		# If page is blank, at least add a background
		var cbi = color_background_scene.instantiate()
		cbi.size = page_size
		cbi.color = Color(0.9, 0.83, 0.8)
		add_child(cbi)
	
	for node in get_children(): 
		# SubViewports don't have a position, so we have to kind-of awkwardly loop through 
		# and update the position of each child node.
		for node2 in node.get_children():
			if(!node2.get_class() == "Node" && !node2.get_class() == "RichTextLabel" && !node2.get_class() == "SubViewport"):
				node2.position += pos
		if(!node.get_class() == "Node"):
			node.position += pos
func calculate_missing_data():
	# MMS files do not store the canvas height or aspect ratio
	# But they do store "max output width" and height variables that have the same ratio
	# So we can calculate it ourselves
	aspect_ratio = float(max_output_width) / float(max_output_height)
	canvas_height = int(canvas_width / aspect_ratio)
func parse_full_page():
	# Get some global data
	num_pages = util_Preloader.scrapbookData[section_index]["num_pages"]
	canvas_width = util_Preloader.scrapbookData[section_index]["canvas_width"]
	max_output_width = util_Preloader.scrapbookData[section_index]["max_output_width"]
	max_output_height = util_Preloader.scrapbookData[section_index]["max_output_height"]
	
	# Parse the individual page's data
	if(page_index < util_Preloader.scrapbookData[section_index]["pages"].size()):
		parse_page(util_Preloader.scrapbookData[section_index]["pages"][page_index])
func parse_page(data):
	calculate_missing_data()
	for object in data["objects"]: # Parse each object one at a time
		parse_page_object(object)

func parse_page_object(object):
	var type = object["type"] # Type of object
	var data = object["data"] # Data direct from the MMS file
	
	# MMS background conventions use an integer "type" variable for each type of background
	# Get used to these arbitrary numbers, the MMS file has a lot of them
	# 1 - Solid Color
	# 2 - Image
	# 3 - Pattern (Unclear what the distinction between pattern and image is)
	# 4 - Gradient
	if(type == "background" && data["type"] == "1"):
		parse_color_background(data)
	elif(type == "background" && (data["type"] == "2" || data["type"] == "3")):
		parse_image_background(data)
	elif(type == "background" && data["type"] == "4"):
		parse_gradient_background(data)
	
	# A lot of different things are basically just different names for an image
	# (with just enough variation of definitions to make the image parser a mess of edge cases,
	# but not quite enough variation of functionality to justify separating anything else out)
	elif(type == "image" || type == "embellishment" || type == "stamp" || type == "paint" || type == "shape"):
		parse_image(data, type)
	elif(type == "line"): # A multi-segment spline defined by an SVG path
		parse_line(data)
	elif(type == "jWordText"): # Textbox with some fancy formatting
		parse_text(data)
	elif(type == "textArt"): # Word art
		parse_text_art(data)
	elif(type != "spanner"): # Spanners are a special object for any object that spans multiple pages.
		# They are handled in the initial preload step
		push_warning("unsupported datatype: " + type) # Otherwise we have an unsupported datatype
		# Effectively only calendars are unsupported,
		# But intriguingly, the MMS codebase does suggest that the file format is include to handle videos,
		# plaintext, links, and more, although MMS itself has no way to use these features
		
func parse_color_background(data): # Background of a solid color
	var color_background_instance = color_background_scene.instantiate()
	var color_data = data["fillColor"]
	
	var _opacity = 1
	if(data.has("imageopacity")):
		_opacity = data["imageopacity"].to_float()
	var color_value = 16777216 + color_data.to_int() # Convert color from a negative integer to a hex value
	# It's actually just the RGB value, but written as an unsigned integer rather than a signed one, 
	# and stored in decimal rather than hex, leading to this odd conversion where we subtract it from 2^24
	var color_code = "#" + ( "%6X" % color_value )
	var main_color = Color(color_code)
	
	color_background_instance.color = main_color
	color_background_instance.size = page_size
	color_background_instance.position = Vector2(0, 0)
	add_child(color_background_instance)

func parse_image_background(data): # Background from image
	var image_background_instance = image_background_scene.instantiate()
	var filename = data["fileName"]
	var image_path = path+"objects/"+filename
	var image_background_instance_texture = image_background_instance.get_node("Texture")
	var image_texture
	if(util_Preloader.imagesDict.has(filename)):
		image_texture = util_Preloader.imagesDict[filename]
	else:
		image_texture = ImageTexture.create_from_image(Image.load_from_file(image_path))
	var image_atlas : AtlasTexture = AtlasTexture.new() # We need an image atlas to crop the image
	image_atlas.atlas = image_texture
	var region = Rect2()
	
	# We are baffled by trying to set the image region properly. The numbers don't quite seem to ever line up.
	# This is as close as we got, and it's a total mess
	if(aspect_ratio <= float(image_texture.get_width()) / float(image_texture.get_height())): 
		# Preserve image as unstretched if unscaled
		region.size.x = aspect_ratio * image_texture.get_height()
		region.position.x = (image_texture.get_width() - region.size.x) / 2.0
	else:
		region.size.y = image_texture.get_height() / aspect_ratio
		region.position.y = (image_texture.get_width() - region.size.x) / 2.0
	if(data.has("SubImage") && data["SubImage"] == "true"):
		# Nonsense, idk. It kinda works? 
		# Every time I try to redo this from scratch I come up with something equally upsetting to look at
		# I think? The stored values are like. The position and scale of a rescaled image 
		# such that the original image shape and size would be the proper scale
		# But the math doesn't quite work out for that.
		if(aspect_ratio <= float(image_texture.get_width()) / float(image_texture.get_height())):
			if(data["sW"].to_int() != 0):
				region.size.x = region.size.x * region.size.x / (region.size.x + float(data["sW"].to_int()))
			if(data["sH"].to_int() != 0):
				region.size.y = image_texture.get_height() * image_texture.get_height() /(image_texture.get_height() + float(data["sH"].to_int()))
			region.position.x = (-float(data["sX"].to_int()) * region.size.y / float(image_texture.get_height()) + image_texture.get_width()/2. - image_texture.get_height() * aspect_ratio / 2.)
			region.position.y = - data["sY"].to_int() * region.size.y / image_texture.get_height()
		else:
			region.size.y = image_texture.get_height() / aspect_ratio - data["sH"].to_int() * canvas_height / image_texture.get_height()
			region.position.y = (image_texture.get_width() - region.size.x) / 2.0 + data["sY"].to_int() * canvas_height / image_texture.get_height()
		
	
	if(data.has("mirror")):
		image_background_instance_texture.flip_h = data["mirror"] == "true"
	if(data.has("flip")):
		image_background_instance_texture.flip_v = data["flip"] == "true"
	if(data.has("rotation")):
		image_background_instance_texture.rotation_degrees = data["rotation"].to_float()
	if(data.has("imageopacity")):
		image_background_instance_texture.self_modulate.a = data["imageopacity"].to_float()
	image_atlas.region = region
	
	image_background_instance_texture.texture = image_atlas # Set the texture properly
	
	image_background_instance_texture.pivot_offset = page_size / 2 # Center of page
	image_background_instance_texture.position = Vector2(0, 0)
	image_background_instance_texture.size = page_size
	image_background_instance.get_node("ColorRect").size = page_size
	image_background_instance.get_node("ColorRect").position = Vector2(0, 0)
	add_child(image_background_instance)

func getGradient(raw_gradient_data, width, height):
	# Little utility function to convert the gradient storage format
	# into a Godot gradient texture
	
	var gradient_data = raw_gradient_data.split("~") # Gradients use tilde to separate parts
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.width = width
	gradient_texture.height = height
	if(gradient_data[0] == "linearGradient"): # First whether the gradient is linear or radial
		gradient_texture.fill = GradientTexture2D.FILL_LINEAR
	else:
		gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	
	# Then the start and end points of the gradient
	# Further separated into 2D coordinates by backtick
	var gradient_from_data = gradient_data[1].split("`") 
	var gradient_from = Vector2(gradient_from_data[0].to_float(), gradient_from_data[1].to_float()) / Vector2(width, height)
	var gradient_to_data = gradient_data[2].split("`")
	var gradient_to = Vector2(gradient_to_data[0].to_float(), gradient_to_data[1].to_float()) / Vector2(width, height)
	gradient_texture.fill_from = gradient_from
	gradient_texture.fill_to = gradient_to
	
	# Then colors in that odd negative number format, again separated by backticks
	var gradient_colors_data = gradient_data[3].split("`")
	var gradient_colors = PackedColorArray()
	for col in gradient_colors_data:
		gradient_colors.append(getColorFromNegative(col.to_int()))
	gradient_texture.gradient = Gradient.new()
	gradient_texture.gradient.colors = gradient_colors
	
	# Then the offsets from 0 to 1 along the gradient each point is at
	var gradient_offset_data = gradient_data[4].split("`")
	var gradient_offsets = []
	for offset in gradient_offset_data:
		gradient_offsets.append(offset.to_float())
	gradient_texture.gradient.offsets = gradient_offsets
	if(gradient_data[5] == "NO_CYCLE"): # And finally the way in which the gradient repeats (or doesn't)
		gradient_texture.repeat = GradientTexture2D.REPEAT_NONE
	if(gradient_data[5] == "REFLECT"):
		gradient_texture.repeat = GradientTexture2D.REPEAT_MIRROR
	else:
		gradient_texture.repeat = GradientTexture2D.REPEAT
	return gradient_texture

func parse_gradient_background(data):
	var image_background_instance = image_background_scene.instantiate()
	var image_background_instance_texture = image_background_instance.get_node("Texture")
	image_background_instance_texture.texture = getGradient(data["GradientDefinition"], canvas_width / 5., canvas_height / 5.)
	image_background_instance_texture.size = page_size
	
	if(data.has("imageopacity")):
		image_background_instance_texture.self_modulate.a = data["imageopacity"].to_float()
	
	add_child(image_background_instance)
	
	pass
func parse_image(data, type):
	var image_instance = image_scene.instantiate()
	# Set image data and add to scene, the image scene itself handles the rest
	image_instance.page_size = page_size
	image_instance.canvas_width = canvas_width
	image_instance.canvas_height = canvas_height
	image_instance.path = path
	image_instance.data = data
	image_instance.type = type
	add_child(image_instance)
	if(data.has("id")): 
		# An image with an id means that the image has text attached to it
		# niche feature where you can combine a 'shape' type image with text
		# and the text will fill the shape
		var held_text_instance = util_Preloader.heldTextInstances[data["id"]].duplicate() 
		# It's possible that the image is being parsed before the text would be
		# so we simply generate all the text instances beforepaw in the preload step
		# so they're here when we need them
		
		held_text_instance.page_size = page_size # Adding info that wasn't available during preload
		held_text_instance.canvas_width = canvas_width
		held_text_instance.canvas_height = canvas_height
		
		# Duplicate is not recursive so we need to duplicate the data ourselves
		held_text_instance.data = util_Preloader.heldTextInstances[data["id"]].data.duplicate()
		held_text_instance.path = util_Preloader.heldTextInstances[data["id"]].path
		held_text_instance.shapedata = util_Preloader.heldTextInstances[data["id"]].shapedata
		add_child(held_text_instance)
		
		# We need to tell the text instance to reload now, which requires a whole signal system
		# because communication between nodes has to be complicated
		reload_text.connect(held_text_instance.reload)
		emit_signal("reload_text")
		reload_text.disconnect(held_text_instance.reload)
	
func parse_text(data): 
	# Much like with images, parsing text requires just setting some things and letting the object handle itself
	get_tree().root.get_viewport().set_canvas_cull_mask_bit(2, false);
	var text_instance = text_scene.instantiate()
	text_instance.page_size = page_size
	text_instance.canvas_width = canvas_width
	text_instance.get_node("TextBox").section_index = section_index
	if(canvas_width == 0):
		text_instance.canvas_width = page_size.x
	text_instance.canvas_height = canvas_height
	text_instance.path = path
	text_instance.data = data
	text_instance.go_to_section.connect(_on_text_go_to_section)
	if(data.has("id")): 
		# Loading text with an id also causes problems because it creates duplicate instances
		text_instance.shapedata = util_Preloader.iddshapes[data["id"]]
		#util_Preloader.heldTextInstances[data["id"]] = text_instance
	else:
		add_child(text_instance)
	if(text_instance.hasLinks && page_type != util_Enums.page_type.TURNING && page_type != util_Enums.page_type.UNDER):
		# If we have links, we need to make an invisible copy of the textbox that is clickable
		# Because subviewports don't like to handle inputs
		# Unless this page is currently turning or under another page
		
		var text_instance_2 = text_scene.instantiate()
		text_instance_2.page_size = page_size
		text_instance_2.canvas_width = canvas_width
		text_instance_2.get_node("TextBox").page_type = page_type
		
		if(canvas_width == 0):
			text_instance_2.canvas_width = page_size.x
		text_instance_2.canvas_height = canvas_height
		text_instance_2.path = path
		text_instance_2.data = data
		text_instance_2.get_node("TextBox").section_index = section_index
		text_instance_2.go_to_section.connect(_on_text_go_to_section)
		text_instance_2.go_to_page.connect(_on_text_go_to_page)
		text_instance_2.get_node("TextBox").input.connect(get_tree().get_root().get_node("Book/SwipeDetecter")._input)
		text_instance_2.get_node("TextBox").set_modulate(Color(1., 1., 1., 0.))
		
		# Add to the clickables holder node in the book scene
		get_tree().get_root().get_node("Book/ClickablesHolder").add_child(text_instance_2)

func getColorFromNegative(val): 
	# Convert the silly negative number color representation to something Godot can interpret
	var negative_value = 16777216 + val
	
	# Not sure Godot is smart enough to do this with bitshifts
	# But that doesn't matter too much since this function doesn't get run too often
	var red = float(floor(negative_value / (256 * 256))) 
	var green = float(floor(negative_value / (256) % 256))
	var blue = float(floor(negative_value % 256))
	return Color(red / 256., green / 256., blue / 256.)
	
func parse_line(data): # Line is stored as a part of an SVG object
	var line_instance = line_scene.instantiate()
	
	# Set up basic position scale and rotation, rescaling from the canvas scale to page scale
	line_instance.position = Vector2(data["startX"].to_int(), data["startY"].to_int()) * page_size.y / canvas_height
	line_instance.size = Vector2(data["width"].to_int(), data["height"].to_int()) * page_size.y / canvas_height
	if(data.has("rotation")):
		line_instance.rotation_degrees = data["rotation"].to_int()
		line_instance.pivot_offset = line_instance.size / 2.
	
	
	var svg_file = FileAccess.open("res://Shapes/line_svg.txt", FileAccess.READ)
	var svg_data = svg_file.get_as_text() # Loading in the line svg template (see Shapes/line_svg.txt)
	var col = Color.BLACK
	if(data.has("fillColor")):
		var color_value = data["fillColor"].to_int()
		if(color_value < 0):
			col = getColorFromNegative(color_value)
		else: # Sometimes the number *is* stored as an unsigned integer when it has alpha, so we gotta do this
			col = getColorFromNegative(-16777216+(color_value % (256 * 256 * 256)))
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
	img.load_svg_from_string(new_svg_data, line_instance.size.x / img.get_width())
	var tex = ImageTexture.create_from_image(img)
	line_instance.texture = tex
	line_instance.self_modulate.a = col.a
	add_child(line_instance)
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


func parse_text_art(data): # Word art
	var word_art_instance = word_art_scene.instantiate()
	word_art_instance.data = data
	word_art_instance.path = path
	word_art_instance.page_size = page_size
	word_art_instance.canvas_width = canvas_width
	
	add_child(word_art_instance)
	
func _on_book_page_update() -> void: # Run on signal from book to reload
	# Clear out the page
	for n in get_children():
		remove_child(n)
		n.free()
	
	# Then reload it
	load_page()


func _on_text_go_to_section(section): # Emitted when a page link is clicked
	emit_signal("go_to_section", section, 1)


func _on_text_go_to_page(section, page): # Emitted when a page link is clicked
	emit_signal("go_to_section", section, page)
