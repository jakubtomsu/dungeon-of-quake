#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragPosition;
in vec3 fragNormal;


// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float timePassed;


// Output fragment color
out vec4 finalColor;



float rand01(const in vec2 uv) {
	return fract(sin(dot(uv, vec2(12.98194798, 78.233283))) * 43758.5952453);
}

// simplex 3d
// discontinuous pseudorandom uniformly distributed in [-0.5, +0.5]^3
vec3 simplex_rand3(const in vec3 c) {
	float j = 4096.0 * sin(dot(c,vec3(17.0, 59.4, 15.0)));
	vec3 r;
	r.z = fract(512.0 * j);
	j *= 0.125;
	r.x = fract(512.0 * j);
	j *= 0.125;
	r.y = fract(512.0 * j);
	return r-0.5;
}

// skew constants for 3d simplex functions
const float F3 =  0.3333333;
const float G3 =  0.1666667;
// 3d simplex noise
float simplex3d(vec3 point) {
	// 1. find current tetrahedron T and it's four vertices
	// s, s+i1, s+i2, s+1.0 - absolute skewed (integer) coordinates of T vertices
	// x, x1, x2, x3 - unskewed coordinates of point relative to each of T vertices
	// calculate s and x
	vec3 s = floor(point + dot(point, vec3(F3)));
	vec3 x = point - s + dot(s, vec3(G3));
	// calculate i1 and i2
	vec3 e = step(vec3(0.0), x - x.yzx);
	vec3 i1 = e*(1.0 - e.zxy);
	vec3 i2 = 1.0 - e.zxy * (1.0 - e);
	// x1, x2, x3
	vec3 x1 = x - i1 + G3;
	vec3 x2 = x - i2 + 2.0 * G3;
	vec3 x3 = x - 1.0 + 3.0 * G3;
	// 2. find four surflets and store them in d
	vec4 w;
	vec4 d;
	// calculate surflet weights
	w.x = dot(x, x);
	w.y = dot(x1, x1);
	w.z = dot(x2, x2);
	w.w = dot(x3, x3);
	// w fades from 0.6 at the center of the surflet to 0.0 at the margin
	w = max(0.6 - w, 0.0);
	// calculate surflet components
	d.x = dot(simplex_rand3(s), x);
	d.y = dot(simplex_rand3(s + i1), x1);
	d.z = dot(simplex_rand3(s + i2), x2);
	d.w = dot(simplex_rand3(s + 1.0), x3);
	// multiply d by w^4
	w *= w;
	w *= w;
	d *= w;
	// 3. return the sum of the four surflets
	return dot(d, vec4(52.0));
}

// const matrices for 3d rotation
const mat3 rot1 = mat3(-0.37, 0.36, 0.85,-0.14,-0.93, 0.34,0.92, 0.01,0.4);
const mat3 rot2 = mat3(-0.55,-0.39, 0.74, 0.33,-0.91,-0.24,0.77, 0.12,0.63);
const mat3 rot3 = mat3(-0.71, 0.52,-0.47,-0.08,-0.72,-0.68,-0.7,-0.45,0.56);
// directional artifacts can be reduced by rotating each octave
float simplex3d_fractal(vec3 m) {
	return 0.5333333 * simplex3d(m * rot1)
		+ 0.2666667 * simplex3d(2.0 * m * rot2)
		+ 0.1333333 * simplex3d(4.0 * m * rot3)
		+ 0.0666667 * simplex3d(8.0 * m);
}

void main() {
	// Texel color fetching from texture sampler
	vec2 uv = fragTexCoord + vec2(sin(fragTexCoord.x*14.0 + timePassed*2.0), cos(fragTexCoord.y*14.0 + timePassed*2.0)) * 0.02 + vec2(sin(timePassed), cos(timePassed))*0.4;
	vec4 texelColor = texture(texture0, uv)*colDiffuse*fragColor;

	float noise = simplex3d_fractal(fragPosition*0.3)*0.5 + 0.5;
	vec3 col = texelColor.rgb + vec3(noise*noise)*0.5;

	float alpha = noise*noise*texelColor.a*texelColor.a - 0.01;
	if(alpha < 0.05) {
		discard;
	}

	finalColor = vec4(col, (alpha > 0.5 ? 1.0 : 0.2) * (0.2 + texelColor.a));
}