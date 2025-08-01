extends Button

func _ready():
	
	get_tree().get_root().size_changed.connect(resize)
	resize()
	if(OS.has_feature("web")):
		visible = false;
func resize():
	if(get_viewport() != null):
		size = get_viewport().get_visible_rect().size * Vector2(0.6, 0.1);
		position = get_viewport().get_visible_rect().size * Vector2(0.2, 0.32);

func _on_button_up() -> void:
	$FileDialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	$FileDialog.visible = true


func _on_file_dialog_dir_selected(dir: String) -> void:
	util_Compressor.compress(dir);
