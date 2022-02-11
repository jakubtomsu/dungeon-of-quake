#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform vec3 tintColor;


out vec4 finalColor;

const float screengamma = 2.2;

// Narkowicz 2015, "ACES Filmic Tone Mapping Curve"
vec3 tonemapACES(const in vec3 x) {
	const float a = 2.51;
	const float b = 0.03;
	const float c = 2.43;
	const float d = 0.59;
	const float e = 0.14;
	return(clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0));
}


#define TRY_FIT_COLOR(new) old = mix (new, old, step (length (old-ref), length (new-ref)));
/*
vec3 gameboyColor(vec3 ref) {
	ref *= 255.0;
	vec3 old = vec3(100.0*255.0);
	TRY_FIT_COLOR(vec3(156.0, 189.0, 015.0));
	TRY_FIT_COLOR(vec3(140.0, 173.0, 015.0));
	TRY_FIT_COLOR(vec3(048.0, 098.0, 048.0));
	TRY_FIT_COLOR(vec3(015.0, 056.0, 015.0));
	return old / 255.0;
}

vec3 NESColor(vec3 ref) {
	ref *= 255.0;
	vec3 old = vec3(100.0*255.0);
	TRY_FIT_COLOR(vec3 (000.0, 088.0, 000.0));
	TRY_FIT_COLOR(vec3 (080.0, 048.0, 000.0));
	TRY_FIT_COLOR(vec3 (000.0, 104.0, 000.0));
	TRY_FIT_COLOR(vec3 (000.0, 064.0, 088.0));
	TRY_FIT_COLOR(vec3 (000.0, 120.0, 000.0));
	TRY_FIT_COLOR(vec3 (136.0, 020.0, 000.0));
	TRY_FIT_COLOR(vec3 (000.0, 168.0, 000.0));
	TRY_FIT_COLOR(vec3 (168.0, 016.0, 000.0));
	TRY_FIT_COLOR(vec3 (168.0, 000.0, 032.0));
	TRY_FIT_COLOR(vec3 (000.0, 168.0, 068.0));
	TRY_FIT_COLOR(vec3 (000.0, 184.0, 000.0));
	TRY_FIT_COLOR(vec3 (000.0, 000.0, 188.0));
	TRY_FIT_COLOR(vec3 (000.0, 136.0, 136.0));
	TRY_FIT_COLOR(vec3 (148.0, 000.0, 132.0));
	TRY_FIT_COLOR(vec3 (068.0, 040.0, 188.0));
	TRY_FIT_COLOR(vec3 (120.0, 120.0, 120.0));
	TRY_FIT_COLOR(vec3 (172.0, 124.0, 000.0));
	TRY_FIT_COLOR(vec3 (124.0, 124.0, 124.0));
	TRY_FIT_COLOR(vec3 (228.0, 000.0, 088.0));
	TRY_FIT_COLOR(vec3 (228.0, 092.0, 016.0));
	TRY_FIT_COLOR(vec3 (088.0, 216.0, 084.0));
	TRY_FIT_COLOR(vec3 (000.0, 000.0, 252.0));
	TRY_FIT_COLOR(vec3 (248.0, 056.0, 000.0));
	TRY_FIT_COLOR(vec3 (000.0, 088.0, 248.0));
	TRY_FIT_COLOR(vec3 (000.0, 120.0, 248.0));
	TRY_FIT_COLOR(vec3 (104.0, 068.0, 252.0));
	TRY_FIT_COLOR(vec3 (248.0, 120.0, 088.0));
	TRY_FIT_COLOR(vec3 (216.0, 000.0, 204.0));
	TRY_FIT_COLOR(vec3 (088.0, 248.0, 152.0));
	TRY_FIT_COLOR(vec3 (248.0, 088.0, 152.0));
	TRY_FIT_COLOR(vec3 (104.0, 136.0, 252.0));
	TRY_FIT_COLOR(vec3 (252.0, 160.0, 068.0));
	TRY_FIT_COLOR(vec3 (248.0, 184.0, 000.0));
	TRY_FIT_COLOR(vec3 (184.0, 248.0, 024.0));
	TRY_FIT_COLOR(vec3 (152.0, 120.0, 248.0));
	TRY_FIT_COLOR(vec3 (000.0, 232.0, 216.0));
	TRY_FIT_COLOR(vec3 (060.0, 188.0, 252.0));
	TRY_FIT_COLOR(vec3 (188.0, 188.0, 188.0));
	TRY_FIT_COLOR(vec3 (216.0, 248.0, 120.0));
	TRY_FIT_COLOR(vec3 (248.0, 216.0, 120.0));
	TRY_FIT_COLOR(vec3 (248.0, 164.0, 192.0));
	TRY_FIT_COLOR(vec3 (000.0, 252.0, 252.0));
	TRY_FIT_COLOR(vec3 (184.0, 184.0, 248.0));
	TRY_FIT_COLOR(vec3 (184.0, 248.0, 184.0));
	TRY_FIT_COLOR(vec3 (240.0, 208.0, 176.0));
	TRY_FIT_COLOR(vec3 (248.0, 120.0, 248.0));
	TRY_FIT_COLOR(vec3 (252.0, 224.0, 168.0));
	TRY_FIT_COLOR(vec3 (184.0, 248.0, 216.0));
	TRY_FIT_COLOR(vec3 (216.0, 184.0, 248.0));
	TRY_FIT_COLOR(vec3 (164.0, 228.0, 252.0));
	TRY_FIT_COLOR(vec3 (248.0, 184.0, 248.0));
	TRY_FIT_COLOR(vec3 (248.0, 216.0, 248.0));
	TRY_FIT_COLOR(vec3 (248.0, 248.0, 248.0));
	TRY_FIT_COLOR(vec3 (252.0, 252.0, 252.0));
	return old / 255.0;
}

vec3 EGAColor(vec3 ref) {
	ref *= 255.0;
	vec3 old = vec3(100.0*255.0);
	TRY_FIT_COLOR(vec3(000.0,000.0,000.0));
	TRY_FIT_COLOR(vec3(255.0,255.0,255.0));
	TRY_FIT_COLOR(vec3(255.0,  0.0,  0.0));
	TRY_FIT_COLOR(vec3(  0.0,255.0,  0.0));
	TRY_FIT_COLOR(vec3(  0.0,  0.0,255.0));
	TRY_FIT_COLOR(vec3(255.0,255.0,  0.0));
	TRY_FIT_COLOR(vec3(  0.0,255.0,255.0));
	TRY_FIT_COLOR(vec3(255.0,  0.0,255.0));
	TRY_FIT_COLOR(vec3(128.0,  0.0,  0.0));
	TRY_FIT_COLOR(vec3(  0.0,128.0,  0.0));
	TRY_FIT_COLOR(vec3(  0.0,  0.0,128.0));
	TRY_FIT_COLOR(vec3(128.0,128.0,  0.0));
	TRY_FIT_COLOR(vec3(  0.0,128.0,128.0));
	TRY_FIT_COLOR(vec3(128.0,  0.0,128.0));
	TRY_FIT_COLOR(vec3(128.0,128.0,128.0));
	TRY_FIT_COLOR(vec3(255.0,128.0,128.0));
	return old / 255.0;
}
*/

