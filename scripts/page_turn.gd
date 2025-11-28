extends Node

# The page turning process has gotten pretty complicated
# With the animations, the covers, and skipping to sections / pages
# So it got separated out from book.gd to this file.

var cover_inside_left # These are the covers that turn when the book is opened
var cover_outside

var turning_right: bool = true # Whether we are turning to the right or left
var opening_book: bool = false # Whether we are opening/closing the cover rather than a page
var has_cover: bool = false # Whether this scrapbook has a cover


var current_left_page: int = -1
var current_right_page: int = 1
var current_left_turning_page: int = -1
var current_right_turning_page: int = -1

# Whether the turning pages are in the same section as the left or right page
# Note: Sometimes they are neither, such as when a section is only a single page
# or flipping between sections. This glitches the program a little, 
# and might be worth reworking at some point.
var turning_page_left_section_side: bool
var turning_page_right_section_side: bool

var left_page_section_index = 0
var right_page_section_index = 0

var book_is_open: bool = false # Whether the cover is open or closed

func reset_values(): # Set everything back to its default: section zero, page one
	left_page_section_index = 0
	right_page_section_index = 0
	current_left_page = -1
	current_right_page = 1
	current_left_turning_page = -1
	current_right_turning_page = -1

func turn_page_right():
	var time = 1
	if(!book_is_open):
		cover_inside_left.visible = true
		opening_book = true
		time = 0
		turning_right = true
		return time
	if(current_right_page == -1):
		return time
	if(current_right_page == util_Preloader.scrapbookData[right_page_section_index]["num_pages"] && right_page_section_index == util_Preloader.sectionsList.size() - 1):
		return time
	current_left_turning_page = current_right_page + 1
	current_right_turning_page = current_right_page
	current_right_page = current_right_page + 2
	if(current_right_page > util_Preloader.scrapbookData[right_page_section_index]["num_pages"]):
		if(util_Preloader.sectionsList.size() > right_page_section_index + 1):
			turning_page_right_section_side = false
			turning_page_left_section_side = false
			right_page_section_index+=1
			if(current_right_page == util_Preloader.scrapbookData[left_page_section_index]["num_pages"] + 2):
				current_right_page = 2
				current_left_turning_page = 1
				turning_page_left_section_side = true
			else:
				current_right_page = 1
		else:
			current_right_page = -1
	else:
		turning_page_right_section_side = true
		turning_page_left_section_side = true
	time = 0
	turning_right = true
	return time

func turn_page_left():
	var time = 0
	if(current_left_page <= 1 && left_page_section_index == 0):
		if(book_is_open && has_cover):
			cover_outside.visible = true
			opening_book = true
			time = 1
			turning_right = false
		return time
	current_left_turning_page = current_left_page
	current_right_turning_page = current_left_page - 1
	current_left_page = current_left_page - 2
	if(current_left_page < 1):
		if(left_page_section_index > 0):
			turning_page_left_section_side = true
			left_page_section_index-=1
			if(current_left_page == -1):
				current_left_page = util_Preloader.scrapbookData[left_page_section_index]["num_pages"]- 1
				turning_page_right_section_side = false
				current_right_turning_page = current_left_page + 1
			else:
				current_left_page = util_Preloader.scrapbookData[left_page_section_index]["num_pages"]
				turning_page_right_section_side = true
		else:
			current_left_page = -1
	else:
		turning_page_right_section_side = false
		turning_page_left_section_side = false
	turning_right = false
	time = 1
	return time
func turn_to_section_start():
	if(opening_book):
		return 1
	if(current_left_page == 1 || current_right_turning_page == 1):
		return
	current_right_turning_page = 2 if current_left_page % 2 == 1 else 1
	if(left_page_section_index < right_page_section_index):
		right_page_section_index -= 1
	turning_page_left_section_side = true
	turning_page_right_section_side = true
	if(current_left_page % 2 == 1):
		current_left_page = 1
	else:
		if(left_page_section_index > 0):
			left_page_section_index-=1
			current_left_page = util_Preloader.scrapbookData[left_page_section_index]["num_pages"]
		else:
			current_left_page = -1

func turn_to_next_section():
	if(opening_book):
		return 0
	if(current_left_turning_page == 1 || current_right_page == 1):
		return
	
	if(right_page_section_index != left_page_section_index):
		left_page_section_index += 1
	if(right_page_section_index < util_Preloader.sectionsList.size() - 1):
		turning_page_right_section_side = false
		right_page_section_index+=1
		if((current_right_page % 2) == (util_Preloader.scrapbookData[left_page_section_index]["num_pages"] % 2)):
			current_right_page = 2
			turning_page_left_section_side = true
			current_left_turning_page = 1
		else:
			current_right_page = 1
			turning_page_left_section_side = false
			current_left_turning_page = util_Preloader.scrapbookData[left_page_section_index]["num_pages"]
	else:
		if(current_right_page % 2 == util_Preloader.scrapbookData[right_page_section_index]["num_pages"] % 2):
			current_left_turning_page = util_Preloader.scrapbookData[right_page_section_index]["num_pages"] - 1
			current_right_page = util_Preloader.scrapbookData[right_page_section_index]["num_pages"]
		else:
			current_left_turning_page = util_Preloader.scrapbookData[right_page_section_index]["num_pages"]
			current_right_page = -1

func turn_to_start_of_book():
	if(opening_book):
		return 1
	while(right_page_section_index > 0 || current_left_page > 1):
		turn_page_left()
		current_right_turning_page = 2 if current_left_page % 2 == 1 else 1
		if(left_page_section_index < right_page_section_index):
			right_page_section_index -= 1
		turning_page_left_section_side = true
		turning_page_right_section_side = true
		if(current_left_page % 2 == 1):
			current_left_page = 1
		else:
			if(left_page_section_index > 0):
				left_page_section_index-=1
				current_left_page = util_Preloader.scrapbookData[right_page_section_index]["num_pages"]
			else:
				current_left_page = -1

