extends Node

const stepSize = 10

var bookPath
var zipPath
var sectionsList
var isZip
var scrapbookData
var iddshapes = {}
var spanners = {}
var imagesDict = {}
var textsDict = {}
var systemFontsDict = {}
var preloadedFontsDict = {}

var currentTextData
var finalTextData

var imageScene = preload("res://scenes/pageobjects/image.tscn")
var textScene = preload("res://scenes/pageobjects/j_word_text.tscn")
var pageScene = preload("res://scenes/page.tscn")

var specialFontsDict = {
	"Scrap Casual": "igscas.TTF",
	"LD Glorious": "LDGLORIO.TTF",
	"LDJ What Up": "ldjwhatu.ttf",
	"LD Keri": "ldkeri.ttf",
	"LD Shelly Print": "LDSHELPR.TTF",
	"TXT Abrasive": "txtabras.ttf"
}
var systemDefaultFontsDict = {
	"Dialog" : "sans-serif",
	"DialogInput" : "monospace",
	"Monospaced": "monospace",
	"SansSerif": "sans-serif",
	"Serif": "serif"
	
}

func preload_xmls():
	for i in range(sectionsList.size()):
		var sectionData = preload_section(sectionsList[i])
		scrapbookData.append(sectionData)
		pass

func preload_section(path):
	var filepath
	var dir = DirAccess.open(bookPath + "/" + path)
	if(dir == null):
		return
	for file: String in dir.get_files():
		var extension = file.split(".")[file.split(".").size() - 1]
		if(extension == "mms"):
			filepath = file
	
	var zipreader = ZIPReader.new()
	zipreader.open(bookPath + "/" + path + "/" + filepath)
	var content = zipreader.read_file(zipreader.get_files()[0])
	zipreader.close()
	var parser = XMLParser.new()
	parser.open_buffer(content)
	var lastPage
	var canvasWidth
	var maxOutputWidth
	var maxOutputHeight
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			if(parser.get_node_name() == "canvasWidth"):
				canvasWidth = get_text_contents(parser).to_int()
			elif(parser.get_node_name() == "maxOutputWidth"):
				maxOutputWidth = get_text_contents(parser).to_int()
			elif(parser.get_node_name() == "maxOutputHeight"):
				maxOutputHeight = get_text_contents(parser).to_int()
			elif(parser.get_node_name() == "pageObject"):
				var pagename = parser.get_named_attribute_value_safe("name")
				preload_page_object_first_pass(parser, canvasWidth, maxOutputWidth, maxOutputHeight, path)
				lastPage = pagename.to_int()
	parser = XMLParser.new()
	parser.open_buffer(content)
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			if(parser.get_node_name() == "canvasWidth"):
				canvasWidth = get_text_contents(parser).to_int()
			elif(parser.get_node_name() == "maxOutputWidth"):
				maxOutputWidth = get_text_contents(parser).to_int()
			elif(parser.get_node_name() == "maxOutputHeight"):
				maxOutputHeight = get_text_contents(parser).to_int()
			elif(parser.get_node_name() == "pageObject"):
				var pagename = parser.get_named_attribute_value_safe("name")
				preload_page_object_second_pass(parser, canvasWidth, maxOutputWidth, maxOutputHeight, path)
				lastPage = pagename.to_int()
	parser = XMLParser.new()
	parser.open_buffer(content)
	var pages = []
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			if parser.get_node_name() == "page":
				var pagename = parser.get_named_attribute_value_safe("name")
				var pagedata = preload_page(parser, pagename, canvasWidth, maxOutputWidth, maxOutputHeight, path)
				pages.append(pagedata)
				lastPage = pagename.to_int()
	
	var numPages = lastPage
	return {"pages" : pages, "canvasWidth" : canvasWidth, "maxOutputWidth" : maxOutputWidth, "maxOutputHeight" : maxOutputHeight, "numPages" : numPages}

