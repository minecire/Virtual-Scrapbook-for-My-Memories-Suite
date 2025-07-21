extends Panel

@export var sampleCount : int
#todo:
#(low priority)a few missing fonts, bold/italics failing on some fonts, rotation on curves
var data = {}
var pageSize
var canvasWidth
var canvasHeight
var systemFontsDict = {}
var isContents = false
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
var path
var shapedata
var hasCurve = false
var hasShape = false
var defaultCurvesDict = {
	"square": "M 0 0 H 1 V 1 H 0 V 0 Z",
	"squareinside": "M 0 0 V 1 H 1 V 0 H 0 Z",
	"circle": "M 0 0.5 C 0 0.22 0.22 0 0.5 0 S 1 0.22 1 0.5 S 0.78 1 0.5 1 S 0 0.78 0 0.5 Z",
	"circleinside": "M 0 0.5 C 0 0.78 0.22 1 0.5 1 S 1 0.78 1 0.5 S 0.78 0 0.5 0 S 0 0.22 0 0.5 Z"
}
var curve
var shapeCurves = []
var shapePolygons = []
var curveAdvance = 0.

var currentTextData = {}

var pageType : util_Enums.pageType;

signal go_to_section

func _has_point(_point):
	if(_point.x < get_viewport().get_visible_rect().size.x / 2 && $TextBox.pageType == util_Enums.pageType.LEFT):
		return true
	
	if(_point.x > get_viewport().get_visible_rect().size.x / 2 && $TextBox.pageType == util_Enums.pageType.RIGHT):
		return true
	return false

func _ready():
	reload()

func reload():
	$TextBox.pageSize = pageSize
	if(shapedata != null):
		parse_shape()
	parse_text()

func parse_shape():
	if(shapedata["objecttype"] == "line"):
		curve = util_SvgProcessing.parse_path(shapedata["svgPathData"], pageSize.x / canvasWidth, 1)[0]
		$LineCanvas.pageScale = pageSize.x / canvasWidth
		$LineCanvas.shapeCoords = Vector2(shapedata["startX"].to_int(), shapedata["startY"].to_int())
		$LineCanvas.curve = curve
		hasCurve = true
	elif(data.has("shapeTextPlacements")):
		$ShapeCanvas.data = data["shapeTextPlacements"]
		$ShapeCanvas.pageScale = pageSize.x / canvasWidth
		hasShape = true
	
func parse_default_shape(shapename):
	curve = util_SvgProcessing.parse_path(defaultCurvesDict[shapename], pageSize.x / canvasWidth * data["width"].to_int(), float(data["height"].to_int()) / float(data["width"].to_int()))[0]
	$LineCanvas.pageScale = pageSize.x / canvasWidth
	$LineCanvas.shapeCoords = Vector2(data["startX"].to_int(), data["startY"].to_int())
	$LineCanvas.fontSizeFactor = float(data["height"].to_int()) / float(data["width"].to_int())
	$LineCanvas.curve = curve
	hasCurve = true
	
	pass
func parse_text():
	if(data == {}):
		return
	if(data.has("mirror")):
		self.scale.x = -1 if data["mirror"] == "true" else 1
	if(data.has("flip")):
		self.scale.y = -1 if data["flip"] == "true" else 1
	if(data.has("rotation")):
		self.rotation_degrees = data["rotation"].to_float()
	
	var boxsize = Vector2(0,0)
	boxsize.x = float(data["width"].to_int())
	boxsize.y = float(data["height"].to_int())
	var pos = Vector2(0,0)
	pos.x = float(data["startX"].to_int())
	pos.y = float(data["startY"].to_int())
	boxsize *= (pageSize.x / canvasWidth)
	pos *= (pageSize.x / canvasWidth)
	self.size = boxsize
	$TextBox.size = boxsize 
	$TextBox.position = Vector2.ZERO
	if(data.has("padding")):
		$TextBox.size -= Vector2(data["padding"].to_int(), data["padding"].to_int()) * 2 * (pageSize.x / canvasWidth)
		$TextBox.position += Vector2(data["padding"].to_int(), data["padding"].to_int()) * (pageSize.x / canvasWidth)
	self.position = pos
	
	self.pivot_offset = boxsize / 2
	var mattewidth = 0
	if(data.has("outlineThickness") && data["outlineThickness"].to_int() > 0 && !hasCurve && !hasShape):
		self.visible = true
		var panel = StyleBoxFlat.new()
		panel.draw_center = false
		mattewidth = data["outlineThickness"].to_int() * (pageSize.x / canvasWidth)
		panel.border_width_left = mattewidth
		panel.border_width_right = mattewidth
		panel.border_width_top = mattewidth
		panel.border_width_bottom = mattewidth
		var matteColor = Color("#"+ "%06x" % (16777216 + data["outlineColor"].to_int()))
		panel.border_color = matteColor
		self.add_theme_stylebox_override("panel", panel)
		self.position.x -= mattewidth
		self.position.y -= mattewidth
		self.size.x += mattewidth * 2
		self.size.y += mattewidth * 2
	else:
		self.self_modulate.a = 0
		
	if(data.has("shape")):
		var shapename = ""
		if(data["shape"] == "0"):
			shapename = "circle"
		else:
			shapename = "square"
		if(data.has("drawInside") && data["drawInside"]):
			shapename += "inside"
		parse_default_shape(shapename)

	if(data.has("imageopacity")):
		self.modulate.a = data["imageopacity"].to_float()
	if(data.has("shadow") && data["shadow"] == "true"):
		$TextBox.add_theme_constant_override("shadow_offset_y", data["offsety"].to_int())
		$TextBox.add_theme_constant_override("shadow_offset_x", data["offsetx"].to_int())
		$TextBox.add_theme_constant_override("shadow_outline_size", 4)
		$TextBox.add_theme_color_override("font_shadow_color", Color(
			(data["shadowred"].to_int() / 256.) * (data["shadowred"].to_int() / 256.),
			data["shadowgreen"].to_int() / 256. * data["shadowgreen"].to_int() / 256.,
			data["shadowblue"].to_int() / 256. * data["shadowblue"].to_int() / 256.,
			data["shadowopacity"].to_float()*0.25))
	if(data.has("verticalAlignment")):
		var valign = data["verticalAlignment"].to_int()
		$TextBox.vertical_alignment = valign - 1
	$LineCanvas.size = pageSize
	$LineCanvas.top_level = true
	$ShapeCanvas.size = pageSize
	$ShapeCanvas.top_level = true
	
	set_text_from_file($TextBox, path + "/objects/" + data["fileName"])


