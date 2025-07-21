extends Node

var data
var path

var pageSize
var canvasWidth

func _ready():
	parse_text(path + "/objects/" + data["fileName"])
	prepare_texture()
	

func prepare_texture():
	$TextTexture.size = Vector2(data["width"].to_int(), data["height"].to_int()) * pageSize.x / canvasWidth
	$TextTexture.position = Vector2(data["startX"].to_int(), data["startY"].to_int()) * pageSize.x / canvasWidth

func parse_text(filepath):
	
	var attributes
	var text
	
	var parser = XMLParser.new()
	parser.open(filepath)
	
	while parser.read() != ERR_FILE_EOF:
		if(parser.get_node_type() == XMLParser.NODE_ELEMENT && parser.get_node_name() == "content"):
			attributes = parse_attributes(parser)
			text = get_text_contents(parser)
			pass
	#$TextViewport/Text.push_font_size(50)
	$TextViewport/Text.push_outline_size(30)
	$TextViewport/Text.push_outline_color(Color.BLACK)
	$TextViewport/Text.push_color(Color.WHITE)
	$TextViewport/Text.add_text(text)
	
	var font = SystemFont.new()
	var fontNames = PackedStringArray()
	fontNames.append(attributes["fontname"])
	font.set_font_names(fontNames)
	#$TextViewport/Text.add_theme_font_override("normal_font", font)
	$TextViewport/Text.add_theme_font_size_override("normal_font_size", 300)
	
	var stringSize = font.get_string_size(text, 0, -1, 300)
	$TextViewport.size = stringSize
	$TextViewport/Text.size = stringSize


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
		push_warning("no text found")
		return ""
