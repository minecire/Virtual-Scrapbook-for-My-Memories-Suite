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
	var time = 1 # Assume we can't turn the page until proven otherwise
	if(!book_is_open): # If the book is closed we gotta open it
		cover_inside_left.visible = true
		opening_book = true
		time = 0
		turning_right = true
		return time
	
	if(current_right_page == -1): # If there's no more pages, do nothing
		return time
	if(current_right_page == util_Preloader.scrapbook_data[right_page_section_index]["num_pages"] && right_page_section_index == util_Preloader.sections_list.size() - 1):
		return time
	
	current_left_turning_page = current_right_page + 1 # This page will become the new left page
	current_right_turning_page = current_right_page # This page was the old right page
	current_right_page = current_right_page + 2 # Set the new right page immediately
	
	time = 0
	turning_right = true
	if(current_right_page <= util_Preloader.scrapbook_data[right_page_section_index]["num_pages"]):
		turning_page_right_section_side = true
		turning_page_left_section_side = true
		return time
	
	if(util_Preloader.sections_list.size() > right_page_section_index):
		current_right_page = -1 # End of book, no more pages
		return time
	
	# If we haven't returned yet we're moving between sections
	turning_page_right_section_side = false
	turning_page_left_section_side = false
	right_page_section_index+=1
	current_right_page = 1
	
	if(current_right_page == util_Preloader.scrapbook_data[left_page_section_index]["num_pages"] + 2):
		# Page boundary is between a left/right page
		current_right_page = 2
		current_left_turning_page = 1
		turning_page_left_section_side = true
	return time

func turn_page_left():
	var time = 0 # Assume we can't turn the page until proven otherwise
	if(current_left_page <= 1 && left_page_section_index == 0): # On the first page
		if(book_is_open && has_cover): # If theres an open cover we can close the book
			cover_outside.visible = true
			opening_book = true
			time = 1
			turning_right = false
		return time
	current_left_turning_page = current_left_page # Left page starts turning
	current_right_turning_page = current_left_page - 1 # Right page loads the next one
	current_left_page = current_left_page - 2 # New left page loaded
	
	turning_right = false
	time = 1
	
	if(current_left_page >= 1):
		turning_page_right_section_side = false
		turning_page_left_section_side = false
		return time
		
	if(left_page_section_index <= 0): # Start of book, no more left pages
		current_left_page = -1
		return time
		
	turning_page_left_section_side = true
	left_page_section_index-=1 # Previous section
	
	if(current_left_page == -1): # Last two pages of previous section
		current_left_page = util_Preloader.scrapbook_data[left_page_section_index]["num_pages"]- 1
		turning_page_right_section_side = false
		current_right_turning_page = current_left_page + 1
	else: # Last page of previous section, first page of current
		current_left_page = util_Preloader.scrapbook_data[left_page_section_index]["num_pages"]
		turning_page_right_section_side = true
		
	return time

func turn_to_section_start():
	if(opening_book):
		return 1
	# Page one of current section
	return turn_left_to_section(util_Preloader.sections_list[left_page_section_index], 1)

func turn_to_next_section():
	if(opening_book):
		return 0
	if(right_page_section_index == util_Preloader.sections_list.size() - 1):
		# End of book if in last section
		return turn_right_to_section(util_Preloader.sections_list[right_page_section_index], 
			util_Preloader.scrapbook_data[right_page_section_index]["num_pages"] - 1)
	# Otherwise page one of next section
	return turn_right_to_section(util_Preloader.sections_list[right_page_section_index + 1], 1)

func turn_to_start_of_book():
	if(opening_book):
		return 1
	# Section zero, page one
	var time = turn_left_to_section(util_Preloader.sections_list[0], 1)
	return time

func turn_to_end_of_book():
	if(opening_book):
		return 0
	var last_section = util_Preloader.sections_list.size() - 1
	var last_page = util_Preloader.scrapbook_data[last_section]["num_pages"]
	return turn_right_to_section(util_Preloader.sections_list[last_section], last_page - 1)

