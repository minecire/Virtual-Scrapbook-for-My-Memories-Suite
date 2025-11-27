shader_type canvas_item;

/*
	This file is a mess! My Memories Suite has a TON of complicated things you can do to images
	with some strange functionality, and most of them need to essentially be rendered by this one shader.
	Additionally, Godot has some frustrating quirks with shaders that prevent us using best practices.
*/

//Textures cannot be instanced so we're forced to use big arrays of them used in all instances, with an instanced index variable
uniform sampler2D shape_textures[30];
uniform sampler2D gradient_textures[30];

uniform sampler2D corner_textures[2]; //Textures for stylized rounded corners
uniform sampler2D rip_textures[10]; //Textures for torn paper effect

//Indeces into the uninstanced shape_textures and gradient_textures arrays, and edge rip array for each edge
instance uniform int texture_index = 1;
instance uniform int gradient_index = -1;
instance uniform vec4 edge_rip_textures = vec4(1., 3., 3., 7.);

//RGBA value to be mixed additively
instance uniform vec4 recolor_value = vec4(0.000000, 0.000000, 0.000000, 0.000000);
instance uniform vec4 corner_rounding = vec4(0.100000, 0.100000, 0.100000, 0.100000);

//due to limited number of uniforms, a few values are combined into one vec4
instance uniform vec4 assorted_data = vec4(2.0, 0.02, 0.18, 0.);
	//Aspect Ratio, Border ("Matte") Size, Shadow Blur Level, Unused

instance uniform vec4 matte_color = vec4(0., 0., 0., 1.); //Border Color

//Size and position of the region of texture that should be cropped in
instance uniform vec4 subtexture = vec4(0.24, 0., 0.71, 0.5);

//Same as subtexture but for the "Shape" / mask layer
instance uniform vec4 shape_subtexture = vec4(0.1, 0.1, 0.8, 0.8);
instance uniform vec4 shadow_color = vec4(0., 0., 0., 1.);
instance uniform vec2 shadow_transform = vec2(0.1, 0.1);
instance uniform vec4 edge_blur = vec4(0., 0., 0., 0.);
instance uniform vec4 edge_rip = vec4(0.1, 0.1, 0.1, 0.1); //Amount each edge is ripped


//Type of rounded corner, numerical values taken from MMS convention:
//  0 - Circular (computed mathematically)
//  1 - "Window" (just circular with a + shape cut out in the middle like an old-fashioned window,
		//not sure why this is even a corner and not its own thing)
//  2 - "Button" (corner textures array index 0)
//  3 - "Cloud" (corner textures array index 1)
instance uniform int corner_type = 1;

// Transform relative to page
instance uniform vec4 transformation_matrix;
instance uniform vec2 translation;

// Some quick functions for checking textures, mostly for better parity with the web version,
// in which these checks need to be handled in a much sillier way, see image_web.gdshader
float rip_check(vec2 uv, int tex){
	return texture(rip_textures[tex], uv).r;
}

float corner_texture_check(vec2 uv, int tex){
	return texture(corner_textures[tex], uv).a;
}

vec4 shape_texture_check(vec2 uv, int tex){
	return texture(shape_textures[tex], uv);
}

vec4 gradient_texture_check(vec2 uv, int tex){
	return texture(gradient_textures[tex], uv);
}

//returns 1 if a pixel is not ripped off, 0 otherwise.
float check_all_rips(vec2 uv, vec4 rips, vec4 textures){ //UV sample position, size of each edge rip, texture indeces
	float right = rip_check((vec2(uv.y, 1. - uv.x)) / vec2(1., rips.x), int(textures.x));
	float up = rip_check(uv / vec2(1., rips.y), int(textures.y));
	float left = rip_check(vec2(uv.y, uv.x) / vec2(1., rips.z), int(textures.z));
	float down = rip_check((vec2(uv.x, 1. - uv.y)) / vec2(1., rips.w), int(textures.w));
	return right * left * up * down; //if any edge says a pixel is ripped off return 0, otherwise 1
}

