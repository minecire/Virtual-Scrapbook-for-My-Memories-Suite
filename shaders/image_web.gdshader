shader_type canvas_item;

uniform sampler2D shape_textures[4];
uniform sampler2D corner_textures[2];
uniform sampler2D rip_textures[3];
uniform sampler2D gradient_textures[2];

instance uniform vec4 recolor_value = vec4(0.000000, 0.000000, 0.000000, 0.000000);
instance uniform vec4 corner_rounding = vec4(0.100000, 0.100000, 0.100000, 0.100000);
instance uniform vec4 assorted_data = vec4(2.0, 0.02, 0.18, 0.);
instance uniform vec4 matte_color = vec4(0., 0., 0., 1.);
instance uniform int textureIndex = 1;
instance uniform vec4 subtexture = vec4(0.24, 0., 0.71, 0.5);
instance uniform vec4 shape_subtexture = vec4(0.1, 0.1, 0.8, 0.8);
instance uniform vec4 shadowColor = vec4(0., 0., 0., 1.);
instance uniform vec2 shadowTransform = vec2(0.1, 0.1);
instance uniform vec4 edgeBlur = vec4(0., 0., 0., 0.);
instance uniform int cornerType = 1;
instance uniform vec4 edgeRip = vec4(0.1, 0.1, 0.1, 0.1);
instance uniform vec4 edgeRipTextures = vec4(1., 3., 3., 7.);

instance uniform int gradientIndex = -1;
instance uniform vec4 transformationMatrix;
instance uniform vec2 translation;

float rip_check(vec2 uv, int tex){
	if(tex % 3 == 0){
		return texture(rip_textures[0], uv).r;
	}
	if(tex % 3 == 1){
		return texture(rip_textures[1], uv).r;
	}
	if(tex % 3 == 2){
		return texture(rip_textures[2], uv).r;
	}
	return 0.;
}

float corner_texture_check(vec2 uv, int tex){
	if(tex == 0){
		return texture(corner_textures[0], uv).a;
	}
	else{
		return texture(corner_textures[1], uv).a;
	}
	return 0.;
}

vec4 shape_texture_check(vec2 uv, int tex){
	if(tex == 0){
		return texture(shape_textures[0], uv);
	}
	if(tex == 1){
		return texture(shape_textures[1], uv);
	}
	if(tex == 2){
		return texture(shape_textures[2], uv);
	}
	if(tex == 3){
		return texture(shape_textures[3], uv);
	}
	//if(tex == 4){
		//return texture(shape_textures[4], uv);
	//}
	//if(tex == 5){
		//return texture(shape_textures[5], uv);
	//}
	//if(tex == 6){
		//return texture(shape_textures[6], uv);
	//}
	//if(tex == 7){
		//return texture(shape_textures[7], uv);
	//}
	//if(tex == 8){
		//return texture(shape_textures[8], uv);
	//}
	//if(tex == 9){
		//return texture(shape_textures[9], uv);
	//}
	return vec4(0.,0.,0.,0.);
}

vec4 gradient_texture_check(vec2 uv, int tex){
	if(tex == 0){
		return texture(gradient_textures[0], uv);
	}
	if(tex == 1){
		return texture(gradient_textures[1], uv);
	}
	//if(tex == 2){
		//return texture(gradient_textures[2], uv);
	//}
	return vec4(0.,0.,0.,0.);
}

float check_all_rips(vec2 uv, vec4 rips, vec4 textures){
	float right = rip_check((vec2(uv.y, 1. - uv.x)) / vec2(1., rips.x), int(textures.x));
	float up = rip_check(uv / vec2(1., rips.y), int(textures.y));
	float left = rip_check(vec2(uv.y, uv.x) / vec2(1., rips.z), int(textures.z));
	float down = rip_check((vec2(uv.x, 1. - uv.y)) / vec2(1., rips.w), int(textures.w));
	return(min(min(right, left), min(up,down)));
}

float corner_check(vec2 uv, float val, float ar, int type){
	if(uv.x < 0. || uv.x > 1. || uv.y < 0. || uv.y > 1.){
		return 0.;
	}
	bool outbool;
	if(type < 2){
		float distX = uv.x * ar - val;
		float distY = (uv.y - val);
		float dist = distX * distX + distY * distY;
		outbool = dist < val * val || uv.x >= val / ar || uv.y >= val;
	}
	else{
		vec2 scaledUV = uv / val;
		if(type == 2){
			scaledUV.x *= ar;
		}
		else{
			scaledUV.x /= 1.8;
			scaledUV.y /= 1.2;
		}
		if(scaledUV.x < 0. || scaledUV.x > 1. || scaledUV.y < 0. || scaledUV.y > 1.){
			return 1.;
		}
		outbool = corner_texture_check(scaledUV, type - 2) > 0.;
	}
	if(outbool) {
		return 1.;
	}
	else {
		return 0.;
	}
}

