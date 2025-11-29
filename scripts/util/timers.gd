extends Node

# Godot has a timer but it didn't quite work for our use cases

class e_Timer: # e_ to differentiate from the Godot one
	var function_to_call : Callable
	var time_left_in_seconds : float
	var id : String
	var no_function : bool
	func set_data(function, length, id_) -> void:
		no_function = function == null
		if(!no_function):
			function_to_call = function
		time_left_in_seconds = length
		id = id_
		

var running_timers : Array[e_Timer] = []

func set_timer(function_to_call, time_in_seconds, id):
	# If we already have a timer we set that one
	var timer_index = find_timer_by_id(id)
	if(timer_index != -1):
		running_timers[timer_index].set_data(function_to_call, time_in_seconds, id)
		return
	# Otherwise make a new one
	var new_timer : e_Timer = e_Timer.new()
	new_timer.set_data(function_to_call, time_in_seconds, id)
	running_timers.append(new_timer)

func cancel_timer(id): # Remove timer from array
	var timer_index = find_timer_by_id(id)
	if(timer_index == -1):
		return
	running_timers.remove_at(timer_index)

func get_time_left(id):
	var timer_index = find_timer_by_id(id)
	if(timer_index == -1):
		return 0.
	return running_timers[timer_index].time_left_in_seconds
	

func find_timer_by_id(id): # Loop through timers for a match
	for i in range (running_timers.size()):
		if(running_timers[i].id == id):
			return i
	return -1

func _process(delta_time):
	for i in range (running_timers.size()): # Loop through and decrement timers
		var current_timer = running_timers[i]
		current_timer.time_left_in_seconds -= delta_time
		if(current_timer.time_left_in_seconds < 0.): # Out of time!
			if(!current_timer.no_function):
				current_timer.function_to_call.call() # Call the specified function
			running_timers.remove_at(i) # Remove from array
			i-=1 # Decrement index so we don't skip
