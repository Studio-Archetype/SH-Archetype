/* 
BSL Shaders v7.2.01 by Capt Tatsu 
https://bitslablab.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord;

varying vec3 sunVec, upVec;

//Uniforms//
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;

uniform float blindFactor;
uniform float far, near;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight, aspectRatio;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;
uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

#ifdef LIGHT_SHAFT
uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;
#endif

//Attributes//

//Optifine Constants//
const bool colortex5Clear = false;

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility = clamp(dot(sunVec, upVec) + 0.05, 0.0, 0.1) * 10.0;

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float GetLinearDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}

//Includes//
#include "/lib/color/waterColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/atmospherics/waterFog.glsl"
#include "/lib/lighting/ambientOcclusion.glsl"
#include "/lib/outline/outlineOffset.glsl"
#include "/lib/outline/promoOutline.glsl"

#ifdef LIGHT_SHAFT
#include "/lib/atmospherics/volumetricLight.glsl"
#endif

//Program//
void main() {
    vec4 color = texture2D(colortex0, texCoord);
    vec3 translucent = texture2D(colortex1,texCoord).rgb;
	float z0 = texture2D(depthtex0, texCoord).r;
	float z1 = texture2D(depthtex1, texCoord).r;
	
	vec4 screenPos = vec4(texCoord.x, texCoord.y, z0, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;
	
    float lz0 = GetLinearDepth(z0) * far;
	float effectMix = clamp(0.03125 * lz0, 0.0, 1.0);
    
	#if defined AO || defined LIGHT_SHAFT
	float dither = Bayer64(gl_FragCoord.xy);
	#endif

	#ifdef AO
	if (z1 - z0 > 0.0 && lz0 < 32.0) {
		if (dot(translucent, translucent) < 0.02) {
            float ao = AmbientOcclusion(depthtex0, dither);
            color.rgb *= mix(ao, 1.0, effectMix);
        }
	}
	#endif

	#ifdef FOG
	if (isEyeInWater == 1.0) {
        vec4 screenPos = vec4(texCoord.x, texCoord.y, z0, 1.0);
		vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
		viewPos /= viewPos.w;

		WaterFog(color.rgb, viewPos.xyz, waterFog * (1.0 + 0.4 * eBS));
	}
	#endif
	
	#ifdef PROMO_OUTLINE
	if (z1 - z0 > 0.0){
		vec3 promoColor = PromoOutline(color.rgb, depthtex0);
		color.rgb = mix(promoColor, color.rgb, effectMix);
	}
	#endif
	
	#ifdef LIGHT_SHAFT
	vec3 vl = getVolumetricRays(z0, z1, translucent, dither);
	#else
	vec3 vl = vec3(0.0);
    #endif
	
    /*DRAWBUFFERS:01*/
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(vl, 1.0);
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

varying vec3 sunVec, upVec;

//Uniforms//
uniform float timeAngle;

uniform mat4 gbufferModelView;

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
}

#endif
