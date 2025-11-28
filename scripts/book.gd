extends Control


# This is the heart of Virtual Scrapbook
# It renders the entire scrapbook
# Most of these features are my own ideas built from scratch
# I can blame a bit of the spaghetti on godot engine quirks being frustrating
# But mostly it's my own fault

#TODO:
# -more optimized web images / shaders

# File / Folder path to the scrapbook
@export var book_path: String

# Distance between edge of book and edge of screen
@export var border_size: int

# amount_page_is_turned it takes to turn a page
@export var page_turn_time_seconds: float

# Used for the multi-section feature, a list of file paths to each section from the book path
var sections_list: Array[String]

# Used to track the page turn animation
var amount_page_is_turned: float = 1.0

# Sent to reload the pages after a page turn
signal page_update

# Sent to add pages underneath the main visible one
# Used when a page has transparency
signal add_pages_below

# Sent to signal pages to detect backgrounds
signal get_has_background


# A reference to the image scene, used for access to shader parameters 
# for more efficient CPU ~ GPU communication
var image_scene = preload("res://scenes/pageobjects/image.tscn")

# Variables to reference scene objects
var pages_under #Pages visible underneath transparent ones

var left_page #Left and right page
var left_page_texture
var right_page
var right_page_texture
var turning_page_left #Front and back side of an animated turning page
var turning_page_left_texture
var turning_page_right
var turning_page_right_texture

# These store which section the left and right page are on
# These are potentially separate in the case of a book being open 
# to the last page of one section and the first of the next
var left_page_section
var right_page_section

# Used to stop people exiting to the main menu when creating a standalone scrapbook with the engine built in
# (That feature is used for creating entirely web-hosted scrapbooks)
var cant_exit = false

# Detects whether this is the first amount_page_is_turned user has turned a page to display another tip
var show_tip_on_next_page_turn = true

# For drag / swipe page turn motions
var dragging = false
var done_dragging = false

# Whether the scrapbook has been compressed into a .zip or .vsb file
var is_zip

func _ready():
	show_tip_on_next_page_turn = true # Display skip sections tooltip next amount_page_is_turned user turns a page
	util_Timers.set_timer(display_page_turn_info, 5.0, "page_turn_info") # Display tooltip if user doesn't turn page within five seconds
	
	#These values get set here instead of in UI because they have a habit of reverting back to defaults
	$CoverOutside.material.set("shader_parameter/amount_page_is_turned", 0)
	$CoverInsideLeft.material.set("shader_parameter/amount_page_is_turned", 0)
	$LeftPage.page_type = util_Enums.page_type.LEFT
	$RightPage.page_type = util_Enums.page_type.RIGHT
	$TurningPageLeft.page_type = util_Enums.page_type.TURNING
	$TurningPageRight.page_type = util_Enums.page_type.TURNING
	$LeftPage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	$RightPage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	$LeftPageTexture.texture.set_viewport_path_in_scene("LeftPage")
	$RightPageTexture.texture.set_viewport_path_in_scene("RightPage")
	$TurningPageLeftTexture.texture.set_viewport_path_in_scene("TurningPageLeft")
	$TurningPageRightTexture.texture.set_viewport_path_in_scene("TurningPageRight")
	
	#Set sections for left and right page
	left_page_section = sections_list[PageTurn.left_page_section_index]
	right_page_section = sections_list[PageTurn.right_page_section_index]
	
	#Set PageTurn's cover references properly
	#This cannot be done in page_turn.gd since it is not technically a node in the scene
	PageTurn.cover_inside_left = $CoverInsideLeft
	PageTurn.cover_outside = $CoverOutside
	
	#Load the entire scrapbook into memory to cut down on lagspikes due to loading from files
	util_Preloader.reload_stuff(sections_list, book_path, is_zip)
	
	if(util_Preloader.imagesDict.has("coverOutside") && util_Preloader.imagesDict["coverOutside"] != null): #If there is a cover, set the cover textures
		$CoverInsideLeft.texture = util_Preloader.imagesDict["coverInsideLeft"]
		$CoverInsideRight.texture = util_Preloader.imagesDict["coverInsideRight"]
		$CoverOutside.texture = util_Preloader.imagesDict["coverOutside"]
		PageTurn.has_cover = true #Tell PageTurn about it
		if(PageTurn.book_is_open): #If the book is open, the inside covers should be visible
			$CoverInsideRight.visible = true
			$CoverInsideLeft.visible = true
			$CoverOutside.visible = false
			$CoverInsideLeft.material.set("shader_parameter/amount_page_is_turned", 1.0) 
			$CoverOutside.material.set("shader_parameter/amount_page_is_turned", 1.0) 
			#And the cover shader needs to know the book is fully open
		else: #Otherwise, only the outside cover should be visible
			$CoverOutside.visible = true
			$CoverInsideRight.visible = true
			$CoverInsideLeft.visible = false
			$CoverInsideLeft.material.set("shader_parameter/amount_page_is_turned", 0.0) 
			$CoverOutside.material.set("shader_parameter/amount_page_is_turned", 0.0) 
			#And set the shader timer appropriately for a closed book
	else: #If there is no cover
		PageTurn.book_is_open = true #Make sure PageTurn knows the book is open
		PageTurn.has_cover = false #And that there is no cover so it doesn't try to close an invisible one
		$CoverOutside.visible = false #And covers are not visible.
		$CoverInsideRight.visible = false
		$CoverInsideLeft.visible = false
	
	book_path = util_Preloader.book_path #Set the book's path from the one given to preloader
	update_pages()
	if(is_inside_tree()):
		get_tree().get_root().size_changed.connect(delayed_page_update) 
	#Make sure there's a delayed page update on resize
	
	save_page()
	#Save the program so the scrapbook will be open next amount_page_is_turned

