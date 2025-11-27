extends SubViewport

# This file handles the rendering of a single page
# This is the heart of the My Memories Suite techical debt jank

@export var path: String;
@export var file: String;
@export var pageName: String;
@export var pageSize: Vector2;
@export var pos: Vector2;

var pageIndex = 0
var sectionIndex = 0

#Preload scenes to be used later
var imageBackgroundScene = preload("res://scenes/pageobjects/image_background.tscn")
var colorBackgroundScene = preload("res://scenes/pageobjects/color_background.tscn")
var imageScene = preload("res://scenes/pageobjects/image.tscn")
var textScene = preload("res://scenes/pageobjects/j_word_text.tscn")
var lineScene = preload("res://scenes/pageobjects/line.tscn")
var wordArtScene = preload("res://scenes/pageobjects/word_art.tscn")

var aspectRatio: float;

var maxOutputWidth: int; #Variables used for calculations later
var maxOutputHeight: int;

#Size that MMS considers the page to be
# (This is very different from the actual size of the page, which is dependent on window size)
var canvasWidth: int;
var canvasHeight: int;

var numPages = -1

var pageType : util_Enums.pageType;

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
		var cbi = colorBackgroundScene.instantiate()
		cbi.size = pageSize
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
	aspectRatio = float(maxOutputWidth) / float(maxOutputHeight)
	canvasHeight = int(canvasWidth / aspectRatio)
func parse_full_page():
	# Get some global data
	numPages = util_Preloader.scrapbookData[sectionIndex]["numPages"]
	canvasWidth = util_Preloader.scrapbookData[sectionIndex]["canvasWidth"]
	maxOutputWidth = util_Preloader.scrapbookData[sectionIndex]["maxOutputWidth"]
	maxOutputHeight = util_Preloader.scrapbookData[sectionIndex]["maxOutputHeight"]
	
	# Parse the individual page's data
	if(pageIndex < util_Preloader.scrapbookData[sectionIndex]["pages"].size()):
		parse_page(util_Preloader.scrapbookData[sectionIndex]["pages"][pageIndex])
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
	var colorBackgroundInstance = colorBackgroundScene.instantiate()
	var colordata = data["fillColor"]
	
	var opacity = 1
	if(data.has("imageopacity")):
		opacity = data["imageopacity"].to_float()
	var colorvalue = 16777216 + colordata.to_int() # Convert color from a negative integer to a hex value
	# It's actually just the RGB value, but written as an unsigned integer rather than a signed one, 
	# and stored in decimal rather than hex, leading to this odd conversion where we subtract it from 2^24
	var colorcode = "#" + ( "%6X" % colorvalue )
	var maincolor = Color(colorcode)
	
	colorBackgroundInstance.color = maincolor
	colorBackgroundInstance.size = pageSize
	colorBackgroundInstance.position = Vector2(0, 0)
	add_child(colorBackgroundInstance)
	pass

