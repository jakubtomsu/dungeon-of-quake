#version 330

in Vec2 fragTexCoord;
in Vec4 fragColor;
in Vec3 fragPosition;
in Vec3 fragNormal;

uniform sampler2D texture0;
uniform sampler2D texture1;
uniform sampler2D texture2;
uniform Vec4 colDiffuse;
uniform Vec3 camPos;
uniform Vec4 fogColor;

out Vec4 finalColor;

// NOTE: has to be synced with `tile.frag` for it to look consistent
void main() {
	Vec2 uv = fragTexCoord;
	Vec4 texelColor = texture(texture0, uv)*colDiffuse*fragColor;
	float dist = length(fragPosition - camPos);

	Vec3 col = texelColor.rgb;

	float fog = pow(dist * 0.001 * fogColor.a, 0.6);
	col = mix(col, fogColor.rgb, clamp(fog, 0.0, 1.0));

	finalColor = Vec4(col, 1.0);
}