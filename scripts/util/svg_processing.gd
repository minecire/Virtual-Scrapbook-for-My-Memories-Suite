extends Node

# Godot doesn't quite support SVG. Their rasterizer doesn't really have any options for modifying the SVG data,
# And it doesn't support text. My Memories Suite has a very robust SVG library that gives it a lot of features
# for free that we need to work hard to support.

# This is our proudest creation: a partially implemented parser for SVG files
# Mainly used to fit text into shapes and onto curves

func convert_shape_to_curves(file, shape_data, page_size, canvas_width, canvas_height):
	# Given a svg file, this function creates Godot curve objects (multi-segment bezier splines)
	# That can be used to fit text to curves or convert to polygons that can then compute fitting text to shapes
	var shape = Image.load_from_file(file)
	var width = shape.get_width()
	var height = shape.get_height()
	# One thing that Godot can help us with is getting the full size of an SVG object
	# This is otherwise quite challenging to obtain
	
	var transform_stack = [] 
	# Transformations will gradually be added and removed from the top as we parse through the SVG data tree
	var curves = []
	# An array of curves
	
	# We add some transformations to put the object in the right place on the page
	transform_stack.append("translate(" + str(shape_data["startX"].to_float() * page_size.x / canvas_width) + 
		" " + str(shape_data["startY"].to_float() * page_size.y / canvas_height) + ")")
	transform_stack.append("scale(" + str(shape_data["width"].to_float() / width * page_size.x / canvas_width) + 
		" " + str(shape_data["height"].to_float() / height * page_size.y / canvas_height) + ")")
		
	var parser = XMLParser.new()
	parser.open(file)
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
			if(parser.get_node_name() == "g" || parser.get_node_name() == "svg:g"):
				transform_stack.pop_back() # End of a transformed scope, remove a transform
			pass
			
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue # SVGs dont really have any non-element data, so this is just whitespace
		var node_name = parser.get_node_name()
		if(node_name == "svg" || node_name == "svg:svg"): # Beginning of the file
			var svg_data = util_ExtraXML.parse_attributes(parser)
			if(svg_data.has("x") && svg_data.has("y")): 
				# Stores the position, which we can add as a little transform
				transform_stack.append("matrix(1 0 0 1 " +svg_data["x"] + " " + svg_data["y"] + ")")
		elif(node_name == "g" || node_name == "svg:g"):
			# A kind of scope with its own transform
			var attributes = util_ExtraXML.parse_attributes(parser)
			if(attributes.has("transform")): # Add the transform to the stack
				transform_stack.append(attributes["transform"])
			else:
				transform_stack.append("")
		elif(node_name == "path" || node_name == "svg:path" || node_name == "rect" || node_name == "svg:rect" 
			|| node_name == "circle" || node_name == "svg:circle" || node_name == "ellipse" || 
			node_name == "svg:ellipse" || node_name == "polygon" || node_name == "svg:polygon"):
			# Some kind of shape object
			var attributes = util_ExtraXML.parse_attributes(parser)
			if(attributes.has("transform")): # Might have its own transform
				transform_stack.append(attributes["transform"])
			else:
				transform_stack.append("")
			# Add a curve together with its transform
			curves.append([parse_shape_object(node_name, attributes), transform_stack.duplicate()])
			transform_stack.pop_back()
	
	# Transform the curves based on its transformations
	var transformed_curves = []
	for curve_array in curves:
		for curve in curve_array[0]: # Each shape object returns an array of curves
			transformed_curves.append(apply_transformations_to_curve(curve, curve_array[1]))
	return transformed_curves
	
func parse_shape_object(shape_name, data_):
	# A lot of SVG parsing is simplifying the various types of objects into a singular type
	# Here everything gets converted to a path
	var path_
	if(shape_name == "path" || shape_name == "svg:path"):
		path_ = data_["d"]
	if(shape_name == "rect" || shape_name == "svg:rect"):
		path_ = convert_rect_to_path(data_)
	if(shape_name == "circle" || shape_name == "svg:circle"):
		path_ = convert_circle_to_path(data_)
	if(shape_name == "ellipse" || shape_name == "svg:ellipse"):
		path_ = convert_ellipse_to_path(data_)
	if(shape_name == "polygon" || shape_name == "svg:polygon"):
		path_ = convert_polygon_to_path(data_)
	
	# And the path is parsed
	return parse_path(path_, 1., 1.)
	

