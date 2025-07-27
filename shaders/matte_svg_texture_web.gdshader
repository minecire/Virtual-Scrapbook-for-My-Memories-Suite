shader_type canvas_item;

uniform sampler2D gradient_textures[3];

instance uniform vec4 subtexture = vec4(0., 0., 1., 1.);
instance uniform vec4 shadowColor = vec4(0., 0., 0., 1.);
instance uniform vec2 shadowTransform = vec2(0.01, 0.01);
instance uniform float shadowBlur = 0.018;
instance uniform float matteSize;

instance uniform int gradientIndex = 1;
instance uniform vec4 transformationMatrix;
instance uniform vec2 translation;

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
	//if(tex == 3){
		//return texture(gradient_textures[3], uv);
	//}
	//if(tex == 4){
		//return texture(gradient_textures[4], uv);
	//}
	//if(tex == 5){
		//return texture(gradient_textures[5], uv);
	//}
	//if(tex == 6){
		//return texture(gradient_textures[6], uv);
	//}
	//if(tex == 7){
		//return texture(gradient_textures[7], uv);
	//}
	//if(tex == 8){
		//return texture(gradient_textures[8], uv);
	//}
	//if(tex == 9){
		//return texture(gradient_textures[9], uv);
	//}
	return vec4(0.,0.,0.,0.);
}


void fragment() {
	vec2 scaledUV = vec2(UV.x * subtexture.z + subtexture.x, UV.y * subtexture.w + subtexture.y);
	vec2 globalUV = vec2((UV.x - translation.x) / transformationMatrix.x, (UV.y - translation.y) / transformationMatrix.w) / 2.;
	vec2 shadowUV = scaledUV - shadowTransform;
	float shadowAlpha = 0.;
	float colA;
	if(gradientIndex != -1){
		colA = COLOR.a * gradient_texture_check(globalUV, gradientIndex).a;
		COLOR = vec4(gradient_texture_check(globalUV, gradientIndex).rgb, COLOR.a * gradient_texture_check(globalUV, gradientIndex).a);
	}
	else{
		COLOR = texture(TEXTURE, scaledUV);
		colA = texture(TEXTURE, scaledUV).a;
		if(texture(TEXTURE, scaledUV).w < 1.){
			COLOR.w = 0.;
			colA = 0.;
		}
	}
	if(UV.x < 0.25 - matteSize * 1.5 || UV.x > 0.75 + matteSize * 1.5 || UV.y < 0.25 - matteSize * 1.5 || UV.y > 0.75 + matteSize * 1.5){
		COLOR = vec4(1., 1., 1., 0.);
		colA = 0.;
	}
	shadowAlpha = 1.;
	if(colA < shadowAlpha){
		if(texture(TEXTURE, shadowUV).w == 1.){
			float dist = length(shadowTransform);
			float moddist = dist / 2.;
			for(int i = 0; i < 10; i++){
				if(texture(TEXTURE, scaledUV - dist * shadowTransform / length(shadowTransform)).w == 1.){
					dist -= moddist;
				}
				else{
					dist += moddist;
				}
				moddist /= 2.;
			}
			if(length(shadowTransform) - dist < shadowBlur){
				shadowAlpha *= (length(shadowTransform) - dist) / shadowBlur;
			}
			COLOR = vec4(shadowColor.rgb, shadowColor.a * shadowAlpha);
		}
	}

}