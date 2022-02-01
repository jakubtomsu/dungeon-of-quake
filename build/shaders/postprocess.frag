#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Output fragment color
out vec4 finalColor;

// NOTE: Add here your custom variables

float postergamma = 0.6;
float numColors = 16.0;
const float screengamma = 2.2;

// Narkowicz 2015, "ACES Filmic Tone Mapping Curve"
vec3 tonemapACES(const in vec3 x) {
	const float a = 2.51;
	const float b = 0.03;
	const float c = 2.43;
	const float d = 0.59;
	const float e = 0.14;
	return(clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0));
}


void main() {
	// Texel color fetching from texture sampler
	vec3 origColor = texture(texture0, fragTexCoord.xy).rgb;
	vec3 col = origColor;

	// posterization
	//col = pow(col, vec3(postergamma, postergamma, postergamma));
	//col = col*numColors;
	//col = floor(col);
	//col = col/numColors;
	//col = pow(col, vec3(1.0/postergamma));

	//col = tonemapACES(col);
	//col = pow(col, vec3(1.0 / screengamma)); // gamma correction

	if(gl_FragCoord.x < 10 && gl_FragCoord.y < 10) col = vec3(1,0,0);

	finalColor = vec4(col, 1.0);
}