func preload_page_object_first_pass(parser, canvasWidth, maxOutputWidth, maxOutputHeight, path):
	var type = parser.get_named_attribute_value_safe("type")
	if(type == "spanner"):
		return
	var data = {}
	while !(parser.get_node_type()  == XMLParser.NODE_ELEMENT_END && parser.get_node_name() == "pageObject"):
		parser.read()
		if parser.get_node_type()  == XMLParser.NODE_ELEMENT:
			var nodename = parser.get_node_name()
			var nodedata = get_text_contents(parser)
			data[nodename] = nodedata
	if(data.has("spannerId") && type != "spanner"):
		data["objecttype"] = type
		spanners[data["spannerId"]] = data
	if(data.has("id") && (type == "shape" || type == "line")):
		data["objecttype"] = type
		iddshapes[data["id"]] = data
func preload_page_object_second_pass(parser, canvasWidth, maxOutputWidth, maxOutputHeight, path):
	var type = parser.get_named_attribute_value_safe("type")
	if(type == "spanner"):
		return
	var data = {}
	while !(parser.get_node_type()  == XMLParser.NODE_ELEMENT_END && parser.get_node_name() == "pageObject"):
		parser.read()
		if parser.get_node_type()  == XMLParser.NODE_ELEMENT:
			var nodename = parser.get_node_name()
			var nodedata = get_text_contents(parser)
			data[nodename] = nodedata
	if(data.has("spannerId") && type != "spanner"):
		data["objecttype"] = type
		spanners[data["spannerId"]] = data
	if(type == "jWordText" && data.has("id") && iddshapes.has(data["id"])):
		parse_text(data, canvasWidth, maxOutputWidth, maxOutputHeight, path)
var heldTextInstances = {}
func parse_text(data, canvasWidth, maxOutputWidth, maxOutputHeight, path):
	var canvasHeight = float(maxOutputHeight) / float(maxOutputWidth) * float(canvasWidth)
	get_tree().root.get_viewport().set_canvas_cull_mask_bit(2, false);
	var textInstance = textScene.instantiate()
	textInstance.pageSize = Vector2(100, 100)
	textInstance.canvasWidth = canvasWidth
	textInstance.canvasHeight = canvasHeight
	textInstance.path = bookPath + "/" + path
	textInstance.data = data
	var shape = iddshapes[data["id"]]
	if(shape["objecttype"] == "shape"):
		textInstance.data["shapeTextPlacements"] = parse_text_shape(shape, data, canvasWidth, canvasHeight, bookPath + path)
	textInstance.shapedata = shape
	heldTextInstances[data["id"]] = textInstance

func parse_text_shape(shape, data, canvasWidth, canvasHeight, path):
	var shapeFile = path + "/objects/" + shape["customShapeName"]
	var shapeCurves = util_SvgProcessing.convert_shape_to_curves(shapeFile, shape, Vector2(canvasWidth, canvasHeight), canvasWidth, canvasHeight)
	var naivePolygons = util_SvgProcessing.convert_curves_to_polygons_naive(shapeCurves, 60)
	var shapePolygons = util_SvgProcessing.combine_polygons(naivePolygons)
	var finalShapePolygons = util_SvgProcessing.convert_to_convex_polygon_shapes_2d(shapePolygons)
	var shapes = finalShapePolygons
	var boundsPos = Vector2(shape["startX"].to_int(), shape["startY"].to_int())
	var boundsSize = Vector2(shape["width"].to_int(), shape["height"].to_int())
	var padding = Vector2.ZERO
	if(data.has("padding")):
		padding = Vector2(data["padding"].to_int(), data["padding"].to_int()) / 7.
	preparse_text_for_shape(path + "/objects/" + data["fileName"], boundsSize.x)
	return find_text_placements(shapes, boundsPos, boundsSize, padding)

func find_text_placements(shapes, boundsPos, boundsSize, padding):
	var words = break_data_into_words(finalTextData)
	return calculate_positions(words, boundsPos, boundsSize, padding, shapes)