func convert_polygon_to_path(data_):
	# M to move to each point sequentially, then close the loop with a line
	return "M " + data_["points"] + " Z"
func convert_ellipse_to_path(data_):
	# center x, center y, radius x, radius y
	var cx = data_["cx"].to_float()
	var cy = data_["cy"].to_float()
	var rx = data_["rx"].to_float()
	var ry = data_["ry"].to_float()
	var path_ = ""
	path_ += "M " + str(cx + rx) + " " + str(cy) # Move to one side
	
	# Make a series of 90 degree arcs
	path_ += " A " + str(rx) + " " + str(ry) + " 0 0 0 " + str(cx) + " " + str(cy + ry)
	path_ += " A " + str(rx) + " " + str(ry) + " 0 0 0 " + str(cx - rx) + " " + str(cy)
	path_ += " A " + str(rx) + " " + str(ry) + " 0 0 0 " + str(cx) + " " + str(cy - ry)
	path_ += " A " + str(rx) + " " + str(ry) + " 0 0 0 " + str(cx + rx) + " " + str(cy)
	path_ += " Z" # And close
	return path_
	
func convert_circle_to_path(data_): # Simplified ellipse
	var cx = data_["cx"].to_float()
	var cy = data_["cy"].to_float()
	var r = data_["r"].to_float()
	
	var path_ = ""
	
	# Same thing but rx and ry are the same
	path_ += "M " + str(cx + r) + " " + str(cy)
	path_ += " A " + str(r) + " " + str(r) + " 0 0 1 " + str(cx) + " " + str(cy + r)
	path_ += " A " + str(r) + " " + str(r) + " 0 0 1 " + str(cx - r) + " " + str(cy)
	path_ += " A " + str(r) + " " + str(r) + " 0 0 1 " + str(cx) + " " + str(cy - r)
	path_ += " A " + str(r) + " " + str(r) + " 0 0 1 " + str(cx + r) + " " + str(cy)
	path_ += " Z"
	return path_
	
func convert_rect_to_path(data_):
	# Rectangle is complex because they can support rounded corners
	var x = data_["x"].to_float()
	var y = data_["y"].to_float()
	var width = data_["width"].to_float()
	var height = data_["height"].to_float()
	var rx = 0
	var ry = 0
	if(data_.has("rx") && data_.has("ry")):
		rx = data_["rx"].to_float()
		ry = data_["ry"].to_float()
	var path_ = ""
	path_ += "M " + str(x + rx) + " " + str(y) # Move to top left, offset by rounding
	path_ += " H " + str(x + width - rx) # Horizontal to top right
	if(rx > 0 && ry > 0): # Arc if applicable
		path_ += " A " + str(rx) + " " + str(ry) + " 0 0 1 " + str(x+width) + " " + str(y + ry)
	path_ += " V " + str(y + height - ry) # Bottom right
	if(rx > 0 && ry > 0): # Arc if applicable
		path_ += " A " + str(rx) + " " + str(ry) + " 0 0 1 " + str(x+width - rx) + " " + str(y + height)
	path_ += " H " + str(x + rx) # Bottom Left
	if(rx > 0 && ry > 0): # Arc
		path_ += " A " + str(rx) + " " + str(ry) + " 0 0 1 " + str(x) + " " + str(y + height - ry)
	path_ += " V " + str(y + ry) # Top Left
	if(rx > 0 && ry > 0): # One final arc
		path_ += " A " + str(rx) + " " + str(ry) + " 0 0 1 " + str(x + rx) + " " + str(y)
	path_ += "Z" # And close out
	return path_


