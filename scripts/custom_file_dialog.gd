extends Window

# Welcome to part 24,493 of Godot letting us down!
# We need a file dialogue box that can open both folders and single files
# This is doable in godot but you cannot use the system file dialogue, you have to use Godot's default one.
# That dialogue is missing some crucial features for navigation across your operating system efficiently
# Hence, we made our own.

var current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
@export var extensions : PackedStringArray # Array of file extensions to show
var current_file = ""
var current_file_is_dir
var current_file_is_invalid = false

signal file_selected
signal dir_selected

var items_are_folders = [] # Stores which items in a directory are subdirectories

func populate_files(): # Populate the list of files in directory
	$Box/Middle/Files.clear()
	$Box/Path.text = current_dir
	$Box/Bottom/FileName.text = ""
	items_are_folders = []
	if(current_dir == ""): # If in a root directory use hard drive icons and populate with drives
		var drive_icon = load("res://drive_icon.png")
		for i in range(DirAccess.get_drive_count()):
			$Box/Middle/Files.add_item(DirAccess.get_drive_name(i) + "//", drive_icon)
			items_are_folders.append(true)
		return
	var folder_icon = load("res://icons/folder_icon.png")
	var zip_icon = load("res://icons/zip_icon.png")
	
	var diracc = DirAccess.open(current_dir)
	$Box/Middle/Files.add_item("..", folder_icon) # Add item for parent directory
	diracc.list_dir_begin()
	for file_name in diracc.get_directories():
		$Box/Middle/Files.add_item(file_name, folder_icon) # Add directories with folder icon
		items_are_folders.append(true)
	for file_name in diracc.get_files():
		if(file_name.contains(".")):
			
			var extension = file_name.split(".")[file_name.split(".").size() - 1]
			if(extensions.find(extension) != -1): # Add files with proper extensions
				if(extension == "zip" || extension == "vsb"):
					$Box/Middle/Files.add_item(file_name, zip_icon) # Use zip icon for compressed folders
				else:
					$Box/Middle/Files.add_item(file_name)
				items_are_folders.append(false)
	current_file = ""
	current_file_is_invalid = false

func _ready():
	populate_files()
	size_changed.connect(resize) # Adjust elements when window resizes
	resize()
func resize():
	if(is_inside_tree()):
		$Box.position = size * 0.025
		$Box.size = size * 0.95
		$Box/Path.custom_minimum_size.y = 40
		$Box/Middle/FolderSelect.custom_minimum_size.x = size.x * 0.4
		$Box/Middle/FolderSelect/SystemFolders.custom_minimum_size.x = size.x * 0.4
		$Box/Bottom.custom_minimum_size.y = 40
		$Box/Bottom/FileName.custom_minimum_size.y = 40
		$Box/Bottom/SelectButton.custom_minimum_size.y = 40
		$Box/Bottom/EnterFolderButton.custom_minimum_size.y = 40
		$Box/Bottom/FileName.custom_minimum_size.x = size.x * 0.4



func _on_files_item_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	# When clicking on a file / folder
	
	if(mouse_button_index != 1):
		return #only left click
		
	if(index == 0): # Parent directory button is handled separately
		$Box/Bottom/FileName.text = ""
		current_file = ""
		current_file_is_invalid = false
		current_file_is_dir = true
		update_buttons()
		return
		
	var text = $Box/Middle/Files.get_item_text(index)
	current_file_is_dir = items_are_folders[index - 1] # subtract one to account for the parent dir at [0]
	if(text != ".."): # Otherwise set current file to clicked filename
		$Box/Bottom/FileName.text = text
		current_file = text
		current_file_is_invalid = false # We know it's valid if it's in the list
	update_buttons()


