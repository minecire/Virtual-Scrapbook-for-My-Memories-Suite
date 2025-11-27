extends Node

# The page turning process has gotten pretty complicated
# With the animations, the covers, and skipping to sections / pages
# So it got separated out from book.gd to this file.

var CoverInsideLeft # These are the covers that turn when the book is opened
var CoverOutside

var turningRight: bool = true
var openingBook: bool = false
var hasCover: bool = false

var currentLeftPage: int = -1
var currentRightPage: int = 1
var currentLeftTurningPage: int = -1
var currentRightTurningPage: int = -1

var turning_page_left_section_side: bool
var turning_page_right_section_side: bool

var left_page_section_index = 0
var right_page_section_index = 0

var bookOpen: bool = false

func reset_values():
	left_page_section_index = 0
	right_page_section_index = 0
	currentLeftPage = -1
	currentRightPage = 1
	currentLeftTurningPage = -1
	currentRightTurningPage = -1

func turn_page_right():
	var time = 1
	if(!bookOpen):
		CoverInsideLeft.visible = true
		openingBook = true
		time = 0
		turningRight = true
		return time
	if(currentRightPage == -1):
		return time
	if(currentRightPage == util_Preloader.scrapbookData[right_page_section_index]["num_pages"] && right_page_section_index == util_Preloader.sectionsList.size() - 1):
		return time
	currentLeftTurningPage = currentRightPage + 1
	currentRightTurningPage = currentRightPage
	currentRightPage = currentRightPage + 2
	if(currentRightPage > util_Preloader.scrapbookData[right_page_section_index]["num_pages"]):
		if(util_Preloader.sectionsList.size() > right_page_section_index + 1):
			turning_page_right_section_side = false
			turning_page_left_section_side = false
			right_page_section_index+=1
			if(currentRightPage == util_Preloader.scrapbookData[left_page_section_index]["num_pages"] + 2):
				currentRightPage = 2
				currentLeftTurningPage = 1
				turning_page_left_section_side = true
			else:
				currentRightPage = 1
		else:
			currentRightPage = -1
	else:
		turning_page_right_section_side = true
		turning_page_left_section_side = true
	time = 0
	turningRight = true
	return time

func turn_page_left():
	var time = 0
	if(currentLeftPage <= 1 && left_page_section_index == 0):
		if(bookOpen && hasCover):
			CoverOutside.visible = true
			openingBook = true
			time = 1
			turningRight = false
		return time
	currentLeftTurningPage = currentLeftPage
	currentRightTurningPage = currentLeftPage - 1
	currentLeftPage = currentLeftPage - 2
	if(currentLeftPage < 1):
		if(left_page_section_index > 0):
			turning_page_left_section_side = true
			left_page_section_index-=1
			if(currentLeftPage == -1):
				currentLeftPage = util_Preloader.scrapbookData[left_page_section_index]["num_pages"]- 1
				turning_page_right_section_side = false
				currentRightTurningPage = currentLeftPage + 1
			else:
				currentLeftPage = util_Preloader.scrapbookData[left_page_section_index]["num_pages"]
				turning_page_right_section_side = true
		else:
			currentLeftPage = -1
	else:
		turning_page_right_section_side = false
		turning_page_left_section_side = false
	turningRight = false
	time = 1
	return time
func turn_to_section_start():
	if(openingBook):
		return 1
	if(currentLeftPage == 1 || currentRightTurningPage == 1):
		return
	currentRightTurningPage = 2 if currentLeftPage % 2 == 1 else 1
	if(left_page_section_index < right_page_section_index):
		right_page_section_index -= 1
	turning_page_left_section_side = true
	turning_page_right_section_side = true
	if(currentLeftPage % 2 == 1):
		currentLeftPage = 1
	else:
		if(left_page_section_index > 0):
			left_page_section_index-=1
			currentLeftPage = util_Preloader.scrapbookData[left_page_section_index]["num_pages"]
		else:
			currentLeftPage = -1

