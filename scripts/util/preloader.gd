extends Node

# We do a lot of work upfront to make sure everything can run smoothly

class ScrapbookSection:
	var pages : Array[ScrapbookPage]
	var num_pages : int
	var canvas_width : float
	var canvas_height : float
	var path : String

class ScrapbookPage:
	var objects : Array[ScrapbookPageObject]
	var name : String
	var has_background : bool

class ScrapbookPageObject:
	var type : String
	var xml_data : Dictionary

var sections_list # List of sections
var is_zip # Whether the file is a zip
var scrapbook_data # Basically the MMS file converted into an object
var idd_shapes = {} # Dictionary of shapes with ids
var spanners = {} # Dictionary of "Spanner" objects that span across pages
var images_dict = {} # Images by name
var texts_dict = {} # jWordText objects

var preloaded_fonts_dict = {} # Preloaded fonts from files
var system_fonts_dict = {} # Each individual font + style gets stored here

var zip_path # Path to zip file

func reload_stuff(sections_list_, book_path_, is_zip_): # Reload everything
	is_zip = is_zip_
	
	var book_path
	if(is_zip): # Unzip if zip
		zip_path = book_path_
		var id = extract_all_from_zip(book_path_)
		book_path = "user://temp/" + id + "/" # Book is at unzipped location
	else:
		book_path = book_path_ # Book is at specified path
	sections_list = sections_list_
	scrapbook_data = [] # Clear and repopulate data structures
	images_dict = {}
	spanners = {}
	idd_shapes = {}
	generate_images_dict(book_path)
	generate_texts_dict(book_path)
	generate_fonts_dict(book_path)
	preload_xmls(book_path)

func preload_xmls(book_path): # Preload MMS files, section by section
	for i in range(sections_list.size()):
		var section_data = preload_section(book_path + "/" + sections_list[i])
		scrapbook_data.append(section_data)

func preload_section(path):
	var file_path
	var dir = DirAccess.open(path)
	if(dir == null):
		return
	for file: String in dir.get_files():
		var extension = file.get_extension()
		if(extension == "mms"):
			file_path = file # Find the MMS file
	
	var zip_reader = ZIPReader.new() # Get the XML out of the zip archive
	zip_reader.open(path + "/" + file_path)
	var content = zip_reader.read_file(zip_reader.get_files()[0]) # Should be the only thing in there
	zip_reader.close()
	var parser = XMLParser.new()
	parser.open_buffer(content) # And parse the XML
	
	# First pass gets some important general data
	var num_pages = 0
	var canvas_width
	var canvas_height
	var max_output_width
	var max_output_height
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		if(parser.get_node_name() == "canvasWidth"):
			canvas_width = util_ExtraXML.get_text_contents(parser).to_int()
		elif(parser.get_node_name() == "maxOutputWidth"):
			max_output_width = util_ExtraXML.get_text_contents(parser).to_int()
		elif(parser.get_node_name() == "maxOutputHeight"):
			max_output_height = util_ExtraXML.get_text_contents(parser).to_int()
		elif(parser.get_node_name() == "pageObject"):
			preload_page_object_first_pass(parser)
	
	canvas_height = canvas_width * max_output_height / max_output_width
	
	# New parser for second pass
	parser = XMLParser.new()
	parser.open_buffer(content)
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		if(parser.get_node_name() == "pageObject"):
			preload_page_object_second_pass(parser, canvas_width, canvas_height, path)
	
	# And finally do everything else
	parser = XMLParser.new()
	parser.open_buffer(content)
	var pages : Array[ScrapbookPage] = []
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		if parser.get_node_name() == "page":
			num_pages += 1
			var page_name = parser.get_named_attribute_value_safe("name")
			var page_data = preload_page(parser, page_name)
			pages.append(page_data)
	var section = ScrapbookSection.new()
	section.pages = pages
	section.num_pages = num_pages
	section.path = path
	section.canvas_width = canvas_width
	section.canvas_height = canvas_height
	return section