func turn_left_to_section(section, page):
	turning_page_left_section_side = false
	turning_page_right_section_side = false
	
	if(current_left_page == -1): # No further left to turn
		return 0
	
	var time = turn_page_left() # Try to turn left to initialize things properly
	
	
	var section_number = find_section_number(section)
	var total_page_number = page
	
	# Overall page number in the entire scrapbook
	if(section_number > 0):
		for i in range(section_number):
			total_page_number = util_Preloader.scrapbook_data[i]["num_pages"]
	
	# Just to figure out whether the selected page is on the left or right side
	var side = total_page_number % 2 == 0
	
	if(side): # Page is left side
		left_page_section_index = section_number
		current_left_page = page # so set the left page to it
		if(page < util_Preloader.scrapbook_data[section_number]["num_pages"]):
			right_page_section_index = section_number
			# Set turning page instead of page since right page needs to be covered by the turning one
			current_right_turning_page = page + 1
			return time
		
		# In between sections
		if(section_number < util_Preloader.sections_list.size() - 1): 
			# There is a section before this
			current_right_turning_page = 1
			right_page_section_index = section_number + 1
			turning_page_right_section_side = true # Right page will be in a different section to left
			return time
		# Otherwise we are already at or approaching the start of the book
		return time
	
	# Page is right side
	right_page_section_index = section_number
	current_right_turning_page = page # Set right page
	if(page > 1):
		left_page_section_index = section_number
		current_left_page = page - 1
		return time
	# Between sections
	if(section_number > 0): # Set left page to previous section
		current_left_page = util_Preloader.scrapbook_data[section_number - 1]["num_pages"]
		left_page_section_index = section_number - 1
		turning_page_right_section_side = true # Right page will be in a different section to left
		return time
	
	left_page_section_index = section_number
	current_left_page = -1 # Otherwise is beginning of book, no left page
	return time
	

func turn_right_to_section(section, page):
	# Things get slightly swapped around when turning right
	turning_page_left_section_side = true
	turning_page_right_section_side = true
	if(current_right_page == -1): # Already at end of book
		return 1
	
	var time = turn_page_right() # Try to turn right to initialize things properly
	
	
	var section_number = find_section_number(section)
	var total_page_number = page
	for i in range(section_number):
		total_page_number = util_Preloader.scrapbook_data[i]["num_pages"]
	
	var side = total_page_number % 2 == 0 # Get side of book of page from total page number
	
	if(side): # Page is on left side
		left_page_section_index = section_number
		# Set turning page instead of page since left page needs to be covered by the turning one
		current_left_turning_page = page
		if(page < util_Preloader.scrapbook_data[section_number]["num_pages"]):
			right_page_section_index = section_number
			current_right_page = page + 1
			return time
		# In between sections
		if(section_number < util_Preloader.sections_list.size() - 1):
			# Right page goes to next section if there is one
			current_right_page = 1
			right_page_section_index = section_number + 1
			turning_page_left_section_side = false # and left page is with the left section
			return time
		# Otherwise turn to end of the book
		right_page_section_index = section_number
		current_right_page = -1
		return time
	# Page is on right side
	right_page_section_index = section_number
	current_right_page = page
	if(page > 1):
		left_page_section_index = section_number
		current_left_turning_page = page - 1
		return time
	# In between sections
	if(section_number > 0):
		# Set left page to end of previous section
		current_left_turning_page = util_Preloader.scrapbook_data[section_number - 1]["num_pages"]
		left_page_section_index = section_number - 1
		turning_page_left_section_side = false # And left page will be a different section than right
		return time
	# Already at end of book
	return time


func find_section_number(section): # Find index of section in the sections list
	for i in range(util_Preloader.sections_list.size()):
		if(check_nowhitespace(section, util_Preloader.sections_list[i])): # Ignoring whitespace / case
			return i
	return -1

func check_nowhitespace(a, b): 
	# Checks if strings are equal except case and whitespace
	# To help people manually writing section names
	var new_a = a.replace(" ", "").replace("\n", "").replace("\r", "").replace("\t", "").to_lower()
	var new_b = b.replace(" ", "").replace("\n", "").replace("\r", "").replace("\t", "").to_lower()
	if(new_a.length() > 0 && new_a[0] == "/"):
		new_a = new_a.substr(1, new_a.length())
	if(new_b.length() > 0 && new_b[0] == "/"):
		new_b = new_b.substr(1, new_b.length())
	return new_a == new_b

func finish_turn_right(): # Called when a page turn animation finishes
	if(opening_book): # Book is now open, no more outside cover
		book_is_open = true
		cover_outside.visible = false
		opening_book = false
		return
	current_left_page = current_left_turning_page # Animated turning page becomes left page
	if(turning_page_left_section_side == true): # Update section if changed
		left_page_section_index = right_page_section_index
	current_left_turning_page = -1 # Dont need turning pages showing up anymore
	current_right_turning_page = -1
	return

func finish_turn_left(): # Same but to the left
	if(opening_book): # Book is now closed
		book_is_open = false
		cover_inside_left.visible = false
		opening_book = false
		return
	current_right_page = current_right_turning_page
	if(turning_page_right_section_side == false):
		right_page_section_index = left_page_section_index
	current_left_turning_page = -1
	current_right_turning_page = -1