float check_all_corners(vec2 uv, vec4 vals, float ar, int type, vec4 rips, vec4 riptextures){
	float topLeft = corner_check(uv, vals.x, ar, type);
	float topRight = corner_check(uv * vec2(-1., 1.) + vec2(1., 0.), vals.y, ar, type);
	float bottomLeft = corner_check(uv * vec2(1., -1.) + vec2(0., 1.), vals.z, ar, type);
	float bottomRight = corner_check(uv * vec2(-1., -1.) + vec2(1., 1.), vals.w, ar, type);
	float allCorners = min(min(topLeft,topRight),min(bottomLeft,bottomRight));
	if(type == 1){
		if((uv.x < 0.5 + 0.02 / ar && uv.x > 0.5 - 0.02 / ar) || (uv.y < 0.52 && uv.y > 0.48)){
			return 0.;
		}
	}
	float ripChecks = check_all_rips(uv, rips, riptextures);
	return min(allCorners, ripChecks);
}
float check_all_corners_matte(vec2 uv, vec4 vals, float ar, int type, vec4 rips, vec4 riptextures, float m_size){
	vec4 altrips = vec4(float((int(riptextures.x) + 3) % 10), float((int(riptextures.y) + 2) % 10), float((int(riptextures.z) + 5) % 10), float((int(riptextures.w) + 8) % 10));
	if(type == 1){
		bool isVerticalInnerEdge = uv.x > 0.5 + 0.02 / ar - m_size / ar && uv.x < 0.5 + 0.02 / ar || uv.x < 0.5 - 0.02 / ar + m_size / ar && uv.x > 0.5 - 0.02 / ar;
		bool isHorizontalInnerEdge = uv.y > 0.52 - m_size && uv.y < 0.52 || uv.y < 0.48 + m_size && uv.y > 0.48;
		bool isInsideVertical = uv.x < 0.5 + 0.02 / ar - m_size / ar && uv.x > 0.5 - 0.02 / ar + m_size / ar;
		bool isInsideHorizontal = uv.y < 0.5 + 0.02 - m_size && uv.y > 0.5 - 0.02 + m_size;
		if((isVerticalInnerEdge || isHorizontalInnerEdge) && !(isInsideVertical || isInsideHorizontal)){
			return check_all_corners(uv, vals, ar, 0, rips, altrips);
		}
	}
	return check_all_corners(uv, vals, ar, type, rips, altrips);
}