func parse_path(pathdata, numberScale, squish): 
	# Paths can be scaled and squished in some cases when parsing Line objects
	var curve = Curve2D.new()
	var curves = []
	var current_element_type = "" # Hold on to current element as we loop character by character
	var current_number_string = ""
	var current_relevant_numbers = [] # And numbers relevant to that element
	var is_first_move = true # Starting with a move shouldnt create an empty curve
	for character : String in pathdata:
		if(character.is_valid_int() || character == "." || character == "-"): # Part of a number
			current_number_string += character
		elif(current_number_string != "" && character == " "): # Whitespace after a number, gotta add to array
			if(current_element_type != "A" || current_relevant_numbers.size() < 2 ||
				current_relevant_numbers.size() > 4): 
				# Weird if statement, basicaly arcs have flags that arent coordinates for disambiguation
				# Dont want to scale those
				
				# Scale numbers
				current_relevant_numbers.append(current_number_string.to_float() * numberScale)
			else:
				current_relevant_numbers.append(current_number_string.to_float())
			current_number_string = "" # Clear string to be filled with the next number
		elif(character.to_upper() != character.to_lower()): # We have a letter, this is a new element
			if(current_element_type != ""): # We parse the previous element
				if(current_element_type == "m" || current_element_type == "M"): # Move creates a new curve
					if(!is_first_move):
						curves.append(curve.duplicate(true)) # Add the old one, copied
						curve = Curve2D.new() # Clear for the new one
					else: # Except the first one which does nothing
						is_first_move = false
				# Parse element
				parse_path_element(current_element_type, current_relevant_numbers, squish, curve)
			current_relevant_numbers = [] # Clear the numbers for the next element
			current_element_type = character # Set the next element
			
	if(current_number_string != ""): # Make sure to parse the final element
		current_relevant_numbers.append(current_number_string.to_float() * numberScale)
	parse_path_element(current_element_type, current_relevant_numbers, squish, curve)
	curves.append(curve.duplicate(true)) # Add the final curve
	return curves

