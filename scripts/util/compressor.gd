extends Node

var sectionsList : Array[String] = [];

func compress(dir):
	
	get_sections_list(dir);
	var tempDir = move_sections_to_temp(dir);
	copy_system_fonts(tempDir);
	write_temp_to_zip(tempDir, dir);
	
	util_ClearTemp.clear_temp()
	pass


func write_temp_to_zip(tempDir, origDir):
	var zipPath = origDir
	while(zipPath.ends_with("/")):
		zipPath = zipPath.substr(0, zipPath.length() - 1)
	zipPath += ".zip"
	
	FileAccess.open(zipPath, FileAccess.WRITE)
	
	var packer = ZIPPacker.new()
	packer.open(zipPath);
	
	write_to_zip_recursive(packer, tempDir);
	
	packer.close()
	

func write_to_zip_recursive(packer, dir, packerdir = ""):
	
	if(dir.ends_with("/")):
		dir = dir.substr(0, dir.length() - 1)
	
	var diracc = DirAccess.open(dir)
	
	
	for file in diracc.get_files():
		var filedata = FileAccess.get_file_as_bytes(dir + "/" + file)
		
		var newFileName = packerdir
		if(packerdir != ""):
			newFileName += "[SLASH]"
		newFileName += file
		print("writing file " + newFileName)
		packer.start_file(newFileName)
		packer.write_file(filedata)
		packer.close_file()
	
	for subdir in diracc.get_directories():
		packer.start_file(packerdir + "[SLASH]" + subdir + "[SLASH]")
		packer.close_file()
		var newPackerDir = packerdir
		if(packerdir != ""):
			newPackerDir += "[SLASH]"
		newPackerDir += subdir
		write_to_zip_recursive(packer, dir + "/" + subdir, newPackerDir)
		pass
	
	pass

func get_sections_list(dir):
	sectionsList = get_sections_recursive(dir)
	
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

func move_sections_to_temp(dir):
	if(!dir.ends_with("/")):
		dir += "/";
	
	var id = str(int(floor(randf() * 1000000000)))
	
	var root_dir = DirAccess.open("user://")
	root_dir.make_dir_recursive("temp/" + id + "/")
	
	var temp_dir = "user://temp/" + id;
	
	for section in sectionsList:
		var sectionDir = dir + section;
		var finalSectionDir = temp_dir + section;
		root_dir.make_dir_recursive("temp/" + id + "/" + section)
		copy_section(sectionDir, finalSectionDir);
	
	if(root_dir.dir_exists(dir + "fonts/")):
		root_dir.make_dir_recursive("temp/" + id + "/fonts/")
		var fonts_dir = DirAccess.open(dir + "fonts/")
		for file in fonts_dir.get_files():
			fonts_dir.copy_absolute(dir + "fonts/" + file, temp_dir + "/fonts/" + file)
	
	return temp_dir;
	
func copy_section(dir1, dir2):
	if(!dir1.ends_with("/")):
		dir1 += "/";
	
	if(!dir2.ends_with("/")):
		dir2 += "/";
	var initialDirAccess = DirAccess.open(dir1);
	print(dir2)
	var finalDirAccess = DirAccess.open(dir2);
	finalDirAccess.make_dir_recursive("objects/");
	
	var mmsFileName = "";
	var sectionstxt = false;
	var covers = false;
	for file in initialDirAccess.get_files():
		print(file)
		if(file.get_extension() == "mms"):
			mmsFileName = file;
		if(file == "sections.txt"):
			sectionstxt = true;
		if(file == "cover_outside.png"):
			covers = true;
	print()
	finalDirAccess.copy(dir1 + mmsFileName, dir2 + mmsFileName);
	
	if(sectionstxt):
		finalDirAccess.copy(dir1 + "sections.txt", dir2 + "sections.txt")
	
	if(covers):
		finalDirAccess.copy(dir1 + "cover_outside.png", dir2 + "cover_outside.png")
		finalDirAccess.copy(dir1 + "cover_inside_left.png", dir2 + "cover_inside_left.png")
		finalDirAccess.copy(dir1 + "cover_inside_right.png", dir2 + "cover_inside_right.png")
	
	var relevantObjects = get_relevant_objects_from_mms(dir1 + mmsFileName);
	
	var objectsDirAccess = DirAccess.open(dir1 + "objects/");
	for file in objectsDirAccess.get_files():
		if(file.get_extension() != "png" && file.get_extension() != "jpg" || relevantObjects.find(file) != -1):
			objectsDirAccess.copy_absolute(dir1 + "objects/" + file, dir2 + "objects/" + file);

