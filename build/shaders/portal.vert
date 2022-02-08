#version 330

// Input vertex attributes
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

// Input uniform values
uniform mat4 mvp;
uniform mat4 matModel;
uniform mat4 matNormal;
uniform vec3 portalPos;
uniform float timePassed;

// Output vertex attributes (to fragment shader)
out vec3 fragPosition;
out vec2 fragTexCoord;
out vec4 fragColor;
out vec3 fragNormal;

// NOTE: Add here your custom variables

vec2 triplanarMax(vec3 p, vec3 n) {
	float x = abs(n.x);
	float y = abs(n.y);
	float z = abs(n.z);
	return (x>y ? (x>z ? vec2(p.z*sign(p.x), p.y) : vec2(p.x*sign(p.z), p.y)) : (y>z ? vec2(p.x, p.z) : vec2(p.x*sign(p.z), p.y)));
}

void main() {
	fragPosition = vertexPosition;
	fragTexCoord = vertexTexCoord;
	fragNormal = normalize((vertexPosition - portalPos) * vec3(1,0.5,1));
	fragTexCoord = triplanarMax(fragPosition - portalPos + vec3(0.5), fragNormal) * 0.04;
	fragColor = vertexColor;

	gl_Position = mvp*vec4(vertexPosition, 1.0);
}