func _on_files_item_double_clicked(index: int) -> void: 
	# On double click we want to open a selected file
	# Or navigate into a selected folder
	
	var text = $Box/Middle/Files.get_item_text(index)
	
	if(!items_are_folders[index - 1]): # Open a file by broadcasting it has been selected
		emit_signal("file_selected", current_dir + "/" + text)
		visible = false # And disabling the window
		return
	
	if(text == ".."): # Go to parent directory
		if(current_dir.split(":")[1] == "//"):
			current_dir = ""
		else:
			var split_dir = current_dir.split("/")
			split_dir.remove_at(split_dir.size() - 1)
			current_dir = "/".join(split_dir)
	else: # Or go to selected dir
		if(current_dir != ""):
			current_dir += "/"
		current_dir += text
	populate_files()


func _on_close_requested() -> void:
	visible = false # Disable when closed out


func _on_system_folder_selected(index: int) -> void:
	var text = $Box/Middle/FolderSelect/SystemFolders.get_item_text(index)
	if(text == "Documents"):
		current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	elif(text == "Downloads"):
		current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	elif(text == "Desktop"):
		current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	elif(text == "User"):
		current_dir = OS.get_environment("USERPROFILE") if OS.has_feature("windows") else OS.get_environment("HOME")
	elif(text == "Drives"):
		current_dir = ""
	populate_files()


func _on_enter_folder_button_pressed() -> void:
	if(current_file == ".."):
		if(current_dir.split(":")[1] == "//"):
			current_dir = ""
		else:
			var split_dir = current_dir.split("/")
			split_dir.remove_at(split_dir.size() - 1)
			current_dir = "/".join(split_dir)
	else:
		if(current_dir != ""):
			current_dir += "/"
		current_dir += current_file
	populate_files()


func _on_select_button_pressed() -> void: # Select button
	if(current_file_is_invalid):
		return
	if(current_dir == ""):
		return
	if(current_file == ".."):
		emit_signal("dir_selected", current_dir) # Directory select will choose the current dir if parent is selected
	elif(current_file_is_dir):
		emit_signal("dir_selected", current_dir + "/" + current_file)
	else:
		emit_signal("file_selected", current_dir + "/" + current_file)
	visible = false
	pass # Replace with function body.

func _input(event):
	if(event.is_action_pressed("ui_cancel")):
		visible = false # Disable on ESC press
	if(event.is_action_pressed("ui_accept")): # Pressing enter with path selected will update it
		if($Box/Path.has_focus()):
			var new_path = $Box/Path.text
			new_path.replace("\\", "/")
			if(new_path[new_path.length()-1] == '/'):
				new_path = new_path.erase(new_path.length()-1)
			if(DirAccess.open(new_path).dir_exists(new_path)):
				current_dir = new_path
				populate_files()
		elif($Box/Bottom/FileName.has_focus() || $Box/Middle/Files.has_focus()): 
			# Otherwise either enter the folder or select the file
			if(current_file_is_dir):
				_on_enter_folder_button_pressed()
			else:
				_on_select_button_pressed()
			pass


func _on_file_name_text_changed(new_text: String) -> void: # Handle user editing text
	if(DirAccess.open(current_dir).file_exists(new_text)): # Determine folder/filehood, or enable the invalid flag
		current_file = new_text
		current_file_is_dir = false
		current_file_is_invalid = false
	elif(DirAccess.open(current_dir).dir_exists(new_text)):
		current_file = new_text
		current_file_is_dir = true
		current_file_is_invalid = false
	else:
		current_file = new_text
		current_file_is_invalid = true
	update_buttons()
	pass # Replace with function body.

func update_buttons(): # Disable / enable the bottom buttons depending on what actions are available
	if(current_file_is_invalid):
		$Box/Bottom/EnterFolderButton.disabled = true
		$Box/Bottom/SelectButton.disabled = true
	elif(current_file_is_dir):
		$Box/Bottom/EnterFolderButton.disabled = false
		$Box/Bottom/SelectButton.disabled = false
	else:
		$Box/Bottom/EnterFolderButton.disabled = true
		$Box/Bottom/SelectButton.disabled = false
		
		
