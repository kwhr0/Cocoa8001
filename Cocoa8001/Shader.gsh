#version 150 core

layout (points) in;
layout (triangle_strip, max_vertices = 4) out;

uniform float width;
uniform float height;
uniform mat4 mtx;

in vec2 texcoord_v[];
in vec4 color[];
in float amp[];
in float bias[];

out vec2 texcoord;
out vec4 colorgeo;
out float amp_g;
out float bias_g;

void main() {
	vec4 pos0 = gl_in[0].gl_Position, pos1 = pos0, pos2 = pos0;
	pos1.x += width;
	pos2.y -= height;
	vec4 pos3 = pos2;
	pos3.x = pos1.x;
	vec2 tex0 = texcoord_v[0], tex1 = tex0, tex2 = tex0;
	tex1.x += 1.0 / 256.0;
	tex2.y += 5.0 * height;
	vec2 tex3 = tex2;
	tex3.x = tex1.x;
	colorgeo = color[0];
	amp_g = amp[0];
	bias_g = bias[0];
	gl_Position = mtx * pos0;
	texcoord = tex0;
	EmitVertex();
	gl_Position = mtx * pos1;
	texcoord = tex1;
	EmitVertex();
	gl_Position = mtx * pos2;
	texcoord = tex2;
	EmitVertex();
	gl_Position = mtx * pos3;
	texcoord = tex3;
	EmitVertex();
	EndPrimitive();
}
