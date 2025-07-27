extends Node

func convert_curves_to_polygons_naive(shapeCurves, sampleCount):
	var shapePolygons = {}
	for acurve in shapeCurves:
		if(acurve.get_baked_length() < 0.001):
			continue
		var polygonPoints = []
		for i in range(0, sampleCount, 1):
			var newI = float(i) / float(sampleCount)
			polygonPoints.append(acurve.sample_baked(acurve.get_baked_length() * newI))
		var polygon = Polygon2D.new()
		polygon.polygon = polygonPoints
		var id = str(floor(randf() * 1000000000))
		shapePolygons[id] = polygon
	return shapePolygons

func combine_polygons(shapePolygons):
	var merged = []
	for poly in shapePolygons:
		merged.append(shapePolygons[poly].polygon)
		
	for j in range(0, merged.size(), 2):
		var newMerged = []
		for i in range(0, merged.size(), 2):
			if(i == merged.size() - 1):
				newMerged.append(merged[i])
			else:
				newMerged.append_array(Geometry2D.merge_polygons(merged[i], merged[i + 1]))
		merged = newMerged
	return merged
	#var polygonProperties = []
	#for id in shapePolygons:
		#var polygon = shapePolygons[id]
		#var points = polygon.polygon
		#var positiveExtremePoints = []
		#var negativeExtremePoints = []
		#var intersectedPolygons = []
		#var lastPoint
		#var lastIntersected = false
		#for point in points:
			#var intersecting = false
			#for intersectTestid in shapePolygons:
				#if(id == intersectTestid):
					#continue
				#var intersectTest = shapePolygons[intersectTestid]
				#if(Geometry2D.is_point_in_polygon(point, intersectTest.polygon)):
					#if(intersectedPolygons.find(intersectTestid) == null):
						#intersectedPolygons.append(intersectTestid)
					#intersecting = true
					#break
			#
			#if(intersecting && !lastIntersected && lastPoint != null):
				#negativeExtremePoints.append(lastPoint)
				#lastIntersected = true
				#points.remove_at(points.find(point))
			#elif(!intersecting && lastIntersected):
				#positiveExtremePoints.append(point)
				#lastIntersected = false
			#lastPoint = point
		#var propertiesDict = {}
		#propertiesDict["id"] = id
		#propertiesDict["points"] = points
		#propertiesDict["positiveExtremePoints"] = positiveExtremePoints
		#propertiesDict["negativeExtremePoints"] = negativeExtremePoints
		#propertiesDict["intersectedPolygons"] = intersectedPolygons
		#polygonProperties.append(propertiesDict)
	#print(polygonProperties)
	#var alreadyChecked = []
	#var combinedPolygons = []
	#for poly in polygonProperties:
		#if(alreadyChecked.find(poly["id"]) != -1):
			#continue
		#var polyglob = get_all_connected_polygons(polygonProperties, poly)
		#var newPoly = Polygon2D.new()
		#newPoly.polygon = connect_points(poly, polyglob, 0, true)
		#combinedPolygons.append(newPoly)
		#for globpoly in polyglob:
			#alreadyChecked.append(globpoly["id"])
	#return combinedPolygons

func connect_points(currentpoly, polyglob, pointIndex, positive, usedPoints = []):
	var index = pointIndex
	while true:
		var point = currentpoly["points"][index]
		if(usedPoints.find(point) != -1):
			return usedPoints
		usedPoints.append(point)
		if currentpoly["positiveExtremePoints"].find(point) != -1 || currentpoly["negativeExtremePoints"].find(point) != -1:
			var newdata = find_extreme_point(point, polyglob)
			var newUsedPoints = connect_points(newdata["poly"], polyglob, newdata["point"], newdata["positive"], usedPoints)
			return newUsedPoints
		if(positive):
			index+=1
		else:
			index-=1
		
		if(index >= currentpoly["points"].size()):
			index = 0
		if(index < 0):
			index = currentpoly["points"].size() - 1
	pass