func delayed_page_update():
	util_Timers.set_timer(update_pages, 0.1, "update_pages")


func update_pages(): #This sets all the visible pages to the correct values and then reloads them.
	left_page_section = sections_list[PageTurn.left_page_section_index]
	right_page_section = sections_list[PageTurn.right_page_section_index]
	
	#Set these variables to the appropriate objects
	pages_under = $PagesUnder
	left_page = $LeftPage
	left_page_texture = $LeftPageTexture
	right_page = $RightPage
	right_page_texture = $RightPageTexture
	turning_page_left = $TurningPageLeft
	turning_page_left_texture = $TurningPageLeftTexture
	turning_page_right = $TurningPageRight
	turning_page_right_texture = $TurningPageRightTexture
	
	#Remove all pages underneath transparent ones
	for n in pages_under.get_children():
		pages_under.remove_child(n)
		n.free() 
	if is_inside_tree():
		$Background.size = get_viewport().get_visible_rect().size
	if(PageTurn.current_left_page == -1): #Set pages invisible if the page number is -1, visible otherwise
		left_page_texture.visible = false
	else:
		left_page_texture.visible = true
	if(PageTurn.current_right_page == -1):
		right_page_texture.visible = false
	else:
		right_page_texture.visible = true
	if(PageTurn.current_left_turning_page == -1):
		turning_page_left_texture.visible = false
	else:
		turning_page_left_texture.visible = true
	if(PageTurn.current_right_turning_page == -1):
		turning_page_right_texture.visible = false
	else:
		turning_page_right_texture.visible = true
	
	var sectionPathLeft
	var sectionPathRight
	if(left_page_section != ""): #Set section paths for each page, being careful to just set to the book path 
		#for a top level section
		sectionPathLeft = book_path + "\\" +left_page_section + "\\"
	else:
		sectionPathLeft = book_path
	if(right_page_section != ""):
		sectionPathRight = book_path + "\\" +right_page_section + "\\"
	else:
		sectionPathRight = book_path
	left_page.path = sectionPathLeft
	right_page.path = sectionPathRight
	
	# Set turning pages based on whether they are in the same section as the left or right page
	# Note: Sometimes they are neither, such as when a section is only a single page 
	# or flipping between sections. This glitches the program a little, 
	# and might be worth reworking at some point.
	turning_page_left.path = sectionPathRight if PageTurn.turning_page_left_section_side else sectionPathLeft
	turning_page_right.path = sectionPathRight if PageTurn.turning_page_right_section_side else sectionPathLeft
	
	# Find the name of each page. MMS convention is to name each page Page N for each page, starting at 1
	left_page.page_name = "Page " + ("%d") % PageTurn.current_left_page
	right_page.page_name = "Page " + ("%d") % PageTurn.current_right_page
	turning_page_left.page_name = "Page " + ("%d") % PageTurn.current_left_turning_page
	turning_page_right.page_name = "Page " + ("%d") % PageTurn.current_right_turning_page
	
	# The index needs to start at 0, so we subtract 1
	left_page.page_index = PageTurn.current_left_page - 1
	right_page.page_index = PageTurn.current_right_page - 1
	turning_page_left.page_index = PageTurn.current_left_turning_page - 1
	turning_page_right.page_index = PageTurn.current_right_turning_page - 1
	
	#Set section indeces
	left_page.section_index = PageTurn.left_page_section_index
	right_page.section_index = PageTurn.right_page_section_index
	turning_page_left.section_index = PageTurn.right_page_section_index if PageTurn.turning_page_left_section_side else PageTurn.left_page_section_index
	turning_page_right.section_index = PageTurn.right_page_section_index if PageTurn.turning_page_right_section_side else PageTurn.left_page_section_index
	
	#Calculate the screen aspect ratio, as well as the book 
	#to limit size based on width or height
	var aspect_ratio = float(util_Preloader.scrapbookData[PageTurn.left_page_section_index]["max_output_width"]) / float(util_Preloader.scrapbookData[PageTurn.left_page_section_index]["max_output_height"])
	if(is_inside_tree()):
		if(aspect_ratio * 2 < get_viewport().get_visible_rect().size.x / get_viewport().get_visible_rect().size.y):
			left_page.page_size = Vector2(get_viewport().get_visible_rect().size.y * aspect_ratio - border_size * 2, get_viewport().get_visible_rect().size.y - border_size * 2 / aspect_ratio)
			right_page.page_size = Vector2(get_viewport().get_visible_rect().size.y * aspect_ratio - border_size * 2, get_viewport().get_visible_rect().size.y - border_size * 2 / aspect_ratio)
		else:
			left_page.page_size = Vector2(get_viewport().get_visible_rect().size.x / 2.0 - border_size * 2, get_viewport().get_visible_rect().size.x / aspect_ratio / 2.0 - border_size * 2 / aspect_ratio)
			right_page.page_size = Vector2(get_viewport().get_visible_rect().size.x / 2.0 - border_size * 2, get_viewport().get_visible_rect().size.x / aspect_ratio / 2.0 - border_size * 2 / aspect_ratio)
	
	#Set page sizes, scaled up slightly in order to be run through a shader to give a curve to the pages 
	#as well as animating the page turning
	left_page_texture.size = left_page.page_size
	right_page_texture.size = right_page.page_size
	left_page_texture.size.y *= 1.2
	right_page_texture.size.y *= 1.2
	left_page.size = left_page.page_size
	right_page.size = right_page.page_size
	left_page.size.y *= 1.2
	right_page.size.y *= 1.2
	#Position of the page on screen
	if(is_inside_tree()):
		left_page_texture.position = Vector2(get_viewport().get_visible_rect().size.x / 2.0 - left_page.page_size.x, get_viewport().get_visible_rect().size.y / 2.0 - left_page.page_size.y / 2.0)
		right_page_texture.position = Vector2(get_viewport().get_visible_rect().size.x / 2.0 - left_page.page_size.x, get_viewport().get_visible_rect().size.y / 2.0 - left_page.page_size.y / 2.0)
	right_page_texture.position.x += left_page.page_size.x - 1 
		#Subtract 1 to stop an occasional single pixel showing up between the pages
		#Depending on page size
	
	left_page_texture.position.y /= 2
	right_page_texture.position.y /= 2
	
	turning_page_left.page_size = left_page.page_size
	turning_page_left.size = left_page.size
	turning_page_right.page_size = right_page.page_size
	turning_page_right.size = right_page.size
	
	turning_page_left_texture.size = left_page_texture.size
	turning_page_right_texture.size = right_page_texture.size
	
	var turning_page_pos_offset = Vector2(0, turning_page_left_texture.size.y / 10)
	
	turning_page_left_texture.position = left_page_texture.position - turning_page_pos_offset
	turning_page_right_texture.position = right_page_texture.position - turning_page_pos_offset
	
	#Set "pos", a special variable for placing the page within the window
	#allowing space for the arc of the page turn animation
	turning_page_left.pos = turning_page_pos_offset
	turning_page_right.pos = turning_page_pos_offset
	
	#These are lil blocks of color under the pages, used to fill in the gap to better sell the book texture
	$UnderLeftPage.position = Vector2(left_page_texture.position.x, left_page_texture.position.y + left_page.page_size.y * 0.99)
	$UnderLeftPage.size = Vector2(left_page.page_size.x, left_page.page_size.y * 0.05)
	$UnderRightPage.position = Vector2(right_page_texture.position.x, right_page_texture.position.y + right_page.page_size.y * 0.99)
	$UnderRightPage.size = Vector2(right_page.page_size.x, right_page.page_size.y * 0.05)
	
	$UnderLeftPage.visible = !PageTurn.current_left_page == -1
	$UnderRightPage.visible = !PageTurn.current_right_page == -1
	
	#Set the covers slightly bigger than the pages
	$CoverInsideLeft.size.y = left_page.page_size.y * 1.067 * 1.1
	$CoverInsideLeft.size.x = left_page.page_size.x * 1.067
	$CoverInsideLeft.position = left_page_texture.position - Vector2(left_page.page_size.x / 15, left_page.page_size.y / 60 + $CoverInsideLeft.size.y * 0.0909)
	$CoverInsideRight.size = left_page.page_size * 1.067
	$CoverInsideRight.position = right_page_texture.position - Vector2(0.0, left_page.page_size.y / 60.0)
	$CoverOutside.size.y = left_page.page_size.y * 1.067 * 1.1
	$CoverOutside.size.x = left_page.page_size.x * 1.067
	$CoverOutside.position = right_page_texture.position - Vector2(0.0, left_page.page_size.y / 60.0 + $CoverOutside.size.y * 0.0909)
	
	emit_signal("get_has_background")
	
	# Godot refuses to regiser our gui clicks unless they are outside the subviewports 
	# we use to apply shaders to entire pages
	# Hence, the clickables holder which holds clickable links. 
	# This is cleared out here and filled in again by text nodes
	if($ClickablesHolder.get_children().size() > 0):
		for node in $ClickablesHolder.get_children():
			$ClickablesHolder.remove_child(node)
			node.queue_free()
	
	#Add pages below the left and right page as long as we aren't at bookends
	if(PageTurn.current_right_page != -1): 
		emit_signal("add_pages_below", right_page, right_page_texture.position, right_page_texture.size, PageTurn.right_page_section_index, PageTurn.current_right_page, true)
	if(PageTurn.current_left_page != -1):
		emit_signal("add_pages_below", left_page, left_page_texture.position, left_page_texture.size, PageTurn.left_page_section_index, PageTurn.current_left_page, false)
	
	var isi = image_scene.instantiate() 
	# We instantiate an image scene here to access the image shaders globally
	if(OS.has_feature("web") || RenderingServer.get_current_rendering_method() == "gl_compatibility"):
		# In web mode we barely get any textures to work with, so we clear them out every update
		isi.shapes = {}
		isi.shapesarr = []
		isi.gradients = {}
		isi.gradientsarr = []
	
	
	emit_signal("page_update")
	
	if(!(OS.has_feature("web") || RenderingServer.get_current_rendering_method() == "gl_compatibility")):
		# Otherwise we update the page and only clear the arrays if they're getting too full
		if(isi.shapesarr.size() > 30 || isi.gradientsarr.size() > 30):
			isi.shapes = {}
			isi.shapesarr = []
			isi.gradients = {}
			isi.gradientsarr = []
			emit_signal("page_update") 
			# This helps with lag, although we do need to update the page twice in that case
	
	# Finally, set the shader parameters
	isi.imageMaterial.set("shader_parameter/shape_textures", isi.shapesarr)
	isi.imageMaterial.set("shader_parameter/gradient_textures", isi.gradientsarr)
	isi.imageMatteMaterial.set("shader_parameter/gradient_textures", isi.gradientsarr)
	isi.free()
	
	if($ClickablesHolder.get_children().size() > 0): 
		# Connect signals for changing cursor when hovering on a link
		for node in $ClickablesHolder.get_children():
			node.get_node("TextBox").meta_hover_started.connect(_on_text_box_meta_hover_started)
			node.get_node("TextBox").meta_hover_ended.connect(_on_text_box_meta_hover_ended)


