#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragPosition;


// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform vec3 camPos;


// Output fragment color
out vec4 finalColor;

// NOTE: Add here your custom variables

void main() {
	// Texel color fetching from texture sampler
	vec4 texelColor = texture(texture0, fragTexCoord)*colDiffuse*fragColor;
	float dist = length(fragPosition - camPos);

	vec3 col = texelColor.rgb;

	// Convert texel color to grayscale using NTSC conversion weights
	//col = vec3(dot(col, vec3(0.299, 0.587, 0.114)));

	col = mix(col, vec3(0.85, 0.8, 0.9), clamp(pow(dist, 0.6) * 0.01, 0.0, 1.0));
	
	finalColor = vec4(col, 1.0);
}