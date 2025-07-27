extends Node

func clear_temp():
	clear_dir_recursive("user://temp/")

func clear_dir_recursive(dir):
	var diracc = DirAccess.open(dir)
	for path in diracc.get_files():
		diracc.remove(path)
	for path in diracc.get_directories():
		clear_dir_recursive(dir + path + "/")
		diracc.remove_absolute(dir + path + "/")
