extends Node

var CoverInsideLeft
var CoverOutside

var turningRight: bool = true
var openingBook: bool = false
var hasCover: bool = false

var currentLeftPage: int = -1
var currentRightPage: int = 1
var currentLeftTurningPage: int = -1
var currentRightTurningPage: int = -1

var turningPageLeftSectionSide: bool
var turningPageRightSectionSide: bool

var leftPageSectionIndex = 0
var rightPageSectionIndex = 0

var bookOpen: bool

func reset_values():
	leftPageSectionIndex = 0
	rightPageSectionIndex = 0
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
	if(currentRightPage == util_Preloader.scrapbookData[rightPageSectionIndex]["numPages"] && rightPageSectionIndex == util_Preloader.sectionsList.size() - 1):
		return time
	currentLeftTurningPage = currentRightPage + 1
	currentRightTurningPage = currentRightPage
	currentRightPage = currentRightPage + 2
	if(currentRightPage > util_Preloader.scrapbookData[rightPageSectionIndex]["numPages"]):
		if(util_Preloader.sectionsList.size() > rightPageSectionIndex + 1):
			turningPageRightSectionSide = false
			turningPageLeftSectionSide = false
			rightPageSectionIndex+=1
			if(currentRightPage == util_Preloader.scrapbookData[leftPageSectionIndex]["numPages"] + 2):
				currentRightPage = 2
				currentLeftTurningPage = 1
				turningPageLeftSectionSide = true
			else:
				currentRightPage = 1
		else:
			currentRightPage = -1
	else:
		turningPageRightSectionSide = true
		turningPageLeftSectionSide = true
	time = 0
	turningRight = true
	return time

func turn_page_left():
	var time = 0
	if(currentLeftPage <= 1 && leftPageSectionIndex == 0):
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
		if(leftPageSectionIndex > 0):
			turningPageLeftSectionSide = true
			leftPageSectionIndex-=1
			if(currentLeftPage == -1):
				currentLeftPage = util_Preloader.scrapbookData[leftPageSectionIndex]["numPages"]- 1
				turningPageRightSectionSide = false
				currentRightTurningPage = currentLeftPage + 1
			else:
				currentLeftPage = util_Preloader.scrapbookData[leftPageSectionIndex]["numPages"]
				turningPageRightSectionSide = true
		else:
			currentLeftPage = -1
	else:
		turningPageRightSectionSide = false
		turningPageLeftSectionSide = false
	turningRight = false
	time = 1
	return time
func turn_to_section_start():
	if(openingBook):
		return 1
	if(currentLeftPage == 1 || currentRightTurningPage == 1):
		return
	currentRightTurningPage = 2 if currentLeftPage % 2 == 1 else 1
	if(leftPageSectionIndex < rightPageSectionIndex):
		rightPageSectionIndex -= 1
	turningPageLeftSectionSide = true
	turningPageRightSectionSide = true
	if(currentLeftPage % 2 == 1):
		currentLeftPage = 1
	else:
		if(leftPageSectionIndex > 0):
			leftPageSectionIndex-=1
			currentLeftPage = util_Preloader.scrapbookData[leftPageSectionIndex]["numPages"]
		else:
			currentLeftPage = -1

func turn_to_next_section():
	if(openingBook):
		return 0
	if(currentLeftTurningPage == 1 || currentRightPage == 1):
		return
	
	if(rightPageSectionIndex != leftPageSectionIndex):
		leftPageSectionIndex += 1
	if(rightPageSectionIndex < util_Preloader.sectionsList.size() - 1):
		turningPageRightSectionSide = false
		rightPageSectionIndex+=1
		if((currentRightPage % 2) == (util_Preloader.scrapbookData[leftPageSectionIndex]["numPages"] % 2)):
			currentRightPage = 2
			turningPageLeftSectionSide = true
			currentLeftTurningPage = 1
		else:
			currentRightPage = 1
			turningPageLeftSectionSide = false
			currentLeftTurningPage = util_Preloader.scrapbookData[leftPageSectionIndex]["numPages"]
	else:
		if(currentRightPage % 2 == util_Preloader.scrapbookData[rightPageSectionIndex]["numPages"] % 2):
			currentLeftTurningPage = util_Preloader.scrapbookData[rightPageSectionIndex]["numPages"] - 1
			currentRightPage = util_Preloader.scrapbookData[rightPageSectionIndex]["numPages"]
		else:
			currentLeftTurningPage = util_Preloader.scrapbookData[rightPageSectionIndex]["numPages"]
			currentRightPage = -1

func turn_to_start_of_book():
	if(openingBook):
		return 1
	while(rightPageSectionIndex > 0 || currentLeftPage > 1):
		turn_page_left()
		currentRightTurningPage = 2 if currentLeftPage % 2 == 1 else 1
		if(leftPageSectionIndex < rightPageSectionIndex):
			rightPageSectionIndex -= 1
		turningPageLeftSectionSide = true
		turningPageRightSectionSide = true
		if(currentLeftPage % 2 == 1):
			currentLeftPage = 1
		else:
			if(leftPageSectionIndex > 0):
				leftPageSectionIndex-=1
				currentLeftPage = util_Preloader.scrapbookData[rightPageSectionIndex]["numPages"]
			else:
				currentLeftPage = -1

