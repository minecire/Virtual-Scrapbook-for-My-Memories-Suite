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

# Time it takes to turn a page
@export var turn_time: float

# Used for the multi-section feature, a list of file paths to each section from the book path
var sections_list: Array[String]

# Used to check for an ESC double tap, which quits Virtual Scrapbook back to the main menu
var escape_Timer = 0

# Used to track the page turn animation
var time: float = 1.0

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

# Used to update pages after a short delay when resizing the window
var update_delay_timer = -1

# Used to handle clicking links
var cursor_timer = 0

# Timer for displaying tips to assist people who don't intuit the controls
var display_info_timer = 5.

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

# Detects whether this is the first time user has turned a page to display another tip
var show_tip_on_next_page_turn = true

# For drag / swipe page turn motions
var dragging = false
var done_dragging = false

# Whether the scrapbook has been compressed into a .zip or .vsb file
var is_zip

func _ready():
	show_tip_on_next_page_turn = true # Display skip sections tooltip next time user turns a page
	display_info_timer = 5. # Display tooltip if user doesn't turn page within five seconds
	
	#These values get set here instead of in UI because they have a habit of reverting back to defaults
	$CoverOutside.material.set("shader_parameter/time", 0)
	$CoverInsideLeft.material.set("shader_parameter/time", 0)
	$LeftPage.pageType = util_Enums.pageType.LEFT
	$RightPage.pageType = util_Enums.pageType.RIGHT
	$TurningPageLeft.pageType = util_Enums.pageType.TURNING
	$TurningPageRight.pageType = util_Enums.pageType.TURNING
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
	PageTurn.CoverInsideLeft = $CoverInsideLeft
	PageTurn.CoverOutside = $CoverOutside
	
	#Load the entire scrapbook into memory to cut down on lagspikes due to loading from files
	util_Preloader.reload_stuff(sections_list, book_path, is_zip)
	
	if(util_Preloader.imagesDict["coverOutside"] != null): #If there is a cover, set the cover textures
		$CoverInsideLeft.texture = util_Preloader.imagesDict["coverInsideLeft"]
		$CoverInsideRight.texture = util_Preloader.imagesDict["coverInsideRight"]
		$CoverOutside.texture = util_Preloader.imagesDict["coverOutside"]
		PageTurn.hasCover = true #Tell PageTurn about it
		if(PageTurn.bookOpen): #If the book is open, the inside covers should be visible
			$CoverInsideRight.visible = true
			$CoverInsideLeft.visible = true
			$CoverOutside.visible = false
			$CoverInsideLeft.material.set("shader_parameter/time", 1.0) 
			$CoverOutside.material.set("shader_parameter/time", 1.0) 
			#And the cover shader needs to know the book is fully open
		else: #Otherwise, only the outside cover should be visible
			$CoverOutside.visible = true
			$CoverInsideRight.visible = true
			$CoverInsideLeft.visible = false
			$CoverInsideLeft.material.set("shader_parameter/time", 0.0) 
			$CoverOutside.material.set("shader_parameter/time", 0.0) 
			#And set the shader timer appropriately for a closed book
	else: #If there is no cover
		PageTurn.bookOpen = true #Make sure PageTurn knows the book is open
		PageTurn.hasCover = false #And that there is no cover so it doesn't try to close an invisible one
		$CoverOutside.visible = false #And covers are not visible.
		$CoverInsideRight.visible = false
		$CoverInsideLeft.visible = false
	
	book_path = util_Preloader.book_path #Set the book's path from the one given to preloader
	update_pages()
	get_tree().get_root().size_changed.connect(delayed_page_update) 
	#Make sure there's a delayed page update on resize
	
	save_page()
	#Save the program so the scrapbook will be open next time

