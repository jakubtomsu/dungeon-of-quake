#version 330

in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

uniform mat4 mvp;
uniform mat4 matModel;
uniform mat4 matNormal;

out vec3 fragPosition;
out vec2 fragTexCoord;
out vec4 fragColor;
out vec3 fragNormal;

void main() {
	fragPosition = (matModel * vec4(vertexPosition, 1.0)).xyz;
	fragTexCoord = vertexTexCoord;
	fragNormal = vertexNormal;
	fragColor = vertexColor;

	gl_Position = mvp*vec4(vertexPosition, 1.0);
}
