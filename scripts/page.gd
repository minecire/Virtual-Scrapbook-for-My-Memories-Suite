extends SubViewport

@export var path: String;
@export var file: String;
@export var pageName: String;
@export var pageSize: Vector2;
@export var pos: Vector2;

var pageIndex = 0
var sectionIndex = 0
var imageBackgroundScene = preload("res://scenes/pageobjects/image_background.tscn")
var colorBackgroundScene = preload("res://scenes/pageobjects/color_background.tscn")
var imageScene = preload("res://scenes/pageobjects/image.tscn")
var textScene = preload("res://scenes/pageobjects/j_word_text.tscn")
var lineScene = preload("res://scenes/pageobjects/line.tscn")
var wordArtScene = preload("res://scenes/pageobjects/word_art.tscn")

var aspectRatio: float;

var maxOutputWidth: int;
var maxOutputHeight: int;

var canvasWidth: int;
var canvasHeight: int;

var numPages = -1


var pageType : util_Enums.pageType;
signal go_to_section
signal reload_text

#object types: background, image, jwordtext, textart, line, calendar, shape
#    todo: 
#word art
#calendar(low priority)
#images(low priority): shadow resize, mask subtexture bullshit, shape rotation, fix bug with multiple shapes with different stretch on one page
#text(low priority): a few missing fonts, bold/italics failing on some fonts, rotation on curves

var id;

func _ready():
	set_canvas_cull_mask_bit(2, false);


func load_page():
	parse_xml()
	
	if get_children().size() == 0:
		var cbi = colorBackgroundScene.instantiate()
		cbi.size = pageSize
		cbi.color = Color(0.9, 0.83, 0.8)
		add_child(cbi)
	
	for node in get_children():
		for node2 in node.get_children():
			if(!node2.get_class() == "Node" && !node2.get_class() == "RichTextLabel" && !node2.get_class() == "SubViewport"):
				node2.position += pos
		if(!node.get_class() == "Node"):
			node.position += pos
func calculate_missing_data():
	aspectRatio = float(maxOutputWidth) / float(maxOutputHeight)
	canvasHeight = int(canvasWidth / aspectRatio)
func parse_xml():
	var parser = XMLParser.new()
	numPages = util_Preloader.scrapbookData[sectionIndex]["numPages"]
	canvasWidth = util_Preloader.scrapbookData[sectionIndex]["canvasWidth"]
	maxOutputWidth = util_Preloader.scrapbookData[sectionIndex]["maxOutputWidth"]
	maxOutputHeight = util_Preloader.scrapbookData[sectionIndex]["maxOutputHeight"]
	if(pageIndex < util_Preloader.scrapbookData[sectionIndex]["pages"].size()):
		parse_page(util_Preloader.scrapbookData[sectionIndex]["pages"][pageIndex])
func parse_page(data):
	calculate_missing_data()
	for object in data["objects"]:
		parse_page_object(object)

func parse_page_object(object):
	var type = object["type"]
	var data = object["data"]
	if(type == "background" && data["type"] == "1"):
		parse_color_background(data)
	elif(type == "background" && data["type"] == "2"):
		parse_image_background(data)
	elif(type == "background" && data["type"] == "4"):
		parse_gradient_background(data)
	elif(type == "image" || type == "embellishment" || type == "stamp" || type == "paint" || type == "shape"):
		parse_image(data, type)
	elif(type == "line"):
		parse_line(data)
	elif(type == "jWordText"):
		parse_text(data)
	elif(type == "textArt"):
		parse_text_art(data)
	elif(type != "spanner"):
		push_warning("unsupported datatype: " + type)
		
func parse_color_background(data):
	var colorBackgroundInstance = colorBackgroundScene.instantiate()
	var colordata = data["fillColor"]
	
	var opacity = 1
	if(data.has("imageopacity")):
		opacity = data["imageopacity"].to_float()
	var colorvalue = 16777216 + colordata.to_int()
	var colorcode = "#" + ( "%6X" % colorvalue )
	var maincolor = Color(colorcode)
	#var backcolor = Color("White")
	#var finalcolor = maincolor * opacity + backcolor * (1-opacity)
	colorBackgroundInstance.color = maincolor
	colorBackgroundInstance.size = pageSize
	colorBackgroundInstance.position = Vector2(0, 0)
	add_child(colorBackgroundInstance)
	pass

