extends PageObject

#todo:
#(low priority)shadow resize, mask subtexture bullshit, shape rotation
var data = {}
static var shapes = {}
static var shapesarr = []
static var gradients = {}
static var gradientsarr = []
var page_size
var canvas_width
var canvas_height
var path
var image_size
var image_pos
var numberedShapesDict = {
	0: "Circle.svg",
	1: "Heart.svg",
	2: "Star.svg",
	3: "Triangle.svg",
	5: "Pentagon.svg",
	6: "Diamond.svg",
	7: "Rounded Square.svg",
	8: "Right Angle.svg",
	9: "Talk Bubble.svg",
	10: "Think Bubble.svg",
	12: "Frame.svg",
	13: "Circle.svg"
}
var assortedShaderData = Vector4(0.0, 0.0, 0.0, 0.0)
var type
var region
var region2

static var imageMatteMaterialWeb = preload("res://shaders/image_matte_material_web.tres") as ShaderMaterial
static var imageMaterialWeb = preload("res://shaders/image_material_web.tres") as ShaderMaterial
static var imageMatteMaterial = preload("res://shaders/image_matte_material.tres") as ShaderMaterial
static var imageMaterial = preload("res://shaders/image_material.tres") as ShaderMaterial

signal reload_text

static func update_shaders_pre():
	if(OS.has_feature("web") || RenderingServer.get_current_rendering_method() == "gl_compatibility"):
		# In web mode we barely get any textures to work with, so we clear them out every update
		shapes = {}
		shapesarr = []
		gradients = {}
		gradientsarr = []
		
static func update_shaders_post():
	if(!(OS.has_feature("web") || RenderingServer.get_current_rendering_method() == "gl_compatibility")
	 && shapesarr.size() > 30 || gradientsarr.size() > 30):
		# Otherwise we update the page and only clear the arrays if they're getting too full
		shapes = {}
		shapesarr = []
		gradients = {}
		gradientsarr = []
		return true
	# Finally, set the shader parameters
	imageMaterial.set("shader_parameter/shape_textures", shapesarr)
	imageMaterial.set("shader_parameter/gradient_textures", gradientsarr)
	imageMatteMaterial.set("shader_parameter/gradient_textures", gradientsarr)
	return false

func initialize_variables(type_, data_, path_, page_size_, _page_type, canvas_width_, canvas_height_, _section_index):
	type = type_
	data = data_
	path = path_
	page_size = page_size_
	canvas_width = canvas_width_
	canvas_height = canvas_height_

func check_for_held_text():
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
		get_parent().add_child(held_text_instance)
		
		# We need to tell the text instance to reload now, which requires a whole signal system
		# because communication between nodes has to be complicated
		reload_text.connect(held_text_instance.reload)
		emit_signal("reload_text")
		reload_text.disconnect(held_text_instance.reload)

func _ready():
	if(OS.has_feature("web") || RenderingServer.get_current_rendering_method() == "gl_compatibility"):
		$MatteSvgTexture.set_material(imageMatteMaterialWeb)
		$Texture.set_material(imageMaterialWeb)
	else:
		$MatteSvgTexture.set_material(imageMatteMaterial)
		$Texture.set_material(imageMaterial)
	parseImage()
func find_xml_attribute(xmldata, attr):
	if(xmldata.find(attr + "=\"") == -1):
		return ""
	var left = xmldata.find(attr + "=\"") + len(attr) + 2
	var right = xmldata.find("\"", left)
	return xmldata.substr(left, right - left)
func parseMatte():
	if(data.has("outlineThickness")):
		data["mattewidth"] = data["outlineThickness"]
	if(data.has("type") && data["type"] != "7" && data["type"] != "4"):
		parseShapeMatte()
	else:
		$MatteSvgTexture.visible = false
		parseRegularMatte()
func getColorFromNegative(val):
	var negval = 16777216 + val
	var red = float(floor(negval / (256 * 256)))
	var green = float(floor(negval / (256) % 256))
	var blue = float(floor(negval % 256))
	return Color(red / 256., green / 256., blue / 256.)