float _ditherMatrix(float x, float y) {
	return mix(mix(mix(
		mix(mix(mix(0.0,32.0,step(1.0,y)),mix(8.0,40.0,step(3.0,y)),step(2.0,y)),mix(mix(2.0,34.0,step(5.0,y)),mix(10.0,42.0,step(7.0,y)),step(6.0,y)),step(4.0,y)),mix(mix(mix(48.0,16.0,step(1.0,y)),mix(56.0,24.0,step(3.0,y)),step(2.0,y)),mix(mix(50.0,18.0,step(5.0,y)),mix(58.0,26.0,step(7.0,y)),step(6.0,y)),step(4.0,y)),step(1.0,x)),mix(mix(mix(mix(12.0,44.0,step(1.0,y)),mix(4.0,36.0,step(3.0,y)),step(2.0,y)),mix(mix(14.0,46.0,step(5.0,y)),mix(6.0,38.0,step(7.0,y)),step(6.0,y)),step(4.0,y)),mix(mix(mix(60.0,28.0,step(1.0,y)),mix(52.0,20.0,step(3.0,y)),step(2.0,y)),mix(mix(62.0,30.0,step(5.0,y)),mix(54.0,22.0,step(7.0,y)),step(6.0,y)),step(4.0,y)),step(3.0,x)),step(2.0,x)),
		mix(mix(mix(mix(mix(3.0,35.0,step(1.0,y)),mix(11.0,43.0,step(3.0,y)),step(2.0,y)),mix(mix(1.0,33.0,step(5.0,y)),mix(9.0,41.0,step(7.0,y)),step(6.0,y)),step(4.0,y)),mix(mix(mix(51.0,19.0,step(1.0,y)),mix(59.0,27.0,step(3.0,y)),step(2.0,y)),mix(mix(49.0,17.0,step(5.0,y)),mix(57.0,25.0,step(7.0,y)),step(6.0,y)),step(4.0,y)),step(5.0,x)),mix(mix(mix(mix(15.0,47.0,step(1.0,y)),mix(7.0,39.0,step(3.0,y)),step(2.0,y)),mix(mix(13.0,45.0,step(5.0,y)),mix(5.0,37.0,step(7.0,y)),step(6.0,y)),step(4.0,y)),mix(mix(mix(63.0,31.0,step(1.0,y)),mix(55.0,23.0,step(3.0,y)),step(2.0,y)),mix(mix(61.0,29.0,step(5.0,y)),mix(53.0,21.0,step(7.0,y)),step(6.0,y)),step(4.0,y)),step(7.0,x)),step(6.0,x)),step(4.0,x));
}

vec3 dither(vec2 fragcoord) {
	return vec3(_ditherMatrix(mod(fragcoord.x, 8.0), mod(fragcoord.y, 8.0))) / 255.0;
}

vec3 posterize(vec3 col, int numcolors, float gamma) {
	col = pow(col, vec3(gamma, gamma, gamma));
	col = col*numcolors;
	col = floor(col);
	col = col/numcolors;
	col = pow(col, vec3(1.0/gamma));
	return col;
}

float toGrayscale(vec3 col) {
	return dot(col, vec3(0.299, 0.587, 0.114));
}


void main() {
	vec2 uv = fragTexCoord.xy;
	vec4 origColor = texture(texture0, uv) * vec4(tintColor, 1.0);
	vec3 col = origColor.rgb;

	//col = pow(col, vec3(1.0 / screengamma)); // gamma correction

	col += dither(gl_FragCoord.xy)*0.25;
	col = posterize(col, 12, 0.8);
	//col = gameboyColor(col);

	// if(gl_FragCoord.x < 30 && gl_FragCoord.y < 30) col = vec3(1,0,1); // debug
	finalColor = vec4(col, 1.0);
}