func parse_image_background(data): # Background from image
	var imageBackgroundInstance = imageBackgroundScene.instantiate()
	var filename = data["fileName"]
	var imagePath = path+"objects/"+filename
	var ibiTexture = imageBackgroundInstance.get_node("Texture")
	var imageTexture
	if(util_Preloader.imagesDict.has(filename)):
		imageTexture = util_Preloader.imagesDict[filename]
	else:
		imageTexture = ImageTexture.create_from_image(Image.load_from_file(imagePath))
	var imageAtlas : AtlasTexture = AtlasTexture.new() # We need an image atlas to crop the image
	imageAtlas.atlas = imageTexture
	var region = Rect2()
	
	# We are baffled by trying to set the image region properly. The numbers don't quite seem to ever line up.
	# This is as close as we got, and it's a total mess
	if(aspectRatio <= float(imageTexture.get_width()) / float(imageTexture.get_height())): 
		# Preserve image as unstretched if unscaled
		region.size.x = aspectRatio * imageTexture.get_height()
		region.position.x = (imageTexture.get_width() - region.size.x) / 2.0
	else:
		region.size.y = imageTexture.get_height() / aspectRatio
		region.position.y = (imageTexture.get_width() - region.size.x) / 2.0
	if(data.has("SubImage") && data["SubImage"] == "true"):
		# Nonsense, idk. It kinda works? 
		# Every time I try to redo this from scratch I come up with something equally upsetting to look at
		# I think? The stored values are like. The position and scale of a rescaled image 
		# such that the original image shape and size would be the proper scale
		# But the math doesn't quite work out for that.
		if(aspectRatio <= float(imageTexture.get_width()) / float(imageTexture.get_height())):
			if(data["sW"].to_int() != 0):
				region.size.x = region.size.x * region.size.x / (region.size.x + float(data["sW"].to_int()))
			if(data["sH"].to_int() != 0):
				region.size.y = imageTexture.get_height() * imageTexture.get_height() /(imageTexture.get_height() + float(data["sH"].to_int()))
			region.position.x = (-float(data["sX"].to_int()) * region.size.y / float(imageTexture.get_height()) + imageTexture.get_width()/2. - imageTexture.get_height() * aspectRatio / 2.)
			region.position.y = - data["sY"].to_int() * region.size.y / imageTexture.get_height()
		else:
			region.size.y = imageTexture.get_height() / aspectRatio - data["sH"].to_int() * canvasHeight / imageTexture.get_height()
			region.position.y = (imageTexture.get_width() - region.size.x) / 2.0 + data["sY"].to_int() * canvasHeight / imageTexture.get_height()
		
	
	if(data.has("mirror")):
		ibiTexture.flip_h = data["mirror"] == "true"
	if(data.has("flip")):
		ibiTexture.flip_v = data["flip"] == "true"
	if(data.has("rotation")):
		ibiTexture.rotation_degrees = data["rotation"].to_float()
	if(data.has("imageopacity")):
		ibiTexture.self_modulate.a = data["imageopacity"].to_float()
	imageAtlas.region = region
	
	ibiTexture.texture = imageAtlas # Set the texture properly
	
	ibiTexture.pivot_offset = pageSize / 2 # Center of page
	ibiTexture.position = Vector2(0, 0)
	ibiTexture.size = pageSize
	imageBackgroundInstance.get_node("ColorRect").size = pageSize
	imageBackgroundInstance.get_node("ColorRect").position = Vector2(0, 0)
	add_child(imageBackgroundInstance)

func getGradient(rawGradientData, width, height):
	# Little utility function to convert the gradient storage format
	# into a Godot gradient texture
	
	var gradientData = rawGradientData.split("~") # Gradients use tilde to separate parts
	var gradientTexture = GradientTexture2D.new()
	gradientTexture.width = width
	gradientTexture.height = height
	if(gradientData[0] == "linearGradient"): # First whether the gradient is linear or radial
		gradientTexture.fill = GradientTexture2D.FILL_LINEAR
	else:
		gradientTexture.fill = GradientTexture2D.FILL_RADIAL
	
	# Then the start and end points of the gradient
	# Further separated into 2D coordinates by backtick
	var gradientFromData = gradientData[1].split("`") 
	var gradientFrom = Vector2(gradientFromData[0].to_float(), gradientFromData[1].to_float()) / Vector2(width, height)
	var gradientToData = gradientData[2].split("`")
	var gradientTo = Vector2(gradientToData[0].to_float(), gradientToData[1].to_float()) / Vector2(width, height)
	gradientTexture.fill_from = gradientFrom
	gradientTexture.fill_to = gradientTo
	
	# Then colors in that odd negative number format, again separated by backticks
	var gradientColorsData = gradientData[3].split("`")
	var gradientColors = PackedColorArray()
	for col in gradientColorsData:
		gradientColors.append(getColorFromNegative(col.to_int()))
	gradientTexture.gradient = Gradient.new()
	gradientTexture.gradient.colors = gradientColors
	
	# Then the offsets from 0 to 1 along the gradient each point is at
	var gradientOffsetData = gradientData[4].split("`")
	var gradientOffsets = []
	for offset in gradientOffsetData:
		gradientOffsets.append(offset.to_float())
	gradientTexture.gradient.offsets = gradientOffsets
	if(gradientData[5] == "NO_CYCLE"): # And finally the way in which the gradient repeats (or doesn't)
		gradientTexture.repeat = GradientTexture2D.REPEAT_NONE
	if(gradientData[5] == "REFLECT"):
		gradientTexture.repeat = GradientTexture2D.REPEAT_MIRROR
	else:
		gradientTexture.repeat = GradientTexture2D.REPEAT
	return gradientTexture

