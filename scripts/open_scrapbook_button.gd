extends Button

# This script handles what happens when you press the Load Book button 
# Opening a file dialogue, then preparing the scrapbook from the selected file
# It also handles save loading since that uses a lot of repeated code

# Our one external dependency besides the Godot engine itself!
# This handles opening local files on the web build
# Which isn't doable in Godot without some Javascript stuff, 
# and for once some one else has beaten us to solving this problem themselves
var file_access_web: FileAccessWeb 
# The scrapbook object is a global variable so it can remain referenced for returning to the menu later
var book 

func _on_button_up() -> void: # When clicked
	if(!OS.has_feature("web")): # Open our custom dialog
		$CustomFileDialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		$CustomFileDialog.visible = true
	else: # Or use the web dialog if this is a web build
		file_access_web.open(".zip,.vsb")
		file_access_web.loaded.connect(_on_web_file_loaded)

func _on_web_file_loaded(_filename, _filetype, data):
	# FileAccessWeb returns a base64 string of the zipped file
	var raw = Marshalls.base64_to_raw(data)
	
	# Godot does not provide functionality to open a zip archive from raw data
	# so we actually have to write it back to disk first in an accessible place
	var fileacc = FileAccess.open("user://temp/rawzip.zip", FileAccess.WRITE)
	fileacc.store_buffer(raw)
	fileacc.close()
	
	# Then we can handle a file select like usual
	_on_file_dialog_file_selected("user://temp/rawzip.zip")
	

func _on_file_dialog_file_selected(path: String, is_export = false) -> Control: # User selected a file
	if(path.get_extension() == "mms"): 
		# MMS files are not complete scrapbooks in themselves, but part of a larger directory of other files
		# Hence, we get the parent directory and handle it as a directory selection
		return _on_file_dialog_dir_selected(path.get_base_dir(), is_export)
	
	# Otherwise we assume the user has selected a compressed scrapbook folder
	
	# Recursively search for valid scrapbooks in the archive
	var sections_list : Array[String] = get_sections_zip(path)
	
	var zip_reader = ZIPReader.new()
	zip_reader.open(path)
	if(zip_reader.file_exists("sections.txt")):
		var final_list : Array[String] = []
		var fileacc = zip_reader.read_file("sections.txt")
		var section_content = fileacc.get_string_from_utf8().split("\n")
		if(sections_list[0] == ""):
			final_list.append("")
		var normalized_sections_list = sections_list.duplicate()
		for i in range(normalized_sections_list.size()): 
			# Loop through and normalize the discovered sections to maximize likelihood of correcting errors
			normalized_sections_list[i] = normalized_sections_list[i].to_lower().replace(" ", "").replace("\t", "").replace("_", "")
			if(normalized_sections_list[i].length() > 0 && normalized_sections_list[i][0] != "/"):
				normalized_sections_list[i] = "/" + normalized_sections_list[i]
		for section in section_content: 
			# And do the same with the sections.txt elements
			var section_normalized = section.to_lower().replace(" ", "").replace("\t", "").replace("\n", "").replace("\r", "").replace("_", "")
			if(section_normalized.length() > 0 && section_normalized[0] != "/"):
				section_normalized = "/" + section_normalized
			var index = normalized_sections_list.find(section_normalized)
			if(index != -1 && section_normalized != ""):
				final_list.append(sections_list[index]) # And add it to the final list if there's a match
		sections_list = final_list
		
	if(sections_list.size() == 0): # Invalid scrapbook
		return null
	if(book == null): # Instantiate the book scene if it's not there already
		var book_scene = load("res://scenes/book.tscn")
		book = book_scene.instantiate()
	book.is_zip = true
	book.book_path = path
	book.sections_list = sections_list
	book.cant_exit = is_export # Set its data
	
	PageTurn.currentLeftPage = -1 # Reset page to page 1
	PageTurn.currentRightPage = 1
	PageTurn.left_page_section_index = 0
	PageTurn.right_page_section_index = 0
	PageTurn.bookOpen = false # And closed book
	
	if(is_inside_tree()):
		var root = get_tree().get_root() # Replace the menu scene with the scrapbook scene
		root.add_child.call_deferred(book)
		root.remove_child.call_deferred(root.get_node("Menu"))
	return book