func addGradient(rawGradientData, width, height):
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
	gradientsarr.append(gradientTexture)
	gradients[rawGradientData] = gradientsarr.size() - 1
func parseRegularMatte():
	var matteColor
	if(data.has("matteGradient")):
		matteColor = Color.WHITE
		var matte_rotation = 0.#$Texture.rotation
		var matte_scale = $Texture.size / page_size
		var transformationMatrix = Vector4(matte_scale.x * cos(matte_rotation), -matte_scale.y * sin(matte_rotation), matte_scale.x * sin(matte_rotation), matte_scale.y * cos(matte_rotation))
		var translationVector = Vector2($Texture.position / page_size) + Vector2(matte_scale.x * cos(matte_rotation) - matte_scale.y * sin(matte_rotation), matte_scale.x * sin(matte_rotation) + matte_scale.y * cos(matte_rotation)) / 2
		$Texture.set_instance_shader_parameter("transformationMatrix", transformationMatrix)
		$Texture.set_instance_shader_parameter("translation", translationVector)
		
		var rawGradientData = data["matteGradient"]
		if(!gradients.has(rawGradientData)):
			addGradient(rawGradientData, canvas_width * 2, canvas_height * 2)
		$Texture.set_instance_shader_parameter("gradientIndex", gradients[rawGradientData])
	elif data.has("outlineColor"):
		matteColor = getColorFromNegative(data["outlineColor"].to_int())
		$Texture.set_instance_shader_parameter("gradientIndex", -1)
	else:
		$Texture.set_instance_shader_parameter("gradientIndex", -1)
		matteColor = Color(float(data["mattered"].to_int())/256, float(data["mattegreen"].to_int())/256, float(data["matteblue"].to_int())/256)
	if(data.has("imageopacity")):
		matteColor.a = data["imageopacity"].to_float()
	var matteColorVec = Vector4(matteColor.r, matteColor.g, matteColor.b, matteColor.a)
	$Texture.set_instance_shader_parameter("matte_color", matteColorVec)
	assortedShaderData.y = data["mattewidth"].to_int() / float(data["height"].to_int())
