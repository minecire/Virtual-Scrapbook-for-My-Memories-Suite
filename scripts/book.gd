extends Control

#TODO:
# -better controls for mobile
# -more optimized web images / shaders

@export var bookPath: String
@export var borderSize: int
@export var turnTime: float


var sectionsList: Array[String]

var escapeTimer = 0
var time: float = 1.0

signal page_update
signal add_pages_below
signal get_has_background



var imageScene = preload("res://scenes/pageobjects/image.tscn")

var updateDelayTimer = -1
var swapBuffersTimer = -1
var cursor_timer = 0

var display_info_timer = 5.


var pagesUnder
var leftPage
var leftPageTexture
var rightPage
var rightPageTexture
var turningPageLeft
var turningPageLeftTexture
var turningPageRight
var turningPageRightTexture

var leftPageSection
var rightPageSection

var cantExit = false

var isFirstPageTurn = true

var isZip

func _ready():
	isFirstPageTurn = true
	display_info_timer = 5.
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
	leftPageSection = sectionsList[PageTurn.leftPageSectionIndex]
	rightPageSection = sectionsList[PageTurn.rightPageSectionIndex]
	
	PageTurn.CoverInsideLeft = $CoverInsideLeft
	PageTurn.CoverOutside = $CoverOutside
	util_Preloader.reload_stuff(sectionsList, bookPath, isZip)
	
	if(util_Preloader.imagesDict["coverOutside"] != null):
		$CoverInsideLeft.texture = util_Preloader.imagesDict["coverInsideLeft"]
		$CoverInsideRight.texture = util_Preloader.imagesDict["coverInsideRight"]
		$CoverOutside.texture = util_Preloader.imagesDict["coverOutside"]
		PageTurn.hasCover = true
		if(PageTurn.bookOpen):
			$CoverInsideRight.visible = true
			$CoverInsideLeft.visible = true
			$CoverOutside.visible = false
			$CoverInsideLeft.material.set("shader_parameter/time", 1.0)
		else:
			$CoverOutside.visible = true
			$CoverInsideRight.visible = true
			$CoverInsideLeft.visible = false
	else:
		PageTurn.bookOpen = true
		PageTurn.hasCover = false
		$CoverOutside.visible = false
		$CoverInsideRight.visible = false
		$CoverInsideLeft.visible = false
	
	bookPath = util_Preloader.bookPath
	update_pages()
	get_tree().get_root().size_changed.connect(delayed_page_update)
	save_page()

func delayed_page_update():
	updateDelayTimer = 0.1


