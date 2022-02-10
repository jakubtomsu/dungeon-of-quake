#version 330

in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragPosition;
in vec3 fragNormal;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float timePassed;

out vec4 finalColor;

void main() {
	vec2 uv = fragTexCoord + vec2(sin(fragTexCoord.x*14.0 + timePassed*2.0), cos(fragTexCoord.y*14.0 + timePassed*2.0)) * 0.02 + vec2(sin(timePassed), cos(timePassed))*0.4;
	vec4 texelColor = texture(texture0, uv)*colDiffuse*fragColor;
	vec3 col = texelColor.rgb;

	finalColor = vec4(col, 1.0);
}