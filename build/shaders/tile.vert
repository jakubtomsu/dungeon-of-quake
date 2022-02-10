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

vec2 triplanarMax(vec3 p, vec3 n) {
	float x = abs(n.x);
	float y = abs(n.y);
	float z = abs(n.z);
	return (x>y ? (x>z ? vec2(p.z*sign(p.x), p.y) : vec2(p.x*sign(p.z), p.y)) : (y>z ? vec2(p.x, p.z) : vec2(p.x*sign(p.z), p.y)));
}

void main() {
	vec3 modPos = matModel[3].xyz;
	fragPosition = (matModel * vec4(vertexPosition, 1.0)).xyz;
	fragTexCoord = vertexTexCoord;
	fragNormal = normalize((matNormal * vec4(vertexNormal, 1.0)).xyz);
	fragTexCoord = triplanarMax((fragPosition - modPos) / 30.0 + vec3(0.5), fragNormal);
	fragColor = vertexColor;

	gl_Position = mvp*vec4(vertexPosition, 1.0);
}