//returns 1 if a pixel is not cut off by a rounded corner, 0 otherwise.
float corner_check(vec2 uv, float val, float ar, int type){
	//UV sample position, corner radius (vertical), aspect ratio, corner type

	if(uv.x < 0. || uv.x > 1. || uv.y < 0. || uv.y > 1.){
		return 0.; //cut off any pixels outside the rectangle
	}
	if(type < 2){ //if the corner is rounded, compute mathematically using the definition of a circle
		float distX = uv.x * ar - val; //scale by aspect ratio so corners are circular
		float distY = (uv.y - val);
		float dist = distX * distX + distY * distY; //calculate distance from pixel to rounded corner center
		return (dist < val * val || uv.x >= val / ar || uv.y >= val)
			? 1.0 : 0.0; //return 1 if distance is less than corner radius
	}
	else{
		vec2 scaledUV = uv / val; //get a uv that can sample the texture
		if(type == 2){ //"Button"
			scaledUV.x *= ar; //Scale by aspect ratio so corners aren't warped
		}
		else{ //"Pillow"
			scaledUV.x /= 1.8;
			//The pillow corners work weird! These magic numbers bring it close enough to how MMS displays them
			scaledUV.y /= 1.2;
		}
		if(scaledUV.x < 0. || scaledUV.x > 1. || scaledUV.y < 0. || scaledUV.y > 1.){
			return 1.; //Return 1 if outside the scope of the texture
				// (but still inside the rectangle, see above)
		}
		return corner_texture_check(scaledUV, type - 2); //otherwise check the appropriate texture, [0] for type 2, [1] for type 3
	}
}

float check_all_corners(vec2 uv, vec4 vals, float ar, int type){
	float topLeft = corner_check(uv, vals.x, ar, type);
	float topRight = corner_check(uv * vec2(-1., 1.) + vec2(1., 0.), vals.y, ar, type);
	float bottomLeft = corner_check(uv * vec2(1., -1.) + vec2(0., 1.), vals.z, ar, type);
	float bottomRight = corner_check(uv * vec2(-1., -1.) + vec2(1., 1.), vals.w, ar, type);
	float allCorners = topLeft * topRight * bottomLeft * bottomRight; //Compile all corners into a single mask
	if(type == 1){ //Mask out a vertical and horizontal bar for the window effect
		if((uv.x < 0.5 + 0.02 / ar && uv.x > 0.5 - 0.02 / ar) || (uv.y < 0.52 && uv.y > 0.48)){
			//These are again some magic numbers because this effect appears to be hardcoded
			return 0.;
		}
	}
	return allCorners;
}
float check_everything_matte(vec2 uv, vec4 vals, float ar, int type, vec4 rips, vec4 ripTextures){
	//Use different rip textures for matte for better variation
	vec4 altRipTextures = vec4(float((int(ripTextures.x) + 3) % 10), float((int(ripTextures.y) + 2) % 10), float((int(ripTextures.z) + 5) % 10), float((int(ripTextures.w) + 8) % 10));
	return check_all_corners(uv, vals, ar, 0) * check_all_rips(uv, rips, altRipTextures);
}


vec4 calculate_shadow_color(sampler2D _TEXTURE,
	float aspectRatio, float matteSize, float shadowBlur, float shadowAlpha,
	vec2 scaledUV, vec2 modUV, vec2 rescaledShapeModUV, vec2 unscaledModUV){

	// quick and dirty algorithm for shadow blur by binary search along the axis of transformation
	float dist = length(shadow_transform); // a maximum distance from the edge
	float modDist = dist / 2.; // amount to change the distance by each step
	if(texture_index != -1){ // if there is a shape mask we sample based on that
		for(int i = 0; i < 4; i++){
			// more uvs!! These are transformed based on the distance in order to find the edge of the shadow and distance to it
			vec2 transformedShapeUV = rescaledShapeModUV - dist * shadow_transform / length(shadow_transform); // UV for sampling the mask
			vec2 transformedImageUV = modUV - dist * shadow_transform / length(shadow_transform); // UV for checking if we are out of bounds
			if(shape_texture_check(transformedShapeUV, texture_index).w == 1. && !(
			transformedImageUV.x < 0. || transformedImageUV.x > 1. || transformedImageUV.y < 0. || transformedImageUV.y > 1.)){ // Binary search
				dist -= modDist;
			}
			else{
				dist += modDist;
			}
			modDist /= 2.;
		}
	}
	else{ // if there is no shape mask we sample based on corners and rips.
		for(int i = 0; i < 4; i++){
			if(texture(_TEXTURE, unscaledModUV - dist * shadow_transform / length(shadow_transform)).w == 1. &&
				max(check_all_corners(modUV - dist * shadow_transform / length(shadow_transform),
					corner_rounding, aspectRatio, corner_type) * check_all_rips(modUV,  edge_rip, edge_rip_textures),
					check_everything_matte(scaledUV - dist * shadow_transform / length(shadow_transform),
					corner_rounding, aspectRatio, corner_type, edge_rip, edge_rip_textures)) == 1.){
				//Basically the same as the other one, but we check for both the border and the texture, and don't need to crop
				//because corner check does that for us
				dist -= modDist;
			}
			else{
				dist += modDist;
			}
			modDist /= 2.;
		}
	}
	float newShadowAlpha = shadowAlpha;
	if(length(shadow_transform) - dist < shadowBlur){
		//Finally, set the alpha based on the distance to the edge for a blur effect
		//As long as we are in range for blur to take effect
		newShadowAlpha *= (length(shadow_transform) - dist) / shadowBlur;
	}
	return vec4(shadow_color.rgb, shadow_color.a * shadowAlpha);
}

