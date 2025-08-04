extends Window

var current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
@export var extensions : PackedStringArray
var current_file = ""
var current_file_is_dir
var current_file_is_invalid = false

signal file_selected
signal dir_selected

var itemsAreFolders = []

func populateFiles():
	$Box/Middle/Files.clear()
	$Box/Path.text = current_dir
	$Box/Bottom/FileName.text = ""
	itemsAreFolders = []
	if(current_dir == ""):
		var driveIcon = load("res://drive_icon.png")
		for i in range(DirAccess.get_drive_count()):
			$Box/Middle/Files.add_item(DirAccess.get_drive_name(i) + "//", driveIcon)
			itemsAreFolders.append(true)
		return
	var folderIcon = load("res://icons/folder_icon.png")
	var zipIcon = load("res://icons/zip_icon.png")
	
	var diracc = DirAccess.open(current_dir)
	$Box/Middle/Files.add_item("..", folderIcon)
	diracc.list_dir_begin()
	for file_name in diracc.get_directories():
		$Box/Middle/Files.add_item(file_name, folderIcon)
		itemsAreFolders.append(true)
	for file_name in diracc.get_files():
		if(file_name.contains(".")):
			
			var extension = file_name.split(".")[file_name.split(".").size() - 1]
			if(extensions.find(extension) != -1):
				if(extension == "zip" || extension == "vsb"):
					$Box/Middle/Files.add_item(file_name, zipIcon)
				else:
					$Box/Middle/Files.add_item(file_name)
				itemsAreFolders.append(false)
		file_name = diracc.get_next()
	current_file = ""
	current_file_is_invalid = false

func _ready():
	populateFiles()
	size_changed.connect(resize)
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



func _on_files_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if(index == 0):
		$Box/Bottom/FileName.text = ""
		current_file = ""
		current_file_is_invalid = false
		current_file_is_dir = true
		update_buttons()
		return
		
	if(mouse_button_index == 1):
		var text = $Box/Middle/Files.get_item_text(index)
		current_file_is_dir = itemsAreFolders[index - 1]
		if(text != ".."):
			$Box/Bottom/FileName.text = text
			current_file = text
			current_file_is_invalid = false
		update_buttons()
	pass # Replace with function body.


func _on_files_item_double_clicked(index: int) -> void:
	var text = $Box/Middle/Files.get_item_text(index)
	if(text == ".."):
		if(current_dir.split(":")[1] == "//"):
			current_dir = ""
		else:
			var split_dir = current_dir.split("/")
			split_dir.remove_at(split_dir.size() - 1)
			current_dir = "/".join(split_dir)
		populateFiles()
	elif(!itemsAreFolders[index - 1]):
		emit_signal("file_selected", current_dir + "/" + text)
		visible = false
	else:
		if(current_dir != ""):
			current_dir += "/"
		current_dir += text
		populateFiles()
	
	pass # Replace with function body.


func _on_close_requested() -> void:
	visible = false


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
	populateFiles()


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
	populateFiles()


func _on_select_button_pressed() -> void:
	if(current_file_is_invalid):
		return
	if(current_dir == ""):
		return
	if(current_file == ".."):
		emit_signal("dir_selected", current_dir)
	elif(current_file_is_dir):
		emit_signal("dir_selected", current_dir + "/" + current_file)
	else:
		emit_signal("file_selected", current_dir + "/" + current_file)
	visible = false
	pass # Replace with function body.

func _input(event):
	if(event.is_action_pressed("ui_cancel")):
		visible = false
	if(event.is_action_pressed("ui_accept")):
		if($Box/Path.has_focus()):
			var newPath = $Box/Path.text
			newPath.replace("\\", "/")
			if(newPath[newPath.length()-1] == '/'):
				newPath = newPath.erase(newPath.length()-1)
			if(DirAccess.open(newPath).dir_exists(newPath)):
				current_dir = newPath
				populateFiles()
		elif($Box/Bottom/FileName.has_focus() || $Box/Middle/Files.has_focus()):
			if(current_file_is_dir):
				_on_enter_folder_button_pressed()
			else:
				_on_select_button_pressed()
			pass


func _on_file_name_text_changed(new_text: String) -> void:
	if(DirAccess.open(current_dir).file_exists(new_text)):
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

func update_buttons():
	if(current_file_is_invalid):
		$Box/Bottom/EnterFolderButton.disabled = true
		$Box/Bottom/SelectButton.disabled = true
	elif(current_file_is_dir):
		$Box/Bottom/EnterFolderButton.disabled = false
		$Box/Bottom/SelectButton.disabled = false
	else:
		$Box/Bottom/EnterFolderButton.disabled = true
		$Box/Bottom/SelectButton.disabled = false
		
		
