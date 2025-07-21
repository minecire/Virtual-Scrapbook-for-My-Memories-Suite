extends TextureRect

func _ready():
	
	get_tree().get_root().size_changed.connect(resize)
	resize()
func resize():
	if(get_viewport() != null):
		size = get_viewport().get_visible_rect().size
