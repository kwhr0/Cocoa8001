#version 150 core

uniform sampler2D tex;

in vec2 texcoord;
in vec4 colorgeo;
in float amp_g;
in float bias_g;

out vec4 fragcolor;

void main() {
	vec4 s = texture(tex, texcoord);
	fragcolor = colorgeo * vec4(bias_g + amp_g * s.rgb, 1.0);
}