void fragment() {
	float aspect_ratio = assorted_data.x;
	float matte_size = assorted_data.y;
	float shadowBlur = assorted_data.z;
	if(edgeBlur != vec4(0., 0., 0., 0.)){
		float opacityRight = 1. - clamp((edgeBlur.x - (1. - UV.x)) / edgeBlur.x, 0., 1.);
		float opacityUp = 1. - clamp((edgeBlur.y - UV.y) / edgeBlur.y, 0., 1.);
		float opacityLeft = 1. - clamp((edgeBlur.z - UV.x) / edgeBlur.z, 0., 1.);
		float opacityDown = 1. - clamp((edgeBlur.w + UV.y - 1.) / edgeBlur.w, 0., 1.);
		COLOR = vec4(COLOR.xyz, COLOR.w * opacityRight * opacityUp * opacityLeft * opacityDown);
	}
	else{
		vec2 globalUV = vec2((UV.x) * transformationMatrix.x + translation.x, (UV.y) * transformationMatrix.w + translation.y) / 2.;
		vec2 scaledUV = vec2((UV.x - subtexture.x) / subtexture.z, (UV.y - subtexture.y) / subtexture.w) * (1. + 2. * abs(shadowTransform)) - abs(shadowTransform);
		vec2 rescaledShapeUV = vec2(scaledUV.x * shape_subtexture.z + shape_subtexture.x, scaledUV.y * shape_subtexture.w + shape_subtexture.y);
		vec2 modUV = scaledUV / vec2((1. - matte_size * 2. / aspect_ratio), 1. - matte_size * 2.) - vec2(matte_size / aspect_ratio, matte_size);
		vec2 unscaledModUV = UV / vec2((1. - matte_size * 2. / aspect_ratio), 1. - matte_size * 2.) - vec2(matte_size / aspect_ratio, matte_size);
		vec2 rescaledShapeModUV = rescaledShapeUV / vec2((1. - matte_size * 2. / aspect_ratio), 1. - matte_size * 2.) - vec2(matte_size / aspect_ratio, matte_size);
		vec2 shadowUV = scaledUV - shadowTransform;
		vec2 rescaledShapeShadowUV = rescaledShapeUV - shadowTransform;
		vec2 shadowmodUV = modUV - shadowTransform;
		vec2 unscaledshadowUV = UV - shadowTransform;
		vec2 unscaledshadowmodUV = unscaledModUV - shadowTransform;
		float allCorners = check_all_corners(modUV, corner_rounding, aspect_ratio, cornerType, edgeRip, edgeRipTextures);
		float allCornersMatte = check_all_corners_matte(scaledUV, corner_rounding, aspect_ratio, cornerType, edgeRip, edgeRipTextures, matte_size);
		float allCornersShadow = max(check_all_corners(shadowmodUV, corner_rounding, aspect_ratio, cornerType, edgeRip, edgeRipTextures), check_all_corners_matte(shadowUV, corner_rounding, aspect_ratio, cornerType, edgeRip, edgeRipTextures, matte_size));

		vec4 recolor = texture(TEXTURE, unscaledModUV) + recolor_value;
		float matteOnly = allCornersMatte - allCorners;
		float shadowAlpha = 0.;
		float colA = 1.;
		if(textureIndex != -1){
			COLOR = vec4(recolor.xyz, COLOR.w * shape_texture_check(rescaledShapeUV, textureIndex).a);
			colA = COLOR.w * shape_texture_check(rescaledShapeUV, textureIndex).a;
			if(scaledUV.x < 0. || scaledUV.x > 1. || scaledUV.y < 0. || scaledUV.y > 1.){
				COLOR.a = 0.;
				colA = 0.;
			}
			shadowAlpha = shape_texture_check(rescaledShapeShadowUV, textureIndex).a;
			if(shadowUV.x < 0. || shadowUV.x > 1. || shadowUV.y < 0. || shadowUV.y > 1.){
				shadowAlpha = 0.;
			}
		}
		else if(matteOnly > 0.){
			if(gradientIndex == -1){
				COLOR = matte_color;
				colA = matte_color.a;
			}
			else{
				COLOR = gradient_texture_check(globalUV, gradientIndex);
				COLOR.a = matte_color.a * gradient_texture_check(globalUV, gradientIndex).a;
				colA = matte_color.a * gradient_texture_check(globalUV, gradientIndex).a;
			}
		}
		else{
			COLOR = vec4(recolor.xyz, texture(TEXTURE, unscaledModUV).w * allCorners);
			colA = texture(TEXTURE, unscaledModUV).w * allCorners;
			if(texture(TEXTURE, unscaledModUV).w < 1.){
				COLOR.w = 0.;
				colA = 0.;
			}
			shadowAlpha = allCornersShadow;
		}
		if(colA < shadowAlpha){
			if(texture(TEXTURE, unscaledshadowmodUV).w == 1.){
				float dist = length(shadowTransform);
				float moddist = dist / 2.;
				if(textureIndex != -1){
					for(int i = 0; i < 4; i++){
						vec2 tfuv = rescaledShapeModUV - dist * shadowTransform / length(shadowTransform);
						vec2 tfuv2 = modUV - dist * shadowTransform / length(shadowTransform);
						if(shape_texture_check(tfuv, textureIndex).w == 1. && !(
						tfuv2.x < 0. || tfuv2.x > 1. || tfuv2.y < 0. || tfuv2.y > 1.)){
							dist -= moddist;
						}
						else{
							dist += moddist;
						}
						moddist /= 2.;
					}
				}
				else{
					for(int i = 0; i < 4; i++){
						if(texture(TEXTURE, unscaledModUV - dist * shadowTransform / length(shadowTransform)).w == 1. &&
							max(check_all_corners(modUV - dist * shadowTransform / length(shadowTransform),
								corner_rounding, aspect_ratio, cornerType, edgeRip, edgeRipTextures),
							check_all_corners_matte(scaledUV - dist * shadowTransform / length(shadowTransform),
								corner_rounding, aspect_ratio, cornerType, edgeRip, edgeRipTextures, matte_size)) == 1.){
							dist -= moddist;
						}
						else{
							dist += moddist;
						}
						moddist /= 2.;
					}
				}
				if(length(shadowTransform) - dist < shadowBlur){
					shadowAlpha *= (length(shadowTransform) - dist) / shadowBlur;
				}
				COLOR = vec4(shadowColor.rgb, shadowColor.a * shadowAlpha);
			}
		}
	}
}