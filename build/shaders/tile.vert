#version 330

in Vec3 vertexPosition;
in Vec2 vertexTexCoord;
in Vec3 vertexNormal;
in Vec4 vertexColor;

uniform mat4 mvp;
uniform mat4 matModel;
uniform mat4 matNormal;

out Vec3 fragPosition;
out Vec2 fragTexCoord;
out Vec4 fragColor;
out Vec3 fragNormal;

Vec2 triplanarMax(Vec3 p, Vec3 n) {
	float x = abs(n.x);
	float y = abs(n.y);
	float z = abs(n.z);
	return (x>y ? ((x>z) ? Vec2(p.z, p.y) : Vec2(p.x, p.y)) : ((y>z) ? Vec2(p.x, p.z) : Vec2(p.x, p.y)));
}

void main() {
	Vec3 modPos = matModel[3].xyz;
	fragPosition = (matModel * Vec4(vertexPosition, 1.0)).xyz;
	fragTexCoord = vertexTexCoord;
	fragNormal = normalize((matNormal * Vec4(vertexNormal, 1.0)).xyz);
	fragTexCoord = triplanarMax((fragPosition - modPos) / 30.0 + Vec3(0.5), fragNormal);
	fragColor = vertexColor;

	gl_Position = mvp*Vec4(vertexPosition, 1.0);
}
