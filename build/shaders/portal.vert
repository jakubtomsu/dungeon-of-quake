#version 330

in Vec3 vertexPosition;
in Vec2 vertexTexCoord;
in Vec3 vertexNormal;
in Vec4 vertexColor;

uniform mat4 mvp;
uniform mat4 matModel;
uniform mat4 matNormal;
uniform Vec3 portalPos;
uniform float g_state.time_passed;

out Vec3 fragPosition;
out Vec2 fragTexCoord;
out Vec4 fragColor;
out Vec3 fragNormal;

Vec2 triplanarMax(Vec3 p, Vec3 n) {
	float x = abs(n.x);
	float y = abs(n.y);
	float z = abs(n.z);
	return (x>y ? (x>z ? Vec2(p.z*sign(p.x), p.y) : Vec2(p.x*sign(p.z), p.y)) : (y>z ? Vec2(p.x, p.z) : Vec2(p.x*sign(p.z), p.y)));
}

void main() {
	fragPosition = vertexPosition;
	fragTexCoord = vertexTexCoord;
	fragNormal = normalize((vertexPosition - portalPos) * Vec3(1,0.5,1));
	fragTexCoord = triplanarMax(fragPosition - portalPos + Vec3(0.5), fragNormal) * 0.04;
	fragColor = vertexColor;

	gl_Position = mvp*Vec4(vertexPosition, 1.0);
}