func calculate_positions(wordBrokenData, boundsPos, boundsSize, padding, shapes):
	var textSpaces = []
	var rectShape = RectangleShape2D.new()
	if(wordBrokenData == []):
		return
	if(boundsPos == null):
		return
	var currentLinePos = boundsPos
	var nextWordIndex = 0
	var nextLetterIndex = 0
	var letterFlag = false
	while currentLinePos.y < boundsPos.y + boundsSize.y:
		var currentWords = []
		var emptySpace
		var continueFlag = false
		while true:
			if(letterFlag):
				var letter = get_letter(wordBrokenData[nextWordIndex][0], nextLetterIndex)
				if(letter == null):
					letterFlag = false
					nextWordIndex += 1
					continue
				currentWords.append(letter)
			else:
				currentWords.append(wordBrokenData[nextWordIndex])
			var newLineSize = (line_size(currentWords) + padding)
			
			var newLinePos1 = currentLinePos
			var newLineRect1 = Rect2(newLinePos1, newLineSize)
			var newEmptySpace = find_empty_space(newLineRect1, boundsPos, boundsSize, shapes, stepSize, padding)
			
			if(newEmptySpace == null || (wordBrokenData[nextWordIndex][0].size() > 0 && wordBrokenData[nextWordIndex][0][0][1] == "\n")):
				if(currentWords.size() == 1 && newEmptySpace == null):
					if(letterFlag):
						break
					letterFlag = true
					nextLetterIndex = 0
					currentWords = []
					continue
				else:
					if(!(wordBrokenData[nextWordIndex][0].size() > 0 && wordBrokenData[nextWordIndex][0][0][1] == "\n")):
						currentWords.pop_back()
					if(emptySpace != null):
						textSpaces.append([currentWords, emptySpace])
						currentLinePos.x = emptySpace.position.x + emptySpace.size.x
						continueFlag = true
					else:
						nextWordIndex+=1
					break
			emptySpace = newEmptySpace
			if(letterFlag):
				nextLetterIndex+=1
			else:
				nextWordIndex+=1
			if(nextWordIndex >= wordBrokenData.size()):
				textSpaces.append([currentWords, emptySpace])
				currentLinePos.x = emptySpace.position.x + emptySpace.size.x
				continueFlag = true
				break
		
		if(nextWordIndex >= wordBrokenData.size()):
			break
			
		if(continueFlag):
			continue
		currentLinePos.x = boundsPos.x
		currentWords = []
		while true:
			if(nextWordIndex >= wordBrokenData.size()):
				textSpaces.append([currentWords, emptySpace])
				break
			if(letterFlag):
				var letter = get_letter(wordBrokenData[nextWordIndex][0], nextLetterIndex)
				if(letter == null):
					letterFlag = false
					nextWordIndex += 1
					continue
				currentWords.append(letter)
			else:
				currentWords.append(wordBrokenData[nextWordIndex])
			var newLineSize = line_size(currentWords) + padding
			
			var newLinePos2 = Vector2(boundsPos.x, currentLinePos.y + newLineSize.y)
			var newLineRect2 = Rect2(newLinePos2, newLineSize)
			var newEmptySpace = find_empty_space(newLineRect2, boundsPos, boundsSize, shapes, stepSize, padding)
			
			if(newEmptySpace == null || (wordBrokenData[nextWordIndex][0].size() > 0 && wordBrokenData[nextWordIndex][0][0][1] == "\n")):
				if(currentWords.size() == 1 && newEmptySpace == null):
					if(letterFlag):
						currentLinePos = Vector2(boundsPos.x, newLinePos2.y)
						break
					letterFlag = true
					nextLetterIndex = 0
					currentWords = []
					continue
				else:
					if(!(wordBrokenData[nextWordIndex][0].size() > 0 && wordBrokenData[nextWordIndex][0][0][1] == "\n")):
						currentWords.pop_back()
					if(emptySpace != null):
						textSpaces.append([currentWords, emptySpace])
						currentLinePos = emptySpace.position + emptySpace.size - Vector2(0., newLineSize.y)
					else:
						nextWordIndex+=1
					if((wordBrokenData[nextWordIndex][0].size() > 0 && wordBrokenData[nextWordIndex][0][0][1] == "\n")):
						currentLinePos = Vector2(boundsPos.x, newLinePos2.y + newLineRect2.size.y)
					break
			emptySpace = newEmptySpace
			if(letterFlag):
				nextLetterIndex+=1
			else:
				nextWordIndex+=1
			
			
			if(nextWordIndex >= wordBrokenData.size()):
				textSpaces.append([currentWords, emptySpace])
				currentLinePos = emptySpace.position + emptySpace.size - Vector2(0., newLineSize.y)
				break
		
		if(nextWordIndex >= wordBrokenData.size()):
			break
	return textSpaces


