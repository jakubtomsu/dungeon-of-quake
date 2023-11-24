#version 330

in Vec2 fragTexCoord;
in Vec4 fragColor;
in Vec3 fragPosition;
in Vec3 fragNormal;

uniform sampler2D texture0;
uniform Vec4 colDiffuse;
uniform float timePassed;
uniform Vec3 camPos;

out Vec4 finalColor;

// by IQ
// https://iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
float sdBox(in Vec2 p, in Vec2 b) {
	Vec2 d = abs(p)-b;
	return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
}

void main() {
	// Texel color fetching from texture sampler
	Vec2 uv = (fragPosition.xz*0.003) + Vec2(timePassed*0.06) + Vec2(fragPosition.y/50.0) + Vec2(cos(timePassed+fragPosition.y), sin(timePassed+fragPosition.y))*0.02;
	Vec4 texelColor = texture(texture0, uv)*colDiffuse*fragColor;
	float box = 0.5;
	float fade = smoothstep(0.0, 1.0, max(0.0, 1.0 - (length(fragPosition.xz-camPos.xz)*0.001)));
	//fade = 1.0;
	texelColor.a *= fade;
	finalColor = texelColor;
	//finalColor = Vec4(fragPosition*0.01, 1.0);
	//finalColor = Vec4(1,1,0,1);
}