func quit_to_menu():
	if(cant_exit):
		return
	PageTurn.reset_values()
	# Save the program in the MENU state so it will be there if the user closes and reopens after quitting
	save_menu()
	
	# Clear out temporary storage
	util_ClearTemp.clear_temp()
	
	#Switch scene to menu and clean up the book scene
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	get_tree().get_root().remove_child(get_tree().get_root().get_node("Book"))


# In order to get our cursor to behave with weird page shapes with links,
# We basically have to handle everything ourselves

# We've overwritten the cross cursor with the hand and the hand with the arrow
# Because otherwise the hand shows up in the wrong place, and there is no way to tell Godot not to use the hand
# This also requires a custom cursor set as there is no way to set these cursors to different default cursors
# This is the only way to fix the issue, trust me I tried everything else.
var time_since_link_hovered_last_frames = 0
func _on_text_box_meta_hover_started(_meta): 
	# When we start hovering on a link, set the cursor to "CROSS" (actually hand)
	time_since_link_hovered_last_frames = 60
	num_small_mouse_moves = 0
	for node in $ClickablesHolder.get_children():
		node.mouse_default_cursor_shape = Control.CURSOR_CROSS
func _on_text_box_meta_hover_ended(_meta):
	# When we stop hovering, we-
	# do the same thing?
	# Turns out hover ended just doesn't activate when the cursor exits a link
	# But instead every amount_page_is_turned the cursor moves after entering it.
	time_since_link_hovered_last_frames = 60
	num_small_mouse_moves = 0
	for node in $ClickablesHolder.get_children():
		node.mouse_default_cursor_shape = Control.CURSOR_CROSS

