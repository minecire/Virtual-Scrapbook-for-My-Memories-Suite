extends Label

# Info box popup

func _ready(): # Make sure it stays positioned properly
	get_tree().get_root().size_changed.connect(resize)
	resize()
func resize():
	if(get_viewport() != null):
		position.y = get_viewport().get_visible_rect().size.y / 20.

func display_text(txt, time):
	text = txt
	util_Timers.set_timer(turn_off, time, "info_box") # Disable after a bit
	visible = true
	self_modulate.a = 1

func _process(_delta):
	position.x = (get_viewport().get_visible_rect().size.x - size.x) / 2 # Recenter based on text amount
	if(util_Timers.get_time_left("info_box") < 0.5):
		self_modulate.a = max(0, util_Timers.get_time_left("info_box") * 2) # Fade out over 0.5s
		
func turn_off():
	visible = false