func turn_to_end_of_book():
	if(openingBook):
		return 0
	var time
	while((rightPageSectionIndex < util_Preloader.sectionsList.size() - 1 || currentRightPage < util_Preloader.scrapbookData[rightPageSectionIndex]["numPages"] - 1 || currentLeftTurningPage < util_Preloader.scrapbookData[rightPageSectionIndex]["numPages"] - 2) && currentRightPage != -1):
		time = turn_page_right()
		if(!(rightPageSectionIndex < util_Preloader.sectionsList.size() - 1 || currentRightPage < util_Preloader.scrapbookData[rightPageSectionIndex]["numPages"] - 1 || currentLeftTurningPage < util_Preloader.scrapbookData[rightPageSectionIndex]["numPages"] - 2) && currentRightPage != -1):
			return time
		if(rightPageSectionIndex != leftPageSectionIndex):
			leftPageSectionIndex += 1
		if(rightPageSectionIndex < util_Preloader.sectionsList.size() - 1):
			turningPageRightSectionSide = false
			rightPageSectionIndex+=1
			if((currentRightPage % 2) == (util_Preloader.scrapbookData[leftPageSectionIndex]["numPages"] % 2)):
				currentRightPage = 2
				turningPageLeftSectionSide = true
				currentLeftTurningPage = 1
			else:
				currentRightPage = 1
				turningPageLeftSectionSide = false
				currentLeftTurningPage = util_Preloader.scrapbookData[leftPageSectionIndex]["numPages"]
		else:
			if(currentRightPage % 2 == util_Preloader.scrapbookData[rightPageSectionIndex]["numPages"] % 2):
				currentLeftTurningPage = util_Preloader.scrapbookData[rightPageSectionIndex]["numPages"] - 1
				currentRightPage = util_Preloader.scrapbookData[rightPageSectionIndex]["numPages"]
			else:
				currentLeftTurningPage = util_Preloader.scrapbookData[rightPageSectionIndex]["numPages"]
				currentRightPage = -1
	return time

func turn_left_to_section(section):
	var time = 0
	while(util_Preloader.sectionsList[rightPageSectionIndex] != section && rightPageSectionIndex > 0):
		time = turn_page_left()
		currentRightTurningPage = 2 if currentLeftPage % 2 == 1 else 1
		if(leftPageSectionIndex < rightPageSectionIndex):
			rightPageSectionIndex -= 1
		turningPageLeftSectionSide = true
		turningPageRightSectionSide = true
		if(currentLeftPage % 2 == 1):
			currentLeftPage = 1
		else:
			if(leftPageSectionIndex > 0):
				leftPageSectionIndex-=1
				currentLeftPage = util_Preloader.scrapbookData[leftPageSectionIndex]["numPages"]
			else:
				currentLeftPage = -1
	return time

func turn_right_to_section(section):
	var time = 1
	while(util_Preloader.sectionsList[rightPageSectionIndex] != section && rightPageSectionIndex < util_Preloader.sectionsList.size() - 1):
		time = turn_page_right()
		if(util_Preloader.sectionsList[rightPageSectionIndex] == section || rightPageSectionIndex >= util_Preloader.sectionsList.size() - 1):
			return time
		if(rightPageSectionIndex != leftPageSectionIndex):
			leftPageSectionIndex += 1
		if(rightPageSectionIndex < util_Preloader.sectionsList.size() - 1):
			turningPageRightSectionSide = false
			rightPageSectionIndex+=1
			if((currentRightPage % 2) == (util_Preloader.scrapbookData[leftPageSectionIndex]["numPages"] % 2)):
				currentRightPage = 2
				turningPageLeftSectionSide = true
				currentLeftTurningPage = 1
			else:
				currentRightPage = 1
				turningPageLeftSectionSide = false
				currentLeftTurningPage = util_Preloader.scrapbookData[leftPageSectionIndex]["numPages"]
		else:
			if(currentRightPage % 2 == util_Preloader.scrapbookData[rightPageSectionIndex]["numPages"] % 2):
				currentLeftTurningPage = util_Preloader.scrapbookData[rightPageSectionIndex]["numPages"] - 1
				currentRightPage = util_Preloader.scrapbookData[rightPageSectionIndex]["numPages"]
			else:
				currentLeftTurningPage = util_Preloader.scrapbookData[rightPageSectionIndex]["numPages"]
				currentRightPage = -1
	return time
	
func finish_turn_right():
	if(openingBook):
		bookOpen = true
		CoverOutside.visible = false
		openingBook = false
		return
	currentLeftPage = currentLeftTurningPage
	if(turningPageLeftSectionSide == true):
		leftPageSectionIndex = rightPageSectionIndex
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
	if(turningPageRightSectionSide == false):
		rightPageSectionIndex = leftPageSectionIndex
	currentLeftTurningPage = -1
	currentRightTurningPage = -1