# So we have to try to set cursor back on our own when it seems like its not hovering a link anymore.
var num_small_mouse_moves = 0 
	# Tracks a bunch of small mouse movements in a row to signal switching the cursor back
func _input(event: InputEvent):
	if(time_since_link_hovered_last_frames <= 0 && event is InputEventMouseMotion):
		if(event.relative.length_squared() > 5 || num_small_mouse_moves > 5): 
			#If we have moved the mouse enough times, and enough distance, set the cursor back to arrow
			for node in $ClickablesHolder.get_children():
				node.mouse_default_cursor_shape = Control.CURSOR_ARROW
			
			num_small_mouse_moves = 0
		else:
			num_small_mouse_moves += 1
	if(event.is_action_pressed("ui_cancel")): # Escape, quits to menu after double tap
		if(util_Timers.find_timer_by_id("escape_double_tap") != -1):
			quit_to_menu()
		else:
			util_Timers.set_timer(null, 0.3, "escape_double_tap")
	if(event.is_action_pressed("ui_left")): # Left arrow, turn page left
		# Start a page turn left or cancel if page is already turning
		util_Timers.cancel_timer("page_turn_info") # They know what theyre doing already
		if(amount_page_is_turned < 1 && PageTurn.turning_right):
			amount_page_is_turned = 0.001
			PageTurn.turning_right = false
		elif(amount_page_is_turned > 0 && !PageTurn.turning_right):
			amount_page_is_turned = 0.001 # Setting the amount_page_is_turned to a very small amount so it will end the page turn next update
		else:
			amount_page_is_turned = PageTurn.turn_page_left()
			update_pages() # Remember to update all pages
			if(show_tip_on_next_page_turn):
				display_section_skip_info() # And display the tip for the first page turn
				show_tip_on_next_page_turn = false
	elif(event.is_action_pressed("ui_right")): # Right arrow, turn page right
		# Much the same but for turning right
		util_Timers.cancel_timer("page_turn_info") # They know what theyre doing already
		if(amount_page_is_turned < 1 && PageTurn.turning_right):
			amount_page_is_turned = 0.999
		elif(amount_page_is_turned > 0 && !PageTurn.turning_right):
			amount_page_is_turned = 0.999
			PageTurn.turning_right = true
		else:
			amount_page_is_turned = PageTurn.turn_page_right()
			update_pages()
			if(show_tip_on_next_page_turn):
				display_section_skip_info()
				show_tip_on_next_page_turn = false
	elif(event.is_action_pressed("reload_pages")):
		# "R" button by default, reloads everything for utility when modifying a scrapbook in MMS
		# And checking how it updates in VS
		util_Preloader.reload_stuff(sections_list, book_path, is_zip)
		update_pages()
	
	if(event.is_action_pressed("start_of_section")): # Shift + Left
		PageTurn.turn_to_section_start()
		update_pages()
	elif(event.is_action_pressed("next_section")): # Shift + Right
		PageTurn.turn_to_next_section()
		update_pages()
	if(event.is_action_pressed("start_of_book")): # Ctrl + Left
		PageTurn.turn_to_start_of_book()
		update_pages()
	if(event.is_action_pressed("end_of_book")): # Ctrl + Right
		PageTurn.turn_to_end_of_book()
		update_pages()

