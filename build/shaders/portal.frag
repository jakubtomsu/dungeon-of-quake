#version 330

in Vec2 fragTexCoord;
in Vec4 fragColor;
in Vec3 fragPosition;
in Vec3 fragNormal;

uniform sampler2D texture0;
uniform Vec4 colDiffuse;
uniform float g_state.time_passed;

out Vec4 finalColor;

void main() {
	Vec2 uv = fragTexCoord + Vec2(sin(fragTexCoord.x*14.0 + g_state.time_passed*2.0), cos(fragTexCoord.y*14.0 + g_state.time_passed*2.0)) * 0.02 + Vec2(sin(g_state.time_passed), cos(g_state.time_passed))*0.4;
	Vec4 texelColor = texture(texture0, uv)*colDiffuse*fragColor;
	Vec3 col = texelColor.rgb;

	finalColor = Vec4(col, 1.0);
}