func parse_gradient_background(data):
	var imageBackgroundInstance = imageBackgroundScene.instantiate()
	var ibiTexture = imageBackgroundInstance.get_node("Texture")
	ibiTexture.texture = getGradient(data["GradientDefinition"], canvasWidth / 5., canvasHeight / 5.)
	ibiTexture.size = pageSize
	
	if(data.has("imageopacity")):
		ibiTexture.self_modulate.a = data["imageopacity"].to_float()
	
	add_child(imageBackgroundInstance)
	
	pass
func parse_image(data, type):
	var imageInstance = imageScene.instantiate()
	# Set image data and add to scene, the image scene itself handles the rest
	imageInstance.pageSize = pageSize
	imageInstance.canvasWidth = canvasWidth
	imageInstance.canvasHeight = canvasHeight
	imageInstance.path = path
	imageInstance.data = data
	imageInstance.type = type
	add_child(imageInstance)
	if(data.has("id")): 
		# An image with an id means that the image has text attached to it
		# niche feature where you can combine a 'shape' type image with text
		# and the text will fill the shape
		var hti = util_Preloader.heldTextInstances[data["id"]].duplicate() 
		# It's possible that the image is being parsed before the text would be
		# so we simply generate all the text instances beforepaw in the preload step
		# so they're here when we need them
		
		hti.pageSize = pageSize # Adding info that wasn't available during preload
		hti.canvasWidth = canvasWidth
		hti.canvasHeight = canvasHeight
		
		# Duplicate is not recursive so we need to duplicate the data ourselves
		hti.data = util_Preloader.heldTextInstances[data["id"]].data.duplicate()
		hti.path = util_Preloader.heldTextInstances[data["id"]].path
		hti.shapedata = util_Preloader.heldTextInstances[data["id"]].shapedata
		add_child(hti)
		
		# We need to tell the text instance to reload now, which requires a whole signal system
		# because communication between nodes has to be complicated
		reload_text.connect(hti.reload)
		emit_signal("reload_text")
		reload_text.disconnect(hti.reload)
	
func parse_text(data): 
	# Much like with images, parsing text requires just setting some things and letting the object handle itself
	get_tree().root.get_viewport().set_canvas_cull_mask_bit(2, false);
	var textInstance = textScene.instantiate()
	textInstance.pageSize = pageSize
	textInstance.canvasWidth = canvasWidth
	textInstance.get_node("TextBox").sectionIndex = sectionIndex
	if(canvasWidth == 0):
		textInstance.canvasWidth = pageSize.x
	textInstance.canvasHeight = canvasHeight
	textInstance.path = path
	textInstance.data = data
	textInstance.go_to_section.connect(_on_text_go_to_section)
	if(data.has("id")): 
		# Loading text with an id also causes problems because it creates duplicate instances
		textInstance.shapedata = util_Preloader.iddshapes[data["id"]]
		#util_Preloader.heldTextInstances[data["id"]] = textInstance
	else:
		add_child(textInstance)
	if(textInstance.hasLinks && pageType != util_Enums.pageType.TURNING && pageType != util_Enums.pageType.UNDER):
		# If we have links, we need to make an invisible copy of the textbox that is clickable
		# Because subviewports don't like to handle inputs
		# Unless this page is currently turning or under another page
		
		var textInstance2 = textScene.instantiate()
		textInstance2.pageSize = pageSize
		textInstance2.canvasWidth = canvasWidth
		textInstance2.get_node("TextBox").pageType = pageType
		
		if(canvasWidth == 0):
			textInstance2.canvasWidth = pageSize.x
		textInstance2.canvasHeight = canvasHeight
		textInstance2.path = path
		textInstance2.data = data
		textInstance2.get_node("TextBox").sectionIndex = sectionIndex
		textInstance2.go_to_section.connect(_on_text_go_to_section)
		textInstance2.go_to_page.connect(_on_text_go_to_page)
		textInstance2.get_node("TextBox").input.connect(get_tree().get_root().get_node("Book/SwipeDetecter")._input)
		textInstance2.get_node("TextBox").set_modulate(Color(1., 1., 1., 0.))
		
		# Add to the clickables holder node in the book scene
		get_tree().get_root().get_node("Book/ClickablesHolder").add_child(textInstance2)