func _process(delta_time):
	if((amount_page_is_turned < 1 || dragging) && PageTurn.turning_right): 
		# In the middle of page turn or user is dragging/swiping the page
		if(!dragging):
			amount_page_is_turned += delta_time / page_turn_time_seconds # Increment amount_page_is_turned if page is turning automatically
			
		 # Set shader parameters to update visual effect
		if(PageTurn.opening_book):
			$CoverOutside.material.set("shader_parameter/time", amount_page_is_turned)
			$CoverInsideLeft.material.set("shader_parameter/time", amount_page_is_turned)
		else:
			$TurningPageLeftTexture.material.set("shader_parameter/time", amount_page_is_turned)
			$TurningPageRightTexture.material.set("shader_parameter/time", amount_page_is_turned)
		if(amount_page_is_turned >= 1): # Page has finished turning, we need to update the pages again
			amount_page_is_turned = 1
			PageTurn.finish_turn_right()
			update_pages()
			save_page()
			if(dragging):
				done_dragging = true
	elif((amount_page_is_turned > 0 || dragging) && !PageTurn.turning_right):
		if(!dragging):
			amount_page_is_turned -= delta_time / page_turn_time_seconds
		if(PageTurn.opening_book):
			$CoverOutside.material.set("shader_parameter/time", amount_page_is_turned)
			$CoverInsideLeft.material.set("shader_parameter/time", amount_page_is_turned)
		else:
			$TurningPageLeftTexture.material.set("shader_parameter/time", amount_page_is_turned)
			$TurningPageRightTexture.material.set("shader_parameter/time", amount_page_is_turned)
		if(amount_page_is_turned <= 0):
			amount_page_is_turned = 0
			PageTurn.finish_turn_left()
			update_pages()
			save_page()
			if(dragging):
				done_dragging = true
	else:
		amount_page_is_turned = round(amount_page_is_turned) #Make sure amount_page_is_turned hasn't gotten too far outside its expected range