func delayed_page_update():
	update_delay_timer = 0.1


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
	
	$Background.size = get_viewport().get_visible_rect().size
	if(PageTurn.currentLeftPage == -1): #Set pages invisible if the page number is -1, visible otherwise
		left_page_texture.visible = false
	else:
		left_page_texture.visible = true
	if(PageTurn.currentRightPage == -1):
		right_page_texture.visible = false
	else:
		right_page_texture.visible = true
	if(PageTurn.currentLeftTurningPage == -1):
		turning_page_left_texture.visible = false
	else:
		turning_page_left_texture.visible = true
	if(PageTurn.currentRightTurningPage == -1):
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
	turning_page_left.path = sectionPathRight if PageTurn.turning_page_leftSectionSide else sectionPathLeft
	turning_page_right.path = sectionPathRight if PageTurn.turning_page_rightSectionSide else sectionPathLeft
	
	# Find the name of each page. MMS convention is to name each page Page N for each page, starting at 1
	left_page.pageName = "Page " + ("%d") % PageTurn.currentLeftPage
	right_page.pageName = "Page " + ("%d") % PageTurn.currentRightPage
	turning_page_left.pageName = "Page " + ("%d") % PageTurn.currentLeftTurningPage
	turning_page_right.pageName = "Page " + ("%d") % PageTurn.currentRightTurningPage
	
	# The index needs to start at 0, so we subtract 1
	left_page.pageIndex = PageTurn.currentLeftPage - 1
	right_page.pageIndex = PageTurn.currentRightPage - 1
	turning_page_left.pageIndex = PageTurn.currentLeftTurningPage - 1
	turning_page_right.pageIndex = PageTurn.currentRightTurningPage - 1
	
	#Set section indeces
	left_page.section_index = PageTurn.left_page_section_index
	right_page.section_index = PageTurn.right_page_section_index
	turning_page_left.section_index = PageTurn.right_page_section_index if PageTurn.turning_page_leftSectionSide else PageTurn.left_page_section_index
	turning_page_right.section_index = PageTurn.right_page_section_index if PageTurn.turning_page_rightSectionSide else PageTurn.left_page_section_index
	
	#Calculate the screen aspect ratio, as well as the book 
	#to limit size based on width or height
	var aspect_ratio = float(util_Preloader.scrapbookData[PageTurn.left_page_section_index]["maxOutputWidth"]) / float(util_Preloader.scrapbookData[PageTurn.left_page_section_index]["maxOutputHeight"])
	if(aspect_ratio * 2 < get_viewport().get_visible_rect().size.x / get_viewport().get_visible_rect().size.y):
		left_page.pageSize = Vector2(get_viewport().get_visible_rect().size.y * aspect_ratio - border_size * 2, get_viewport().get_visible_rect().size.y - border_size * 2 / aspect_ratio)
		right_page.pageSize = Vector2(get_viewport().get_visible_rect().size.y * aspect_ratio - border_size * 2, get_viewport().get_visible_rect().size.y - border_size * 2 / aspect_ratio)
	else:
		left_page.pageSize = Vector2(get_viewport().get_visible_rect().size.x / 2.0 - border_size * 2, get_viewport().get_visible_rect().size.x / aspect_ratio / 2.0 - border_size * 2 / aspect_ratio)
		right_page.pageSize = Vector2(get_viewport().get_visible_rect().size.x / 2.0 - border_size * 2, get_viewport().get_visible_rect().size.x / aspect_ratio / 2.0 - border_size * 2 / aspect_ratio)
	
	#Set page sizes, scaled up slightly in order to be run through a shader to give a curve to the pages 
	#as well as animating the page turning
	left_page_texture.size = left_page.pageSize
	right_page_texture.size = right_page.pageSize
	left_page_texture.size.y *= 1.2
	right_page_texture.size.y *= 1.2
	left_page.size = left_page.pageSize
	right_page.size = right_page.pageSize
	left_page.size.y *= 1.2
	right_page.size.y *= 1.2
	#Position of the page on screen
	left_page_texture.position = Vector2(get_viewport().get_visible_rect().size.x / 2.0 - left_page.pageSize.x, get_viewport().get_visible_rect().size.y / 2.0 - left_page.pageSize.y / 2.0)
	right_page_texture.position = Vector2(get_viewport().get_visible_rect().size.x / 2.0 - left_page.pageSize.x, get_viewport().get_visible_rect().size.y / 2.0 - left_page.pageSize.y / 2.0)
	right_page_texture.position.x += left_page.pageSize.x - 1 
		#Subtract 1 to stop an occasional single pixel showing up between the pages
		#Depending on page size
	
	left_page_texture.position.y /= 2
	right_page_texture.position.y /= 2
	
	turning_page_left.pageSize = left_page.pageSize
	turning_page_left.size = left_page.size
	turning_page_right.pageSize = right_page.pageSize
	turning_page_right.size = right_page.size
	
	turning_page_left_texture.size = left_page_texture.size
	turning_page_right_texture.size = right_page_texture.size
	turning_page_left_texture.position = left_page_texture.position - Vector2(0, turning_page_left_texture.size.y / 10)
	turning_page_right_texture.position = right_page_texture.position - Vector2(0, turning_page_left_texture.size.y / 10)
	
	#Set "pos", a special variable for placing the page within the window
	#allowing space for the arc of the page turn animation
	turning_page_left.pos = Vector2(0, turning_page_left_texture.size.y / 10)
	turning_page_right.pos = Vector2(0, turning_page_left_texture.size.y / 10)
	
	#These are lil blocks of color under the pages, used to fill in the gap to better sell the book texture
	$UnderLeftPage.position = Vector2(left_page_texture.position.x, left_page_texture.position.y + left_page.pageSize.y * 0.99)
	$UnderLeftPage.size = Vector2(left_page.pageSize.x, left_page.pageSize.y * 0.05)
	$UnderRightPage.position = Vector2(right_page_texture.position.x, right_page_texture.position.y + right_page.pageSize.y * 0.99)
	$UnderRightPage.size = Vector2(right_page.pageSize.x, right_page.pageSize.y * 0.05)
	
	$UnderLeftPage.visible = !PageTurn.currentLeftPage == -1
	$UnderRightPage.visible = !PageTurn.currentRightPage == -1
	
	#Set the covers slightly bigger than the pages
	$CoverInsideLeft.size.y = left_page.pageSize.y * 1.067 * 1.1
	$CoverInsideLeft.size.x = left_page.pageSize.x * 1.067
	$CoverInsideLeft.position = left_page_texture.position - Vector2(left_page.pageSize.x / 15, left_page.pageSize.y / 60 + $CoverInsideLeft.size.y * 0.0909)
	$CoverInsideRight.size = left_page.pageSize * 1.067
	$CoverInsideRight.position = right_page_texture.position - Vector2(0.0, left_page.pageSize.y / 60.0)
	$CoverOutside.size.y = left_page.pageSize.y * 1.067 * 1.1
	$CoverOutside.size.x = left_page.pageSize.x * 1.067
	$CoverOutside.position = right_page_texture.position - Vector2(0.0, left_page.pageSize.y / 60.0 + $CoverOutside.size.y * 0.0909)
	
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
	if(PageTurn.currentRightPage != -1): 
		emit_signal("add_pages_below", right_page, right_page_texture.position, right_page_texture.size, PageTurn.right_page_section_index, PageTurn.currentRightPage, true)
	if(PageTurn.currentLeftPage != -1):
		emit_signal("add_pages_below", left_page, left_page_texture.position, left_page_texture.size, PageTurn.left_page_section_index, PageTurn.currentLeftPage, false)
	
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
 