func parse_path_element(type, numbers, squish, curve):
	# Paths are made up of jumps between curves, straight lines, quadratic beziers, cubic beziers, and arcs
	# Which are further split up
	
	# Capitalization implies absolute positions, lowercase means relative to the previous point
	# An element can also have multiple sets of numbers which basically repeat the element type
	
	if(type == "M" || type == "L"): 
		# Move or draw a straight line, basically the same besides breaking the curve or not
		# Repeated coordinates after a move are actually documented to draw lines after the first one
		
		# Which gets handled in parse_path
		for i in range(0, numbers.size() - 1, 2):
			curve.add_point(Vector2(numbers[i], numbers[i+1]) * Vector2(1., squish))
	elif(type == "m" || type == "l"):
		for i in range(0, numbers.size() - 1, 2):
			var relative_pos = curve.get_point_position(curve.point_count - 1) # Previous point position
			curve.add_point(relative_pos + Vector2(numbers[i], numbers[i+1]) * Vector2(1., squish))
	elif(type == "H"): # Horizontal, only a single X coordinate
		for i in range(numbers.size()):
			var relative_pos = curve.get_point_position(curve.point_count - 1)
			curve.add_point(Vector2(numbers[i], relative_pos.y))
	elif(type == "h"):
		for i in range(numbers.size()):
			var relative_pos = curve.get_point_position(curve.point_count - 1)
			curve.add_point(Vector2(relative_pos.x + numbers[i], relative_pos.y))
	elif(type == "V"): # Vertical, only a y coordinate
		for i in range(numbers.size()):
			var relative_pos = curve.get_point_position(curve.point_count - 1)
			curve.add_point(Vector2(relative_pos.x, numbers[i]) * Vector2(1., squish))
	elif(type == "v"):
		for i in range(numbers.size()):
			var relative_pos = curve.get_point_position(curve.point_count - 1)
			curve.add_point(Vector2(relative_pos.x, relative_pos.y + numbers[i]) * Vector2(1., squish))
	elif(type == "Z" || type == "z"): # Close the curve, takes no numbers
		curve.add_point(curve.get_point_position(0)) # Back to the first point on the curve
	elif(type == "C"): # Cubic bezier
		for i in range(0, numbers.size(), 6):
			var relative_pos = curve.get_point_position(curve.point_count - 1)
			# Bezier control points on Godot curves are relative to the point they connect to
			curve.set_point_out(curve.point_count - 1, Vector2(numbers[i], numbers[i+1]) * Vector2(1., squish) - relative_pos)
			curve.add_point(Vector2(numbers[i+4], numbers[i+5]) * Vector2(1., squish), 
				Vector2(numbers[i+2] - numbers[i+4], numbers[i+3] - numbers[i+5]) * Vector2(1., squish))
	elif(type == "c"):
		for i in range(0, numbers.size(), 6):
			var relative_pos = curve.get_point_position(curve.point_count - 1)
			# This gets complicated because we have to convert from relative to the previous point
			# To relative to the current one
			curve.set_point_out(curve.point_count - 1, Vector2(numbers[i], numbers[i+1]) * Vector2(1., squish))
			curve.add_point(Vector2(numbers[i+4], numbers[i+5]) * Vector2(1., squish) + relative_pos, 
			Vector2(numbers[i+2], numbers[i+3] - Vector2(numbers[i+4], numbers[i+5])) * Vector2(1., squish) + relative_pos)
	elif(type == "S"): # Smooth cubic bezier
		for i in range(0, numbers.size(), 4):
			# Out vector opposite in vector for a smooth curve
			curve.set_point_out(curve.point_count - 1, -1 * curve.get_point_in(curve.point_count - 1))
			# Otherwise the same as C but without the extra numbers passed in
			curve.add_point(Vector2(numbers[i+2], numbers[i+3]) * Vector2(1., squish), 
				Vector2(numbers[i] - numbers[i+2], numbers[i+1] - numbers[i+3]) * Vector2(1., squish))
	elif(type == "s"):
		for i in range(0, numbers.size(), 4):
			var relative_pos = curve.get_point_position(curve.point_count - 1)
			curve.set_point_out(curve.point_count - 1, -1 * curve.get_point_in(curve.point_count - 1))
			curve.add_point(Vector2(numbers[i+2], numbers[i+3]) * Vector2(1., squish) + relative_pos, 
			Vector2(numbers[i], numbers[i+1] - Vector2(numbers[i+2], numbers[i+3])) * Vector2(1., squish) + relative_pos)
	elif(type == "Q"): # Quadratic bezier
		for i in range(0, numbers.size(), 4):
			var relative_pos = curve.get_point_position(curve.point_count - 1)
			# Basically just uses the same control point for out of the previous point and into the next
			curve.set_point_out(curve.point_count - 1, Vector2(numbers[i], numbers[i+1]) * Vector2(1., squish) - relative_pos)
			curve.add_point(Vector2(numbers[i+2], numbers[i+3]) * Vector2(1., squish), Vector2(numbers[i] - numbers[i+2], numbers[i+1] - numbers[i+3]) * Vector2(1., squish))
	elif(type == "q"):
		for i in range(0, numbers.size(), 4):
			var relative_pos = curve.get_point_position(curve.point_count - 1)
			curve.set_point_out(curve.point_count - 1, Vector2(numbers[i], numbers[i+1]) * Vector2(1., squish))
			curve.add_point(Vector2(numbers[i+2], numbers[i+3]) * Vector2(1., squish) + relative_pos, Vector2(numbers[i], numbers[i+1]) * Vector2(1., squish))
	elif(type == "T"): # Smooth quadratic
		for i in range(0, numbers.size(), 2):
			curve.set_point_out(curve.point_count - 1, -1 * curve.get_point_in(curve.point_count - 1))
			curve.add_point(Vector2(numbers[i], numbers[i+1]) * Vector2(1., squish), (curve.get_point_out(curve.point_count - 1) - curve.get_point_position(curve.point_count - 1) + Vector2(numbers[i], numbers[i+1])) * Vector2(1., squish))
	elif(type == "t"):
		for i in range(0, numbers.size(), 2):
			var relative_pos = curve.get_point_position(curve.point_count - 1)
			curve.set_point_out(curve.point_count - 1, -1 * curve.get_point_in(curve.point_count - 1))
			curve.add_point(Vector2(numbers[i], numbers[i+1]) * Vector2(1., squish) + relative_pos, (curve.get_point_out(curve.point_count - 1) - curve.get_point_position(curve.point_count - 1) + Vector2(numbers[i], numbers[i+1])) * Vector2(1., squish))
	elif(type == "A"): # Arc
		var relative_pos = curve.get_point_position(curve.point_count - 1)
		# Basically just convert it to cubic beziers
		# Technically not a perfect arc but solid approximation
		var curve_coords = arc_to_cubic(numbers, relative_pos, squish) 
		for i in range(0, curve_coords.size(), 3): # Add the same as normal cubics
			relative_pos = curve.get_point_position(curve.point_count - 1)
			curve.set_point_out(curve.point_count - 1, curve_coords[i] * Vector2(1., squish) - relative_pos)
			curve.add_point(curve_coords[i + 2] * Vector2(1., squish), (curve_coords[i + 1] - curve_coords[i + 2]) * Vector2(1., squish))
	elif(type == "a"):
		var relative_pos = curve.get_point_position(curve.point_count - 1)
		numbers[5] += relative_pos.x
		numbers[6] += relative_pos.y / squish # Convert coordinates to relative position
		var curve_coords = arc_to_cubic(numbers, relative_pos, squish) # And do the same thing
		for i in range(0, curve_coords.size(), 3):
			relative_pos = curve.get_point_position(curve.point_count - 1)
			curve.set_point_out(curve.point_count - 1, curve_coords[i] * Vector2(1., squish) - relative_pos)
			curve.add_point(curve_coords[i + 2] * Vector2(1., squish), (curve_coords[i + 1] - curve_coords[i + 2]) * Vector2(1., squish))