func get_relevant_objects_from_mms(file):
	print(file)
	var zipreader = ZIPReader.new()
	zipreader.open(file)
	var content = zipreader.read_file(zipreader.get_files()[0])
	zipreader.close()
	var parser = XMLParser.new()
	parser.open_buffer(content)
	var relevantObjects = [];
	while parser.read() != ERR_FILE_EOF:
		if(parser.get_node_type() == XMLParser.NODE_ELEMENT):
			var nodeName = parser.get_node_name();
			if(nodeName == "fileName" || nodeName == "customShapeName" || nodeName == "imageMaskFill"):
				relevantObjects.append(get_text_contents(parser));
				pass
			
	return relevantObjects;
	pass


func copy_system_fonts(dir):
	var textFiles = get_text_files_recursive(dir)
	var fontNames = [];
	for textFile in textFiles:
		var fileFontNames = get_font_names(dir, textFile)
		for fn in fileFontNames:
			if(fontNames.find(fn) != -1):
				continue
			fontNames.append(fn)
	
	var fontPaths = get_system_font_paths(fontNames)
	
	
	var diracc = DirAccess.open(dir)
	
	for path in fontPaths:
		diracc.make_dir("fonts/")
		diracc.copy_absolute(path, dir + "/fonts/" + path.get_file())
func get_system_font_paths(fonts):
	var paths = []
	for font in fonts:
		var fontPath = OS.get_system_font_path(font[0], 700 if font[1].contains("b") else 400, 100, font[1].contains("i"))
		if(fontPath != ""):
			paths.append(fontPath)
	return paths
	
func get_font_names(dir, file):
	if(!dir.ends_with("/")):
		dir += "/"
	var fonts = []
	var parser = XMLParser.new()
	parser.open(dir + file)
	while parser.read() != ERR_FILE_EOF:
		if(parser.get_node_type() == XMLParser.NODE_ELEMENT):
			var nodeName = parser.get_node_name()
			if(nodeName == "txt" || nodeName == "tns:txt"):
				var attr = parse_attributes(parser)
				var font
				var styledfont
				if(!attr.has("font")):
					continue
				else:
					font = attr["font"]
				
				var style = ""
				if(attr.has("fstyle")):
					style = attr["fstyle"]
				
				fonts.append([font, style])
			if(nodeName == "content"):
				var attr = parse_attributes(parser)
				if(!attr.has("fontname")):
					continue
				else:
					fonts.append(attr["fontname"])
				
		pass
	return fonts
	

func get_text_files_recursive(dir):
	if(!dir.ends_with("/")):
		dir += "/"
	var diracc = DirAccess.open(dir)
	var files = [];
	for file in diracc.get_files():
		if(file.get_extension() == "xml" || file.get_extension() == "srw"):
			files.append(file)
	for subdir in diracc.get_directories():
		var dirfiles = get_text_files_recursive(dir + subdir)
		for i in range(dirfiles.size()):
			dirfiles[i] = subdir + "/" + dirfiles[i]
		files.append_array(dirfiles)
	return files
	

func get_text_contents(parser):
	parser.read()
	if(parser.get_node_type() == XMLParser.NODE_TEXT):
		return(parser.get_node_data())
	else:
		push_warning("no text found")
		return ""

func parse_attributes(parser):
	var data = {}
	for idx in range(parser.get_attribute_count()):
		data[parser.get_attribute_name(idx)] = parser.get_attribute_value(idx)
	return data