func update_pages():
	leftPageSection = sectionsList[PageTurn.leftPageSectionIndex]
	rightPageSection = sectionsList[PageTurn.rightPageSectionIndex]
	
	pagesUnder = $PagesUnder
	leftPage = $LeftPage
	leftPageTexture = $LeftPageTexture
	rightPage = $RightPage
	rightPageTexture = $RightPageTexture
	turningPageLeft = $TurningPageLeft
	turningPageLeftTexture = $TurningPageLeftTexture
	turningPageRight = $TurningPageRight
	turningPageRightTexture = $TurningPageRightTexture
		
	for n in pagesUnder.get_children():
		pagesUnder.remove_child(n)
		n.free() 
	$Background.size = get_viewport().get_visible_rect().size
	if(PageTurn.currentLeftPage == -1):
		leftPageTexture.visible = false
	else:
		leftPageTexture.visible = true
	if(PageTurn.currentRightPage == -1):
		rightPageTexture.visible = false
	else:
		rightPageTexture.visible = true
	if(PageTurn.currentLeftTurningPage == -1):
		turningPageLeftTexture.visible = false
	else:
		turningPageLeftTexture.visible = true
	if(PageTurn.currentRightTurningPage == -1):
		turningPageRightTexture.visible = false
	else:
		turningPageRightTexture.visible = true
	var sectionPathLeft
	var sectionPathRight
	if(leftPageSection != ""):
		sectionPathLeft = bookPath + "\\" +leftPageSection + "\\"
	else:
		sectionPathLeft = bookPath
	if(rightPageSection != ""):
		sectionPathRight = bookPath + "\\" +rightPageSection + "\\"
	else:
		sectionPathRight = bookPath
	leftPage.path = sectionPathLeft
	rightPage.path = sectionPathRight
	
	turningPageLeft.path = sectionPathRight if PageTurn.turningPageLeftSectionSide else sectionPathLeft
	turningPageRight.path = sectionPathRight if PageTurn.turningPageRightSectionSide else sectionPathLeft
	
	leftPage.pageName = "Page " + ("%d") % PageTurn.currentLeftPage
	rightPage.pageName = "Page " + ("%d") % PageTurn.currentRightPage
	turningPageLeft.pageName = "Page " + ("%d") % PageTurn.currentLeftTurningPage
	turningPageRight.pageName = "Page " + ("%d") % PageTurn.currentRightTurningPage
	leftPage.pageIndex = PageTurn.currentLeftPage - 1
	rightPage.pageIndex = PageTurn.currentRightPage - 1
	turningPageLeft.pageIndex = PageTurn.currentLeftTurningPage - 1
	turningPageRight.pageIndex = PageTurn.currentRightTurningPage - 1
	leftPage.sectionIndex = PageTurn.leftPageSectionIndex
	rightPage.sectionIndex = PageTurn.rightPageSectionIndex
	turningPageLeft.sectionIndex = PageTurn.rightPageSectionIndex if PageTurn.turningPageLeftSectionSide else PageTurn.leftPageSectionIndex
	turningPageRight.sectionIndex = PageTurn.rightPageSectionIndex if PageTurn.turningPageRightSectionSide else PageTurn.leftPageSectionIndex
	
	var aspectRatio = float(util_Preloader.scrapbookData[PageTurn.leftPageSectionIndex]["maxOutputWidth"]) / float(util_Preloader.scrapbookData[PageTurn.leftPageSectionIndex]["maxOutputHeight"])
	if(aspectRatio * 2 < get_viewport().get_visible_rect().size.x / get_viewport().get_visible_rect().size.y):
		leftPage.pageSize = Vector2(get_viewport().get_visible_rect().size.y * aspectRatio - borderSize * 2, get_viewport().get_visible_rect().size.y - borderSize * 2 / aspectRatio)
		rightPage.pageSize = Vector2(get_viewport().get_visible_rect().size.y * aspectRatio - borderSize * 2, get_viewport().get_visible_rect().size.y - borderSize * 2 / aspectRatio)
	else:
		leftPage.pageSize = Vector2(get_viewport().get_visible_rect().size.x / 2.0 - borderSize * 2, get_viewport().get_visible_rect().size.x / aspectRatio / 2.0 - borderSize * 2 / aspectRatio)
		rightPage.pageSize = Vector2(get_viewport().get_visible_rect().size.x / 2.0 - borderSize * 2, get_viewport().get_visible_rect().size.x / aspectRatio / 2.0 - borderSize * 2 / aspectRatio)

	leftPageTexture.size = leftPage.pageSize
	rightPageTexture.size = rightPage.pageSize
	leftPageTexture.size.y *= 1.2
	rightPageTexture.size.y *= 1.2
	leftPage.size = leftPage.pageSize
	rightPage.size = rightPage.pageSize
	leftPage.size.y *= 1.2
	rightPage.size.y *= 1.2
	leftPageTexture.position = Vector2(get_viewport().get_visible_rect().size.x / 2.0 - leftPage.pageSize.x, get_viewport().get_visible_rect().size.y / 2.0 - leftPage.pageSize.y / 2.0)
	rightPageTexture.position = Vector2(get_viewport().get_visible_rect().size.x / 2.0 - leftPage.pageSize.x, get_viewport().get_visible_rect().size.y / 2.0 - leftPage.pageSize.y / 2.0)
	rightPageTexture.position.x += leftPage.pageSize.x - 1
	
	
	leftPageTexture.position.y /= 2
	rightPageTexture.position.y /= 2
	
	#$LeftPageContainer.position = leftPageTexture.position
	#$RightPageContainer.position = rightPageTexture.position
	#$LeftPageContainer.size /= 1.2
	#$RightPageContainer.size /= 1.2
	turningPageLeft.pageSize = leftPage.pageSize
	turningPageLeft.size = leftPage.size
	turningPageRight.pageSize = rightPage.pageSize
	turningPageRight.size = rightPage.size
	
	turningPageLeftTexture.size = leftPageTexture.size
	turningPageRightTexture.size = rightPageTexture.size
	turningPageLeftTexture.position = leftPageTexture.position - Vector2(0, turningPageLeftTexture.size.y / 10)
	turningPageRightTexture.position = rightPageTexture.position - Vector2(0, turningPageLeftTexture.size.y / 10)
	
	turningPageLeft.pos = Vector2(0, turningPageLeftTexture.size.y / 10)
	turningPageRight.pos = Vector2(0, turningPageLeftTexture.size.y / 10)
	
	$UnderLeftPage.position = Vector2(leftPageTexture.position.x, leftPageTexture.position.y + leftPage.pageSize.y * 0.99)
	$UnderLeftPage.size = Vector2(leftPage.pageSize.x, leftPage.pageSize.y * 0.05)
	$UnderRightPage.position = Vector2(rightPageTexture.position.x, rightPageTexture.position.y + rightPage.pageSize.y * 0.99)
	$UnderRightPage.size = Vector2(rightPage.pageSize.x, rightPage.pageSize.y * 0.05)
	
	$UnderLeftPage.visible = !PageTurn.currentLeftPage == -1
	$UnderRightPage.visible = !PageTurn.currentRightPage == -1
	
	$CoverInsideLeft.size.y = leftPage.pageSize.y * 1.067 * 1.1
	$CoverInsideLeft.size.x = leftPage.pageSize.x * 1.067
	$CoverInsideLeft.position = leftPageTexture.position - Vector2(leftPage.pageSize.x / 15, leftPage.pageSize.y / 60 + $CoverInsideLeft.size.y * 0.0909)
	$CoverInsideRight.size = leftPage.pageSize * 1.067
	$CoverInsideRight.position = rightPageTexture.position - Vector2(0.0, leftPage.pageSize.y / 60.0)
	$CoverOutside.size.y = leftPage.pageSize.y * 1.067 * 1.1
	$CoverOutside.size.x = leftPage.pageSize.x * 1.067
	$CoverOutside.position = rightPageTexture.position - Vector2(0.0, leftPage.pageSize.y / 60.0 + $CoverOutside.size.y * 0.0909)
	var isi = imageScene.instantiate()
	
	
	
	emit_signal("get_has_background")
	
	if($ClickablesHolder.get_children().size() > 0):
		for node in $ClickablesHolder.get_children():
			$ClickablesHolder.remove_child(node)
			node.queue_free()
	if(PageTurn.currentRightPage != -1):
		emit_signal("add_pages_below", rightPage, rightPageTexture.position, rightPageTexture.size, PageTurn.rightPageSectionIndex, PageTurn.currentRightPage, true)
	if(PageTurn.currentLeftPage != -1):
		emit_signal("add_pages_below", leftPage, leftPageTexture.position, leftPageTexture.size, PageTurn.leftPageSectionIndex, PageTurn.currentLeftPage, false)
	if(OS.has_feature("web")):
		isi.shapes = {}
		isi.shapesarr = []
		isi.gradients = {}
		isi.gradientsarr = []
	emit_signal("page_update")
	
	if($ClickablesHolder.get_children().size() > 0):
		for node in $ClickablesHolder.get_children():
			node.get_node("TextBox").meta_hover_started.connect(_on_text_box_meta_hover_started)
			node.get_node("TextBox").meta_hover_ended.connect(_on_text_box_meta_hover_ended)
	if(OS.has_feature("web")):
		isi.imageMaterialWeb.set("shader_parameter/shape_textures", isi.shapesarr)
		isi.imageMaterialWeb.set("shader_parameter/gradient_textures", isi.gradientsarr)
		isi.imageMatteMaterialWeb.set("shader_parameter/gradient_textures", isi.gradientsarr)
	else:
		if(isi.shapesarr.size() > 30 || isi.gradientsarr.size() > 30):
			isi.shapes = {}
			isi.shapesarr = []
			isi.gradients = {}
			isi.gradientsarr = []
			emit_signal("page_update")
	
		isi.imageMaterial.set("shader_parameter/shape_textures", isi.shapesarr)
		isi.imageMaterial.set("shader_parameter/gradient_textures", isi.gradientsarr)
		isi.imageMatteMaterial.set("shader_parameter/gradient_textures", isi.gradientsarr)
	isi.free()