func find_extreme_point(point, polyglob):
	var closestSoFar = {"distance2": -1}
	for poly in polyglob:
		for i in range (poly["positiveExtremePoints"].size()):
			var extremepoint = poly["positiveExtremePoints"][i]
			if(closestSoFar["distance2"] == -1 || closestSoFar["distance2"] > (point - extremepoint).length_squared()):
				closestSoFar = {
					"distance2" : (point - extremepoint).length_squared(),
					"point" : i,
					"poly": poly,
					"positive": true
				}
		for i in range (poly["negativeExtremePoints"].size()):
			var extremepoint = poly["negativeExtremePoints"][i]
			if(closestSoFar["distance2"] == -1 || closestSoFar["distance2"] > (point - extremepoint).length_squared()):
				closestSoFar = {
					"distance2" : (point - extremepoint).length_squared(),
					"point" : i,
					"poly": poly,
					"positive": false
				}
	return closestSoFar

func get_all_connected_polygons(polygonProperties, poly, checked = [], list = []):
	var polygons = list
	polygons.append(poly)
	checked.append(poly["id"])
	for id in poly["intersectedPolygons"]:
		if(checked.find(id) != null):
			continue
		var newCheck = polygonProperties.find_custom(id, search_by_id)
		polygons.append(get_all_connected_polygons(polygonProperties, newCheck, checked, polygons))
	return polygons

func search_by_id(element, id):
	if(element["id"] == id):
		return true
	return false

func apply_transformation_matrix(point, matrix):
	var pointvec4 = Vector4(point.x, point.y, 1., 1.)
	var newpoint = Vector2.ZERO
	newpoint.x = pointvec4.x * matrix[0][0] + pointvec4.y * matrix[0][1] + matrix[0][3]
	newpoint.y = pointvec4.x * matrix[1][0] + pointvec4.y * matrix[1][1] + matrix[1][3]
	return newpoint

func apply_transformation(point, tf, translate):
	var type = tf[0]
	var tfdata = tf[1]
	if(type == "scale"):
		tfdata.append(tfdata[0])
	tfdata.append_array([0., 0., 0., 0., 0., 0.])
	var tfmatrix
	if(type == "matrix"):
		tfmatrix = [[tfdata[0], tfdata[2], 0., tfdata[4]], [tfdata[1], tfdata[3], 0., tfdata[5]], [0., 0., 1., 0.], [0., 0., 0., 1.]]
	elif(type == "translate"):
		tfmatrix = [[1., 0., 0., tfdata[0]], [0., 1., 0., tfdata[1]], [0., 0., 1., 0.], [0., 0., 0., 1.]]
	elif(type == "translateX"):
		tfmatrix = [[1., 0., 0., tfdata[0]], [0., 1., 0., 0.], [0., 0., 1., 0.], [0., 0., 0., 1.]]
	elif(type == "translateY"):
		tfmatrix = [[1., 0., 0., 0.], [0., 1., 0., tfdata[0]], [0., 0., 1., 0.], [0., 0., 0., 1.]]
	elif(type == "scale"):
		tfmatrix = [[tfdata[0], 0., 0., 0.], [0., tfdata[1], 0., 0.], [0., 0., 1., 0.], [0., 0., 0., 1.]]
	elif(type == "scaleX"):
		tfmatrix = [[tfdata[0], 0., 0., 0.], [0., 1., 0., 0.], [0., 0., 1., 0.], [0., 0., 0., 1.]]
	elif(type == "scaleY"):
		tfmatrix = [[1., 0., 0., 0.], [0., tfdata[0], 0., 0.], [0., 0., 1., 0.], [0., 0., 0., 1.]]
	elif(type == "rotate"):
		tfmatrix = [[cos(tfdata[0]), -sin(tfdata[1]), 0., 0.], [sin(tfdata[0]), cos(tfdata[1]), 0., 0.], [0., 0., 1., 0.], [0., 0., 0., 1.]]
	elif(type == "skew"):
		tfmatrix = [[1., tan(tfdata[0]), 0., 0.], [tan(tfdata[1]), 1., 0., 0.], [0., 0., 1., 0.], [0., 0., 0., 1.]]
	elif(type == "skewX"):
		tfmatrix = [[1., tan(tfdata[0]), 0., 0.], [0., 1., 0., 0.], [0., 0., 1., 0.], [0., 0., 0., 1.]]
	elif(type == "skewY"):
		tfmatrix = [[1., 0., 0., 0.], [tan(tfdata[0]), 1., 0., 0.], [0., 0., 1., 0.], [0., 0., 0., 1.]]
	if(!translate):
		tfmatrix[0][3] = 0.
		tfmatrix[1][3] = 0.
	return(apply_transformation_matrix(point, tfmatrix))

