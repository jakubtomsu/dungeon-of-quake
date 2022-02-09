#version 330

in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragPosition;
in vec3 fragNormal;

uniform sampler2D texture0;
uniform sampler2D texture1;
uniform sampler2D texture2;
uniform vec4 colDiffuse;
uniform vec3 camPos;
uniform vec4 fogColor;

out vec4 finalColor;

// NOTE: has to be synced with `tile.frag` for it to look consistent
void main() {
	/*
	vec2 uv = fragTexCoord;
	vec4 texelColor = texture(texture0, uv)*colDiffuse*fragColor;
	float dist = length(fragPosition - camPos);

	vec3 col = texelColor.rgb;

	float fog = pow(dist * 0.001 * fogColor.a, 0.6);
	col = mix(col, fogColor.rgb, clamp(fog, 0.0, 1.0));

	col = fragNormal;

	finalColor = vec4(col, 1.0);
	*/
	finalColor = vec4(1,1,0, 1.0);
}