func parseShapeMatte():
	var shapeFile
	var shapefileContent
	if(util_Preloader.images_dict.has(data["customShapeName"])):
		if(data["type"] == "20"):
			shapefileContent = util_Preloader.images_dict[data["customShapeName"]]
		else:
			shapefileContent = util_Preloader.images_dict[numberedShapesDict[data["type"].to_int()]]
	else:
		if(data["type"] == "20"):
			if(data["customShapeName"].split('.')[0].to_int() > 100):
				shapeFile = path + "/objects/" + data["customShapeName"]
			else:
				shapeFile = "res://Shapes/Basics/" + data["customShapeName"]
		else:
			shapeFile = "res://Shapes/Basics/" + numberedShapesDict[data["type"].to_int()]
		
		var shapefile = FileAccess.open(shapeFile, FileAccess.READ)
		shapefileContent = shapefile.get_as_text()
	var matteColor
	if(data.has("matteGradient")):
		matteColor = Color.WHITE
		var matte_rotation = 0.#$Texture.rotation
		var matte_scale = $Texture.size / page_size
		var transformationMatrix = Vector4(matte_scale.x * cos(matte_rotation), -matte_scale.y * sin(matte_rotation), matte_scale.x * sin(matte_rotation), matte_scale.y * cos(matte_rotation))
		var translationVector = Vector2($Texture.position / page_size) + Vector2(matte_scale.x * cos(matte_rotation) - matte_scale.y * sin(matte_rotation), matte_scale.x * sin(matte_rotation) - matte_scale.y * cos(matte_rotation)) / 2.
		if(type != "shape"):
			$MatteSvgTexture.set_instance_shader_parameter("transformationMatrix", transformationMatrix)
			$MatteSvgTexture.set_instance_shader_parameter("translation", translationVector)
		else:
			$MatteSvgTexture.set_instance_shader_parameter("transformationMatrix", Vector4(4., 0., 0., 4.))
			$MatteSvgTexture.set_instance_shader_parameter("translation", Vector2(0., 0.))
		var rawGradientData = data["matteGradient"]
		if(!gradients.has(rawGradientData)):
			addGradient(rawGradientData, canvas_width * 2, canvas_height * 2)
		$MatteSvgTexture.set_instance_shader_parameter("gradientIndex", gradients[rawGradientData])
	elif data.has("outlineColor"):
		matteColor = getColorFromNegative(data["outlineColor"].to_int())
		$MatteSvgTexture.set_instance_shader_parameter("gradientIndex", -1)
	else:
		$MatteSvgTexture.set_instance_shader_parameter("gradientIndex", -1)
		matteColor = Color(float(data["mattered"].to_int())/256, float(data["mattegreen"].to_int())/256, float(data["matteblue"].to_int())/256)
	var shapewidthattr = find_xml_attribute(shapefileContent, "width")
	var shapeheightattr = find_xml_attribute(shapefileContent, "height")
	var viewboxattr = find_xml_attribute(shapefileContent, "viewBox")
	var editedContent = shapefileContent
	var shape: Image = Image.new()
	shape.load_svg_from_string(editedContent, 1.)
	
	var shapewidth
	var shapeheight
	if(viewboxattr != ""):
		shapewidth = shapewidthattr.to_float() * 2.
		shapeheight = shapeheightattr.to_float() * 2.
		editedContent = shapefileContent.replace("width=\""+shapewidthattr+"\"", "width=\"" + str(shapewidthattr.to_float() * 2.) + "px\"")
		editedContent = editedContent.replace("height=\""+shapeheightattr+"\"", "height=\"" + str(shapeheightattr.to_float() * 2.) + "px\"")
		editedContent = editedContent.replace(viewboxattr,
			str(viewboxattr.split(' ')[0].to_float() - shapewidthattr.to_float() / 2.) + " " + 
			str(viewboxattr.split(' ')[1].to_float() - shapeheightattr.to_float() / 2.) + " " + 
			str(shapewidthattr.to_float() * 2.) + " " + str(shapeheightattr.to_float() * 2.))
			
	else:
		if(shape.get_width() < 100):
			shape.load_svg_from_string(editedContent, 30.)
			shapewidth = shape.get_width() / 30. * 2.
			shapeheight = shape.get_height() / 30. * 2.
		else:
			shapewidth = shape.get_width() * 2.
			shapeheight = shape.get_height() * 2.
		editedContent = editedContent.replace("<svg ", "<svg width=\"" + str(shapewidth) + "px\" height=\"" + str(shapeheight) + "px\" 
			viewBox=\"" + str(-shapewidth / 4.) + " " + str(-shapeheight / 4.) +" " + str(shapewidth) + " " + str(shapeheight) + "\"")
	$MatteSvgTexture.pivot_offset = image_size
	$MatteSvgTexture.position = image_pos - image_size / 2
	$MatteSvgTexture.size = image_size * 2
	editedContent = editedContent.replace("fill=\"none\"", "")
	editedContent = editedContent.replace("<path", "<path fill=\"#" + matteColor.to_html(false) + "\" stroke=\"#" + matteColor.to_html(false) + "\" stroke-width=\"" + str(float(data["mattewidth"].to_int()) * shapewidth / float(image_size.x) * page_size.x / canvas_width * 2.) + "\"") 
	editedContent = editedContent.replace("<ellipse", "<ellipse fill=\"#" + matteColor.to_html(false) + "\" stroke=\"#" + matteColor.to_html(false) + "\" stroke-width=\"" + str(float(data["mattewidth"].to_int()) * shapewidth / float(image_size.x) * page_size.x / canvas_width * 2.) + "\"") 
	editedContent = editedContent.replace("<circle", "<circle fill=\"#" + matteColor.to_html(false) + "\" stroke=\"#" + matteColor.to_html(false) + "\" stroke-width=\"" + str(float(data["mattewidth"].to_int()) * shapewidth / float(image_size.x) * page_size.x / canvas_width * 2.) + "\"") 
	editedContent = editedContent.replace("<rect", "<rect fill=\"#" + matteColor.to_html(false) + "\" stroke=\"#" + matteColor.to_html(false) + "\" stroke-width=\"" + str(float(data["mattewidth"].to_int()) * shapewidth / float(image_size.x) * page_size.x / canvas_width * 2.) + "\"") 
	editedContent = editedContent.replace("<polygon", "<polygon fill=\"#" + matteColor.to_html(false) + "\" stroke=\"#" + matteColor.to_html(false) + "\" stroke-width=\"" + str(float(data["mattewidth"].to_int()) * shapewidth / float(image_size.x) * page_size.x / canvas_width * 2.) + "\"") 
	shape.load_svg_from_string(editedContent, 1.)
	shape.load_svg_from_string(editedContent, image_size.x / shape.get_width() * 2)
	var shapeTexture = ImageTexture.create_from_image(shape)
	$MatteSvgTexture.texture = shapeTexture
	$MatteSvgTexture.visible = true
	if(type == "shape" && data.has("SubImage")):
		$MatteSvgTexture.set_instance_shader_parameter("matteSize", data["mattewidth"].to_float() / data["width"].to_float())
	else:
		$MatteSvgTexture.set_instance_shader_parameter("matteSize", 0.25)
		
