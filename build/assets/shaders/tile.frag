#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragPosition;
in vec3 fragNormal;


// Input uniform values
uniform sampler2D texture0;
uniform sampler2D texture1;
uniform sampler2D texture2;
uniform vec4 colDiffuse;
uniform vec3 camPos;
uniform vec4 fogColor;


// Output fragment color
out vec4 finalColor;

// NOTE: Add here your custom variables

void main() {
	// Texel color fetching from texture sampler
	vec2 uv = fragTexCoord;
	vec4 texelColor = texture(texture0, uv)*colDiffuse*fragColor;
	float dist = length(fragPosition - camPos);

	vec3 col = texelColor.rgb;
	col += vec3(abs(fragNormal.x)*0.04 + fragNormal.y*0.04);

	//col = vec3(dot(col, vec3(0.299, 0.587, 0.114)));

	col = mix(col, fogColor.rgb, clamp(pow(dist * 0.001 * fogColor.a, 0.6), 0.0, 1.0));
	
	//col = fragNormal/2.0 + vec3(0.5);


	finalColor = vec4(col, 1.0);
}