func _on_text_box_meta_hover_started(_meta): 
	# When we start hovering on a link, set the cursor to "CROSS" (actually hand)
	cursor_timer = 60
	num_small_mouse_moves = 0
	for node in $ClickablesHolder.get_children():
		node.mouse_default_cursor_shape = Control.CURSOR_CROSS
func _on_text_box_meta_hover_ended(_meta):
	# When we stop hovering, we-
	# do the same thing?
	# Turns out hover ended just doesn't activate when the cursor exits a link
	# But instead every time the cursor moves after entering it.
	cursor_timer = 60
	num_small_mouse_moves = 0
	for node in $ClickablesHolder.get_children():
		node.mouse_default_cursor_shape = Control.CURSOR_CROSS

# So we have to try to set cursor back on our own when it seems like its not hovering a link anymore.
var num_small_mouse_moves = 0 
	# Tracks a bunch of small mouse movements in a row to signal switching the cursor back
func _input(event: InputEvent):
	if(cursor_timer <= 0 && event is InputEventMouseMotion):
		if(event.relative.length_squared() > 5 || num_small_mouse_moves > 5): 
			#If we have moved the mouse enough times, and enough distance, set the cursor back to arrow
			for node in $ClickablesHolder.get_children():
				node.mouse_default_cursor_shape = Control.CURSOR_ARROW
			
			num_small_mouse_moves = 0
		else:
			num_small_mouse_moves += 1
	if(event.is_action_pressed("ui_cancel")): # Escape, quits to menu after double tap
		if(escape_Timer > 0):
			quit_to_menu()
		else:
			escape_Timer = 0.3
	if(event.is_action_pressed("ui_left")): # Left arrow, turn page left
		# Start a page turn left or cancel if page is already turning
		display_info_timer = -1
		if(time < 1 && PageTurn.turningRight):
			time = 0.001
			PageTurn.turningRight = false
		elif(time > 0 && !PageTurn.turningRight):
			time = 0.001 # Setting the time to a very small amount so it will end the page turn next update
		else:
			time = PageTurn.turn_page_left()
			update_pages() # Remember to update all pages
			if(show_tip_on_next_page_turn):
				display_first_page_turn_info() # And display the tip for the first page turn
				show_tip_on_next_page_turn = false
	elif(event.is_action_pressed("ui_right")): # Right arrow, turn page right
		# Much the same but for turning right
		display_info_timer = -1
		if(time < 1 && PageTurn.turningRight):
			time = 0.999
		elif(time > 0 && !PageTurn.turningRight):
			time = 0.999
			PageTurn.turningRight = true
		else:
			time = PageTurn.turn_page_right()
			update_pages()
			if(show_tip_on_next_page_turn):
				display_first_page_turn_info()
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
	# Update timers and apply effects when applicable
	cursor_timer -= 1
	if(escape_Timer > 0.):
		escape_Timer -= delta_time
	if(update_delay_timer > 0.):
		update_delay_timer -= delta_time
		if(update_delay_timer <= 0.):
			update_pages()
	if(display_info_timer > 0):
		display_info_timer -= delta_time
		if(display_info_timer <= 0):
			display_basic_info()
	if((time < 1 || dragging) && PageTurn.turningRight): 
		# In the middle of page turn or user is dragging/swiping the page
		if(!dragging):
			time += delta_time / turn_time # Increment time if page is turning automatically
			
		 # Set shader parameters to update visual effect
		if(PageTurn.openingBook):
			$CoverOutside.material.set("shader_parameter/time", time)
			$CoverInsideLeft.material.set("shader_parameter/time", time)
		else:
			$TurningPageLeftTexture.material.set("shader_parameter/time", time)
			$TurningPageRightTexture.material.set("shader_parameter/time", time)
		if(time >= 1): # Page has finished turning, we need to update the pages again
			time = 1
			PageTurn.finish_turn_right()
			update_pages()
			save_page()
			if(dragging):
				done_dragging = true
	elif((time > 0 || dragging) && !PageTurn.turningRight):
		if(!dragging):
			time -= delta_time / turn_time
		if(PageTurn.openingBook):
			$CoverOutside.material.set("shader_parameter/time", time)
			$CoverInsideLeft.material.set("shader_parameter/time", time)
		else:
			$TurningPageLeftTexture.material.set("shader_parameter/time", time)
			$TurningPageRightTexture.material.set("shader_parameter/time", time)
		if(time <= 0):
			time = 0
			PageTurn.finish_turn_left()
			update_pages()
			save_page()
			if(dragging):
				done_dragging = true
	else:
		time = round(time) #Make sure time hasn't gotten too far outside its expected range

