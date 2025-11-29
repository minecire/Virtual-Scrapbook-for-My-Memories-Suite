extends Control

# Silly object with scroll box to detect click-drags and screen swipes

func _ready(): # Always set horizontal scroll back to 500
	set_deferred("scroll_horizontal", 500)

var last_position = -1 # Tracks mouse position at start of drag

signal next_section # Double tap right
signal previous_section # Double tap left
signal scrolling # Started to drag
signal released # Released drag

var is_pressed = false
var ignore_next_release = false

func _input(event):
	if(event is InputEventScreenTouch): # Also triggered by mouse clicks
		if(event.double_tap):
			if(event.position.x < get_viewport().get_visible_rect().size.x / 3):
				emit_signal("previous_section")
			elif(event.position.x > get_viewport().get_visible_rect().size.x * 2 / 3):
				emit_signal("next_section")
			last_position = event.position.x
			ignore_next_release = true # Released signal after double tap will stop the page turn
		else:
			if(event.pressed): # Single tap
				last_position = event.position.x
				is_pressed = true 
			else:
				if(ignore_next_release):
					ignore_next_release = false
					return
				last_position = -1 # Reset last position
				is_pressed = false
				emit_signal("released")
	if(event is InputEventMouseMotion && is_pressed): # Click drag
		var movement = event.position.x - last_position # Calculate mouse movement
		emit_signal("scrolling", movement / get_viewport().get_visible_rect().size.x * 2) # Normalize to screen size
