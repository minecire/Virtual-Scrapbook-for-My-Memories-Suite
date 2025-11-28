extends Node


class e_Timer:
	var function_to_call : Callable
	var time_left_in_seconds : float
	var id : String
	var no_function : bool
	func set_data(function, length, id_) -> void:
		if(function != null):
			function_to_call = function
		else:
			no_function = true
		time_left_in_seconds = length
		id = id_
		

var running_timers : Array[e_Timer] = []

func set_timer(function_to_call, time_in_seconds, id):
	var timer_index = find_timer_by_id(id)
	if(timer_index != -1):
		running_timers[timer_index].set_data(function_to_call, time_in_seconds, id)
		return
	var new_timer : e_Timer = e_Timer.new()
	new_timer.set_data(function_to_call, time_in_seconds, id)
	running_timers.append(new_timer)

func cancel_timer(id):
	for i in range (running_timers.size()):
		if(running_timers[i].id == id):
			running_timers.remove_at(i)
			return

func get_time_left(id):
	for i in range (running_timers.size()):
		if(running_timers[i].id == id):
			return running_timers[i].time_left_in_seconds
	return 0.
	

func find_timer_by_id(id):
	for i in range (running_timers.size()):
		if(running_timers[i].id == id):
			return i
	return -1

func _process(delta_time):
	for i in range (running_timers.size()):
		var current_timer = running_timers[i]
		current_timer.time_left_in_seconds -= delta_time
		if(current_timer.time_left_in_seconds < 0.):
			if(!current_timer.no_function):
				current_timer.function_to_call.call()
			running_timers.remove_at(i)
			i-=1
