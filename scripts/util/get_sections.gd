extends Node

# Used for obtaining a list of section names/paths from a scrapbook, in order


func get_file_sections_list(file):
	var sections_list : Array[String] = get_sections_zip(file)
	
	var zip_reader = ZIPReader.new()
	zip_reader.open(file)
	if(!zip_reader.file_exists("sections.txt")):
		return sections_list
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
	return final_list

func get_dir_sections_list(dir):
	var sections_list = get_sections_recursive(dir) # List of sections
	
	var diracc = DirAccess.open(dir)
	if(!diracc.file_exists("sections.txt")):
		return sections_list
	
	# The user has specified sections
	var final_list : Array[String] = []
	var fileacc = FileAccess.open(dir + "/sections.txt", FileAccess.READ)
	var section_content = fileacc.get_as_text().split("\n") # List of sections
	if(sections_list[0] == ""):
		final_list.append("")
	var normalized_sections_list = sections_list.duplicate()
	for i in range(normalized_sections_list.size()): # Clear whitespace and case
		normalized_sections_list[i] = normalized_sections_list[i].to_lower().replace(" ", "").replace("\t", "").replace("_", "")
	
	for section in section_content: # Get the intersection of both lists, in order of sections.txt
		var section_normalized = section.to_lower().replace(" ", "").replace("\t", "").replace("\n", "").replace("\r", "").replace("_", "")
		if(section_normalized.length() > 0 && section_normalized[0] != "/"):
			section_normalized = "/" + section_normalized
		var index = normalized_sections_list.find(section_normalized)
		if(index != -1 && section_normalized != ""):
			final_list.append(sections_list[index])
	return final_list

func get_sections_recursive(dir: String, subdir: String = ""):
	
	var diracc := DirAccess.open(dir + subdir)
	if diracc == null: printerr("Could not open folder"); return
	var has_this_section = false
	for file: String in diracc.get_files():
		var extension = file.split(".")[file.split(".").size() - 1]
		if(extension == "mms"):
			has_this_section = true # There's an mms file here, its a valid section
	var sections : Array[String] = []
	if(has_this_section):
		sections.append(subdir)
	for sub in (diracc.get_directories()): # Look for more sections in all the subfolders
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