func display_page_turn_info():
	if(OS.has_feature("mobile") || OS.has_feature("web_android") || OS.has_feature("web_ios")):
		$Info.display_text("Swipe left or right to turn page", 4.)
	else:
		$Info.display_text("Press left or right arrow keys to turn page", 4.)

func display_section_skip_info():
	if(OS.has_feature("mobile") || OS.has_feature("web_android") || OS.has_feature("web_ios")):
		$Info.display_text("Double tap the left or right side of the screen to move between sections", 4.)
	else:
		$Info.display_text("Hold shift and press left or right to move between sections", 4.)

func save_page(): # Save some data regularly so users can leave and return where they left off
	var savefile = FileAccess.open("user://save", FileAccess.WRITE)
	var savedata = {
		"book_path": util_Preloader.zipPath if is_zip else util_Preloader.book_path,
		"sections_list": sections_list,
		"left_page_section_index": PageTurn.left_page_section_index,
		"right_page_section_index": PageTurn.right_page_section_index,
		"currentLeftPage": PageTurn.current_left_page,
		"currentRightPage": PageTurn.current_right_page,
		"bookOpen": PageTurn.book_is_open,
		"is_zip": is_zip
		}
	var json_string = JSON.stringify(savedata)
	savefile.store_line(json_string)
