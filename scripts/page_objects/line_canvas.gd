extends Control

var pageScale = 1.
var data = []
var shapeCoords
var curve
var curveAdvance = 0
var stretchVertical = 1.
var fontSizeFactor = 1.

func _draw():
	curveAdvance = 0
	if(data != [] && curve != null):
		for datum in data:
			var currentTextData = datum[0]
			var text = datum[1]
			var font = currentTextData["font"]
			for char in text.to_utf8_buffer():
				if(curveAdvance <= curve.get_baked_length()):
					var transform = curve.sample_baked_with_rotation(curveAdvance)
					draw_set_transform(shapeCoords * pageScale + transform.get_origin() * Vector2(1., stretchVertical), transform.get_rotation())
					curveAdvance += font.draw_char(get_canvas_item(), Vector2.ZERO, char, currentTextData["fontSize"] * fontSizeFactor, currentTextData["color"]);