//This is where the real fun begins
void fragment() {
	//Grab data from the assorted_data vec4
	float aspectRatio = assorted_data.x;
	float matteSize = assorted_data.y;
	float shadowBlur = assorted_data.z;

	if(edge_blur != vec4(0., 0., 0., 0.)){
		//In the case of blurred edges, pretty much all other functionality is disabled.
		float opacityRight = 1. - clamp((edge_blur.x - (1. - UV.x)) / edge_blur.x, 0., 1.);
		float opacityUp = 1. - clamp((edge_blur.y - UV.y) / edge_blur.y, 0., 1.);
		float opacityLeft = 1. - clamp((edge_blur.z - UV.x) / edge_blur.z, 0., 1.);
		float opacityDown = 1. - clamp((edge_blur.w + UV.y - 1.) / edge_blur.w, 0., 1.); //Calculate opacity from blur for each edge
		COLOR = vec4(COLOR.xyz, COLOR.w * opacityRight * opacityUp * opacityLeft * opacityDown); //Multiply them
		//Normally we would return here to get rid of some nested brackets,
		//but Godot has a quirk with the fragment function specifically
		//where returning from fragment exits the entire shader (rather than just fragment function itself)
		//without applying the color
	}
	else{ //Hence we have a stupid else here. This bracket closes at the end of the fragment function.

		//We need to sample textures in a LOT of different coordinate spaces, especially for combinations of effects
		//So there's no avoiding a dozen different UVs

		//Pixel position on the actual page, used by MMS for gradients rather than local UV
		//Probably a bug but it impacts visuals enough to be worth replicating here
		vec2 globalUV = vec2((UV.x) * transformation_matrix.x + translation.x, (UV.y) * transformation_matrix.w + translation.y) / 2.;

		//UV for sampling the actual image is scaled down so effects like borders and shadows will actually show up
		//Yes, we do need to scale the image up as well beforepaw
		vec2 scaledUV = vec2((UV.x - subtexture.x) / subtexture.z, (UV.y - subtexture.y) / subtexture.w) * (1. + 2. * abs(shadow_transform)) - abs(shadow_transform);

		//Scale the mask to be cropped properly
		vec2 rescaledShapeUV = vec2(scaledUV.x * shape_subtexture.z + shape_subtexture.x, scaledUV.y * shape_subtexture.w + shape_subtexture.y);

		//Scale the image to be square so border width stays consistent
		vec2 modUV = scaledUV / vec2((1. - matteSize * 2. / aspectRatio), 1. - matteSize * 2.) - vec2(matteSize / aspectRatio, matteSize);

		//Square scaling on the original UV
		vec2 unscaledModUV = UV / vec2((1. - matteSize * 2. / aspectRatio), 1. - matteSize * 2.) - vec2(matteSize / aspectRatio, matteSize);

		//Square scaling on the mask
		vec2 rescaledShapeModUV = rescaledShapeUV / vec2((1. - matteSize * 2. / aspectRatio), 1. - matteSize * 2.) - vec2(matteSize / aspectRatio, matteSize);

		//Offset shadow from image
		vec2 shadowUV = scaledUV - shadow_transform;

		//We need variants of all these UVs for the shadow as well so we can match up the textures properly
		vec2 rescaledShapeShadowUV = rescaledShapeUV - shadow_transform;
		vec2 shadowmodUV = modUV - shadow_transform;
		vec2 unscaledshadowUV = UV - shadow_transform;
		vec2 unscaledshadowmodUV = unscaledModUV - shadow_transform;

		//Get corner-rip mask for image itself using the modified square UV
		float allCorners = check_all_corners(modUV, corner_rounding, aspectRatio, corner_type);
		float allRips = check_all_rips(modUV, edge_rip, edge_rip_textures);
		float allCornersAndRips = min(allCorners, allRips);

		//Get corner-rip mask for border / matte using the main scaled UV
		float allCornersAndRipsMatte = check_everything_matte(scaledUV, corner_rounding, aspectRatio, corner_type, edge_rip, edge_rip_textures);

		//Get corner-rip mask for shadow by compiling the border and image checks, but using the shadow UVs
		float allCornersAndRipsShadow =
			max(check_all_corners(shadowmodUV, corner_rounding, aspectRatio, corner_type) *
			check_all_rips(shadowmodUV, edge_rip, edge_rip_textures),
			check_everything_matte(shadowUV, corner_rounding, aspectRatio, corner_type, edge_rip, edge_rip_textures));

		//Mix the texture color with the recolor
		vec4 recolor = texture(TEXTURE, unscaledModUV) + recolor_value;
		float matteOnly = allCornersAndRipsMatte - allCornersAndRips; //Mask of only the matte, not including the image
		float shadowAlpha = 0.; //Opacity of shadow
		float colA = 1.; //Opacity of image
		//We have to store this opacity separately from setting the actual color because of another quirk of Godot shaders!
		//sampling COLOR will always sample the color originally passed in

		if(texture_index != -1){ //if there is a shape mask, we set alpha according to the mask.
			COLOR = vec4(recolor.xyz, COLOR.w * shape_texture_check(rescaledShapeUV, texture_index).a);
			colA = COLOR.w * shape_texture_check(rescaledShapeUV, texture_index).a;
			if(scaledUV.x < 0. || scaledUV.x > 1. || scaledUV.y < 0. || scaledUV.y > 1.){
				COLOR.a = 0.;
				colA = 0.;
			}
			//Can't forget to do the same for the shadow! (sigh..)
			shadowAlpha = shape_texture_check(rescaledShapeShadowUV, texture_index).a;
			if(shadowUV.x < 0. || shadowUV.x > 1. || shadowUV.y < 0. || shadowUV.y > 1.){
				shadowAlpha = 0.;
			}
		}
		else if(matteOnly > 0.){ //In the case that the pixel is part of the border
			if(gradient_index == -1){ //Set the color if there is no gradient
				COLOR = matte_color;
				colA = matte_color.a;
			}
			else{ //Otherwise, set the color based on a gradient texture sample
				COLOR = gradient_texture_check(globalUV, gradient_index);
				COLOR.a = matte_color.a * gradient_texture_check(globalUV, gradient_index).a;
				colA = matte_color.a * gradient_texture_check(globalUV, gradient_index).a;
			}
		}
		else{ //We are not in the matte, and there is no shape mask
			//So we mask using the corners & rips we prepared earlier
			COLOR = vec4(recolor.xyz, texture(TEXTURE, unscaledModUV).w * allCornersAndRips);
			colA = texture(TEXTURE, unscaledModUV).w * allCornersAndRips;
			if(texture(TEXTURE, unscaledModUV).w < 1.){
				COLOR.a = 0.;
				colA = 0.;
			}
			//Set shadow again
			shadowAlpha = allCornersAndRipsShadow;
		}
		if(colA < shadowAlpha && texture(TEXTURE, unscaledshadowmodUV).w == 1.){
			// if(colA >= shadowAlpha || texture(TEXTURE, unscaledshadowmodUV).w == 1.){return;}
			// this is checking if we are in shadow.
			// these brackets close at the end of the fragment function

			COLOR = calculate_shadow_color(TEXTURE, aspectRatio, matteSize, shadowBlur, shadowAlpha,
				scaledUV, modUV, rescaledShapeModUV, unscaledModUV);
		}
	}
}