func preload_page_object_first_pass(parser):
	
	# We do three passes to deal with bits of data that depend on each other
	# But may appear in any order
	var type = parser.get_named_attribute_value_safe("type") # Type of page object it is
	var data = util_ExtraXML.get_page_object_data(parser) # Data contained inside
	
	if(data.has("spannerId") && type != "spanner"):
		# Gonna be referenced by a spanner object somewhere
		data["objecttype"] = type
		spanners[data["spannerId"]] = data # Hold on to that data for them
	if(data.has("id") && (type == "shape" || type == "line")):
		# Gonna be referenced by a text object for text attached to shapes / lines
		data["objecttype"] = type
		idd_shapes[data["id"]] = data
func preload_page_object_second_pass(parser, canvas_width, canvas_height, path):
	var type = parser.get_named_attribute_value_safe("type")
	var data = util_ExtraXML.get_page_object_data(parser)
	if(type == "jWordText" && data.has("id") && idd_shapes.has(data["id"])):
		# Text object referencing a shape
		# Gotta preload it because calculating in-shape text alignment takes a second
		util_TextParsing.parse_text(data, canvas_width, canvas_height, path)
	
func preload_page(parser, page_name):
	var objects : Array[ScrapbookPageObject] = []
	var has_background = false # Used for transparency
	var has_children = false # We make our own background if theres a blank page
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT_END && parser.get_node_name() == "page":
			break # End of page
		if parser.get_node_type() == XMLParser.NODE_ELEMENT && parser.get_node_name() == "pageObject":
			has_children = true # Has objects!
			var page_object_data = preload_page_object(parser)
			objects.append(page_object_data)
			if(page_object_data.type == "background" && (!page_object_data.xml_data.has("imageopacity") || page_object_data.xml_data["imageopacity"].to_float() > 0.99)):
				has_background = true # Opaque background, no need to show pages under this one
	var page = ScrapbookPage.new()
	page.name = page_name
	page.objects = objects
	page.has_background = has_background || !has_children
	return page

func preload_page_object(parser):
	var type = parser.get_named_attribute_value_safe("type")
	var data = util_ExtraXML.get_page_object_data(parser) # Pick up the type and data
	if(type == "spanner"):
		# Spanners dont store their own data so we have to grab it from the object it referenced
		if(spanners.has(data["spannerId"])):
			type = spanners[data["spannerId"]]["objecttype"];
			for spanner_object_data in spanners[data["spannerId"]]:
				if(!data.has(spanner_object_data)):
					data[spanner_object_data] = spanners[data["spannerId"]][spanner_object_data]
	var object = ScrapbookPageObject.new()
	object.type = type
	object.xml_data = data
	return object

func generate_images_dict(book_path): # Fill dictionary with all images
	if(FileAccess.file_exists(book_path + "/cover_outside.png")): # Pick up the covers if there are any
		images_dict["coverOutside"] = ImageTexture.create_from_image(Image.load_from_file(book_path + "/cover_outside.png"))
		images_dict["coverInsideLeft"] = ImageTexture.create_from_image(Image.load_from_file(book_path + "/cover_inside_left.png"))
		images_dict["coverInsideRight"] = ImageTexture.create_from_image(Image.load_from_file(book_path + "/cover_inside_right.png"))
		
	for section in sections_list:
		# Images are stored in a folder called "objects" in the MMS project directory
		var section_objects_path = book_path + "/" + section + "/objects/"
		var diracc = DirAccess.open(section_objects_path)
		if(diracc == null):
			continue
		diracc.list_dir_begin()
		var file_name = diracc.get_next()
		while file_name != "":
			if !diracc.current_is_dir():
				var extension = file_name.split(".")[file_name.split(".").size() - 1]
				if(extension == "png"): # Load pngs as images
					var image = ImageTexture.create_from_image(Image.load_from_file(section_objects_path + file_name))
					images_dict[file_name] = image
				elif(extension == "svg"): # But save svgs as text for reference later
					var fileacc = FileAccess.open(section_objects_path + file_name, FileAccess.READ)
					var svg_data = fileacc.get_as_text()
					images_dict[file_name] = svg_data
			file_name = diracc.get_next() # Grab a new file and repeat
	
	# Finally load in the shape SVGs packaged with MMS
	# Theyre stored in a zip so Godot doesn't fuck us over by rasterizing them and only exporting the rasters
	# (This also significantly reduces some load times and file sizes)
	var basics_zip = ZIPReader.new()
	basics_zip.open("res://Shapes/Basics.zip")
	for file_name in basics_zip.get_files():
		var extension = file_name.split(".")[file_name.split(".").size() - 1]
		if(extension == "svg"):
			var svg_data = basics_zip.read_file(file_name).get_string_from_utf8()
			images_dict[file_name] = svg_data