func arc_to_cubic(numbers, relative_pos, squish, recursive = null):
	# from: https://github.com/adobe-webplatform/Snap.svg/blob/b242f49e6798ac297a3dad0dfb03c0893e394464/src/path.js#L752
	# Tried figuring this out on our own, could not get it to work and copied someone else
	
	var rx = numbers[0]
	var ry = numbers[1]
	var rad = numbers[2] * PI / 180.
	var large_arc_flag = numbers[3]
	var sweep_flag = numbers[4]
	var x2 = numbers[5]
	var y2 = numbers[6]
	
	var x1 = relative_pos.x
	var y1 = relative_pos.y / squish
	
	var _120_degrees = PI * 120. / 180.
	var res = []
	var xy
	var cx
	var cy
	var f1
	var f2
	if(recursive == null):
		xy = rotatePoint(Vector2(x1, y1), -rad)
		x1 = xy.x
		y1 = xy.y
		xy = rotatePoint(Vector2(x2, y2), -rad)
		x2 = xy.x
		y2 = xy.y
		
		var x = (x1 - x2) / 2.
		var y = (y1 - y2) / 2.
		var h = x * x / (rx * rx) + y * y / (ry * ry)
		if(h > 1):
			rx *= sqrt(h)
			ry *= sqrt(h)
		var rx2 = rx * rx
		var ry2 = ry * ry
		var k = -1. if (large_arc_flag > 0. && sweep_flag > 0. || large_arc_flag == 0. && sweep_flag == 0.) else 1.
		k *= sqrt(abs((rx2 * ry2 - rx2 * y * y - ry2 * x * x) / (rx2 * y * y + ry2 * x * x)))
		cx = k * rx * y / ry + (x1 + x2) / 2.
		cy = k * -ry * x / rx + (y1 + y2) / 2.
		
		f1 = asin((y1 - cy) / ry)
		f2 = asin((y2 - cy) / ry)
		
		f1 = (PI - f1) if x1 < cx else f1
		f2 = (PI - f2) if x2 < cx else f2
		f1 += (2. * PI) if f1 < 0 else 0.
		f2 += (2. * PI) if f2 < 0 else 0.
		if (sweep_flag > 0 && f1 > f2):
			f1 = f1 - PI * 2.;
		if (sweep_flag == 0 && f2 > f1):
			f2 = f2 - PI * 2.;
	else:
		f1 = recursive[0]
		f2 = recursive[1]
		cx = recursive[2]
		cy = recursive[3]
	
	var df = f2 - f1
	if(abs(df) > _120_degrees):
		var f2old = f2
		var x2old = x2
		var y2old = y2
		f2 = f1 + _120_degrees * (1 if (sweep_flag > 0 && f2 > f1) else -1)
		x2 = cx + rx * cos(f2)
		y2 = cy + ry * sin(f2)
		res = arc_to_cubic([rx, ry, numbers[2], 0., sweep_flag, x2old, y2old], Vector2(x2, y2), 1., [f2, f2old, cx, cy])
	df = f2 - f1
	var c1 = cos(f1)
	var s1 = sin(f1)
	var c2 = cos(f2)
	var s2 = sin(f2)
	var t = tan(df / 4.)
	var hx = 4. / 3. * rx * t
	var hy = 4. / 3. * ry * t
	var m1 = Vector2(x1, y1)
	var m2 = Vector2(x1 + hx * s1, y1 - hy * c1)
	var m3 = Vector2(x2 + hx * s2, y2 - hy * c2)
	var m4 = Vector2(x2, y2)
	m2 = 2 * m1 - m2
	if(recursive != null):
		var arr = [m2, m3, m4]
		arr.append_array(res)
		return arr
	else:
		var arr = [m2, m3, m4]
		arr.append_array(res)
		res = arr
		var newres = []
		for i in range(res.size()):
			var new_point = rotatePoint(res[i], rad)
			newres.append(new_point)
		return newres