func parseShape():
	
	var shapeFile
	var shapeImage = Image.new()
	var shapeImageData
	
	if(data["type"] == "20"):
		if(data["customShapeName"].split('.')[0].to_int() > 100):
			shapeFile = path + "/objects/" + data["customShapeName"]
		else:
			shapeFile = "res://Shapes/Basics/" + data["customShapeName"]
	else:
		shapeFile = "res://Shapes/Basics/" + numberedShapesDict[data["type"].to_int()]
	if(util_Preloader.images_dict.has(data["customShapeName"])):
		if(data["type"] == "20"):
			shapeImageData = util_Preloader.images_dict[data["customShapeName"]]
		else:
			shapeImageData = util_Preloader.images_dict[numberedShapesDict[data["type"].to_int()]]
	else:
		var shapefile = FileAccess.open(shapeFile, FileAccess.READ)
		shapeImageData = shapefile.get_as_text()
	shapeImageData = shapeImageData.replace("fill=\"none\"", "stroke-width=\"0\"")
	shapeImage.load_svg_from_string(shapeImageData, 1.)
	if(find_xml_attribute(shapeImageData, "viewBox") == ""):
		var shapewidth
		var shapeheight
		if(shapeImage.get_width() < 100):
			shapeImage.load_svg_from_string(shapeImageData, 100.)
			shapewidth = shapeImage.get_width() / 100. + 1
			shapeheight = shapeImage.get_height() / 100. + 1
		else:
			shapewidth = shapeImage.get_width()
			shapeheight = shapeImage.get_height()
		shapeImageData = shapeImageData.replace("<svg ", "<svg width=\"" + str(shapewidth * 2.) + "px\" height=\"" + str(shapeheight * 2.) + "px\" 
			viewBox=\"" + str(-shapewidth / 2.) + " " + str(-shapeheight / 2.) +" " + str(shapewidth * 2.) + " " + str(shapeheight * 2.) + "\"")
		image_size *= 2.
		image_pos -= image_size / 4.
		$Texture.size = image_size
		$Texture.position = image_pos
	shapeImage.load_svg_from_string(shapeImageData, 1.)
	shapeImage.load_svg_from_string(shapeImageData, image_size.x / shapeImage.get_width())
	var shape = ImageTexture.create_from_image(shapeImage)
	if(type == "shape"):
		var shapeSubtexture = Vector4(
		region2.position.x / shape.get_width() * page_size.x / canvas_width,
		region2.position.y / shape.get_height() * page_size.x / canvas_width,
		1 if region2.size.x == 0 else region2.size.x / shape.get_width() * page_size.x / canvas_width,
		1 if region2.size.y == 0 else region2.size.y / shape.get_height() * page_size.x / canvas_width)
		$Texture.set_instance_shader_parameter("shape_subtexture", shapeSubtexture);
		if(data.has("mattewidth") && data.has("SubImage")):
			$MatteSvgTexture.set_instance_shader_parameter("subtexture", shapeSubtexture + Vector4(data["mattewidth"].to_float() / shape.get_width() * page_size.y / canvas_height, data["mattewidth"].to_float() / shape.get_height() * page_size.y / canvas_height, 0., 0.) * 9 / 5);
	if(!shapes.has(shapeFile)):
		shapesarr.append(shape)
		shapes[shapeFile] = shapesarr.size() - 1
	else:
		shapesarr[shapes[shapeFile]] = shape
	$Texture.set_instance_shader_parameter("textureIndex",shapes[shapeFile])