func apply_transformation_string(point, string, translate):
	var currentType = ""
	var currentNumberString = ""
	var currentRelevantNumbers = []
	var newpoint = point
	for i in range(string.length()):
		var char: String = string[i]
		if(char.to_upper() != char.to_lower()):
			currentType += char
		elif(char == "("):
			while(char != ")"):
				i+=1
				if(i >= string.length()):
					break
				char = string[i]
				if(char == "," || char == " "):
					currentRelevantNumbers.append(parse_css_number_thing(currentNumberString))
					currentNumberString = ""
				else:
					currentNumberString += char
			currentRelevantNumbers.append(parse_css_number_thing(currentNumberString))
			currentNumberString = ""
			newpoint = apply_transformation(newpoint, [currentType.replace(" ", ""), currentRelevantNumbers], translate)
	return newpoint

func apply_transformations_to_curve(acurve, tfs):
	var newcurve = acurve.duplicate()
	for i in range(0, newcurve.point_count):
		var p_in = newcurve.get_point_in(i)
		var p_out = newcurve.get_point_out(i)
		var p_pos = newcurve.get_point_position(i)
		var p_in_new = p_in
		var p_out_new = p_out
		var p_pos_new = p_pos
		for j in range(tfs.size() - 1, -1, -1):
			p_in_new = apply_transformation_string(p_in_new, tfs[j], false)
			p_out_new = apply_transformation_string(p_out_new, tfs[j], false)
			p_pos_new = apply_transformation_string(p_pos_new, tfs[j], true)
		newcurve.set_point_in(i, p_in_new)
		newcurve.set_point_out(i, p_out_new)
		newcurve.set_point_position(i, p_pos_new)
	return newcurve
func parse_css_number_thing(str):
	var unit = ""
	var number = str.to_float()
	for char: String in str:
		if(char.to_upper() != char.to_lower()):
			unit += char
	if(unit == "" || unit == "px" || unit == "rad"):
		return number
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
	
	elif(unit == "deg"):
		return number * PI / 180.
	elif(unit == "grad"):
		return number * PI / 200.
	elif(unit == "turn"):
		return number * 2. * PI
	else:
		push_warning("unsupported svg parameter")
		return number

func parse_path(pathdata, numberScale, squish):
	var curve = Curve2D.new()
	var curves = []
	var currentElementType = ""
	var currentNumberString = ""
	var currentRelevantNumbers = []
	var firstMove = true
	for char : String in pathdata:
		if(char.is_valid_int() || char == "." || char == "-"):
			currentNumberString += char
		elif(currentNumberString != "" && char == " "):
			if(currentElementType != "A" || currentRelevantNumbers.size() < 2 ||
				currentRelevantNumbers.size() > 4):
				currentRelevantNumbers.append(currentNumberString.to_float() * numberScale)
			else:
				currentRelevantNumbers.append(currentNumberString.to_float())
			currentNumberString = ""
		elif(char.to_upper() != char.to_lower()):
			if(currentElementType != ""):
				if(currentElementType == "m" || currentElementType == "M"):
					if(!firstMove):
						curves.append(curve.duplicate(true))
						curve = Curve2D.new()
					else:
						firstMove = false
				parse_path_element(currentElementType, currentRelevantNumbers, squish, curve)
				currentRelevantNumbers = []
			currentElementType = char
	if(currentNumberString != ""):
		currentRelevantNumbers.append(currentNumberString.to_float() * numberScale)
	parse_path_element(currentElementType, currentRelevantNumbers, squish, curve)
	curves.append(curve.duplicate(true))
	return curves

