extends Node

func get_gradient(raw_gradient_data, width, height):
	# Little utility function to convert the gradient storage format
	# into a Godot gradient texture
	
	var gradient_data = raw_gradient_data.split("~") # Gradients use tilde to separate parts
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.width = width
	gradient_texture.height = height
	if(gradient_data[0] == "linearGradient"): # First whether the gradient is linear or radial
		gradient_texture.fill = GradientTexture2D.FILL_LINEAR
	else:
		gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	
	# Then the start and end points of the gradient
	# Further separated into 2D coordinates by backtick
	var gradient_from_data = gradient_data[1].split("`") 
	var gradient_from = Vector2(gradient_from_data[0].to_float(), gradient_from_data[1].to_float()) / Vector2(width, height)
	var gradient_to_data = gradient_data[2].split("`")
	var gradient_to = Vector2(gradient_to_data[0].to_float(), gradient_to_data[1].to_float()) / Vector2(width, height)
	gradient_texture.fill_from = gradient_from
	gradient_texture.fill_to = gradient_to
	
	# Then colors in that odd negative number format, again separated by backticks
	var gradient_colors_data = gradient_data[3].split("`")
	var gradient_colors = PackedColorArray()
	for col in gradient_colors_data:
		gradient_colors.append(getColorFromNegative(col.to_int()))
	gradient_texture.gradient = Gradient.new()
	gradient_texture.gradient.colors = gradient_colors
	
	# Then the offsets from 0 to 1 along the gradient each point is at
	var gradient_offset_data = gradient_data[4].split("`")
	var gradient_offsets = []
	for offset in gradient_offset_data:
		gradient_offsets.append(offset.to_float())
	gradient_texture.gradient.offsets = gradient_offsets
	if(gradient_data[5] == "NO_CYCLE"): # And finally the way in which the gradient repeats (or doesn't)
		gradient_texture.repeat = GradientTexture2D.REPEAT_NONE
	if(gradient_data[5] == "REFLECT"):
		gradient_texture.repeat = GradientTexture2D.REPEAT_MIRROR
	else:
		gradient_texture.repeat = GradientTexture2D.REPEAT
	return gradient_texture

# Convert color from a negative integer to a Godot color
# It's actually just the RGB value, but written as an unsigned integer rather than a signed one, 
# and stored in decimal rather than hex, leading to this odd conversion where we subtract it from 2^24
func getColorFromNegative(val):
	var negative_value = 16777216 + val
	
	# Not sure Godot is smart enough to do this with bitshifts
	# But that doesn't matter too much since this function doesn't get run too often
	var red = float(floor(negative_value / (256 * 256))) 
	var green = float(floor(negative_value / (256) % 256))
	var blue = float(floor(negative_value % 256))
	return Color(red / 256., green / 256., blue / 256.)
