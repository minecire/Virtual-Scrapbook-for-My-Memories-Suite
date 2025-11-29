extends Node

func parse_text_shape(shape, data, canvas_width, canvasHeight, path):
	var shapeFile = path + "/objects/" + shape["customShapeName"]
	var shapeCurves = util_SvgProcessing.convert_shape_to_curves(shapeFile, shape, Vector2(canvas_width, canvasHeight), canvas_width, canvasHeight)
	var naivePolygons = util_SvgProcessing.convert_curves_to_polygons_naive(shapeCurves, 60)
	var shapePolygons = util_SvgProcessing.combine_polygons(naivePolygons)
	var finalShapePolygons = util_SvgProcessing.convert_to_convex_polygon_shapes_2d(shapePolygons)
	var shapes = finalShapePolygons
	var boundsPos = Vector2(shape["startX"].to_int(), shape["startY"].to_int())
	var boundsSize = Vector2(shape["width"].to_int(), shape["height"].to_int())
	var padding = Vector2.ZERO
	if(data.has("padding")):
		padding = Vector2(data["padding"].to_int(), data["padding"].to_int()) / 7.
	util_TextParsing.preparse_text_for_shape(path + "/objects/" + data["fileName"], boundsSize.x)
	return find_text_placements(shapes, boundsPos, boundsSize, padding)

func find_text_placements(shapes, boundsPos, boundsSize, padding):
	var words = util_TextParsing.break_data_into_words(util_TextParsing.finalTextData)
	return calculate_positions(words, boundsPos, boundsSize, padding, shapes)

func calculate_positions(wordBrokenData, boundsPos, boundsSize, padding, shapes):
	var textSpaces = []
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
		var emptySpace = null
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
			var newEmptySpace = find_empty_space(newLineRect1, boundsPos, boundsSize, shapes, padding)
			
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
			var newEmptySpace = find_empty_space(newLineRect2, boundsPos, boundsSize, shapes, padding)
			
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

# Level of precision for fitting text to shapes
const stepSize = 10
func find_minimum_positions(yPos, boundsPos, boundsSize, shapes):
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
func find_empty_space(rect, boundsPos, boundsSize, shapes, padding):
	var newRect = rect
	newRect.size += padding * 2
	newRect.position -= padding
	var mins
	if(!minima.has(newRect.position.y)):
		minima[newRect.position.y] = find_minimum_positions(newRect.position.y, boundsPos, boundsSize, shapes)
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
			var num_intersects = intersects(shapes[i], rectShape, newRect.position)
			if(num_intersects == 1):
				var pos1 = newRect.position.x
				while(num_intersects == 1):
					newRect.position.x += stepSize
					num_intersects = intersects(shapes[i], rectShape, newRect.position)
				newRect.size -= padding * 2
				newRect.position.y += padding.y
				newRect.position.x = (pos1 + newRect.position.x) / 2.
				return newRect
			elif(num_intersects > 1):
				if(newRect.position.x < intersects):
					newRect.position.x = intersects
		newRect.position.x += stepSize
	return null

func next_min(mins, pos):
	for minim in mins:
		if(minim > pos):
			return minim
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
	var maximum = 0
	var width = 0
	for word in words:
		maximum = max(maximum, word[1].y)
		width += word[1].x
	return Vector2(width, maximum)



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
