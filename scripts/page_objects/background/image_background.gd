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
	var filename = data["fileName"]
	var image_path = path+"objects/"+filename
	var image_texture
	if(util_Preloader.images_dict.has(filename)):
		image_texture = util_Preloader.images_dict[filename]
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
		$Texture.flip_h = data["mirror"] == "true"
	if(data.has("flip")):
		$Texture.flip_v = data["flip"] == "true"
	if(data.has("rotation")):
		$Texture.rotation_degrees = data["rotation"].to_float()
	if(data.has("imageopacity")):
		$Texture.self_modulate.a = data["imageopacity"].to_float()
	image_atlas.region = region
	
	$Texture.texture = image_atlas # Set the texture properly
	
	$Texture.pivot_offset = page_size / 2 # Center of page
	$Texture.position = Vector2(0, 0)
	$Texture.size = page_size