func generate_texts_dict(book_path): # Fill dictionary with text objects
	for section in sections_list:
		var section_objects_path = book_path + "/" + section + "/objects/" # Rich text is also stored in objects/
		var diracc = DirAccess.open(section_objects_path)
		if(diracc == null):
			continue
		diracc.list_dir_begin()
		var file_name = diracc.get_next()
		while file_name != "":
			if !diracc.current_is_dir():
				var extension = file_name.get_extension()
				# jWord xml or StoryRock Word Art srw
				if(extension == "xml" || extension == "srw"):
					var fileacc = FileAccess.open(section_objects_path + file_name, FileAccess.READ)
					var xml_data = fileacc.get_as_text()
					texts_dict[file_name] = xml_data
			file_name = diracc.get_next()

func generate_fonts_dict(book_path): # Finally find the fonts from the fonts folder
	var diracc = DirAccess.open(book_path)
	if(!diracc.dir_exists(book_path + "/fonts")):
		return
	diracc = DirAccess.open(book_path + "/fonts")
	for file in diracc.get_files():
		var font = FontFile.new()
		if(book_path.ends_with("/")):
			font.load_dynamic_font(book_path + "fonts/" + file)
		else:
			font.load_dynamic_font(book_path + "/fonts/" + file)
		preloaded_fonts_dict[font.get_font_name() + " " + font.get_font_style_name()] = font


func extract_all_from_zip(path): 
	# Unzip compressed scrapbook to a temporary folder
	# Mostly because we can't read zips out of zips without writing them back to disk first
	var reader = ZIPReader.new()
	reader.open(path)

	# Destination directory for the extracted files (this folder must exist before extraction).
	# Not all ZIP archives put everything in a single root folder,
	# which means several files/folders may be created in `root_dir` after extraction.
	var id = str(int(floor(randf() * 1000000000)))
	
	var root_dir = DirAccess.open("user://")
	root_dir.make_dir_recursive("temp/" + id + "/")
	root_dir = DirAccess.open("user://temp/" + id + "/")

	var files = reader.get_files()
	for file_path in files:
		# Get the path without the silly [SLASH] workaround
		# (Done because Godot doesn't allow directories when making zip archives)
		var real_file_path = file_path.replace("[SLASH]", "/")
		
		if(real_file_path.begins_with("/")):
			real_file_path = real_file_path.substr(1, real_file_path.length())
		# If the current entry is a directory.
		if real_file_path.ends_with("/"):
			root_dir.make_dir_recursive(real_file_path)
			continue

		# Write file contents, creating folders automatically when needed.
		# Not all ZIP archives are strictly ordered, so we need to do this in case
		# the file entry comes before the folder entry.
		root_dir.make_dir_recursive(root_dir.get_current_dir().path_join(real_file_path).get_base_dir())
		var file = FileAccess.open(root_dir.get_current_dir().path_join(real_file_path), FileAccess.WRITE)
		var buffer = reader.read_file(file_path)
		file.store_buffer(buffer)
	return id
