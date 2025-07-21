extends Control

var data = []
var pageScale = 1.

func _draw():
	for element in data:
		write_text(element[0], element[1])


func write_text(words, space):
	var textPos = Vector2(space.position.x - space.size.x / 2., space.position.y + space.size.y) * pageScale
	for word in words:
		for datum in word[0]:
			var currentTextData = datum[0]
			var text = datum[1]
			var font = currentTextData["font"]
			for char in text.to_utf8_buffer():
				textPos.x += font.draw_char(get_canvas_item(), textPos, char, currentTextData["fontSize"] * pageScale, currentTextData["color"]);
