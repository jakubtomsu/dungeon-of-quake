#version 330

// Input vertex attributes
in Vec3 vertexPosition;
in Vec2 vertexTexCoord;
in Vec3 vertexNormal;
in Vec4 vertexColor;

uniform mat4 mvp;

out Vec2 fragTexCoord;
out Vec4 fragColor;
out Vec3 fragPosition;
out Vec3 fragNormal;

void main() {
	fragTexCoord = vertexTexCoord;
	fragColor = vertexColor;
	fragPosition = vertexPosition;

	gl_Position = mvp*Vec4(vertexPosition, 1.0);
}