shader_type canvas_item;

/*
	Web / OpenGL3 version of matte_svg_texture.gdshader
	The image border (matte) needs to be handled separately in some cases.
	This function is largely just a piece of image.gdshader
*/
uniform sampler2D gradient_textures[3]; 
//Textures for matte gradients, Godot doesn't allow instance uniform textures, so this needs to be a big array used for every instance.
instance uniform int gradient_index = 1; //With a per-instance index into it array

instance uniform vec4 subtexture = vec4(0., 0., 1., 1.); //Region of texture to be used
instance uniform vec4 shadow_color = vec4(0., 0., 0., 1.);
instance uniform vec2 shadow_transform = vec2(0.01, 0.01); //Offset of shadow
instance uniform float shadow_blur = 0.018; //Shadow blur amount
instance uniform float matte_size; //Thickness of border

//Transformation of image compared to the screen
instance uniform vec4 transformation_matrix;
instance uniform vec2 translation;

// Due to a bizzare quirk of web-based shaders, using a non-constant value as an array index is forbidden
// Hence this abomination
vec4 gradient_texture_check(vec2 uv, int tex){
	if(tex == 0){
		return texture(gradient_textures[0], uv);
	}
	if(tex == 1){
		return texture(gradient_textures[1], uv);
	}
	if(tex == 2){
		return texture(gradient_textures[2], uv);
	}
	return vec4(0.,0.,0.,0.);
}


void fragment() {
	//We have a few UVs here for different use cases
	
	//UV scaled to crop the subtexture properly
	vec2 scaledUV = vec2(UV.x * subtexture.z + subtexture.x, UV.y * subtexture.w + subtexture.y);
	
	//Pixel position on the entire page, used for gradients for some reason.
	vec2 globalUV = vec2((UV.x - translation.x) / transformation_matrix.x, (UV.y - translation.y) / transformation_matrix.w) / 2.;
	
	//UV offset for sampling by the shadow
	vec2 shadowUV = scaledUV - shadow_transform;
	float colA; 
	//We store the alpha separately from setting COLOR because COLOR isn't quite a proper variable and cannot be read back later
	if(gradient_index != -1){ //If there is a gradient we sample that
		colA = COLOR.a * gradient_texture_check(globalUV, gradient_index).a;
		COLOR = vec4(gradient_texture_check(globalUV, gradient_index).rgb, COLOR.a * gradient_texture_check(globalUV, gradient_index).a);
	}
	else{ //Otherwise, we sample the texture whose color has been set already
		COLOR = texture(TEXTURE, scaledUV);
		colA = texture(TEXTURE, scaledUV).a;
		if(texture(TEXTURE, scaledUV).w < 1.){
			COLOR.w = 0.;
			colA = 0.;
		}
	}
	
	//If we are out of bounds, return a transparent pixel
	//Note that the matte has actually been scaled UP 2x so that it doesn't get cut off
	if(UV.x < 0.25 - matte_size * 1.5 || UV.x > 0.75 + matte_size * 1.5 || 
		UV.y < 0.25 - matte_size * 1.5 || UV.y > 0.75 + matte_size * 1.5){
		COLOR = vec4(1., 1., 1., 0.);
		colA = 0.;
	}
	if(colA < 1. && texture(TEXTURE, shadowUV).w == 1.){ //If our pixel isn't opaque but we are in the shadow, do shadow color calculations
			
		float shadowAlpha = 1.0;
		float dist = length(shadow_transform);
		float modDist = dist / 2.;
		for(int i = 0; i < 4; i++){ //Quick and dirty binary search to find the distance to the edge along the shadow offset axis
			if(texture(TEXTURE, scaledUV - dist * shadow_transform / length(shadow_transform)).w == 1.){
				dist -= modDist;
			}
			else{
				dist += modDist;
			}
			modDist /= 2.;
		}
		if(length(shadow_transform) - dist < shadow_blur){ 
			//This distance provides a good enough blur effect without too much computation
			shadowAlpha *= (length(shadow_transform) - dist) / shadow_blur;
		}
		COLOR = vec4(shadow_color.rgb, shadow_color.a * shadowAlpha);
	}
}