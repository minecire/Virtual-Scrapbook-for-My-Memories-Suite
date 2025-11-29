extends Node

var currentTextData
var finalTextData

var textScene = preload("res://scenes/pageobjects/j_word_text.tscn")

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
	
	var _halign = HORIZONTAL_ALIGNMENT_LEFT if lineData["halign"] == "left" else HORIZONTAL_ALIGNMENT_CENTER if lineData["halign"] == "center" else HORIZONTAL_ALIGNMENT_RIGHT if lineData["halign"] == "right" else HORIZONTAL_ALIGNMENT_FILL
	
	var currentFontSize = float(lineText[0][0]["fs"].to_int()) * scaleFactor
	if(lineData.has("list") && lineData["list"].to_int() > 0):
		parse_blip(lineText[0], scaleFactor, currentFontSize)
	for blip in lineText:
		parse_blip(blip, scaleFactor, currentFontSize)
		add_text_to_line(blip[1])
	
func parse_text(data, canvas_width, max_output_width, max_output_height, path):
	var canvasHeight = float(max_output_height) / float(max_output_width) * float(canvas_width)
	get_tree().root.get_viewport().set_canvas_cull_mask_bit(2, false);
	var textInstance = textScene.instantiate()
	textInstance.pageSize = Vector2(100, 100)
	textInstance.canvas_width = canvas_width
	textInstance.canvasHeight = canvasHeight
	textInstance.path = path
	textInstance.data = data
	var shape = util_Preloader.iddshapes[data["id"]]
	if(shape["objecttype"] == "shape"):
		textInstance.data["shapeTextPlacements"] = util_TextShapes.parse_text_shape(shape, data, canvas_width, canvasHeight, path)
	textInstance.shapedata = shape
	util_Preloader.heldTextInstances[data["id"]] = textInstance

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
		if(util_Preloader.specialFontsDict.has(blipData["font"])):
			font = load("res://fonts/"+util_Preloader.specialFontsDict[blipData["font"]])
		else:
			if(!util_Preloader.systemFontsDict.has(fontName)):
				var newfont = SystemFont.new()
				newfont.font_italic = italics
				newfont.font_weight = 700 if bold else 400
				var fontNames = PackedStringArray()
				if(util_Preloader.systemDefaultFontsDict.has(blipData["font"])):
					fontNames.append(util_Preloader.systemDefaultFontsDict[blipData["font"]])
				else:
					
						fontNames.append(blipData["font"])
						fontNames.append(fontName)
				var dictHas = false
				for fn in fontNames:
					if(util_Preloader.preloadedFontsDict.has(fn)):
						util_Preloader.systemFontsDict[fontName] = util_Preloader.preloadedFontsDict[fn]
						dictHas = true
				if(!dictHas):
					newfont.set_font_names(fontNames)
					util_Preloader.systemFontsDict[fontName] = newfont
			font = util_Preloader.systemFontsDict[fontName]
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
			lineData.append([parse_attributes(parser), util_ExtraXML.get_text_contents(parser)])
	return [lineStyleInfo, lineData]

func parse_attributes(parser):
	var data = {}
	for idx in range(parser.get_attribute_count()):
		data[parser.get_attribute_name(idx)] = parser.get_attribute_value(idx)
	return data

func add_text_to_line(text):
	finalTextData.append([currentTextData.duplicate(), text])
	pass