func set_text_from_file(box, filepath):
	var parsedData = parse_text_content(filepath)
	var textData = parsedData[0]
	var text = parsedData[1]
	var scaleFactor = float(box.size.x) / float(textData["pagewidth"].to_int())
	
	box.size.x -= (textData["margl"].to_int() + textData["margr"].to_int()) * scaleFactor
	box.size.y -= (textData["margt"].to_int() + textData["margb"].to_int()) * scaleFactor
	box.position.x += (textData["margl"].to_int()) * scaleFactor
	box.position.y += (textData["margt"].to_int()) * scaleFactor
	
	
	for line in text:
		parse_line(line, box, scaleFactor)
func parse_line(line, box, scaleFactor):
	var lineData = line[0]
	var lineText = line[1]
	
	var halign = HORIZONTAL_ALIGNMENT_LEFT if lineData["halign"] == "left" else HORIZONTAL_ALIGNMENT_CENTER if lineData["halign"] == "center" else HORIZONTAL_ALIGNMENT_RIGHT if lineData["halign"] == "right" else HORIZONTAL_ALIGNMENT_FILL
	
	box.push_context()
	box.push_paragraph(halign)
	var currentFontSize = float(lineText[0][0]["fs"].to_int()) * scaleFactor
	if(lineData.has("linespace")):
		var linespace = lineData["linespace"].to_float()
		box.add_theme_constant_override("line_separation",linespace)
	if(lineData.has("list") && lineData["list"].to_int() > 0):
		parse_blip(lineText[0], box, scaleFactor, currentFontSize)
		box.push_list(lineData["level"].to_int(), RichTextLabel.LIST_DOTS, false)
		box.add_text(" ")
	if(lineData.has("link")):
		box.push_meta(lineData["link"], 0)
	for blip in lineText:
		box.push_context()
		parse_blip(blip, box, scaleFactor, currentFontSize)
		if(!hasCurve && !hasShape):
			box.add_text(blip[1])
		else:
			add_text_to_line(blip[1])
		box.pop_context()
	box.pop_context()
func parse_blip(blip, box, scaleFactor, currentFontSize):
	var blipData = blip[0]
	
	var bold = blipData.has("fstyle") && blipData["fstyle"].contains("b")
	var italics = blipData.has("fstyle") && blipData["fstyle"].contains("i")
	var underline = blipData.has("fstyle") && blipData["fstyle"].contains("u")
	currentTextData["bold"] = bold
	currentTextData["italics"] = italics
	currentTextData["underline"] = underline
	currentFontSize = round(float(blipData["fs"].to_int()) * scaleFactor)
	currentTextData["fontSize"] = currentFontSize
	box.push_font_size(currentFontSize)
	if(blipData.has("font")):
		var fontName = blipData["font"] + (" Bold" if bold else "") + (" Italic" if italics else "")
		var font;
		if(specialFontsDict.has(blipData["font"])):
			font = load("res://fonts/"+specialFontsDict[blipData["font"]])
			if(italics):
				box.push_italics()
			if(bold):
				box.push_bold()
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
				newfont.set_font_names(fontNames)
				systemFontsDict[fontName] = newfont
			font = systemFontsDict[fontName]
		var fv = FontVariation.new()
		fv.base_font = font
		if(blipData.has("expnd")):
			var expandFactor = float(blipData["expnd"])/(currentFontSize) * 9/5
			fv.set_spacing(TextServer.SPACING_GLYPH, expandFactor)
		currentTextData["font"] = fv
		box.push_font(fv)
	if(blipData.has("color")):
		box.push_color(Color(blipData["color"]))
		currentTextData["color"] = Color(blipData["color"])
	if(underline):
		box.push_underline()

func parse_text_content(filepath):
	var parser = XMLParser.new()
	parser.open(filepath)
	var textData = {}
	var text = []
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
	return [textData, text]

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

func get_text_contents(parser):
	parser.read()
	if(parser.get_node_type() == XMLParser.NODE_TEXT):
		return(parser.get_node_data())
	else:
		return " "

func add_text_to_line(text):
	$LineCanvas.data.append([currentTextData.duplicate(), text])
	pass

var clickTimer = 0.
func _on_text_box_meta_clicked(meta: Variant) -> void:
	if(clickTimer <= 0.):
		clickTimer = 1.
		emit_signal("go_to_section", meta)


func _process(deltaTime):
	clickTimer -= deltaTime / 10.