func rotatePoint(point, rad): # Rotates a point around the origin
	var x = point.x * cos(rad) - point.y * sin(rad)
	var y = point.x * sin(rad) + point.y * cos(rad)
	return Vector2(x, y)

func apply_transformations_to_curve(curve_, tfs): 
	# Apply a list of transformation strings to a curve
	var new_curve = curve_.duplicate()
	for i in range(0, new_curve.point_count): # Loop through all points
		var p_in = new_curve.get_point_in(i) # Get the relative in and out points, and absolute position
		var p_out = new_curve.get_point_out(i)
		var p_pos = new_curve.get_point_position(i)
		var p_in_new = p_in # Make variables for the transformed version
		var p_out_new = p_out
		var p_pos_new = p_pos
		for j in range(tfs.size() - 1, -1, -1): # Loop through transformations in reverse order
			# Relative points don't get translated
			p_in_new = apply_transformation_string(p_in_new, tfs[j], false)
			p_out_new = apply_transformation_string(p_out_new, tfs[j], false)
			p_pos_new = apply_transformation_string(p_pos_new, tfs[j], true)
		new_curve.set_point_in(i, p_in_new)
		new_curve.set_point_out(i, p_out_new)
		new_curve.set_point_position(i, p_pos_new)
	return new_curve

func apply_transformation_string(point, string, translate): 
	# A string can have many transformations in a list
	var current_type = ""
	var new_point = point
	for i in range(string.length()): # Loop through the string
		var character: String = string[i] # Get a character
		if(character.to_upper() != character.to_lower()): # Letter, add it to transform type name
			current_type += character
			continue
		if(character == "("): # List of arguments in the parethesis
			var current_number_string = ""
			var current_relevant_numbers = []
			while(character != ")"):
				i+=1
				if(i >= string.length()): # End of string, we're done
					break
				character = string[i]
				if(character == "," || character == " "): # New number
					current_relevant_numbers.append(parse_css_number_thing(current_number_string))
					current_number_string = ""
				else:
					current_number_string += character
			current_relevant_numbers.append(parse_css_number_thing(current_number_string)) # Parse final number
			current_number_string = ""
			# And apply the transformation
			new_point = apply_transformation(new_point, [current_type.replace(" ", ""), current_relevant_numbers], translate)
	return new_point