func get_letter(word, index):
	var letterIndex = 0
	var wordIndex = 0
	if(wordIndex >= word.size()):
		return null
	for i in range(index):
		if(letterIndex < word[wordIndex][1].length() - 1):
			letterIndex+=1
		else:
			letterIndex = 0
			wordIndex += 1
			if(wordIndex >= word.size()):
				return null
	var a = [[word[wordIndex][0],word[wordIndex][1][letterIndex]]]
	var b = word[wordIndex][1][letterIndex]
	var c = word[wordIndex][0]["font"]
	var d = word[wordIndex][0]["fontSize"]
	return [
		a, 
		get_letter_size(
			b, 
			c, 
			d)]

func find_minimum_positions(yPos, boundsPos, boundsSize, shapes, stepSize):
	var mins = []
	var pos = Vector2(boundsPos.x, yPos)
	while pos.x < boundsPos.x + boundsSize.x:
		var intersecting = false
		while intersecting == false && pos.x < boundsPos.x + boundsSize.x:
			for shape in shapes:
				if(Geometry2D.is_point_in_polygon(pos, shape[1].segments)):
					intersecting = true
					mins.append(pos.x)
			pos.x += stepSize
		while intersecting == true && pos.x < boundsPos.x + boundsSize.x:
			var newIntersecting = false
			for shape in shapes:
				if(Geometry2D.is_point_in_polygon(pos, shape[1].segments)):
					newIntersecting = true
			intersecting = newIntersecting
			pos.x += stepSize
	return mins

var minima = {}
func find_empty_space(rect, boundsPos, boundsSize, shapes, stepSize, padding):
	var newRect = rect
	newRect.size += padding * 2
	newRect.position -= padding
	var mins
	if(!minima.has(newRect.position.y)):
		minima[newRect.position.y] = find_minimum_positions(newRect.position.y, boundsPos, boundsSize, shapes, stepSize)
	mins = minima[newRect.position.y]
	var rectShape = RectangleShape2D.new()
	rectShape.size = newRect.size
	if(mins.size() == 0):
		return null
	newRect.position.x = next_min(mins, newRect.position.x)
	if(newRect.position.x == -1):
		return null
	while newRect.position.x + newRect.size.x < boundsPos.x + boundsSize.x:
		for i in range(shapes.size()):
			var intersects = intersects(shapes[i], rectShape, newRect.position)
			if(intersects == 1):
				var pos1 = newRect.position.x
				while(intersects == 1):
					newRect.position.x += stepSize
					intersects = intersects(shapes[i], rectShape, newRect.position)
				newRect.size -= padding * 2
				newRect.position.y += padding.y
				newRect.position.x = (pos1 + newRect.position.x) / 2.
				return newRect
			elif(intersects > 1):
				if(newRect.position.x < intersects):
					newRect.position.x = intersects
		newRect.position.x += stepSize
	return null

func next_min(mins, pos):
	for min in mins:
		if(min > pos):
			return min
	return -1

func intersects(shape, rect, rectpos):
	var edgeCollideContacts = rect.collide_and_get_contacts(Transform2D(0., rectpos), shape[1], Transform2D(0., Vector2(0., 0.)))
	if(edgeCollideContacts.size() > 0):
		var maxX = 0.
		for contact in edgeCollideContacts:
			maxX = max(contact.x, maxX)
		return maxX
	for polygon in shape[0]:
		if rect.collide(Transform2D(0., rectpos), polygon, Transform2D(0., Vector2(0., 0.))):
			return 1
	return -1

func line_size(words):
	var max = 0
	var width = 0
	for word in words:
		max = max(max, word[1].y)
		width += word[1].x
	return Vector2(width, max)



func break_data_into_words(data):
	var wordBrokenData = []
	var currentWord = []
	for datum in data:
		var splitText = datum[1].split(' ')
		if(splitText.size() < 2):
			if(datum[1].length() > 0):
				currentWord.append(datum)
			continue
		if(splitText[0].length() > 0):
			currentWord.append([datum[0], splitText[0]])
		for i in range(1, splitText.size()):
			wordBrokenData.append([currentWord, get_word_size(currentWord)])
			currentWord = []
			if(splitText[i].length() > 0):
				currentWord.append([datum[0], " " + splitText[i]])
	if(currentWord != []):
		wordBrokenData.append([currentWord, get_word_size(currentWord)])
	return wordBrokenData

