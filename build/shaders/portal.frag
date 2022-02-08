#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragPosition;
in vec3 fragNormal;


// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float timePassed;


// Output fragment color
out vec4 finalColor;

// NOTE: Add here your custom variables

void main() {
	// Texel color fetching from texture sampler
	vec2 uv = fragTexCoord + vec2(sin(fragTexCoord.x*14.0 + timePassed*2.0), cos(fragTexCoord.y*14.0 + timePassed*2.0)) * 0.02 + vec2(sin(timePassed), cos(timePassed))*0.4;
	vec4 texelColor = texture(texture0, uv)*colDiffuse*fragColor;
	vec3 col = texelColor.rgb;

	//col = normalize(fragNormal);
	//col = vec3(uv, 0.0);

	//col = vec3(1,1,0);

	finalColor = vec4(col, 1.0);
}