func save_menu(): # Save that the user has returned to the menu
	var savefile = FileAccess.open("user://save", FileAccess.WRITE)
	savefile.store_line("MENU")


var page_scene = preload("res://scenes/page.tscn") # Preload the page scene to be used by _on_add_pages_below

# Called by the add_pages_below signal
func _on_add_pages_below(page, page_position, page_size, section_index, page_number, increasing, depth = -2) -> void:
	# This function will add pages below the left and right page until it hits the end of the book or
	# a page with a full background that would cover up anything below
	if(util_Preloader.scrapbookData[section_index]["pages"].size() <= page_number - 1): 
		# Return if page doesn't exist (end of book)
		return
	if(util_Preloader.scrapbookData[section_index]["pages"][page_number - 1]["hasBackground"]): 
		# Return once we hit a background
		return
	var newPageNumber = page_number
	var newSectionIndex = section_index
	if(increasing): # Increment / Decrement page number to get the next one
		newPageNumber += 2
		if(newPageNumber > util_Preloader.scrapbookData[section_index]["numPages"]): 
			# Handle cross-section boundaries
			if(section_index >= sections_list.size() - 1):
				$UnderRightPage.visible = false
				return
			else:
				newSectionIndex += 1
				newPageNumber = 2 if newPageNumber % 2 == util_Preloader.scrapbookData[section_index]["numPages"] % 2 else 1
			pass
	else: # Decrement for left page
		newPageNumber -= 2
		if(newPageNumber <= 0):
			if(section_index <= 0):
				$UnderLeftPage.visible = false
				return
			else:
				newSectionIndex -= 1
				newPageNumber = util_Preloader.scrapbookData[newSectionIndex]["numPages"] if newPageNumber == 0 else util_Preloader.scrapbookData[newSectionIndex]["numPages"] - 1
	
	var newPage = page_scene.instantiate() # Make a new page and set its data
	
	newPage.canvasWidth = page.canvasWidth
	newPage.page_size = page.page_size
	newPage.size = page.size
	newPage.pos = page.pos
	newPage.page_name = "Page "+ str(newPageNumber - 1)
	newPage.page_index = newPageNumber - 1
	newPage.section_index = newSectionIndex
	newPage.page_type = util_Enums.page_type.UNDER
	newPage.path = book_path + "/" + sections_list[newSectionIndex] + "/"
	
	page_update.connect(newPage._on_book_page_update) # Make sure it knows to update itself
	pages_under.add_child(newPage) # Add to scene
	
	# We need a texture too to display the subviewport with the proper shader
	var newPageTexture = TextureRect.new()
	newPageTexture.texture = newPage.get_texture()
	newPageTexture.position = page_position
	newPageTexture.size = page_size
	newPageTexture.z_index = depth
	newPageTexture.stretch_mode = TextureRect.STRETCH_KEEP
	newPageTexture.material = ShaderMaterial.new()
	if(increasing): # Use the proper left / right page shader
		newPageTexture.material.shader = load("shaders/page_shader.tres")
	else:
		newPageTexture.material.shader = load("shaders/left_page_shader.tres")
	pages_under.add_child(newPageTexture)
	if(depth > -12): # Break eventually to prevent massive lag spikes for lots of layers of transparency
		_on_add_pages_below(newPage, page_position, page_size, newSectionIndex, newPageNumber, increasing, depth - 2)
	elif(!newPage.hasBackground): # Set invisible if there's a background
		if(increasing):
			$UnderRightPage.visible = false
		else:
			$UnderLeftPage.visible = false

func _on_go_to_section(section, page) -> void: #Turns page to a specific page
	var section_index = get_section_index_from_name(section)
	if(section_index > PageTurn.right_page_section_index || # If the section we're turning to is after the current one
	(section_index == PageTurn.right_page_section_index && 
		page > PageTurn.current_right_page)): # Or the're the same and the page is later on
		amount_page_is_turned = PageTurn.turn_right_to_section(section, page) # Turn right
	else:
		amount_page_is_turned = PageTurn.turn_left_to_section(section, page)
	update_pages()

