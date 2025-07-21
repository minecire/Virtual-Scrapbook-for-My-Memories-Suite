extends Button

signal reload_stuff

func _on_button_up() -> void:
	$FileDialog.visible = true
	$FileDialog.set_current_dir(OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS))


func resize():
	if(get_viewport() != null):
		size = get_viewport().get_visible_rect().size * Vector2(0.6, 0.2)
		position = get_viewport().get_visible_rect().size * Vector2(0.2, 0.6)

func _on_file_dialog_dir_selected(dir: String) -> void:
	var root = get_tree().get_root()
	var book = load("res://scenes/book.tscn").instantiate()
	book.bookPath = dir + "/"
	
	
	var sectionsList : Array[String] = get_sections_recursive(dir)
	
	var diracc = DirAccess.open(dir)
	if(diracc.file_exists("sections.txt")):
		var finalList : Array[String] = []
		var fileacc = FileAccess.open(dir + "/sections.txt", FileAccess.READ)
		var sectionContent = fileacc.get_as_text().split("\n")
		if(sectionsList[0] == ""):
			finalList.append("")
		var normalizedSectionsList = sectionsList.duplicate()
		for i in range(normalizedSectionsList.size()):
			normalizedSectionsList[i] = normalizedSectionsList[i].to_lower().replace(" ", "").replace("\t", "").replace("_", "")
		for section in sectionContent:
			var sectionNormalized = section.to_lower().replace(" ", "").replace("\t", "").replace("\n", "").replace("\r", "").replace("_", "")
			if(sectionNormalized.length() > 0 && sectionNormalized[0] != "/"):
				sectionNormalized = "/" + sectionNormalized
			var index = normalizedSectionsList.find(sectionNormalized)
			if(index != -1 && sectionNormalized != ""):
				finalList.append(sectionsList[index])
		sectionsList = finalList
	
	book.sectionsList = sectionsList
	
	reload_stuff.connect(util_Preloader.reload_stuff)
	
	root.add_child(book)
	emit_signal("reload_stuff")
	root.remove_child(root.get_node("Menu"))

func get_sections_recursive(dir: String, subdir: String = ""):
	var diracc := DirAccess.open(dir + subdir)
	if diracc == null: printerr("Could not open folder"); return
	var hasThisSection = false
	for file: String in diracc.get_files():
		var extension = file.split(".")[file.split(".").size() - 1]
		if(extension == "mms"):
			hasThisSection = true
	var sections : Array[String] = []
	if(hasThisSection):
		sections.append(subdir)
	for sub in (diracc.get_directories()):
		sections.append_array(get_sections_recursive(dir, subdir + "/" + sub))
	return sections
	pass

func _ready():
	load_page()
	get_tree().get_root().size_changed.connect(resize)
	resize()
func load_page():
	if !FileAccess.file_exists("user://save"):
		return
	var savefile = FileAccess.open("user://save", FileAccess.READ)
	print(savefile.get_as_text())
	if(savefile.get_as_text().replace(" ", "").replace("\t", "").replace("\n", "").replace("\r", "") == "MENU"):
		return
	var json = JSON.new()
	json.parse(savefile.get_as_text())
	var data = json.data
	var root = get_tree().get_root()
	var book = load("res://scenes/book.tscn").instantiate()
	book.bookPath = data["bookPath"]
	var array:Array[String]
	array.assign(data["sectionsList"])
	for element in array:
		var diracc := DirAccess.open(data["bookPath"] + "/" + element)
		if diracc == null:
			array.erase(element)
		else:
			var hasThisSection = false
			for file: String in diracc.get_files():
				var extension = file.split(".")[file.split(".").size() - 1]
				if(extension == "mms"):
					hasThisSection = true
			if(!hasThisSection):
				array.erase(element)
	if(array.size() == 0):
		return
	book.sectionsList = array
	PageTurn.leftPageSectionIndex = data["leftPageSectionIndex"]
	PageTurn.rightPageSectionIndex = data["rightPageSectionIndex"]
	PageTurn.currentLeftPage = data["currentLeftPage"]
	PageTurn.currentRightPage = data["currentRightPage"]
	PageTurn.bookOpen = data["bookOpen"]
	
	if(PageTurn.bookOpen):
		book.get_node("CoverInsideRight").visible = true
		book.get_node("CoverInsideLeft").visible = true
		book.get_node("CoverOutside").visible = false
		book.get_node("CoverInsideLeft").set_instance_shader_parameter("time", 1.0)
	else:
		book.get_node("CoverInsideRight").visible = true
		book.get_node("CoverInsideLeft").visible = false
		book.get_node("CoverOutside").visible = true
		
	
	root.add_child.call_deferred(book)
	root.remove_child.call_deferred(root.get_node("Menu"))
	