func turn_to_next_section():
	if(openingBook):
		return 0
	if(currentLeftTurningPage == 1 || currentRightPage == 1):
		return
	
	if(right_page_section_index != left_page_section_index):
		left_page_section_index += 1
	if(right_page_section_index < util_Preloader.sectionsList.size() - 1):
		turning_page_right_section_side = false
		right_page_section_index+=1
		if((currentRightPage % 2) == (util_Preloader.scrapbookData[left_page_section_index]["num_pages"] % 2)):
			currentRightPage = 2
			turning_page_left_section_side = true
			currentLeftTurningPage = 1
		else:
			currentRightPage = 1
			turning_page_left_section_side = false
			currentLeftTurningPage = util_Preloader.scrapbookData[left_page_section_index]["num_pages"]
	else:
		if(currentRightPage % 2 == util_Preloader.scrapbookData[right_page_section_index]["num_pages"] % 2):
			currentLeftTurningPage = util_Preloader.scrapbookData[right_page_section_index]["num_pages"] - 1
			currentRightPage = util_Preloader.scrapbookData[right_page_section_index]["num_pages"]
		else:
			currentLeftTurningPage = util_Preloader.scrapbookData[right_page_section_index]["num_pages"]
			currentRightPage = -1

func turn_to_start_of_book():
	if(openingBook):
		return 1
	while(right_page_section_index > 0 || currentLeftPage > 1):
		turn_page_left()
		currentRightTurningPage = 2 if currentLeftPage % 2 == 1 else 1
		if(left_page_section_index < right_page_section_index):
			right_page_section_index -= 1
		turning_page_left_section_side = true
		turning_page_right_section_side = true
		if(currentLeftPage % 2 == 1):
			currentLeftPage = 1
		else:
			if(left_page_section_index > 0):
				left_page_section_index-=1
				currentLeftPage = util_Preloader.scrapbookData[right_page_section_index]["num_pages"]
			else:
				currentLeftPage = -1

func turn_to_end_of_book():
	if(openingBook):
		return 0
	var time
	while((right_page_section_index < util_Preloader.sectionsList.size() - 1 || currentRightPage < util_Preloader.scrapbookData[right_page_section_index]["num_pages"] - 1 || currentLeftTurningPage < util_Preloader.scrapbookData[right_page_section_index]["num_pages"] - 2) && currentRightPage != -1):
		time = turn_page_right()
		if(!(right_page_section_index < util_Preloader.sectionsList.size() - 1 || currentRightPage < util_Preloader.scrapbookData[right_page_section_index]["num_pages"] - 1 || currentLeftTurningPage < util_Preloader.scrapbookData[right_page_section_index]["num_pages"] - 2) && currentRightPage != -1):
			return time
		if(right_page_section_index != left_page_section_index):
			left_page_section_index += 1
		if(right_page_section_index < util_Preloader.sectionsList.size() - 1):
			turning_page_right_section_side = false
			right_page_section_index+=1
			if((currentRightPage % 2) == (util_Preloader.scrapbookData[left_page_section_index]["num_pages"] % 2)):
				currentRightPage = 2
				turning_page_left_section_side = true
				currentLeftTurningPage = 1
			else:
				currentRightPage = 1
				turning_page_left_section_side = false
				currentLeftTurningPage = util_Preloader.scrapbookData[left_page_section_index]["num_pages"]
		else:
			if(currentRightPage % 2 == util_Preloader.scrapbookData[right_page_section_index]["num_pages"] % 2):
				currentLeftTurningPage = util_Preloader.scrapbookData[right_page_section_index]["num_pages"] - 1
				currentRightPage = util_Preloader.scrapbookData[right_page_section_index]["num_pages"]
			else:
				currentLeftTurningPage = util_Preloader.scrapbookData[right_page_section_index]["num_pages"]
				currentRightPage = -1
	return time