func parse_css_number_thing(string):
	# Numbers can be stored in all kinds of ways, with units signifying how
	# A lot of them are kind of undefined behavior in this context, so we support what we can
	
	var unit = ""
	var number = string.to_float()
	for character: String in string:
		if(character.to_upper() != character.to_lower()): # Letter
			unit += character # Get the units string
	if(unit == "" || unit == "px" || unit == "rad"): # Pixels and radians are default units, no parsing needed
		return number
		
	# Spatial dimension units have direct translations to pixels outlined in the SVG specs
	# Based on 1 inch = 96 pixels (A bit silly since this relationship varies wildly depending on the screen)
	elif(unit == "cm"):
		return number * 2.54 / 96.
	elif(unit == "mm"):
		return number * 2.54 * 10. / 96.
	elif(unit == "Q"):
		return number * 2.54 * 40. / 96.
	elif(unit == "in"):
		return number / 96.
	elif(unit == "pc"):
		return number * 6. / 96.
	elif(unit == "pt"):
		return number * 72. / 96.
	
	# Finally we can convert some angle measures to radians
	elif(unit == "deg"):
		return number * PI / 180.
	elif(unit == "grad"):
		return number * PI / 200.
	elif(unit == "turn"):
		return number * 2. * PI
	else:
		push_warning("unsupported svg parameter") # Outta luck :(
		return number

func apply_transformation(point, tf, translate): # A single transformation
	var type = tf[0]
	var transformation_data = tf[1]
	if(type == "scale"): 
		# Scaling can take one or two arguments, so we just duplicate the first one
		# so either way the first two arguments will be correct
		transformation_data.append(transformation_data[0])
	transformation_data.append_array([0., 0., 0., 0., 0., 0.]) # Everything else just assumes zero if argument isnt specified
	var tfmatrix 
	# Convert everything to a 4x4 transformation matrix
	# Formulae from the SVG spec
	if(type == "matrix"):
		tfmatrix = [[transformation_data[0], transformation_data[2], 0., transformation_data[4]], [transformation_data[1], transformation_data[3], 0., transformation_data[5]], [0., 0., 1., 0.], [0., 0., 0., 1.]]
	elif(type == "translate"):
		tfmatrix = [[1., 0., 0., transformation_data[0]], [0., 1., 0., transformation_data[1]], [0., 0., 1., 0.], [0., 0., 0., 1.]]
	elif(type == "translateX"):
		tfmatrix = [[1., 0., 0., transformation_data[0]], [0., 1., 0., 0.], [0., 0., 1., 0.], [0., 0., 0., 1.]]
	elif(type == "translateY"):
		tfmatrix = [[1., 0., 0., 0.], [0., 1., 0., transformation_data[0]], [0., 0., 1., 0.], [0., 0., 0., 1.]]
	elif(type == "scale"):
		tfmatrix = [[transformation_data[0], 0., 0., 0.], [0., transformation_data[1], 0., 0.], [0., 0., 1., 0.], [0., 0., 0., 1.]]
	elif(type == "scaleX"):
		tfmatrix = [[transformation_data[0], 0., 0., 0.], [0., 1., 0., 0.], [0., 0., 1., 0.], [0., 0., 0., 1.]]
	elif(type == "scaleY"):
		tfmatrix = [[1., 0., 0., 0.], [0., transformation_data[0], 0., 0.], [0., 0., 1., 0.], [0., 0., 0., 1.]]
	elif(type == "rotate"):
		tfmatrix = [[cos(transformation_data[0]), -sin(transformation_data[1]), 0., 0.], [sin(transformation_data[0]), cos(transformation_data[1]), 0., 0.], [0., 0., 1., 0.], [0., 0., 0., 1.]]
	elif(type == "skew"):
		tfmatrix = [[1., tan(transformation_data[0]), 0., 0.], [tan(transformation_data[1]), 1., 0., 0.], [0., 0., 1., 0.], [0., 0., 0., 1.]]
	elif(type == "skewX"):
		tfmatrix = [[1., tan(transformation_data[0]), 0., 0.], [0., 1., 0., 0.], [0., 0., 1., 0.], [0., 0., 0., 1.]]
	elif(type == "skewY"):
		tfmatrix = [[1., 0., 0., 0.], [tan(transformation_data[0]), 1., 0., 0.], [0., 0., 1., 0.], [0., 0., 0., 1.]]
	if(!translate): # We're not translating (it's a relative coordinate), set translation to zero
		tfmatrix[0][3] = 0.
		tfmatrix[1][3] = 0.
	return(apply_transformation_matrix(point, tfmatrix)) # Apply the matrix

