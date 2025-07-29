extends Control

func _ready():
	set_deferred("scroll_horizontal", 500)

var lastPosition = -1

signal scroll_ended_2
signal next_section
signal previous_section

func _input(event):
	if(event is InputEventScreenTouch):
		if(event.double_tap):
			if(event.position.x < get_viewport().get_visible_rect().size.x / 3):
				emit_signal("previous_section")
			elif(event.position.x > get_viewport().get_visible_rect().size.x * 2 / 3):
				emit_signal("next_section")
		if(event.pressed && lastPosition == -1):
			lastPosition = event.position.x
		elif(lastPosition != -1 && !event.pressed):
			var movement = event.position.x - lastPosition
			emit_signal("scroll_ended_2", -movement)
			lastPosition = -1
	pass
