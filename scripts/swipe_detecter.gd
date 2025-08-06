extends Control

func _ready():
	set_deferred("scroll_horizontal", 500)

var lastPosition = -1

signal scroll_ended_2
signal next_section
signal previous_section
signal scrolling
signal released

var isPressed = false
var ignoreNextRelease = false

func _input(event):
	if(event is InputEventScreenTouch):
		if(event.double_tap):
			if(event.position.x < get_viewport().get_visible_rect().size.x / 3):
				emit_signal("previous_section")
			elif(event.position.x > get_viewport().get_visible_rect().size.x * 2 / 3):
				emit_signal("next_section")
			lastPosition = event.position.x
			ignoreNextRelease = true
		else:
		#if(event.pressed && lastPosition == -1):
			#lastPosition = event.position.x
		#elif(lastPosition != -1 && !event.pressed):
			#var movement = event.position.x - lastPosition
			#emit_signal("scroll_ended_2", -movement)
			#lastPosition = -1
			if(event.pressed):
				lastPosition = event.position.x
				isPressed = true
			if(!event.pressed):
				if(ignoreNextRelease):
					ignoreNextRelease = false
					return
				lastPosition = -1
				isPressed = false
				emit_signal("released")
	if(event is InputEventMouseMotion && isPressed):
		var movement = event.position.x - lastPosition
		emit_signal("scrolling", (event.position.x - lastPosition) / get_viewport().get_visible_rect().size.x * 2) 
		
