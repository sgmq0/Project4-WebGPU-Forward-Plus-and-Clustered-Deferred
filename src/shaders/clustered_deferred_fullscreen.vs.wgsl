// TODO-3: implement the Clustered Deferred fullscreen vertex shader

// This shader should be very simple as it does not need all of the information passed by the the naive vertex shader.

@group(${bindGroup_model}) @binding(0) 
var<uniform> modelMat: mat4x4f;

@group(${bindGroup_scene}) @binding(0) 
var<uniform> cameraUniforms: CameraUniforms;

struct VertexOutput
{
    @builtin(position) fragPos: vec4f,
    @location(0) uv: vec2f
}

@vertex
fn main(@builtin(vertex_index) vIdx: u32) -> VertexOutput
{
    var pos = array<vec2f, 3>(
        vec2f(-1.0, -1.0),
        vec2f( 3.0, -1.0),
        vec2f(-1.0,  3.0)
    );

    var out: VertexOutput;
    out.fragPos = vec4f(pos[vIdx], 0.0, 1.0);
    out.uv =  0.5 * (pos[vIdx] + vec2f(1.0, 1.0));

    return out;
}
