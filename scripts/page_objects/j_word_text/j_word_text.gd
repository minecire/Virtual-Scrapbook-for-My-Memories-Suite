extends PageObject

signal go_to_page
signal go_to_section

func initialize_variables(_type, data, path, page_size, page_type, canvas_width, canvas_height, section_index):
	$Background.data = data
	$Background.path = path
	$Background.page_size = page_size
	$Background.canvas_width = canvas_width
	$Background.canvas_height = canvas_height
	$Background/TextBox.section_index = section_index
	
	if(data.has("id")):
		$Background.shapedata = util_Preloader.idd_shapes[data["id"]]
		if(util_TextParsing.held_text_instances.has(data["id"]) && 
			util_TextParsing.held_text_instances[data["id"]]
			.get_node("Background").data.has("shape_text_placements")):
			$Background.data["shape_text_placements"] = util_TextParsing.held_text_instances[data["id"]].get_node("Background").data["shape_text_placements"]
	
	$Background.page_type = page_type
	$Background/TextBox.page_type = page_type
	
	$Background.reload()

func _on_background_go_to_page(section, page):
	emit_signal("go_to_page", section, page)


func _on_background_go_to_section(meta):
	emit_signal("go_to_section", meta)