func quit_to_menu():
	if(cantExit):
		return
	PageTurn.reset_values()
	save_menu()
	util_ClearTemp.clear_temp()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	get_tree().get_root().remove_child(get_tree().get_root().get_node("Book"))

var numSmallMouseMoves = 0
func _input(event: InputEvent):
	if(cursor_timer <= 0 && event is InputEventMouseMotion):
		if(event.relative.length_squared() > 5 || numSmallMouseMoves > 5):
			for node in $ClickablesHolder.get_children():
				node.mouse_default_cursor_shape = Control.CURSOR_ARROW
			
			numSmallMouseMoves = 0
		else:
			numSmallMouseMoves += 1
	if(event.is_action_pressed("ui_cancel")):
		if(escapeTimer > 0):
			quit_to_menu()
		else:
			escapeTimer = 0.3
	if(event.is_action_pressed("ui_left")):
		display_info_timer = -1
		if(time < 1 && PageTurn.turningRight):
			time = 0.001
			PageTurn.turningRight = false
		elif(time > 0 && !PageTurn.turningRight):
			time = 0.001
		else:
			time = PageTurn.turn_page_left()
			update_pages()
			if(isFirstPageTurn):
				display_first_page_turn_info()
				isFirstPageTurn = false
	elif(event.is_action_pressed("ui_right")):
		display_info_timer = -1
		if(time < 1 && PageTurn.turningRight):
			time = 0.999
		elif(time > 0 && !PageTurn.turningRight):
			time = 0.999
			PageTurn.turningRight = true
		else:
			time = PageTurn.turn_page_right()
			update_pages()
			if(isFirstPageTurn):
				display_first_page_turn_info()
				isFirstPageTurn = false
	elif(event.is_action_pressed("reload_pages")):
		util_Preloader.reload_stuff(sectionsList, bookPath, isZip)
		update_pages()
	
	if(event.is_action_pressed("start_of_section")):
		PageTurn.turn_to_section_start()
		update_pages()
	elif(event.is_action_pressed("next_section")):
		PageTurn.turn_to_next_section()
		update_pages()
	if(event.is_action_pressed("start_of_book")):
		PageTurn.turn_to_start_of_book()
		update_pages()
	if(event.is_action_pressed("end_of_book")):
		PageTurn.turn_to_end_of_book()
		update_pages()