func _on_file_dialog_dir_selected(dir: String, is_export = false) -> Control:
	# If a directory was selected it's similar
	# But using DirAccess rather than a zip archive
	
	var sections_list : Array[String] = get_sections_recursive(dir)
	
	var diracc = DirAccess.open(dir)
	if(diracc.file_exists("sections.txt")):
		var final_list : Array[String] = []
		var fileacc = FileAccess.open(dir + "/sections.txt", FileAccess.READ)
		var section_content = fileacc.get_as_text().split("\n")
		if(sections_list[0] == ""):
			final_list.append("")
		var normalized_sections_list = sections_list.duplicate()
		for i in range(normalized_sections_list.size()):
			# Loop through and normalize the discovered sections to maximize likelihood of correcting errors
			normalized_sections_list[i] = normalized_sections_list[i].to_lower().replace(" ", "").replace("\t", "").replace("_", "")
		for section in section_content:
			# And do the same with the sections.txt elements
			var section_normalized = section.to_lower().replace(" ", "").replace("\t", "").replace("\n", "").replace("\r", "").replace("_", "")
			if(section_normalized.length() > 0 && section_normalized[0] != "/"):
				section_normalized = "/" + section_normalized
			var index = normalized_sections_list.find(section_normalized)
			if(index != -1 && section_normalized != ""):
				final_list.append(sections_list[index]) # And add it to the final list if there's a match
		sections_list = final_list
	
	
	if(sections_list.size() == 0): # Invalid scrapbook
		return null
	
	if(book == null): # Instantiate the book scene if it's not there already
		var book_scene = load("res://scenes/book.tscn")
		book = book_scene.instantiate()
	book.is_zip = false
	book.book_path = dir
	book.sections_list = sections_list
	book.cant_exit = is_export
	
	PageTurn.currentLeftPage = -1 # Reset page to page 1
	PageTurn.currentRightPage = 1
	PageTurn.left_page_section_index = 0
	PageTurn.right_page_section_index = 0
	PageTurn.bookOpen = false # And closed book
	
	if(is_inside_tree()):
		var root = get_tree().get_root() # Replace the menu scene with the scrapbook scene
		root.add_child.call_deferred(book)
		root.remove_child.call_deferred(root.get_node("Menu"))
	
	return book

func get_sections_recursive(dir: String, subdir: String = ""): # Searches for valid sections in a directory
	var diracc := DirAccess.open(dir + subdir)
	if diracc == null: printerr("Could not open folder"); return
	var has_this_section = false
	for file: String in diracc.get_files(): # Loop through files
		var extension = file.split(".")[file.split(".").size() - 1]
		if(extension == "mms"): # Look for an MMS scrapbook file
			has_this_section = true
	var sections : Array[String] = []
	if(has_this_section):
		sections.append(subdir) # Append if it found one
	for sub in (diracc.get_directories()): # Loop through directories to check if each one has sections
		sections.append_array(get_sections_recursive(dir, subdir + "/" + sub))
	return sections

func get_sections_zip(path: String): 
	# The zip version of that function works differently 
	# since zipreaders will just give you every file in the archive
	var zip_reader = ZIPReader.new()
	zip_reader.open(path)
	var zip_files = zip_reader.get_files()
	var sections : Array[String] = []
	for file in zip_files: # Loop through and check for mms extensions
		var extension = file.split(".")[file.split(".").size() - 1]
		if(extension == "mms"): 
			var dir
			if(file.find("[SLASH]") != -1): # Split by / or by [SLASH]
				# Godot does not allow the creation of subdirectories when making a zip archive
				# So our compressor immitates them by putting [SLASH] in the filename where a / would go
				dir = file.split("[SLASH]")
			else:
				dir = file.split("/")
			dir.remove_at(dir.size() - 1) # Remove the file name and rejoin to get just the directory path
			dir = "/".join(dir)
			sections.append(dir)
	return sections