func display_basic_info():
	if(OS.has_feature("mobile") || OS.has_feature("web_android") || OS.has_feature("web_ios")):
		$Info.display_text("Swipe left or right to turn page", 4.)
	else:
		$Info.display_text("Press left or right arrow keys to turn page", 4.)

func display_first_page_turn_info():
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
		"currentLeftPage": PageTurn.currentLeftPage,
		"currentRightPage": PageTurn.currentRightPage,
		"bookOpen": PageTurn.bookOpen,
		"is_zip": is_zip
		}
	var json_string = JSON.stringify(savedata)
	savefile.store_line(json_string)
func save_menu(): # Save that the user has returned to the menu
	var savefile = FileAccess.open("user://save", FileAccess.WRITE)
	savefile.store_line("MENU")


var page_scene = preload("res://scenes/page.tscn") # Preload the page scene to be used by _on_add_pages_below

func _on_add_pages_below(page, position, size, section_index, page_number, increasing, depth = -2) -> void:
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
	newPage.pageSize = page.pageSize
	newPage.size = page.size
	newPage.pos = page.pos
	newPage.pageName = "Page "+ str(newPageNumber - 1)
	newPage.pageIndex = newPageNumber - 1
	newPage.section_index = newSectionIndex
	newPage.pageType = util_Enums.pageType.UNDER
	newPage.path = book_path + "/" + sections_list[newSectionIndex] + "/"
	
	page_update.connect(newPage._on_book_page_update) # Make sure it knows to update itself
	pages_under.add_child(newPage) # Add to scene
	
	# We need a texture too to display the subviewport with the proper shader
	var newPageTexture = TextureRect.new()
	newPageTexture.texture = newPage.get_texture()
	newPageTexture.position = position
	newPageTexture.size = size
	newPageTexture.z_index = depth
	newPageTexture.stretch_mode = TextureRect.STRETCH_KEEP
	newPageTexture.material = ShaderMaterial.new()
	if(increasing): # Use the proper left / right page shader
		newPageTexture.material.shader = load("shaders/page_shader.tres")
	else:
		newPageTexture.material.shader = load("shaders/left_page_shader.tres")
	pages_under.add_child(newPageTexture)
	if(depth > -12): # Break eventually to prevent massive lag spikes for lots of layers of transparency
		_on_add_pages_below(newPage, position, size, newSectionIndex, newPageNumber, increasing, depth - 2)
	elif(!newPage.hasBackground): # Set invisible if there's a background
		if(increasing):
			$UnderRightPage.visible = false
		else:
			$UnderLeftPage.visible = false