func turn_left_to_section(section, page):
	var time = 0
	while(!check_nowhitespace(util_Preloader.sectionsList[right_page_section_index], section) && right_page_section_index > 0):
		time = turn_page_left()
		currentRightTurningPage = 2 if currentLeftPage % 2 == 1 else 1
		if(left_page_section_index < right_page_section_index):
			right_page_section_index -= 1
		turning_page_left_section_side = true
		turning_page_right_section_side = true
		if(currentLeftPage % 2 == 1):
			currentLeftPage = 1
		else:
			if(left_page_section_index > 0):
				left_page_section_index-=1
				currentLeftPage = util_Preloader.scrapbookData[left_page_section_index]["num_pages"]
			else:
				currentLeftPage = -1
	if(page > 1):
		left_page_section_index = right_page_section_index
	if(currentLeftPage % 2 == page % 2):
		currentLeftPage = page
		if(page < util_Preloader.scrapbookData[left_page_section_index]["num_pages"]):
			currentRightTurningPage = page + 1
		else:
			currentRightTurningPage = 1
			right_page_section_index += 1
	elif(page > 1):
		currentLeftPage = page - 1
		currentRightTurningPage = page
		
	return time

func turn_right_to_section(section, page):
	var time = 1
	while(!check_nowhitespace(util_Preloader.sectionsList[right_page_section_index], section) && right_page_section_index < util_Preloader.sectionsList.size() - 1):
		time = turn_page_right()
		if(check_nowhitespace(util_Preloader.sectionsList[right_page_section_index], section) || right_page_section_index >= util_Preloader.sectionsList.size() - 1):
			break
		if(right_page_section_index != left_page_section_index):
			left_page_section_index += 1
		if(right_page_section_index < util_Preloader.sectionsList.size() - 1):
			turning_page_right_section_side = false
			right_page_section_index+=1
			if((currentRightPage % 2) == (util_Preloader.scrapbookData[left_page_section_index]["num_pages"] % 2)):
				currentRightPage = 2
				turning_page_left_section_side = true
				currentLeftTurningPage = 1
			else:
				currentRightPage = 1
				turning_page_left_section_side = false
				currentLeftTurningPage = util_Preloader.scrapbookData[left_page_section_index]["num_pages"]
		else:
			if(currentRightPage % 2 == util_Preloader.scrapbookData[right_page_section_index]["num_pages"] % 2):
				currentLeftTurningPage = util_Preloader.scrapbookData[right_page_section_index]["num_pages"] - 1
				currentRightPage = util_Preloader.scrapbookData[right_page_section_index]["num_pages"]
			else:
				currentLeftTurningPage = util_Preloader.scrapbookData[right_page_section_index]["num_pages"]
				currentRightPage = -1
	if(page > 1):
		left_page_section_index = right_page_section_index
	if(currentRightPage % 2 == page % 2):
		currentRightPage = page
		if(page != 1):
			currentLeftTurningPage = page - 1
	elif(page < util_Preloader.scrapbookData[right_page_section_index]["num_pages"]):
		currentRightPage = page + 1
		currentLeftTurningPage = page
	else:
		right_page_section_index += 1
		currentRightPage = 1
		currentLeftTurningPage = page
	return time


func check_nowhitespace(a, b):
	var newa = a.replace(" ", "").replace("\n", "").replace("\r", "").replace("\t", "").to_lower()
	var newb = b.replace(" ", "").replace("\n", "").replace("\r", "").replace("\t", "").to_lower()
	if(newa.length() > 0 && newa[0] == "/"):
		newa = newa.substr(1, newa.length())
	if(newb.length() > 0 && newb[0] == "/"):
		newb = newb.substr(1, newb.length())
	return newa == newb

func finish_turn_right():
	if(openingBook):
		bookOpen = true
		CoverOutside.visible = false
		openingBook = false
		return
	currentLeftPage = currentLeftTurningPage
	if(turning_page_left_section_side == true):
		left_page_section_index = right_page_section_index
	currentLeftTurningPage = -1
	currentRightTurningPage = -1
	return

func finish_turn_left():
	if(openingBook):
		bookOpen = false
		CoverInsideLeft.visible = false
		openingBook = false
		return
	currentRightPage = currentRightTurningPage
	if(turning_page_right_section_side == false):
		right_page_section_index = left_page_section_index
	currentLeftTurningPage = -1
	currentRightTurningPage = -1