func apply_transformation_matrix(point, matrix):
	var point_vec4 = Vector4(point.x, point.y, 1., 1.) # Get as 4D vector
	var new_point = Vector2.ZERO # Just need to calculate XY using matrix math
	new_point.x = point_vec4.x * matrix[0][0] + point_vec4.y * matrix[0][1] + matrix[0][3]
	new_point.y = point_vec4.x * matrix[1][0] + point_vec4.y * matrix[1][1] + matrix[1][3]
	return new_point


func convert_curves_to_convex_polygon_shapes_2d(shape_curves, sample_count):
	# Convert curves to polygons to do collision detection
	# Done to compute fitting text to arbitrary shapes
	var shape_polygons = convert_curves_to_polygons_naive(shape_curves, sample_count)
	var merged_polygons = combine_polygons(shape_polygons)
	var convex_polygons = convert_to_convex_polygon_shapes_2d(merged_polygons)
	
	return convex_polygons

func convert_curves_to_polygons_naive(shape_curves, sampleCount):
	# Convert everything into polygons by sampling a bunch of points
	# Naive because this doesnt account for curves that intersect each other, which should be combined
	# This is fixed in the next step
	
	var shape_polygons = {}
	for curve_ in shape_curves:
		if(curve_.get_baked_length() < 0.001):
			# Tiny curves are errors that will break things, ignore
			continue
		var polygon_points = []
		for i in range(0, sampleCount, 1):
			var newI = float(i) / float(sampleCount) # Distance along the curve from 0 to 1
			polygon_points.append(curve_.sample_baked(curve_.get_baked_length() * newI)) # Grab a point
		var polygon = Polygon2D.new() # Make a polygon with them
		polygon.polygon = polygon_points
		var id = str(floor(randf() * 1000000000)) # Give a randomized id
		shape_polygons[id] = polygon
	return shape_polygons

func combine_polygons(shape_polygons):
	var merged = [] # We make an array of polygons
	for poly in shape_polygons:
		merged.append(shape_polygons[poly].polygon)
		
	for j in range(0, merged.size(), 2):
		# Loop through and merge neighbors repeatedly
		# Assumes that SVG formatting is reasonable enough that connected polygons will always be neighbors
		# I think this is almost always true
		var new_merged = []
		for i in range(0, merged.size(), 2):
			if(i == merged.size() - 1):
				new_merged.append(merged[i])
			else:
				new_merged.append_array(Geometry2D.merge_polygons(merged[i], merged[i + 1]))
		if(merged == new_merged):
			return merged
		merged = new_merged
	return merged

func convert_to_convex_polygon_shapes_2d(polygons):
	# The computation cannot be done on concave polygons, so we need to break them up into convex chunks
	var new_polygons = []
	for polygon in polygons:
		# Convert to ConcavePolygonShape2D
		# Why this is different from Polygon2D we couldn't tell you
		# It takes segments made of two points
		var edge = []
		for i in range(polygon.size()):
			edge.append(polygon[i])
			if(i > 0):
				edge.append(polygon[i]) # So we duplicate each point except the first
				
		edge.append(polygon[0]) # And put the first point back at the end
		var edge_shape = ConcavePolygonShape2D.new()
		edge_shape.segments = edge
		
		# ConcavePolygonShape2D can then be broken up
		var decomposed = Geometry2D.decompose_polygon_in_convex(polygon)
		var new = []
		for part in decomposed: 
			# This returns an array of sets of points that we need to put together into convex polygons
			var new_poly = ConvexPolygonShape2D.new()
			new_poly.points = part
			new.append(new_poly)
		new_polygons.append([new, edge_shape])
	return new_polygons
