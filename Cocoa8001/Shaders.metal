#include <metal_stdlib>
#include "ShaderTypes.h"

using namespace metal;

struct Data {
    float4 pos [[position]];
	float2 texcoord;
	float4 ofs, amp;
};

kernel void geometryShader(constant Chr *in [[ buffer(0) ]],
						   device Vtx *out [[ buffer(1) ]],
						   constant Prm *prm [[ buffer(2) ]],
						   uint id [[ thread_position_in_grid ]],
						   uint id1 [[ thread_position_in_threadgroup ]],
						   uint id2 [[ threadgroup_position_in_grid ]]) {
	constant Chr &i = in[id];
	int pixW = prm->pixW, pixH = prm->pixH;
	int x = id1 * pixW - 320, y = 200 - (id2 + 1) * pixH;
	float g = 0.5 * i.graph;
	uint oid = 6 * id;
	out[oid + 1].pos.x = out[oid + 2].pos.x = out[oid + 4].pos.x = x;
	out[oid + 0].pos.x = out[oid + 3].pos.x = out[oid + 5].pos.x = x + pixW;
	out[oid + 0].pos.y = out[oid + 1].pos.y = out[oid + 3].pos.y = y;
	out[oid + 2].pos.y = out[oid + 4].pos.y = out[oid + 5].pos.y = y + pixH;
	out[oid + 1].texcoord.x = out[oid + 2].texcoord.x = out[oid + 4].texcoord.x = i.code / 256.0;
	out[oid + 0].texcoord.x = out[oid + 3].texcoord.x = out[oid + 5].texcoord.x = (i.code + 1) / 256.0;
	out[oid + 0].texcoord.y = out[oid + 1].texcoord.y = out[oid + 3].texcoord.y = g + pixH / 40.0;
	out[oid + 2].texcoord.y = out[oid + 4].texcoord.y = out[oid + 5].texcoord.y = g;
	float4 color = float4(i.color >> 1 & 1, i.color >> 2 & 1, i.color & 1, 1);
	float4 ofs = i.rev * color, amp = !i.secret * (1 - 2 * i.rev) * color;
	out[oid].ofs = out[oid + 1].ofs = out[oid + 2].ofs = out[oid + 3].ofs = out[oid + 4].ofs = out[oid + 5].ofs = ofs;
	out[oid].amp = out[oid + 1].amp = out[oid + 2].amp = out[oid + 3].amp = out[oid + 4].amp = out[oid + 5].amp = amp;
}

vertex Data vertexShader(uint vertexID [[ vertex_id ]],
						 constant Vtx *vertexArray [[ buffer(0) ]],
						 constant bool &rotation [[ buffer(1) ]]) {
	constant Vtx &v = vertexArray[vertexID];
	Data r;
	if (rotation)
		r.pos = vector_float4(-v.pos.y / (400 / 2), v.pos.x / (640 / 2), 0.0, 1.0);
	else
		r.pos = vector_float4(v.pos.x / (640 / 2), v.pos.y / (400 / 2), 0.0, 1.0);
	r.texcoord = v.texcoord;
	r.ofs = v.ofs;
	r.amp = v.amp;
	return r;
}

fragment float4 fragmentShader(Data in [[stage_in]],
							   texture2d<half> tex [[ texture(0) ]]) {
	constexpr sampler ts(mag_filter::nearest, min_filter::nearest);
	return float4(in.ofs + in.amp * (float4)tex.sample(ts, in.texcoord));
}