func get_word_size(word):
	var maxHeight = 0
	var width = 0
	for datum in word:
		var dSize = get_datum_size(datum)
		maxHeight = max(dSize.y, maxHeight)
		width += dSize.x
	return Vector2(width, maxHeight)

func get_datum_size(datum):
	var data = datum[0]
	var text = datum[1]
	return data["font"].get_string_size(text, 0, -1, data["fontSize"])

func get_letter_size(letter, font, fontSize):
	return font.get_string_size(letter, 0, -1, fontSize)
	
func preload_page(parser, pagename, canvasWidth, maxOutputWidth, maxOutputHeight, path):
	var name = pagename
	var objects = []
	var hasBackground = false
	var hasChildren = false
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT_END && parser.get_node_name() == "page":
			break
		if parser.get_node_type() == XMLParser.NODE_ELEMENT && parser.get_node_name() == "pageObject":
			hasChildren = true
			var pageobjectdata = preload_page_object(parser)
			objects.append(pageobjectdata)
			if(pageobjectdata["type"] == "background" && (!pageobjectdata["data"].has("imageopacity") || pageobjectdata["data"]["imageopacity"].to_float() > 0.99)):
				hasBackground = true
			if(pageobjectdata["type"] == "jWordText" && pageobjectdata.has("id")):
				parse_text(pageobjectdata, canvasWidth, maxOutputWidth, maxOutputHeight, path)
	return {"name" : name, "objects" : objects, "hasBackground" : hasBackground || !hasChildren}

func preload_page_object(parser):
	var type = parser.get_named_attribute_value_safe("type")
	var data = {}
	while true:
		parser.read()
		if parser.get_node_type()  == XMLParser.NODE_ELEMENT_END && parser.get_node_name() == "pageObject":
			break
		if parser.get_node_type()  == XMLParser.NODE_ELEMENT:
			var nodename = parser.get_node_name()
			var nodedata = get_text_contents(parser)
			data[nodename] = nodedata
	if(type == "spanner"):
		if(spanners.has(data["spannerId"])):
			type = spanners[data["spannerId"]]["objecttype"];
			for spanner_object_data in spanners[data["spannerId"]]:
				if(!data.has(spanner_object_data)):
					data[spanner_object_data] = spanners[data["spannerId"]][spanner_object_data]
	return {"type" : type, "data" : data}


func get_text_contents(parser):
	parser.read()
	if(parser.get_node_type() == XMLParser.NODE_TEXT):
		return(parser.get_node_data())
	else:
		push_warning("no text found")
		return ""

func generate_images_dict():
	imagesDict["coverOutside"] = ImageTexture.create_from_image(Image.load_from_file(bookPath + "/cover_outside.png"))
	imagesDict["coverInsideLeft"] = ImageTexture.create_from_image(Image.load_from_file(bookPath + "/cover_inside_left.png"))
	imagesDict["coverInsideRight"] = ImageTexture.create_from_image(Image.load_from_file(bookPath + "/cover_inside_right.png"))
		
	for section in sectionsList:
		var sectionObjectsPath = bookPath + "/" + section + "/objects/"
		var diracc = DirAccess.open(sectionObjectsPath)
		if(diracc == null):
			continue
		diracc.list_dir_begin()
		var filename = diracc.get_next()
		while filename != "":
			if !diracc.current_is_dir():
				var extension = filename.split(".")[filename.split(".").size() - 1]
				if(extension == "png"):
					var image
					if((sectionObjectsPath + filename).begins_with("res://")):
						image = load(sectionObjectsPath + filename)
					else:
						image = ImageTexture.create_from_image(Image.load_from_file(sectionObjectsPath + filename))
					imagesDict[filename] = image
				elif(extension == "svg"):
					if((sectionObjectsPath + filename).begins_with("res://")):
						filename += ".import"
					var fileacc = FileAccess.open(sectionObjectsPath + filename, FileAccess.READ)
					var svgdata = fileacc.get_as_text()
					imagesDict[filename] = svgdata
			filename = diracc.get_next()
	var basicsZip = ZIPReader.new()
	basicsZip.open("res://Shapes/Basics.zip")
	for filename in basicsZip.get_files():
		var extension = filename.split(".")[filename.split(".").size() - 1]
		if(extension == "svg"):
			var svgdata = basicsZip.read_file(filename).get_string_from_utf8()
			imagesDict[filename] = svgdata