func _process(deltaTime):
	cursor_timer -= 1
	if(escapeTimer > 0.):
		escapeTimer -= deltaTime
	if(updateDelayTimer > 0.):
		updateDelayTimer -= deltaTime
		if(updateDelayTimer <= 0.):
			update_pages()
	if(display_info_timer > 0):
		display_info_timer -= deltaTime
		if(display_info_timer <= 0):
			display_basic_info()
	if(time < 1 && PageTurn.turningRight):
		time += deltaTime / turnTime
		if(PageTurn.openingBook):
			$CoverOutside.material.set("shader_parameter/time", time)
			$CoverInsideLeft.material.set("shader_parameter/time", time)
		else:
			$TurningPageLeftTexture.material.set("shader_parameter/time", time)
			$TurningPageRightTexture.material.set("shader_parameter/time", time)
		if(time >= 1):
			time = 1
			PageTurn.finish_turn_right()
			update_pages()
			save_page()
	if(time > 0 && !PageTurn.turningRight):
		time -= deltaTime / turnTime
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
func save_page():
	var savefile = FileAccess.open("user://save", FileAccess.WRITE)
	var savedata = {
		"bookPath": util_Preloader.zipPath if isZip else util_Preloader.bookPath,
		"sectionsList": sectionsList,
		"leftPageSectionIndex": PageTurn.leftPageSectionIndex,
		"rightPageSectionIndex": PageTurn.rightPageSectionIndex,
		"currentLeftPage": PageTurn.currentLeftPage,
		"currentRightPage": PageTurn.currentRightPage,
		"bookOpen": PageTurn.bookOpen,
		"isZip": isZip
		}
	var json_string = JSON.stringify(savedata)
	savefile.store_line(json_string)
func save_menu():
	var savefile = FileAccess.open("user://save", FileAccess.WRITE)
	savefile.store_line("MENU")
func get_text_contents(parser):
	parser.read()
	if(parser.get_node_type() == XMLParser.NODE_TEXT):
		return(parser.get_node_data())
	else:
		push_warning("no text found")
		return ""

var pageScene = preload("res://scenes/page.tscn")