func parse_image_background(data):
	var imageBackgroundInstance = imageBackgroundScene.instantiate()
	var filename = data["fileName"]
	var imagePath = path+"objects/"+filename
	var ibiTexture = imageBackgroundInstance.get_node("Texture")
	var imageTexture
	if(util_Preloader.imagesDict.has(filename)):
		imageTexture = util_Preloader.imagesDict[filename]
	else:
		imageTexture = ImageTexture.create_from_image(Image.load_from_file(imagePath))
	var imageAtlas : AtlasTexture = AtlasTexture.new()
	imageAtlas.atlas = imageTexture
	var region = Rect2()
	if(aspectRatio <= float(imageTexture.get_width()) / float(imageTexture.get_height())):
		region.size.x = aspectRatio * imageTexture.get_height()
		region.position.x = (imageTexture.get_width() - region.size.x) / 2.0
	else:
		region.size.y = imageTexture.get_height() / aspectRatio
		region.position.y = (imageTexture.get_width() - region.size.x) / 2.0
	if(data.has("SubImage") && data["SubImage"] == "true"):
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
	
	ibiTexture.texture = imageAtlas
	
	ibiTexture.pivot_offset = pageSize / 2
	ibiTexture.position = Vector2(0, 0)
	ibiTexture.size = pageSize
	imageBackgroundInstance.get_node("ColorRect").size = pageSize
	imageBackgroundInstance.get_node("ColorRect").position = Vector2(0, 0)
	add_child(imageBackgroundInstance)
	pass
func getGradient(rawGradientData, width, height):
	var gradientData = rawGradientData.split("~")
	var gradientTexture = GradientTexture2D.new()
	gradientTexture.width = width
	gradientTexture.height = height
	if(gradientData[0] == "linearGradient"):
		gradientTexture.fill = GradientTexture2D.FILL_LINEAR
	else:
		gradientTexture.fill = GradientTexture2D.FILL_RADIAL
	var gradientFromData = gradientData[1].split("`")
	var gradientFrom = Vector2(gradientFromData[0].to_float(), gradientFromData[1].to_float()) / Vector2(width, height)
	var gradientToData = gradientData[2].split("`")
	var gradientTo = Vector2(gradientToData[0].to_float(), gradientToData[1].to_float()) / Vector2(width, height)
	gradientTexture.fill_from = gradientFrom
	gradientTexture.fill_to = gradientTo
	var gradientColorsData = gradientData[3].split("`")
	var gradientColors = PackedColorArray()
	for col in gradientColorsData:
		gradientColors.append(getColorFromNegative(col.to_int()))
	gradientTexture.gradient = Gradient.new()
	gradientTexture.gradient.colors = gradientColors
	var gradientOffsetData = gradientData[4].split("`")
	var gradientOffsets = []
	for offset in gradientOffsetData:
		gradientOffsets.append(offset.to_float())
	gradientTexture.gradient.offsets = gradientOffsets
	if(gradientData[5] == "NO_CYCLE"):
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
	imageInstance.pageSize = pageSize
	imageInstance.canvasWidth = canvasWidth
	imageInstance.canvasHeight = canvasHeight
	imageInstance.path = path
	imageInstance.data = data
	imageInstance.type = type
	add_child(imageInstance)
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
	
func parse_text(data):
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
		textInstance.shapedata = util_Preloader.iddshapes[data["id"]]
		#util_Preloader.heldTextInstances[data["id"]] = textInstance
	else:
		add_child(textInstance)
	if(textInstance.hasLinks && pageType != util_Enums.pageType.TURNING && pageType != util_Enums.pageType.UNDER):
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
		get_tree().get_root().get_node("Book/ClickablesHolder").add_child(textInstance2)

func getColorFromNegative(val):
	var negval = 16777216 + val
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
