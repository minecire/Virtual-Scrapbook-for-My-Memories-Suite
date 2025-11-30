extends Control

# This file handles the rendering of a single page
# Jank has been moved elsewhere until further notice

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
var gradient_background_scene = preload("res://scenes/pageobjects/gradient_background.tscn")
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

#object types: background, image, jwordtext, textart, line, calendar, shape
#    todo: 
#word art
#calendar(low priority)
#images(low priority): shadow resize, mask subtexture bullshit, shape rotation, fix bug with multiple shapes with different stretch on one page
#text(low priority): a few missing fonts, bold/italics failing on some fonts, rotation on curves

var id;


func load_page(): # Called to reload a page
	
	for n in get_children():
		remove_child(n)
		n.free()
	
	parse_page() # Loops through to add elements
	
	if get_children().size() == 0: 
		# If page is blank, at least add a background
		var cbi = color_background_scene.instantiate()
		# Downside of having objects parse data directly from the MMS file themselves
		# It's hard to make our own from scratch
		cbi.get_node("ColorPanel").size = page_size
		cbi.get_node("ColorPanel").color = Color(0.9, 0.83, 0.8)
		add_child(cbi)

func parse_page():
	# Get some global data
	num_pages = util_Preloader.scrapbook_data[section_index].num_pages
	canvas_width = util_Preloader.scrapbook_data[section_index].canvas_width
	canvas_height = util_Preloader.scrapbook_data[section_index].canvas_height
	
	# Parse the individual page's data
	if(page_index >= util_Preloader.scrapbook_data[section_index]["pages"].size()):
		return
	for object in util_Preloader.scrapbook_data[section_index]["pages"][page_index]["objects"]:
		# Parse each object one at a time
		parse_page_object(object)

func parse_page_object(object):
	var type = object.type # Type of object
	var data = object.xml_data # Data direct from the MMS file
	
	# MMS background conventions use an integer "type" variable for each type of background
	# Get used to these arbitrary numbers, the MMS file has a lot of them
	# 1 - Solid Color
	# 2 - Image
	# 3 - Pattern (Unclear what the distinction between pattern and image is)
	# 4 - Gradient
	if(type == "background" && data["type"] == "1"):
		parse_color_background(data, type)
	elif(type == "background" && (data["type"] == "2" || data["type"] == "3")):
		parse_image_background(data, type)
	elif(type == "background" && data["type"] == "4"):
		parse_gradient_background(data, type)
	
	# A lot of different things are basically just different names for an image
	# (with just enough variation of definitions to make the image parser a mess of edge cases,
	# but not quite enough variation of functionality to justify separating anything else out)
	elif(type == "image" || type == "embellishment" || type == "stamp" || type == "paint" || type == "shape"):
		parse_image(data, type)
	elif(type == "line"): # A multi-segment spline defined by an SVG path
		parse_line(data, type)
	elif(type == "jWordText"): # Textbox with some fancy formatting
		parse_text(data, type)
	elif(type == "textArt"): # Word art
		parse_text_art(data, type)
	elif(type != "spanner"): # Spanners are a special object for any object that spans multiple pages.
		# They are handled in the initial preload step
		push_warning("unsupported datatype: " + type) # Otherwise we have an unsupported datatype
		# Effectively only calendars are unsupported,
		# But intriguingly, the MMS codebase does suggest that the file format is include to handle videos,
		# plaintext, links, and more, although MMS itself has no way to use these features
		
func parse_color_background(data, type): # Background of a solid color
	var color_background_instance = color_background_scene.instantiate()
	color_background_instance.initialize_variables(type, data, path, page_size, page_type, canvas_width, canvas_height, section_index)
	add_child(color_background_instance)

func parse_image_background(data, type): # Background from image
	var image_background_instance = image_background_scene.instantiate()
	image_background_instance.initialize_variables(type, data, path, page_size, page_type, canvas_width, canvas_height, section_index)
	add_child(image_background_instance)

func parse_gradient_background(data, type):
	var gradient_background_instance = gradient_background_scene.instantiate()
	gradient_background_instance.initialize_variables(type, data, path, page_size, page_type, canvas_width, canvas_height, section_index)
	add_child(gradient_background_instance)
	
func parse_image(data, type):
	var image_instance = image_scene.instantiate()
	image_instance.initialize_variables(type, data, path, page_size, page_type, canvas_width, canvas_height, section_index)
	add_child(image_instance)
	
func parse_text(data, type): 
	var text_instance = text_scene.instantiate()
	text_instance.initialize_variables(type, data, path, page_size, page_type, canvas_width, canvas_height, section_index)
	text_instance.go_to_section.connect(_on_text_go_to_section) # Clickable links need a signal connection
	if(data.has("id")):
		# Loading text with an id causes problems because it creates duplicate instances
		return
	add_child(text_instance)
	
func parse_line(data, type): # Line is stored as a part of an SVG object
	var line_instance = line_scene.instantiate()
	line_instance.initialize_variables(type, data, path, page_size, page_type, canvas_width, canvas_height, section_index)
	add_child(line_instance)


func parse_text_art(data, type): # Word art
	var word_art_instance = word_art_scene.instantiate()
	word_art_instance.initialize_variables(type, data, path, page_size, page_type, canvas_width, canvas_height, section_index)
	add_child(word_art_instance)

# Emitted when a page link is clicked
func _on_text_go_to_section(section): 
	emit_signal("go_to_section", section, 1)
func _on_text_go_to_page(section, page):
	emit_signal("go_to_section", section, page)