func parseShadow():
	if(!(data.has("type") && data["type"] != "7" && data["type"] != "4")):
		parseNormalShadow()
		
		
	else:
		parseSvgShadow()
func parseNormalShadow():
	var shadowColor = Color(
		sqrt(float(data["shadowred"].to_int()) / 256.), 
		sqrt(float(data["shadowgreen"].to_int()) / 256.), 
		sqrt(float(data["shadowblue"].to_int()) / 256.), 
		data["shadowopacity"].to_float())
	$Texture.set_instance_shader_parameter("shadowColor", shadowColor)
	var shadowTransform = Vector2(float(data["offsetx"].to_int()) / float(data["width"].to_int()), float(data["offsety"].to_int()) / float(data["height"].to_int()))
	var rotatedShadowTransform;
	if(data.has("rotation")):
		rotatedShadowTransform = Vector2(
			shadowTransform.x * cos(-data["rotation"].to_float() * PI / 180.) - shadowTransform.y * sin(-data["rotation"].to_float() * PI / 180.),
			shadowTransform.x * sin(-data["rotation"].to_float() * PI / 180.) + shadowTransform.y * cos(-data["rotation"].to_float() * PI / 180.),
			)
	else:
		rotatedShadowTransform = shadowTransform
	$Texture.set_instance_shader_parameter("shadowTransform", rotatedShadowTransform)
	if(data.has("blur")):
		assortedShaderData.z = (data["blur"].to_float() - 0.02) / 2.
	else:
		assortedShaderData.z = 0.
func parseSvgShadow():
	$Texture.set_instance_shader_parameter("shadowColor", Color.TRANSPARENT)
	assortedShaderData.z = 0.
	$Texture.set_instance_shader_parameter("shadowTransform", Vector2.ZERO)
	var shadowColor = Color(sqrt(float(data["shadowred"].to_int()) / 256.), sqrt(float(data["shadowgreen"].to_int()) / 256.), sqrt(float(data["shadowblue"].to_int()) / 256.), data["shadowopacity"].to_float())
	$MatteSvgTexture.set_instance_shader_parameter("shadowColor", shadowColor)
	var shadowTransform = Vector2(float(data["offsetx"].to_int()) / float(data["width"].to_int()), float(data["offsety"].to_int()) / float(data["height"].to_int()))
	var rotatedShadowTransform;
	if(data.has("rotation")):
		rotatedShadowTransform = Vector2(
			shadowTransform.x * cos(-data["rotation"].to_float() * PI / 180.) - shadowTransform.y * sin(-data["rotation"].to_float() * PI / 180.),
			shadowTransform.x * sin(-data["rotation"].to_float() * PI / 180.) + shadowTransform.y * cos(-data["rotation"].to_float() * PI / 180.),
			)
	else:
		rotatedShadowTransform = shadowTransform
	#rotatedShadowTransform /= 2.
	$MatteSvgTexture.set_instance_shader_parameter("shadowTransform", rotatedShadowTransform)
	if(data.has("blur")):
		$MatteSvgTexture.set_instance_shader_parameter("shadowBlur", (data["blur"].to_float() - 0.02) / 4.)
	else:
		$MatteSvgTexture.set_instance_shader_parameter("shadowBlur", 0.)