func _on_go_to_section(section, page) -> void: #Turns page to a specific page
	var section_index = get_section_index_from_name(section)
	if(section_index > PageTurn.right_page_section_index || # If the section we're turning to is after the current one
	(section_index == PageTurn.right_page_section_index && 
		page > PageTurn.currentRightPage)): # Or the're the same and the page is later on
		time = PageTurn.turn_right_to_section(section, page) # Turn right
	else:
		time = PageTurn.turn_left_to_section(section, page)
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
	var newa = a.replace(" ", "").replace("\n", "").replace("\r", "").replace("\t", "").to_lower()
	var newb = b.replace(" ", "").replace("\n", "").replace("\r", "").replace("\t", "").to_lower()
	if(newa.length() > 0 && newa[0] == "/"):
		newa = newa.substr(1, newa.length())
	if(newb.length() > 0 && newb[0] == "/"):
		newb = newb.substr(1, newb.length())
	return newa == newb

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		util_ClearTemp.clear_temp() # Clear temporary storage before exiting
		get_tree().quit()

# You'd think Godot would handle click-drag and swipe actions automatically
# Turns out it kiinda does, but it's quite janky

# Swipe Detector is a screen size scrolling box, with a giant, invisible block inside.
# Dragging will scroll the box, which we can detect

func _on_swipe_detecter_scroll_ended(movement = 0) -> void:
	dragging = false


func _on_swipe_detecter_next_section() -> void: 
	#Detect double click and turn to next / previous section
	if(time < 1 && PageTurn.turningRight):
		time = 0.999 #Or finish turning page if already turning
	elif(time > 0 && !PageTurn.turningRight):
		time = 0.999
		PageTurn.turningRight = true
	else:
		time = PageTurn.turn_page_right()
		update_pages()
	PageTurn.turn_to_next_section()
	update_pages()


func _on_swipe_detecter_previous_section() -> void:
	if(time < 1 && PageTurn.turningRight):
		time = 0.001
		PageTurn.turningRight = false
	elif(time > 0 && !PageTurn.turningRight):
		time = 0.001
	else:
		time = PageTurn.turn_page_left()
		update_pages()
	PageTurn.turn_to_section_start()
	update_pages()


func _on_swipe_detecter_scrolling(movement) -> void:
	# If we are dragging
	# There are a bunch of failsafes to make sure we don't do something silly and break the program
	if(time > 0 && time < 1): # Enable dragging immediately if we are mid page turn
		dragging = true
	if(done_dragging): 
		# done_dragging is a way of telling the program to stop dragging even if the user hasn't let go
		# if a page finishes turning, for example
		return
	movement = -movement
	if(movement > 0.01 && (!dragging || PageTurn.turningRight) || (dragging && PageTurn.turningRight)):
		# If we've moved a bit to the left (turning page right) and aren't dragging yet, 
		# or if we are already turning right
		if(!dragging && movement >= 0.05):
			# But havent immediately dragged too much because that's probably an error
			return
		if(!dragging): 
			PageTurn.turn_page_right()
			PageTurn.turningRight = true
			update_pages() # Initiate page turn and update
			dragging = true
		time = clamp(movement, 0.001, 0.999)
	elif(movement < -0.01 && (!dragging || !PageTurn.turningRight) || (dragging && !PageTurn.turningRight)):
		# Turning left is about the same
		if(!dragging && movement <= -0.05):
			return
		if(!dragging):
			PageTurn.turn_page_left()
			PageTurn.turningRight = false
			update_pages()
			dragging = true
		time = clamp(1 + movement, 0.001, 0.999)


func _on_swipe_detecter_released() -> void: # When releasing click
	if(time > 0.6): # Set pageturn if page hasn't been dragged enough
		PageTurn.turningRight = true
	elif(time < 0.4):
		PageTurn.turningRight = false
	dragging = false
	done_dragging = false # Reset done dragging so we can initiate a new drag next time