func turn_to_end_of_book():
	if(opening_book):
		return 0
	var time
	while((right_page_section_index < util_Preloader.sectionsList.size() - 1 || current_right_page < util_Preloader.scrapbookData[right_page_section_index]["num_pages"] - 1 || current_left_turning_page < util_Preloader.scrapbookData[right_page_section_index]["num_pages"] - 2) && current_right_page != -1):
		time = turn_page_right()
		if(!(right_page_section_index < util_Preloader.sectionsList.size() - 1 || current_right_page < util_Preloader.scrapbookData[right_page_section_index]["num_pages"] - 1 || current_left_turning_page < util_Preloader.scrapbookData[right_page_section_index]["num_pages"] - 2) && current_right_page != -1):
			return time
		if(right_page_section_index != left_page_section_index):
			left_page_section_index += 1
		if(right_page_section_index < util_Preloader.sectionsList.size() - 1):
			turning_page_right_section_side = false
			right_page_section_index+=1
			if((current_right_page % 2) == (util_Preloader.scrapbookData[left_page_section_index]["num_pages"] % 2)):
				current_right_page = 2
				turning_page_left_section_side = true
				current_left_turning_page = 1
			else:
				current_right_page = 1
				turning_page_left_section_side = false
				current_left_turning_page = util_Preloader.scrapbookData[left_page_section_index]["num_pages"]
		else:
			if(current_right_page % 2 == util_Preloader.scrapbookData[right_page_section_index]["num_pages"] % 2):
				current_left_turning_page = util_Preloader.scrapbookData[right_page_section_index]["num_pages"] - 1
				current_right_page = util_Preloader.scrapbookData[right_page_section_index]["num_pages"]
			else:
				current_left_turning_page = util_Preloader.scrapbookData[right_page_section_index]["num_pages"]
				current_right_page = -1
	return time

func turn_left_to_section(section, page):
	var time = 0
	while(!check_nowhitespace(util_Preloader.sectionsList[right_page_section_index], section) && right_page_section_index > 0):
		time = turn_page_left()
		current_right_turning_page = 2 if current_left_page % 2 == 1 else 1
		if(left_page_section_index < right_page_section_index):
			right_page_section_index -= 1
		turning_page_left_section_side = true
		turning_page_right_section_side = true
		if(current_left_page % 2 == 1):
			current_left_page = 1
		else:
			if(left_page_section_index > 0):
				left_page_section_index-=1
				current_left_page = util_Preloader.scrapbookData[left_page_section_index]["num_pages"]
			else:
				current_left_page = -1
	if(page > 1):
		left_page_section_index = right_page_section_index
	if(current_left_page % 2 == page % 2):
		current_left_page = page
		if(page < util_Preloader.scrapbookData[left_page_section_index]["num_pages"]):
			current_right_turning_page = page + 1
		else:
			current_right_turning_page = 1
			right_page_section_index += 1
	elif(page > 1):
		current_left_page = page - 1
		current_right_turning_page = page
		
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
			if((current_right_page % 2) == (util_Preloader.scrapbookData[left_page_section_index]["num_pages"] % 2)):
				current_right_page = 2
				turning_page_left_section_side = true
				current_left_turning_page = 1
			else:
				current_right_page = 1
				turning_page_left_section_side = false
				current_left_turning_page = util_Preloader.scrapbookData[left_page_section_index]["num_pages"]
		else:
			if(current_right_page % 2 == util_Preloader.scrapbookData[right_page_section_index]["num_pages"] % 2):
				current_left_turning_page = util_Preloader.scrapbookData[right_page_section_index]["num_pages"] - 1
				current_right_page = util_Preloader.scrapbookData[right_page_section_index]["num_pages"]
			else:
				current_left_turning_page = util_Preloader.scrapbookData[right_page_section_index]["num_pages"]
				current_right_page = -1
	if(page > 1):
		left_page_section_index = right_page_section_index
	if(current_right_page % 2 == page % 2):
		current_right_page = page
		if(page != 1):
			current_left_turning_page = page - 1
	elif(page < util_Preloader.scrapbookData[right_page_section_index]["num_pages"]):
		current_right_page = page + 1
		current_left_turning_page = page
	else:
		right_page_section_index += 1
		current_right_page = 1
		current_left_turning_page = page
	return time


func check_nowhitespace(a, b):
	var new_a = a.replace(" ", "").replace("\n", "").replace("\r", "").replace("\t", "").to_lower()
	var new_b = b.replace(" ", "").replace("\n", "").replace("\r", "").replace("\t", "").to_lower()
	if(new_a.length() > 0 && new_a[0] == "/"):
		new_a = new_a.substr(1, new_a.length())
	if(new_b.length() > 0 && new_b[0] == "/"):
		new_b = new_b.substr(1, new_b.length())
	return new_a == new_b

func finish_turn_right():
	if(opening_book):
		book_is_open = true
		cover_outside.visible = false
		opening_book = false
		return
	current_left_page = current_left_turning_page
	if(turning_page_left_section_side == true):
		left_page_section_index = right_page_section_index
	current_left_turning_page = -1
	current_right_turning_page = -1
	return

func finish_turn_left():
	if(opening_book):
		book_is_open = false
		cover_inside_left.visible = false
		opening_book = false
		return
	current_right_page = current_right_turning_page
	if(turning_page_right_section_side == false):
		right_page_section_index = left_page_section_index
	current_left_turning_page = -1
	current_right_turning_page = -1
