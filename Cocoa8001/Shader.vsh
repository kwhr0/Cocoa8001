#version 150 core

uniform float height;
uniform sampler2D vramtex;

in float pos_x;
in float pos_y;
in float graphic;
in float colorindex;
in float reverse;
in float secret;

out vec2 texcoord_v;
out vec4 color;
out float amp;
out float bias;

void main() {
	gl_Position = vec4(0.025 * pos_x - 1.0, 1.0 - height * pos_y, 0.0, 1.0);
	vec4 ct = texture(vramtex, vec2((pos_x + 0.5) / 120.0, (pos_y + 0.5) / 25.0));
	texcoord_v = vec2(255.0 * ct.r / 256.0, graphic / 2.0);
	int c = int(colorindex);
	color = vec4((c & 2) != 0, (c & 4) != 0, c & 1, 1.0);
	amp = (1.0 - secret) * (1.0 - 2.0 * reverse);
	bias = reverse;
}
