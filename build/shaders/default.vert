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

void main() {
	fragPosition = (matModel * Vec4(vertexPosition, 1.0)).xyz;
	fragTexCoord = vertexTexCoord;
	fragNormal = vertexNormal;
	fragColor = vertexColor;

	gl_Position = mvp*Vec4(vertexPosition, 1.0);
}