func generate_texts_dict():
	for section in sectionsList:
		var sectionObjectsPath = bookPath + "/" + section + "/objects/"
		var diracc = DirAccess.open(sectionObjectsPath)
		if(diracc == null):
			continue
		diracc.list_dir_begin()
		var filename = diracc.get_next()
		while filename != "":
			if !diracc.current_is_dir():
				var extension = filename.split(".")[filename.split(".").size() - 1]
				if(extension == "xml" || extension == "srw"):
					var fileacc = FileAccess.open(sectionObjectsPath + filename, FileAccess.READ)
					var xmldata = fileacc.get_as_text()
					textsDict[filename] = xmldata
			filename = diracc.get_next()
func generate_fonts_dict():
	var diracc = DirAccess.open(bookPath)
	if(!diracc.dir_exists(bookPath + "/fonts")):
		return
	diracc = DirAccess.open(bookPath + "/fonts")
	for file in diracc.get_files():
		var font = FontFile.new()
		if(bookPath.ends_with("/")):
			font.load_dynamic_font(bookPath + "fonts/" + file)
		else:
			font.load_dynamic_font(bookPath + "/fonts/" + file)
		preloadedFontsDict[font.get_font_name() + " " + font.get_font_style_name()] = font
		pass


func extract_all_from_zip(path):
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

func reload_stuff(sList, bPath, iZip):
	isZip = iZip
	if(iZip):
		zipPath = bPath
		var id = extract_all_from_zip(bPath)
		bookPath = "user://temp/" + id + "/"
	else:
		bookPath = bPath
	sectionsList = sList
	scrapbookData = []
	imagesDict = {}
	spanners = {}
	iddshapes = {}
	generate_images_dict()
	generate_texts_dict()
	generate_fonts_dict()
	preload_xmls()
	#util_ClearTemp.clear_temp()

func preparse_text_for_shape(filepath, width):
	var parsedData = parse_text_content(filepath)
	var textData = parsedData[0]
	var text = parsedData[1]
	
	var scaleFactor = width / float(textData["pagewidth"].to_int()) / 2.
	
	currentTextData = {}
	finalTextData = []
	for line in text:
		preparse_line(line, scaleFactor)
func preparse_line(line, scaleFactor):
	var lineData = line[0]
	var lineText = line[1]
	
	var halign = HORIZONTAL_ALIGNMENT_LEFT if lineData["halign"] == "left" else HORIZONTAL_ALIGNMENT_CENTER if lineData["halign"] == "center" else HORIZONTAL_ALIGNMENT_RIGHT if lineData["halign"] == "right" else HORIZONTAL_ALIGNMENT_FILL
	
	var currentFontSize = float(lineText[0][0]["fs"].to_int()) * scaleFactor
	if(lineData.has("linespace")):
		var linespace = lineData["linespace"].to_float()
	if(lineData.has("list") && lineData["list"].to_int() > 0):
		parse_blip(lineText[0], scaleFactor, currentFontSize)
	for blip in lineText:
		parse_blip(blip, scaleFactor, currentFontSize)
		add_text_to_line(blip[1])
