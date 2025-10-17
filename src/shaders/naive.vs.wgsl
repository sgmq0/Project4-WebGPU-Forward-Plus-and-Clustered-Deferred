// CHECKITOUT: you can use this vertex shader for all of the renderers

// TODO-1.3: add a uniform variable here for camera uniforms (of type CameraUniforms)
// make sure to use ${bindGroup_scene} for the group

@group(${bindGroup_model}) @binding(0) 
var<uniform> modelMat: mat4x4f;

@group(${bindGroup_scene}) @binding(0) 
var<uniform> cameraUniforms: CameraUniforms;

struct VertexInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

struct VertexOutput
{
    @builtin(position) fragPos: vec4f,
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f,
    @location(3) viewPos: vec3f
}

@vertex
fn main(in: VertexInput) -> VertexOutput
{
    let modelPos = modelMat * vec4(in.pos, 1);
    let viewPos = cameraUniforms.viewMat * modelPos;

    var out: VertexOutput;
    out.fragPos = cameraUniforms.viewProjMat * modelPos; // TODO-1.3: replace ??? with the view proj mat from your CameraUniforms uniform variable
    out.pos = modelPos.xyz / modelPos.w;
    out.viewPos = viewPos.xyz / viewPos.w;
    out.nor = in.nor;
    out.uv = in.uv;
    return out;
}