func parse_path_element(type, numbers, squish, curve):
	if(type == "M" || type == "L"):
		for i in range(0, numbers.size() - 1, 2):
			curve.add_point(Vector2(numbers[i], numbers[i+1]) * Vector2(1., squish))
	elif(type == "m" || type == "l"):
		for i in range(0, numbers.size() - 1, 2):
			var relpos = curve.get_point_position(curve.point_count - 1)
			curve.add_point(relpos + Vector2(numbers[i], numbers[i+1]) * Vector2(1., squish))
	elif(type == "H"):
		for i in range(numbers.size()):
			var relpos = curve.get_point_position(curve.point_count - 1)
			curve.add_point(Vector2(numbers[i], relpos.y))
	elif(type == "h"):
		for i in range(numbers.size()):
			var relpos = curve.get_point_position(curve.point_count - 1)
			curve.add_point(Vector2(relpos.x + numbers[i], relpos.y))
	elif(type == "V"):
		for i in range(numbers.size()):
			var relpos = curve.get_point_position(curve.point_count - 1)
			curve.add_point(Vector2(relpos.x, numbers[i]) * Vector2(1., squish))
	elif(type == "v"):
		for i in range(numbers.size()):
			var relpos = curve.get_point_position(curve.point_count - 1)
			curve.add_point(Vector2(relpos.x, relpos.y + numbers[i]) * Vector2(1., squish))
	elif(type == "Z" || type == "z"):
		curve.add_point(curve.get_point_position(0))
	elif(type == "C"):
		for i in range(0, numbers.size(), 6):
			var relpos = curve.get_point_position(curve.point_count - 1)
			curve.set_point_out(curve.point_count - 1, Vector2(numbers[i], numbers[i+1]) * Vector2(1., squish) - relpos)
			curve.add_point(Vector2(numbers[i+4], numbers[i+5]) * Vector2(1., squish), Vector2(numbers[i+2] - numbers[i+4], numbers[i+3] - numbers[i+5]) * Vector2(1., squish))
	elif(type == "c"):
		for i in range(0, numbers.size(), 6):
			var relpos = curve.get_point_position(curve.point_count - 1)
			curve.set_point_out(curve.point_count - 1, Vector2(numbers[i], numbers[i+1]) * Vector2(1., squish))
			curve.add_point(Vector2(numbers[i+4], numbers[i+5]) * Vector2(1., squish) + relpos, Vector2(numbers[i+2], numbers[i+3]) * Vector2(1., squish))
	elif(type == "S"):
		for i in range(0, numbers.size(), 4):
			curve.set_point_out(curve.point_count - 1, -1 * curve.get_point_in(curve.point_count - 1))
			curve.add_point(Vector2(numbers[i+2], numbers[i+3]) * Vector2(1., squish), Vector2(numbers[i] - numbers[i+2], numbers[i+1] - numbers[i+3]) * Vector2(1., squish))
	elif(type == "s"):
		for i in range(0, numbers.size(), 4):
			var relpos = curve.get_point_position(curve.point_count - 1)
			curve.set_point_out(curve.point_count - 1, -1 * curve.get_point_in(curve.point_count - 1))
			curve.add_point(Vector2(numbers[i+2], numbers[i+3]) * Vector2(1., squish) + relpos, Vector2(numbers[i+0], numbers[i+1]) * Vector2(1., squish))
	elif(type == "Q"):
		for i in range(0, numbers.size(), 6):
			var relpos = curve.get_point_position(curve.point_count - 1)
			curve.set_point_out(curve.point_count - 1, Vector2(numbers[i], numbers[i+1]) * Vector2(1., squish) - relpos)
			curve.add_point(Vector2(numbers[i+2], numbers[i+3]) * Vector2(1., squish), Vector2(numbers[i] - numbers[i+2], numbers[i+1] - numbers[i+3]) * Vector2(1., squish))
	elif(type == "q"):
		for i in range(0, numbers.size(), 6):
			var relpos = curve.get_point_position(curve.point_count - 1)
			curve.set_point_out(curve.point_count - 1, Vector2(numbers[i], numbers[i+1]) * Vector2(1., squish))
			curve.add_point(Vector2(numbers[i+2], numbers[i+3]) * Vector2(1., squish) + relpos, Vector2(numbers[i], numbers[i+1]) * Vector2(1., squish))
	elif(type == "T"):
		for i in range(0, numbers.size(), 4):
			curve.set_point_out(curve.point_count - 1, -1 * curve.get_point_in(curve.point_count - 1))
			curve.add_point(Vector2(numbers[i], numbers[i+1]) * Vector2(1., squish), (curve.get_point_out(curve.point_count - 1) - curve.get_point_position(curve.point_count - 1) + Vector2(numbers[i], numbers[i+1])) * Vector2(1., squish))
	elif(type == "t"):
		for i in range(0, numbers.size(), 4):
			var relpos = curve.get_point_position(curve.point_count - 1)
			curve.set_point_out(curve.point_count - 1, -1 * curve.get_point_in(curve.point_count - 1))
			curve.add_point(Vector2(numbers[i], numbers[i+1]) * Vector2(1., squish) + relpos, (curve.get_point_out(curve.point_count - 1) - curve.get_point_position(curve.point_count - 1) + Vector2(numbers[i], numbers[i+1])) * Vector2(1., squish))
	elif(type == "A"):
		var relpos = curve.get_point_position(curve.point_count - 1)
		var curveCoords = arcToCubic(numbers, relpos, squish)
		for i in range(0, curveCoords.size(), 3):
			relpos = curve.get_point_position(curve.point_count - 1)
			curve.set_point_out(curve.point_count - 1, curveCoords[i] * Vector2(1., squish) - relpos)
			curve.add_point(curveCoords[i + 2] * Vector2(1., squish), (curveCoords[i + 1] - curveCoords[i + 2]) * Vector2(1., squish))
	elif(type == "a"):
		var relpos = curve.get_point_position(curve.point_count - 1)
		numbers[5] += relpos.x
		numbers[6] += relpos.y / squish
		var curveCoords = arcToCubic(numbers, relpos, squish)
		for i in range(0, curveCoords.size(), 3):
			relpos = curve.get_point_position(curve.point_count - 1)
			curve.set_point_out(curve.point_count - 1, curveCoords[i] * Vector2(1., squish) - relpos)
			curve.add_point(curveCoords[i + 2] * Vector2(1., squish), (curveCoords[i + 1] - curveCoords[i + 2]) * Vector2(1., squish))
		