func parse_blip(blip, scaleFactor, currentFontSize):
	var blipData = blip[0]
	
	var bold = blipData.has("fstyle") && blipData["fstyle"].contains("b")
	var italics = blipData.has("fstyle") && blipData["fstyle"].contains("i")
	var underline = blipData.has("fstyle") && blipData["fstyle"].contains("u")
	currentTextData["bold"] = bold
	currentTextData["italics"] = italics
	currentTextData["underline"] = underline
	currentFontSize = round(float(blipData["fs"].to_int()) * scaleFactor)
	currentTextData["fontSize"] = currentFontSize
	if(blipData.has("font")):
		var fontName = blipData["font"] + (" Bold" if bold else "") + (" Italic" if italics else "")
		var font;
		if(specialFontsDict.has(blipData["font"])):
			font = load("res://fonts/"+specialFontsDict[blipData["font"]])
		else:
			if(!systemFontsDict.has(fontName)):
				var newfont = SystemFont.new()
				newfont.font_italic = italics
				newfont.font_weight = 700 if bold else 400
				var fontNames = PackedStringArray()
				if(systemDefaultFontsDict.has(blipData["font"])):
					fontNames.append(systemDefaultFontsDict[blipData["font"]])
				else:
					
						fontNames.append(blipData["font"])
						fontNames.append(fontName)
				var dictHas = false
				for fn in fontNames:
					if(util_Preloader.preloadedFontsDict.has(fn)):
						systemFontsDict[fontName] = util_Preloader.preloadedFontsDict[fn]
						dictHas = true
				if(!dictHas):
					newfont.set_font_names(fontNames)
					systemFontsDict[fontName] = newfont
			font = systemFontsDict[fontName]
		var fv = FontVariation.new()
		fv.base_font = font
		if(blipData.has("expnd")):
			var expandFactor = float(blipData["expnd"])/(currentFontSize) * 9/5
			fv.set_spacing(TextServer.SPACING_GLYPH, expandFactor)
		currentTextData["font"] = fv
	if(blipData.has("color")):
		currentTextData["color"] = Color(blipData["color"])

func parse_text_content(filepath):
	var parser = XMLParser.new()
	parser.open(filepath)
	var textData = {}
	var text = []
	var isContents = false
	while parser.read() != ERR_FILE_EOF:
		if(parser.get_node_type() == XMLParser.NODE_ELEMENT):
			if(parser.get_node_name() == "tns:section"):
				textData = parse_attributes(parser)
			if(parser.get_node_name() == "tns:p"):
				text.append(parse_text_line(parser))
	if(check_for_contents(text)):
		isContents = true
		var linestyleinfo = text[0][0]
		var blipstyleinfo = text[0][1][0][0]
		var blipstyleinfo_major_section = blipstyleinfo.duplicate()
		var blipstyleinfo_minor_section = blipstyleinfo.duplicate()
		var blipstyleinfo_subminor_section = blipstyleinfo.duplicate()
		blipstyleinfo_major_section["fs"] = str(blipstyleinfo["fs"].to_float() * 0.8)
		blipstyleinfo_minor_section["fs"] = str(blipstyleinfo["fs"].to_float() * 0.64)
		blipstyleinfo_subminor_section["fs"] = str(blipstyleinfo["fs"].to_float() * 0.4)
		text = []
		text.append([linestyleinfo, [[blipstyleinfo, "Contents:"]]])
		for section in util_Preloader.sectionsList:
			if(section != ""):
				var lsi = linestyleinfo.duplicate()
				lsi["link"] = section
				var split = section.split("/")
				var depth = split.size()
				var last = split[depth - 1]
				var string = ""
				if(depth > 1):
					for i in range(depth - 1):
						string += "    "
				string += last
				var bsi = blipstyleinfo_major_section if depth == 1 else blipstyleinfo_minor_section if depth == 2 else blipstyleinfo_subminor_section
				text.append([lsi, [[bsi, string]]])
	return [textData, text, isContents]

func check_for_contents(text):
	var textString = ""
	for line in text:
		for blip in line[1]:
			textString += blip[1]
	if(textString.contains("[CONTENTS]")):
		return true
	return false

func parse_text_line(parser):
	var lineStyleInfo = parse_attributes(parser)
	var lineData = []
	while true:
		parser.read()
		if(parser.get_node_type() == XMLParser.NODE_ELEMENT_END && parser.get_node_name() == "tns:p"):
			break
		if(parser.get_node_type() == XMLParser.NODE_ELEMENT && parser.get_node_name() == "tns:txt"):
			lineData.append([parse_attributes(parser), get_text_contents(parser)])
	return [lineStyleInfo, lineData]

func parse_attributes(parser):
	var data = {}
	for idx in range(parser.get_attribute_count()):
		data[parser.get_attribute_name(idx)] = parser.get_attribute_value(idx)
	return data

func add_text_to_line(text):
	finalTextData.append([currentTextData.duplicate(), text])
	pass
