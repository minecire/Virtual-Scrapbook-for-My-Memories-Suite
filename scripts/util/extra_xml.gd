extends Node

# Godot's XML parser works okay, but it needs a little help sometimes

func get_text_contents(parser): # Get the contents of a text node
	parser.read()
	if(parser.get_node_type() == XMLParser.NODE_TEXT):
		return(parser.get_node_data())
	else:
		# Uh oh we just skipped a node! Hope it wasn't important, cuz theres no going back
		push_warning("no text found")
		return ""

func parse_attributes(parser): # Get a little dictionary of the attributes of a node
	var data = {}
	for idx in range(parser.get_attribute_count()):
		data[parser.get_attribute_name(idx)] = parser.get_attribute_value(idx)
	return data

func get_page_object_data(parser): # Pull data out of a page object XML
	var data = {}
	while !(parser.get_node_type()  == XMLParser.NODE_ELEMENT_END && parser.get_node_name() == "pageObject"):
		# Loop to the end of the object
		parser.read()
		if parser.get_node_type()  == XMLParser.NODE_ELEMENT:
			# No attributes, just nodes with data as text elements in between
			var nodename = parser.get_node_name()
			var nodedata = get_text_contents(parser)
			data[nodename] = nodedata
	return data