func getColorFromNegative(val): 
	# Convert the silly negative number color representation to something Godot can interpret
	var negval = 16777216 + val
	
	# Not sure Godot is smart enough to do this with bitshifts
	# But that doesn't matter too much since this function doesn't get run too often
	var red = float(floor(negval / (256 * 256))) 
	var green = float(floor(negval / (256) % 256))
	var blue = float(floor(negval % 256))
	return Color(red / 256., green / 256., blue / 256.)
	
func parse_line(data):
	var lineInstance = lineScene.instantiate()
	lineInstance.position = Vector2(data["startX"].to_int(), data["startY"].to_int()) * pageSize.y / canvasHeight
	lineInstance.size = Vector2(data["width"].to_int(), data["height"].to_int()) * pageSize.y / canvasHeight
	if(data.has("rotation")):
		lineInstance.rotation_degrees = data["rotation"].to_int()
		lineInstance.pivot_offset = lineInstance.size / 2.
	var svgfile = FileAccess.open("res://Shapes/line_svg.txt", FileAccess.READ)
	var svgdata = svgfile.get_as_text()
	var col = Color.BLACK
	if(data.has("fillColor")):
		var colvalue = data["fillColor"].to_int()
		if(colvalue < 0):
			col = getColorFromNegative(colvalue)
		else:
			col = getColorFromNegative(-16777216+(colvalue % (256 * 256 * 256)))
			col.a = float(colvalue) / (256 * 256 * 256 * 256)
	var newsvgdata = svgdata.replace(
		"{IMAGE_WIDTH}", data["width"]).replace(
		"{IMAGE_HEIGHT}", data["height"]).replace(
		"{STROKE_WEIGHT}", str(data["outlineThickness"].to_int())).replace(
		"{STROKE_COLOR}", "#" + col.to_html(false)).replace(
		"{LINE_DATA}", data["svgPathData"])
	var img = Image.new()
	img.load_svg_from_string(newsvgdata, 1.0)
	img.load_svg_from_string(newsvgdata, lineInstance.size.x / img.get_width())
	var tex = ImageTexture.create_from_image(img)
	lineInstance.texture = tex
	lineInstance.self_modulate.a = col.a
	add_child(lineInstance)
	if(data.has("id")):
		var hti = util_Preloader.heldTextInstances[data["id"]].duplicate()
		hti.pageSize = pageSize
		hti.data = util_Preloader.heldTextInstances[data["id"]].data.duplicate()
		hti.canvasWidth = canvasWidth
		hti.canvasHeight = canvasHeight
		hti.path = util_Preloader.heldTextInstances[data["id"]].path
		hti.shapedata = util_Preloader.heldTextInstances[data["id"]].shapedata
		add_child(hti)
		reload_text.connect(hti.reload)
		emit_signal("reload_text")
		reload_text.disconnect(hti.reload)


func parse_text_art(data):
	var wordArtInstance = wordArtScene.instantiate()
	wordArtInstance.data = data
	wordArtInstance.path = path
	wordArtInstance.pageSize = pageSize
	wordArtInstance.canvasWidth = canvasWidth
	
	add_child(wordArtInstance)
	
	pass

func parse_attributes(parser):
	var data = {}
	for idx in range(parser.get_attribute_count()):
		data[parser.get_attribute_name(idx)] = parser.get_attribute_value(idx)
	return data

func get_text_contents(parser):
	parser.read()
	if(parser.get_node_type() == XMLParser.NODE_TEXT):
		return(parser.get_node_data())
	else:
		return ""


func _on_book_page_update() -> void:
	for n in get_children():
		remove_child(n)
		n.free()
	
	load_page()


func _on_text_go_to_section(section):
	print("go to section \"" + section + "\"")
	emit_signal("go_to_section", section, 1)


func _on_text_go_to_page(section, page):
	print("go to section \"" + section + "\", page " + str(page))
	emit_signal("go_to_section", section, page)
