extends Node

# Compresses a scrapbook to a vsb file

# MMS scrapbooks store a lot of redundant data
# So we get a very good compression ratio by just getting rid of it
# Additionally, we can package fonts with the file, so it doesn't break when viewed on another computer

func compress(dir):
	
	var sections_list = util_Sections.get_dir_sections_list(dir); # Get a list of sections
	var temp_dir = move_sections_to_temp(dir, sections_list); # Write all relevant files to a temporary directory
	copy_system_fonts(temp_dir); # Add used fonts so it won't break cross platform
	write_temp_to_zip(temp_dir, dir); # Put everything in a file in the original directory
	
	util_ClearTemp.clear_temp()
	pass

func move_sections_to_temp(dir, sections): # Loop through sections and copy everything relevant
	if(!dir.ends_with("/")):
		dir += "/";
	
	var id = str(int(floor(randf() * 1000000000))) # Generate random id
	
	var root_dir = DirAccess.open("user://")
	root_dir.make_dir_recursive("temp/" + id + "/") # To make a unique folder
	
	var temp_dir = "user://temp/" + id;
	
	for section in sections: # Copy section by section
		var section_dir = dir + section;
		var final_section_dir = temp_dir + section;
		root_dir.make_dir_recursive("temp/" + id + "/" + section)
		copy_section(section_dir, final_section_dir);
	
	if(root_dir.dir_exists(dir + "fonts/")): # Then copy over fonts already here if there are any
		root_dir.make_dir_recursive("temp/" + id + "/fonts/")
		var fonts_dir = DirAccess.open(dir + "fonts/")
		for file in fonts_dir.get_files():
			DirAccess.copy_absolute(dir + "fonts/" + file, temp_dir + "/fonts/" + file)
	
	return temp_dir;
	
func copy_section(dir1, dir2): # Copy a single section
	if(!dir1.ends_with("/")):
		dir1 += "/"
	
	if(!dir2.ends_with("/")):
		dir2 += "/"
	var initial_dir_access = DirAccess.open(dir1)
	var final_dir_access = DirAccess.open(dir2)
	final_dir_access.make_dir_recursive("objects/") # Make an objects folder
	
	var mmsFileName = ""
	var sectionstxt = false
	var covers = false
	for file in initial_dir_access.get_files():
		print(file)
		if(file.get_extension() == "mms"):
			mmsFileName = file # Get name of mms file (to be used for determining which data is relevant
		if(file == "sections.txt"):
			sectionstxt = true # Check for sections txt
		if(file == "cover_outside.png"):
			covers = true # Check for covers
	final_dir_access.copy(dir1 + mmsFileName, dir2 + mmsFileName) # Copy the mms
	
	if(sectionstxt): # Copy sections and covers if they exist
		final_dir_access.copy(dir1 + "sections.txt", dir2 + "sections.txt")
	
	if(covers):
		final_dir_access.copy(dir1 + "cover_outside.png", dir2 + "cover_outside.png")
		final_dir_access.copy(dir1 + "cover_inside_left.png", dir2 + "cover_inside_left.png")
		final_dir_access.copy(dir1 + "cover_inside_right.png", dir2 + "cover_inside_right.png")
	
	# Get array of objects that are actually used by the scrapbook
	var relevantObjects = get_relevant_objects_from_mms(dir1 + mmsFileName)
	
	var objectsDirAccess = DirAccess.open(dir1 + "objects/")
	for file in objectsDirAccess.get_files(): # And copy all of them
		if(file.get_extension() != "png" && file.get_extension() != "jpg" || relevantObjects.find(file) != -1):
			# Other than images we can just copy everything because nothing else takes up much space
			DirAccess.copy_absolute(dir1 + "objects/" + file, dir2 + "objects/" + file)

func get_relevant_objects_from_mms(file):
	var zipreader = ZIPReader.new()
	zipreader.open(file)
	var content = zipreader.read_file(zipreader.get_files()[0])
	zipreader.close() # Open up the MMS file
	var parser = XMLParser.new() # And the XML zipped inside
	parser.open_buffer(content)
	var relevantObjects = [];
	while parser.read() != ERR_FILE_EOF:
		if(parser.get_node_type() == XMLParser.NODE_ELEMENT): # Look for elements
			var nodeName = parser.get_node_name();
			if(nodeName == "fileName" || nodeName == "customShapeName" || nodeName == "imageMaskFill"):
				relevantObjects.append(util_ExtraXML.get_text_contents(parser)); # Add anything thats a filename
				pass
			
	return relevantObjects;