func _ready():
	# If you open a scrapbook using Virtual Scrapbook, it should open the book immediately
	check_for_opened_with_book()
	
	load_page() # Load saved place from save file
	get_tree().get_root().size_changed.connect(resize) # Adjust when window is resized
	get_window().files_dropped.connect(on_files_dropped) # Listen for a file drag+dropped on the window
	resize()
	if(OS.has_feature("web")): # Initialize our FileAccessWeb instance
		file_access_web = FileAccessWeb.new()

func resize():
	if(get_viewport() != null):
		size = get_viewport().get_visible_rect().size * Vector2(0.6, 0.1)
		position = get_viewport().get_visible_rect().size * Vector2(0.2, 0.15)

func on_files_dropped(files):
	var file = files[0] # Assume the user wanted to open the first file
	if(file.get_extension() == "zip" || file.get_extension() == "vsb" || file.get_extension() == "mms"):
		# Make sure it's a file we can handle, then select it
		_on_file_dialog_file_selected(file)

func check_for_opened_with_book():
	var args = OS.get_cmdline_args()
	for arg in args:
		if(arg.get_extension() == "vsb" || arg.get_extension() == "zip" || arg.get_extension() == "mms"):
			# Look for a commandline argument with the proper file extension
			# Then select if found
			_on_file_dialog_file_selected(arg)
	pass

func load_packaged_book():
	# Check if we need to load a book for an engine-packaged scrapbook
	if !FileAccess.file_exists("res://export_data.txt"):
		return
	var export_data = FileAccess.open("res://export_data.txt", FileAccess.READ)
	var export_text = export_data.get_as_text().split("\n")
	if(export_text[0] != "true"): # Line zero defines whether a scrapbook is packaged
		return
	var path = export_text[1] # Line one is the path to the scrapbook
	if(export_text[2] == "true"): # Line two is whether the path is a file or directory
		_on_file_dialog_file_selected(path, true)
	else:
		_on_file_dialog_dir_selected(path, true)

func load_page(): # Load based on savefile or from export data
	# # Uncomment to stop VS loading a savefile, useful for debugging
	DirAccess.open("user://").remove("save")
	if !FileAccess.file_exists("user://save"):
		# If there is no savefile we check for a packaged book, then exit
		load_packaged_book()
		return
	var savefile = FileAccess.open("user://save", FileAccess.READ)
	if(savefile.get_as_text().replace(" ", "").replace("\t", "").replace("\n", "").replace("\r", "") == "MENU"):
		# Same if the savefile says we are in the menu
		load_packaged_book()
		return
	
	var json = JSON.new()
	json.parse(savefile.get_as_text()) # Otherwise we can grab the JSON data from the save file
	var data = json.data
	if(data["is_zip"]):
		book = _on_file_dialog_file_selected(data["book_path"])
	else:
		book = _on_file_dialog_dir_selected(data["book_path"])
	PageTurn.left_page_section_index = data["left_page_section_index"]
	PageTurn.right_page_section_index = data["right_page_section_index"]
	PageTurn.currentLeftPage = data["currentLeftPage"]
	PageTurn.currentRightPage = data["currentRightPage"]
	PageTurn.bookOpen = data["bookOpen"]
	if FileAccess.file_exists("res://export_data.txt"):
		var export_data = FileAccess.open("res://export_data.txt", FileAccess.READ)
		var export_text = export_data.get_as_text().split("\n")
		if(export_text[0] == "true"): # If this is packaged, need to make sure you can't quit to menu
			book.cant_exit = true
	if(data.has("is_zip")):
		book.is_zip = data["is_zip"]