func get_section_index_from_name(section_name):
	currentSectionToCheck = section_name
	return sections_list.find_custom(check_nowhitespace)

# Find custom does not take in a parameter to find, so we need to use a global variable
var currentSectionToCheck = ""
func check_nowhitespace(a): 
	# We are checking whether two strings are the same minus some extra whitespace and case insensitive
	# And removes an initial slash
	# This leniency helps make use of the program more intuitive
	var b = currentSectionToCheck
	var new_a = a.replace(" ", "").replace("\n", "").replace("\r", "").replace("\t", "").to_lower()
	var new_b = b.replace(" ", "").replace("\n", "").replace("\r", "").replace("\t", "").to_lower()
	if(new_a.length() > 0 && new_a[0] == "/"):
		new_a = new_a.substr(1, new_a.length())
	if(new_b.length() > 0 && new_b[0] == "/"):
		new_b = new_b.substr(1, new_b.length())
	return new_a == new_b

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		util_ClearTemp.clear_temp() # Clear temporary storage before exiting
		get_tree().quit()

# You'd think Godot would handle click-drag and swipe actions automatically
# Turns out it kiinda does, but it's quite janky

# Swipe Detector is a screen size scrolling box, with a giant, invisible block inside.
# Dragging will scroll the box, which we can detect

func _on_swipe_detecter_scroll_ended(_movement = 0) -> void:
	dragging = false


func _on_swipe_detecter_next_section() -> void: 
	#Detect double click and turn to next / previous section
	if(amount_page_is_turned < 1 && PageTurn.turning_right):
		amount_page_is_turned = 0.999 #Or finish turning page if already turning
	elif(amount_page_is_turned > 0 && !PageTurn.turning_right):
		amount_page_is_turned = 0.999
		PageTurn.turning_right = true
	else:
		amount_page_is_turned = PageTurn.turn_page_right()
		update_pages()
	PageTurn.turn_to_next_section()
	update_pages()


func _on_swipe_detecter_previous_section() -> void:
	if(amount_page_is_turned < 1 && PageTurn.turning_right):
		amount_page_is_turned = 0.001
		PageTurn.turning_right = false
	elif(amount_page_is_turned > 0 && !PageTurn.turning_right):
		amount_page_is_turned = 0.001
	else:
		amount_page_is_turned = PageTurn.turn_page_left()
		update_pages()
	PageTurn.turn_to_section_start()
	update_pages()


func _on_swipe_detecter_scrolling(movement) -> void:
	# If we are dragging
	# There are a bunch of failsafes to make sure we don't do something silly and break the program
	if(amount_page_is_turned > 0 && amount_page_is_turned < 1): # Enable dragging immediately if we are mid page turn
		dragging = true
	if(done_dragging): 
		# done_dragging is a way of telling the program to stop dragging even if the user hasn't let go
		# if a page finishes turning, for example
		return
	movement = -movement
	if(movement > 0.01 && (!dragging || PageTurn.turning_right) || (dragging && PageTurn.turning_right)):
		# If we've moved a bit to the left (turning page right) and aren't dragging yet, 
		# or if we are already turning right
		if(!dragging && movement >= 0.05):
			# But havent immediately dragged too much because that's probably an error
			return
		if(!dragging): 
			PageTurn.turn_page_right()
			PageTurn.turning_right = true
			update_pages() # Initiate page turn and update
			dragging = true
		amount_page_is_turned = clamp(movement, 0.001, 0.999)
	elif(movement < -0.01 && (!dragging || !PageTurn.turning_right) || (dragging && !PageTurn.turning_right)):
		# Turning left is about the same
		if(!dragging && movement <= -0.05):
			return
		if(!dragging):
			PageTurn.turn_page_left()
			PageTurn.turning_right = false
			update_pages()
			dragging = true
		amount_page_is_turned = clamp(1 + movement, 0.001, 0.999)


func _on_swipe_detecter_released() -> void: # When releasing click
	if(amount_page_is_turned > 0.6): # Set pageturn if page hasn't been dragged enough
		PageTurn.turning_right = true
	elif(amount_page_is_turned < 0.4):
		PageTurn.turning_right = false
	dragging = false
	done_dragging = false # Reset done dragging so we can initiate a new drag next amount_page_is_turned
