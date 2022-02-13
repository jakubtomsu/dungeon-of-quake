#version 330

in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragPosition;
in vec3 fragNormal;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float timePassed;
uniform vec3 camPos;

out vec4 finalColor;

// by IQ
// https://iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
float sdBox(in vec2 p, in vec2 b) {
	vec2 d = abs(p)-b;
	return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
}

void main() {
	// Texel color fetching from texture sampler
	vec2 uv = (fragPosition.xz*0.004) + vec2(timePassed*0.06) + vec2(fragPosition.y/50.0) + vec2(cos(timePassed+fragPosition.y), sin(timePassed+fragPosition.y))*0.02;
	vec4 texelColor = texture(texture0, uv)*colDiffuse*fragColor;
	float box = 0.5;
	float fade = smoothstep(0.0, 1.0, max(0.0, 1.0 - (length(fragPosition.xz-camPos.xz)*0.001)));
	//fade = 1.0;
	texelColor.a *= fade;
	finalColor = texelColor;
	//finalColor = vec4(fragPosition*0.01, 1.0);
	//finalColor = vec4(1,1,0,1);
}