func copy_system_fonts(dir): # Copy fonts from system to allow sharing cross platform
	var textFiles = get_text_files_recursive(dir) # Look for stored text files
	var fontNames = [];
	for textFile in textFiles:
		var fileFontNames = get_font_names(dir, textFile) # Find font names
		for fn in fileFontNames:
			if(fontNames.find(fn) != -1): # Skip duplicates
				continue
			fontNames.append(fn)
	
	var fontPaths = get_system_font_paths(fontNames) # Get the filepaths of all the fonts
	
	var diracc = DirAccess.open(dir)
	
	for path in fontPaths: # Copy each one over
		diracc.make_dir("fonts/")
		DirAccess.copy_absolute(path, dir + "/fonts/" + path.get_file())

func get_text_files_recursive(dir): # Find any files probably storing text in the folder
	if(!dir.ends_with("/")):
		dir += "/"
	var diracc = DirAccess.open(dir)
	var files = [];
	for file in diracc.get_files(): 
		# xml files are generally jWord text files
		# srw probably stands for StoryRock Word art, used for word art / text art
		if(file.get_extension() == "xml" || file.get_extension() == "srw"):
			files.append(file)
	for subdir in diracc.get_directories(): # Recurse
		var dirfiles = get_text_files_recursive(dir + subdir)
		for i in range(dirfiles.size()): # Add files in subdirs
			dirfiles[i] = subdir + "/" + dirfiles[i]
		files.append_array(dirfiles)
	return files

func get_system_font_paths(fonts):
	var paths = []
	for font in fonts:
		# Get the path based on stroke weight and italicization
		var fontPath = OS.get_system_font_path(font[0], 700 if font[1].contains("b") else 400, 100, font[1].contains("i"))
		if(fontPath != ""): # Append if it found a match
			paths.append(fontPath)
	return paths
	
func get_font_names(dir, file): # Find fontnames from rich text xmls
	if(!dir.ends_with("/")):
		dir += "/"
	var fonts = []
	var parser = XMLParser.new()
	parser.open(dir + file)
	while parser.read() != ERR_FILE_EOF:
		if(parser.get_node_type() == XMLParser.NODE_ELEMENT):
			var nodeName = parser.get_node_name()
			if(nodeName == "txt" || nodeName == "tns:txt"): # Chunk of text
				var attr = util_ExtraXML.parse_attributes(parser)
				var font
				if(!attr.has("font")):
					continue
				else:
					font = attr["font"]
				
				var style = ""
				if(attr.has("fstyle")): # Font style, bold italics underline basically
					style = attr["fstyle"]
				
				fonts.append([font, style])
			if(nodeName == "content"): # Stored differently for word art
				var attr = util_ExtraXML.parse_attributes(parser)
				if(!attr.has("fontname")):
					continue
				else:
					fonts.append(attr["fontname"])
	return fonts

func write_temp_to_zip(temp_dir, orig_dir):
	var zip_path = orig_dir
	while(zip_path.ends_with("/")):
		zip_path = zip_path.substr(0, zip_path.length() - 1)
	zip_path += ".vsb" # Add .vsb to the end of the zipfile path
	
	FileAccess.open(zip_path, FileAccess.WRITE) # Open the file
	
	var packer = ZIPPacker.new() # Make a new zip packer
	packer.open(zip_path);
	
	write_to_zip_recursive(packer, temp_dir); # Recursively write every file
	
	packer.close()

func write_to_zip_recursive(packer, dir, packer_dir = ""):
	
	if(dir.ends_with("/")): # Trailing slash will break things
		dir = dir.substr(0, dir.length() - 1)
	
	var diracc = DirAccess.open(dir)
	
	
	for file in diracc.get_files(): # Add files
		var file_data = FileAccess.get_file_as_bytes(dir + "/" + file)
		
		var new_file_name = packer_dir
		if(packer_dir != ""):
			# Godot doesn't let us put directories in a generated zip
			# So we improvise by putting [SLASH] in the filenames to signify a subdirectory
			new_file_name += "[SLASH]"
		new_file_name += file
		packer.start_file(new_file_name)
		packer.write_file(file_data)
		packer.close_file()
	
	for subdir in diracc.get_directories(): # Go through directories
		# Add an empty file to signify a directory is here
		packer.start_file(packer_dir + "[SLASH]" + subdir + "[SLASH]")
		packer.close_file()
		
		var new_packer_dir = packer_dir
		if(packer_dir != ""):
			new_packer_dir += "[SLASH]" # Add a slash except the first time so there's no leading slash
		new_packer_dir += subdir
		write_to_zip_recursive(packer, dir + "/" + subdir, new_packer_dir) # Recurse