func parseBlur():
	
	var edges = data["BlurEdges"].to_int()
	var left = edges > 7
	var bottom = edges % 8 > 3
	var right = edges % 4 > 1
	var top = edges % 2 == 1
	var blursize = float(data["BlurEdgeValue"].to_int())
	var blurData = Vector4(right, top, left, bottom) * blursize
	var scaledBlurData = blurData / 100.# * 1.5
	$Texture.set_instance_shader_parameter("edgeBlur", scaledBlurData)

func parseRip(aspectRatio):
	var edges = data["RipEdges"].to_int()
	var left = edges > 7
	var bottom = edges % 8 > 3
	var right = edges % 4 > 1
	var top = edges % 2 == 1
	var ripsize = float(data["RipJagged"].to_int()) / 500.
	var ripData = Vector4(float(right) / aspectRatio, top, float(left) / aspectRatio, bottom) * ripsize
	var ripTextures = Vector4(
		data["ripSetRight"].to_int() if data.has("ripSetRight") else 0, 
		data["ripSetUp"].to_int() if data.has("ripSetUp") else 0, 
		data["ripSetDown"].to_int() if data.has("ripSetDownt") else 0, 
			data["ripSetLeft"].to_int() if data.has("ripSetLeft") else 0)
	$Texture.set_instance_shader_parameter("edgeRip", ripData)
	$Texture.set_instance_shader_parameter("edgeRipTextures", ripTextures)
func parseRounding():
	var corners = data["cornersRounded"].to_int()
	var bottomleft = corners > 7
	var bottomright = corners % 8 > 3
	var topright = corners % 4 > 1
	var topleft = corners % 2 == 1
	var cornersize = float(data["cornerRounding"].to_int())
	var cornersData = Vector4(topleft, topright, bottomleft, bottomright) * cornersize
	var scaledCornersData = cornersData / float(data["height"].to_int())# * 1.5
	$Texture.set_instance_shader_parameter("cornerType", data["CornerType"].to_int())
	$Texture.set_instance_shader_parameter("corner_rounding", scaledCornersData)
