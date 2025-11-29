extends Node

# Utility for getting rid of temporary files

func clear_temp():
	clear_dir_recursive("user://temp/")

func clear_dir_recursive(dir): # Godot only lets you delete a folder once its empty
	var diracc = DirAccess.open(dir)
	for path in diracc.get_files(): # Delete all files
		diracc.remove(path)
	for path in diracc.get_directories(): # Clear and then delete all folders
		clear_dir_recursive(dir + path + "/")
		DirAccess.remove_absolute(dir + path + "/")
