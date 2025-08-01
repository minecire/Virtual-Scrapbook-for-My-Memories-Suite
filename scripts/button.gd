extends Button


var file_access_web: FileAccessWeb

func _on_button_up() -> void:
	if(!OS.has_feature("web")):
		$CustomFileDialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		$CustomFileDialog.visible = true
	else:
		file_access_web.open(".zip")
		file_access_web.loaded.connect(_on_web_file_loaded)


func resize():
	if(get_viewport() != null):
		size = get_viewport().get_visible_rect().size * Vector2(0.6, 0.1)
		position = get_viewport().get_visible_rect().size * Vector2(0.2, 0.15)

func _on_web_file_loaded(_filename, _filetype, data):
	var raw = Marshalls.base64_to_raw(data)
	var fileacc = FileAccess.open("user://temp/rawzip.zip", FileAccess.WRITE)
	fileacc.store_buffer(raw)
	fileacc.close()
	
	_on_file_dialog_file_selected("user://temp/rawzip.zip")
	

func _on_file_dialog_file_selected(path: String, isExport = false) -> Control:
	var root = get_tree().get_root()
	
	var sectionsList : Array[String] = get_sections_recursive_zip(path)
	print(sectionsList)
	var zipReader = ZIPReader.new()
	zipReader.open(path)
	if(zipReader.file_exists("sections.txt")):
		var finalList : Array[String] = []
		var fileacc = zipReader.read_file("sections.txt")
		var sectionContent = fileacc.get_string_from_utf8().split("\n")
		if(sectionsList[0] == ""):
			finalList.append("")
		var normalizedSectionsList = sectionsList.duplicate()
		for i in range(normalizedSectionsList.size()):
			normalizedSectionsList[i] = normalizedSectionsList[i].to_lower().replace(" ", "").replace("\t", "").replace("_", "")
			if(normalizedSectionsList[i].length() > 0 && normalizedSectionsList[i][0] != "/"):
				normalizedSectionsList[i] = "/" + normalizedSectionsList[i]
		for section in sectionContent:
			var sectionNormalized = section.to_lower().replace(" ", "").replace("\t", "").replace("\n", "").replace("\r", "").replace("_", "")
			if(sectionNormalized.length() > 0 && sectionNormalized[0] != "/"):
				sectionNormalized = "/" + sectionNormalized
			var index = normalizedSectionsList.find(sectionNormalized)
			if(index != -1 && sectionNormalized != ""):
				finalList.append(sectionsList[index])
		sectionsList = finalList
	print(sectionsList)
	if(sectionsList.size() == 0):
		return null
	var book = load("res://scenes/book.tscn").instantiate()
	book.isZip = true
	book.bookPath = path
	book.sectionsList = sectionsList
	book.cantExit = isExport
	
	root.add_child.call_deferred(book)
	root.remove_child.call_deferred(root.get_node("Menu"))
	
	return book

func _on_file_dialog_dir_selected(dir: String, isExport = false) -> Control:
	var root = get_tree().get_root()
	
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
	
	
	if(sectionsList.size() == 0):
		return null
	
	var book = load("res://scenes/book.tscn").instantiate()
	book.isZip = false
	book.bookPath = dir
	book.sectionsList = sectionsList
	book.cantExit = isExport
	
	
	root.add_child.call_deferred(book)
	root.remove_child.call_deferred(root.get_node("Menu"))
	
	return book

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

func get_sections_recursive_zip(path: String):
	var zipReader = ZIPReader.new()
	zipReader.open(path)
	var zipFiles = zipReader.get_files()
	var sections : Array[String] = []
	for file in zipFiles:
		var extension = file.split(".")[file.split(".").size() - 1]
		if(extension == "mms"):
			var dir
			if(file.find("[SLASH]") != -1):
				dir = file.split("[SLASH]")
			else:
				dir = file.split("/")
			dir.remove_at(dir.size() - 1)
			dir = "/".join(dir)
			sections.append(dir)
	return sections

func _ready():
	load_page()
	get_tree().get_root().size_changed.connect(resize)
	resize()
	if(OS.has_feature("web")):
		file_access_web = FileAccessWeb.new()
func load_page():
	DirAccess.open("user://").remove("save")
	if !FileAccess.file_exists("user://save"):
		if !FileAccess.file_exists("res://export_data.txt"):
			return
		var exportData = FileAccess.open("res://export_data.txt", FileAccess.READ)
		var exportText = exportData.get_as_text().split("\n")
		if(exportText[0] != "true"):
			return
		var Path = exportText[1]
		if(exportText[2] == "true"):
			_on_file_dialog_file_selected(Path, true)
		else:
			_on_file_dialog_dir_selected(Path, true)
		return
	var savefile = FileAccess.open("user://save", FileAccess.READ)
	if(savefile.get_as_text().replace(" ", "").replace("\t", "").replace("\n", "").replace("\r", "") == "MENU"):
		if !FileAccess.file_exists("res://export_data.txt"):
			return
		var exportData = FileAccess.open("res://export_data.txt", FileAccess.READ)
		var exportText = exportData.get_as_text().split("\n")
		if(exportText[0] != "true"):
			return
		var Path = exportText[1]
		if(exportText[2] == "true"):
			_on_file_dialog_file_selected(Path, true)
		else:
			_on_file_dialog_dir_selected(Path, true)
		
		return
	
	var json = JSON.new()
	json.parse(savefile.get_as_text())
	var data = json.data
	var root = get_tree().get_root()
	var book
	if(data["isZip"]):
		book = _on_file_dialog_file_selected(data["bookPath"])
	else:
		book = _on_file_dialog_dir_selected(data["bookPath"])
	PageTurn.leftPageSectionIndex = data["leftPageSectionIndex"]
	PageTurn.rightPageSectionIndex = data["rightPageSectionIndex"]
	PageTurn.currentLeftPage = data["currentLeftPage"]
	PageTurn.currentRightPage = data["currentRightPage"]
	PageTurn.bookOpen = data["bookOpen"]
	if FileAccess.file_exists("res://export_data.txt"):
		var exportData = FileAccess.open("res://export_data.txt", FileAccess.READ)
		var exportText = exportData.get_as_text().split("\n")
		if(exportText[0] == "true"):
			book.cantExit = true
	if(data.has("isZip")):
		book.isZip = data["isZip"]
	
	if(PageTurn.bookOpen):
		book.get_node("CoverInsideRight").visible = true
		book.get_node("CoverInsideLeft").visible = true
		book.get_node("CoverOutside").visible = false
		book.get_node("CoverInsideLeft").material.set("shader_parameter/time", 1.0)
	else:
		book.get_node("CoverInsideRight").visible = true
		book.get_node("CoverInsideLeft").visible = false
		book.get_node("CoverOutside").visible = true
		
	
	
