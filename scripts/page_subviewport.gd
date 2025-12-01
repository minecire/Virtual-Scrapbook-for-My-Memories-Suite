extends SubViewport

# Mostly just here to pass data down to the Control node
# So we can move the page around in the viewport

var page_type
var page_name
var page_size

signal go_to_page

var page_index
var section_index
var path
var pos = Vector2(0, 0)

func _ready():
	set_canvas_cull_mask_bit(2, false);

func _on_book_page_update():
	load_page()

func load_page():
	$PositionedPage.path = path
	$PositionedPage.page_name = page_name
	$PositionedPage.page_type = page_type
	$PositionedPage.page_size = page_size
	$PositionedPage.size = size
	$PositionedPage.position = pos
	
	$PositionedPage.page_index = page_index
	$PositionedPage.section_index = section_index
	
	$PositionedPage.load_page()


func _on_positioned_page_go_to_section(section, page) -> void:
	print("hello?")
	emit_signal("go_to_page", section, page)