func _on_add_pages_below(page, position, size, sectionIndex, pageNumber, increasing, depth = -2) -> void:
	if(util_Preloader.scrapbookData[sectionIndex]["pages"].size() <= pageNumber - 1):
		return
	if(util_Preloader.scrapbookData[sectionIndex]["pages"][pageNumber - 1]["hasBackground"]):
		return
	var newPageNumber = pageNumber
	var newSectionIndex = sectionIndex
	if(increasing):
		newPageNumber += 2
		if(newPageNumber > util_Preloader.scrapbookData[sectionIndex]["numPages"]):
			if(sectionIndex >= sectionsList.size() - 1):
				$UnderRightPage.visible = false
				return
			else:
				newSectionIndex += 1
				newPageNumber = 2 if newPageNumber % 2 == util_Preloader.scrapbookData[sectionIndex]["numPages"] % 2 else 1
			pass
	else:
		newPageNumber -= 2
		if(newPageNumber <= 0):
			if(sectionIndex <= 0):
				$UnderLeftPage.visible = false
				return
			else:
				newSectionIndex -= 1
				newPageNumber = util_Preloader.scrapbookData[newSectionIndex]["numPages"] if newPageNumber == 0 else util_Preloader.scrapbookData[newSectionIndex]["numPages"] - 1
	
	var newPage = pageScene.instantiate()
	
	newPage.canvasWidth = page.canvasWidth
	newPage.pageSize = page.pageSize
	newPage.size = page.size
	newPage.pos = page.pos
	newPage.pageName = "Page "+ str(newPageNumber - 1)
	newPage.pageIndex = newPageNumber - 1
	newPage.sectionIndex = newSectionIndex
	newPage.pageType = util_Enums.pageType.UNDER
	
	newPage.path = bookPath + "/" + sectionsList[newSectionIndex] + "/"
	
	page_update.connect(newPage._on_book_page_update)
	
	pagesUnder.add_child(newPage)
	var newPageTexture = TextureRect.new()
	newPageTexture.texture = newPage.get_texture()
	newPageTexture.position = position
	newPageTexture.size = size
	newPageTexture.z_index = depth
	newPageTexture.stretch_mode = TextureRect.STRETCH_KEEP
	newPageTexture.material = ShaderMaterial.new()
	if(increasing):
		newPageTexture.material.shader = load("shaders/page_shader.tres")
	else:
		newPageTexture.material.shader = load("shaders/left_page_shader.tres")
	pagesUnder.add_child(newPageTexture)
	if(depth > -12):
		_on_add_pages_below(newPage, position, size, newSectionIndex, newPageNumber, increasing, depth - 2)
	elif(!newPage.hasBackground):
		if(increasing):
			$UnderRightPage.visible = false
		else:
			$UnderLeftPage.visible = false

func _on_go_to_section(section, page) -> void:
	currentSectionToCheck = section
	if(sectionsList.find_custom(check_nowhitespace) > PageTurn.rightPageSectionIndex || (sectionsList.find_custom(check_nowhitespace) == PageTurn.rightPageSectionIndex && page > PageTurn.currentRightPage)):
		time = PageTurn.turn_right_to_section(section, page)
	else:
		time = PageTurn.turn_left_to_section(section, page)
	update_pages()

var currentSectionToCheck = ""
func check_nowhitespace(a):
	var b = currentSectionToCheck
	var newa = a.replace(" ", "").replace("\n", "").replace("\r", "").replace("\t", "").to_lower()
	var newb = b.replace(" ", "").replace("\n", "").replace("\r", "").replace("\t", "").to_lower()
	if(newa.length() > 0 && newa[0] == "/"):
		newa = newa.substr(1, newa.length())
	if(newb.length() > 0 && newb[0] == "/"):
		newb = newb.substr(1, newb.length())
	return newa == newb

func _on_text_box_meta_hover_started(_meta):
	cursor_timer = 60
	numSmallMouseMoves = 0
	for node in $ClickablesHolder.get_children():
		node.mouse_default_cursor_shape = Control.CURSOR_CROSS
	pass
func _on_text_box_meta_hover_ended(_meta):
	cursor_timer = 60
	numSmallMouseMoves = 0
	for node in $ClickablesHolder.get_children():
		node.mouse_default_cursor_shape = Control.CURSOR_CROSS
	pass

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		util_ClearTemp.clear_temp()
		get_tree().quit() # default behavior

func _on_swipe_detecter_scroll_ended(movement = 0) -> void:
	var scrollPos = 500 + movement
	if(scrollPos == 500):
		return
	if(scrollPos > 510):
		display_info_timer = -1
		if(time < 1 && PageTurn.turningRight):
			time = 0.999
		elif(time > 0 && !PageTurn.turningRight):
			time = 0.999
			PageTurn.turningRight = true
		else:
			time = PageTurn.turn_page_right()
			update_pages()
			if(isFirstPageTurn):
				display_first_page_turn_info()
				isFirstPageTurn = false
	elif(scrollPos < 490):
		display_info_timer = -1
		if(time < 1 && PageTurn.turningRight):
			time = 0.001
			PageTurn.turningRight = false
		elif(time > 0 && !PageTurn.turningRight):
			time = 0.001
		else:
			time = PageTurn.turn_page_left()
			update_pages()
			if(isFirstPageTurn):
				display_first_page_turn_info()
				isFirstPageTurn = false
	$SwipeDetecter.set_deferred("scroll_horizontal", 500)


func _on_swipe_detecter_next_section() -> void:
	if(time < 1 && PageTurn.turningRight):
		time = 0.999
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