func parseImage():
	image_size = Vector2(0,0)
		
		
	image_size.x = float(data["width"].to_int())
	image_size.y = float(data["height"].to_int())
	image_pos = Vector2(0,0)
	image_pos.x = float(data["startX"].to_int())
	image_pos.y = float(data["startY"].to_int())
	
	image_size *= (page_size.x / canvas_width)
	image_pos *= (page_size.x / canvas_width)
	$Texture.position = image_pos
	$Texture.size = image_size
	region = Rect2()
	var filename;
	var imagePath
	var imageTexture;
	if(data.has("fileName")):
		filename = data["fileName"]
		imagePath = path+"/objects/"+filename
		
		if(util_Preloader.images_dict.has(filename)):
			imageTexture = util_Preloader.images_dict[filename]
		else:
			if(imagePath.begins_with("res://")):
				imageTexture = load(imagePath)
			else:
				imageTexture = ImageTexture.create_from_image(Image.load_from_file(imagePath))
	elif(data.has("GradientDefinition")):
		if(!gradients.has(data["GradientDefinition"])):
			addGradient(data["GradientDefinition"], image_size.x / 4., image_size.y / 4.)
		imageTexture = gradientsarr[gradients[data["GradientDefinition"]]]
	else:
		imageTexture = GradientTexture1D.new()
		imageTexture.gradient = Gradient.new()
		imageTexture.gradient.colors = [Color.WHITE];
	if(data.has("SubImage") && data["SubImage"] == "true"):
		region.size.x = float(data["sW"].to_int())
		region.size.y = float(data["sH"].to_int())
		region.position.x = float(data["sX"].to_int())
		region.position.y = float(data["sY"].to_int())
	pass
	
	if(data.has("imageMaskFill")):
		if(!shapes.has(imagePath)):
			shapesarr.append(imageTexture)
			shapes[imagePath] = shapesarr.size() - 1
		$Texture.set_instance_shader_parameter("textureIndex",shapes[imagePath])
		var shapeSubtexture = Vector4(
			region.position.x / imageTexture.get_width(),
			region.position.y / imageTexture.get_height(),
			1 if region.size.x == 0 else region.size.x / imageTexture.get_width(),
			1 if region.size.y == 0 else region.size.y / imageTexture.get_height())
		$Texture.set_instance_shader_parameter("shape_subtexture", shapeSubtexture);
		
		filename = data["imageMaskFill"]
		imagePath = path+"/objects/"+filename
		
		if(util_Preloader.images_dict.has(filename)):
			imageTexture = util_Preloader.images_dict[filename]
		else:
			if(imagePath.begins_with("res://")):
				imageTexture = load(imagePath)
			else:
				imageTexture = ImageTexture.create_from_image(Image.load_from_file(imagePath))
		region = Rect2()
		var defaultWidth
		var defaultHeight
		if(image_size.x >= image_size.y):
			defaultWidth = imageTexture.get_width()
			defaultHeight = imageTexture.get_width() * image_size.y / image_size.x
		else:
			defaultWidth = imageTexture.get_height() * image_size.x / image_size.y
			defaultHeight = imageTexture.get_height()
		
		region.size.x = defaultWidth
		region.size.y = defaultHeight
		region.position.x = imageTexture.get_width() / 2. - defaultWidth / 2.
		region.position.y = imageTexture.get_height() / 2. - defaultHeight / 2.
		if(data.has("xOffset")):
			
			region.size.x = defaultWidth * defaultWidth / (defaultWidth + float(data["wOffset"].to_int())) / 2.
			region.size.y = defaultHeight * defaultHeight /(defaultHeight + float(data["hOffset"].to_int())) / 2.
			#region.position.x = imageTexture.get_width() / 2. - region.size.x / 2.
			#region.position.y = imageTexture.get_height() / 2. - region.size.y / 2.
			
			region.position.x -= data["xOffset"].to_int()
			region.position.y -= data["yOffset"].to_int()
	elif(type == "shape"):
		region2 = region

		
		region = Rect2()
		var defaultWidth
		var defaultHeight
		if(image_size.x / image_size.y > imageTexture.get_width() / imageTexture.get_height()):
			defaultWidth = imageTexture.get_width()
			defaultHeight = imageTexture.get_width() * image_size.y / image_size.x
		else:
			defaultWidth = imageTexture.get_height() * image_size.x / image_size.y
			defaultHeight = imageTexture.get_height()
		
		region.size.x = defaultWidth
		region.size.y = defaultHeight
		region.position.x = imageTexture.get_width() / 2. - defaultWidth / 2.
		region.position.y = imageTexture.get_height() / 2. - defaultHeight / 2.
		if(data.has("xOffset")):
			region.size.x = defaultWidth * defaultWidth / (defaultWidth + float(data["wOffset"].to_int())) / 2.
			region.size.y = defaultHeight * defaultHeight /(defaultHeight + float(data["hOffset"].to_int())) / 2.
			#region.position.x = imageTexture.get_width() / 2. - region.size.x / 2.
			#region.position.y = imageTexture.get_height() / 2. - region.size.y / 2.
			
			region.position.x -= data["xOffset"].to_int()
			region.position.y -= data["yOffset"].to_int()
	else:
		$Texture.set_instance_shader_parameter("shape_subtexture", Vector4(0,0,1,1));
	var imageAtlas : AtlasTexture = AtlasTexture.new()
	imageAtlas.atlas = imageTexture
	imageAtlas.region = region
	$Texture.set_instance_shader_parameter("subtexture", Vector4(
		region.position.x / imageTexture.get_width(), region.position.y / imageTexture.get_height(), 
		1 if region.size.x == 0 else region.size.x / imageTexture.get_width(), 
		1 if region.size.y == 0 else region.size.y / imageTexture.get_height()))
	
	if(data.has("mirror")):
		$Texture.flip_h = data["mirror"] == "true"
		$MatteSvgTexture.flip_h = data["mirror"] == "true"
	if(data.has("flip")):
		$Texture.flip_v = data["flip"] == "true"
		$MatteSvgTexture.flip_v = data["flip"] == "true"
	if(data.has("rotation")):
		$Texture.rotation_degrees = data["rotation"].to_float()
		$MatteSvgTexture.rotation_degrees = data["rotation"].to_float()
	#if(data.has("imageopacity")):
		#$Texture.self_modulate.a = data["imageopacity"].to_float()
	
	if(data.has("fillColor") && !data.has("imageMaskFill") && !(data.has("fileName") && data.has("customShapeName")) && !data.has("GradientDefinition")):
		var colordata = data["fillColor"].to_int()
		var colorsign = 1 if colordata > 0 else -1
		var reddata: float = floor(abs(colordata) / (256 * 256)) - 34
		var greendata: float = floor(abs(colordata) / 256) % 256 - 31
		var bluedata: float = abs(colordata) % 256 - 31
		var col = Vector4(colorsign * (reddata / 256.0), colorsign * (greendata / 256.0), colorsign * (bluedata / 256.0), 0)
		$Texture.set_instance_shader_parameter("recolor_value", col)
		
	if(data.has("cornersRounded")):
		parseRounding()
	else:
		$Texture.set_instance_shader_parameter("cornerType", 0)
		$Texture.set_instance_shader_parameter("corner_rounding", Vector4.ZERO)
		
		
	var imageAspectRatio = image_size.x / image_size.y
	if(data.has("RipJagged")):
		parseRip(imageAspectRatio)
	else:
		$Texture.set_instance_shader_parameter("edgeRip", Vector4.ZERO)
		
		
	if(data.has("BlurEdges")):
		parseBlur()
	else:
		$Texture.set_instance_shader_parameter("edgeBlur", Vector4.ZERO)
	assortedShaderData.x = imageAspectRatio;
	
	if(data.has("matte") && data["matte"] || data.has("outlineThickness") && data["outlineThickness"].to_int() > 0):
		parseMatte()
	else:
		$MatteSvgTexture.visible = false
		assortedShaderData.y = 0.
	
	if(data.has("type") && data["type"] != "7" && data["type"] != "4"):
		parseShape();
	elif(!data.has("imageMaskFill")):
		$Texture.set_instance_shader_parameter("textureIndex", -1)
		$MatteSvgTexture.visible = false
		
		
	
	
	if(data.has("shadow") && data["shadow"]):
		parseShadow()
	else:
		$Texture.set_instance_shader_parameter("shadowColor", Color.TRANSPARENT)
		assortedShaderData.z = 0.
		$Texture.set_instance_shader_parameter("shadowTransform", Vector2.ZERO)
		
		$MatteSvgTexture.set_instance_shader_parameter("shadowColor", Color.TRANSPARENT)
		$MatteSvgTexture.set_instance_shader_parameter("shadowBlur", 0.)
		$MatteSvgTexture.set_instance_shader_parameter("shadowTransform", Vector2.ZERO)
	
	
	$Texture.set_instance_shader_parameter("assorted_data", assortedShaderData)
	$Texture.texture = imageAtlas
	$Texture.pivot_offset = image_size / 2
		
	
	if(data.has("imageopacity")):
		$Texture.self_modulate = Color(Color.WHITE, data["imageopacity"].to_float())
		$MatteSvgTexture.self_modulate = Color(Color.WHITE, data["imageopacity"].to_float())
