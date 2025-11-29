extends Node

# A few dictionaries to remap some stuff

# My Memories Suite has some built in fonts
# This maps them to their files in res://fonts/
const special_fonts_dict = {
	"Scrap Casual": "igscas.TTF",
	"LD Glorious": "LDGLORIO.TTF",
	"LDJ What Up": "ldjwhatu.ttf",
	"LD Keri": "ldkeri.ttf",
	"LD Shelly Print": "LDSHELPR.TTF",
	"TXT Abrasive": "txtabras.ttf"
}

# Java and Godot both have system default font names
# Which will essentially just find the best option the OS has
# But they have different conventions, this translates between them as best as we can
const system_default_fonts_dict = {
	"Dialog" : "sans-serif",
	"DialogInput" : "monospace",
	"Monospaced": "monospace",
	"SansSerif": "sans-serif",
	"Serif": "serif"
}