func rotatePoint(point, rad):
	var x = point.x * cos(rad) - point.y * sin(rad)
	var y = point.x * sin(rad) + point.y * cos(rad)
	return Vector2(x, y)
func arcToCubic(numbers, relpos, squish, recursive = null):
	var rx = numbers[0]
	var ry = numbers[1]
	var rad = numbers[2] * PI / 180.
	var large_arc_flag = numbers[3]
	var sweep_flag = numbers[4]
	var x2 = numbers[5]
	var y2 = numbers[6]
	
	var x1 = relpos.x
	var y1 = relpos.y / squish
	
	#from: https://github.com/adobe-webplatform/Snap.svg/blob/b242f49e6798ac297a3dad0dfb03c0893e394464/src/path.js#L752
	
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
		res = arcToCubic([rx, ry, numbers[2], 0., sweep_flag, x2old, y2old], Vector2(x2, y2), 1., [f2, f2old, cx, cy])
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
			var newpoint = rotatePoint(res[i], rad)
			newres.append(newpoint)
		return newres
func convert_shape_to_curves(file, shapedata, pageSize, canvasWidth, canvasHeight):
	
	var shape = Image.load_from_file(file)
	var width = shape.get_width()
	var height = shape.get_height()
	var svgdata
	var transformStack = []
	var curves = []
	transformStack.append("translate(" + str(shapedata["startX"].to_float() * pageSize.x / canvasWidth) + " " + str(shapedata["startY"].to_float() * pageSize.y / canvasHeight) + ")")
	transformStack.append("scale(" + str(shapedata["width"].to_float() / width * pageSize.x / canvasWidth) + " " + str(shapedata["height"].to_float() / height * pageSize.y / canvasHeight) + ")")
	var parser = XMLParser.new()
	parser.open(file)
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			var name = parser.get_node_name()
			if(name == "svg" || name == "svg:svg"):
				svgdata = parse_attributes(parser)
				if(svgdata.has("x") && svgdata.has("y")):
					transformStack.append("matrix(1 0 0 1 " +svgdata["x"] + " " + svgdata["y"] + ")")
			elif(name == "g" || name == "svg:g"):
				var data_ = parse_attributes(parser)
				if(data_.has("transform")):
					transformStack.append(data_["transform"])
				else:
					transformStack.append("")
			elif(name == "path" || name == "svg:path" || name == "rect" || name == "svg:rect" || name == "circle" || name == "svg:circle" || 
				name == "ellipse" || name == "svg:ellipse" || name == "polygon" || name == "svg:polygon"):
				var attributes = parse_attributes(parser)
				if(attributes.has("transform")):
					transformStack.append(attributes["transform"])
				else:
					transformStack.append("")
				curves.append([parse_shape_object(name, attributes, transformStack), transformStack.duplicate()])
				transformStack.pop_back()
				
		if parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
			if(parser.get_node_name() == "g" || parser.get_node_name() == "svg:g"):
				transformStack.pop_back()
			pass
	var tfdCurves = []
	for curveArray in curves:
		for curve in curveArray[0]:
			tfdCurves.append(apply_transformations_to_curve(curve, curveArray[1]))
	return tfdCurves
