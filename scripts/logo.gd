extends TextureRect


func _ready():
	
	get_tree().get_root().size_changed.connect(resize)
	resize()

func resize():
	if(get_viewport() != null && is_inside_tree()):
		size = get_viewport().get_visible_rect().size * Vector2(1, 0.6)
		position = get_viewport().get_visible_rect().size * Vector2(0, 0.4)
