extends Label

var timer = 0

func _ready():
	get_tree().get_root().size_changed.connect(resize)
	resize()
func resize():
	if(get_viewport() != null):
		position.y = get_viewport().get_visible_rect().size.y / 20.

func display_text(txt, time):
	text = txt
	timer = time
	visible = true
	self_modulate.a = 1

func _process(delta):
	position.x = (get_viewport().get_visible_rect().size.x - size.x) / 2
	timer -= delta
	if(timer < 0.5):
		self_modulate.a = max(0, timer * 2)
	if(timer < 0):
		visible = false