func parse_shape_object(name, data_, transforms):
	var shapeCurves = []
	var path_
	if(name == "path" || name == "svg:path"):
		path_ = data_["d"]
	if(name == "rect" || name == "svg:rect"):
		path_ = convert_rect_to_path(data_)
	if(name == "circle" || name == "svg:circle"):
		path_ = convert_circle_to_path(data_)
	if(name == "ellipse" || name == "svg:ellipse"):
		path_ = convert_ellipse_to_path(data_)
	if(name == "polygon" || name == "svg:polygon"):
		path_ = convert_polygon_to_path(data_)
	var curves = parse_path(path_, 1., 1.)
	for curve_ in curves:
		apply_transformations_to_curve(curve_, transforms)
	shapeCurves.append_array(curves)
	return shapeCurves
func convert_polygon_to_path(data_):
	return "M " + data_["points"] + " Z"
func convert_ellipse_to_path(data_):
	var cx = data_["cx"].to_float()
	var cy = data_["cy"].to_float()
	var rx = data_["r"].to_float()
	var ry = data_["r"].to_float()
	var path_ = ""
	path_ += "M " + str(cx + rx) + " " + str(cy)
	path_ += " A " + str(rx) + " " + str(ry) + " 0 0 0 " + str(cx) + " " + str(cy + ry)
	path_ += " A " + str(rx) + " " + str(ry) + " 0 0 0 " + str(cx - rx) + " " + str(cy)
	path_ += " A " + str(rx) + " " + str(ry) + " 0 0 0 " + str(cx) + " " + str(cy - ry)
	path_ += " A " + str(rx) + " " + str(ry) + " 0 0 0 " + str(cx + rx) + " " + str(cy)
	path_ += " Z"
	return path_
	
func convert_circle_to_path(data_):
	var cx = data_["cx"].to_float()
	var cy = data_["cy"].to_float()
	var r = data_["r"].to_float()
	
	var path_ = ""
	path_ += "M " + str(cx + r) + " " + str(cy)
	path_ += " A " + str(r) + " " + str(r) + " 0 0 1 " + str(cx) + " " + str(cy + r)
	path_ += " A " + str(r) + " " + str(r) + " 0 0 1 " + str(cx - r) + " " + str(cy)
	path_ += " A " + str(r) + " " + str(r) + " 0 0 1 " + str(cx) + " " + str(cy - r)
	path_ += " A " + str(r) + " " + str(r) + " 0 0 1 " + str(cx + r) + " " + str(cy)
	path_ += " Z"
	return path_
	
func convert_rect_to_path(data_):
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
	path_ += "M " + str(x + rx) + " " + str(y)
	path_ += " H " + str(x + width - rx)
	if(rx > 0 && ry > 0):
		path_ += " A " + str(rx) + " " + str(ry) + " 0 0 1 " + str(x+width) + " " + str(y + ry)
	path_ += " V " + str(y + height - ry)
	if(rx > 0 && ry > 0):
		path_ += " A " + str(rx) + " " + str(ry) + " 0 0 1 " + str(x+width - rx) + " " + str(y + height)
	path_ += " H " + str(x + rx)
	if(rx > 0 && ry > 0):
		path_ += " A " + str(rx) + " " + str(ry) + " 0 0 1 " + str(x) + " " + str(y + height - ry)
	path_ += " V " + str(y + ry)
	if(rx > 0 && ry > 0):
		path_ += " A " + str(rx) + " " + str(ry) + " 0 0 1 " + str(x + rx) + " " + str(y)
	path_ += "Z"
	return path_


func parse_attributes(parser):
	var data = {}
	for idx in range(parser.get_attribute_count()):
		data[parser.get_attribute_name(idx)] = parser.get_attribute_value(idx)
	return data


func convert_to_convex_polygon_shapes_2d(polygons):
	var newpolys = []
	for polygon in polygons:
		var edge = []
		for i in range(polygon.size()):
			edge.append(polygon[i])
			if(i > 0):
				edge.append(polygon[i])
				
		edge.append(polygon[0])
		var edgeShape = ConcavePolygonShape2D.new()
		edgeShape.segments = edge
		
		
		var decomposed = Geometry2D.decompose_polygon_in_convex(polygon)
		var new = []
		for part in decomposed:
			var newpoly = ConvexPolygonShape2D.new()
			newpoly.points = part
			new.append(newpoly)
		newpolys.append([new, edgeShape])
	return newpolys
