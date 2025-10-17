// TODO-2: implement the Forward+ fragment shader

// See naive.fs.wgsl for basic fragment shader setup; this shader should use light clusters instead of looping over all lights

// ------------------------------------
// Shading process:
// ------------------------------------
// Determine which cluster contains the current fragment.
// Retrieve the number of lights that affect the current fragment from the cluster’s data.
// Initialize a variable to accumulate the total light contribution for the fragment.
// For each light in the cluster:
//     Access the light's properties using its index.
//     Calculate the contribution of the light based on its position, the fragment’s position, and the surface normal.
//     Add the calculated contribution to the total light accumulation.
// Multiply the fragment’s diffuse color by the accumulated light contribution.
// Return the final color, ensuring that the alpha component is set appropriately (typically to 1).
@group(${bindGroup_scene}) @binding(0) 
var<uniform> cameraUniforms: CameraUniforms;

@group(${bindGroup_scene}) @binding(1) 
var<storage, read> lightSet: LightSet;

@group(${bindGroup_scene}) @binding(2) 
var<storage, read_write> clusterSet: ClusterSet;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f,
    @location(3) viewPos: vec3f
}

// list of colors
// var colors = array<vec3f, 8>(
//     vec3f(1.0, 0.0, 0.0),
//     vec3f(0.0, 1.0, 0.0),
//     vec3f(0.0, 0.0, 1.0),
//     vec3f(1.0, 1.0, 0.0),
//     vec3f(1.0, 0.0, 1.0),
//     vec3f(0.0, 1.0, 1.0),
//     vec3f(1.0, 1.0, 1.0),
//     vec3f(0.5, 0.5, 0.5)
// );

// helper function to color the clusters
fn debugColor(clusterX: u32, clusterY: u32, clusterZ: u32) -> vec3f {
    let r = f32(clusterX) / f32(${numClustersX});
    let g = f32(clusterY) / f32(${numClustersY});
    let b = f32(clusterZ) / f32(${numClustersZ});
    return vec3f(r, g, b);
}

fn zIndex(z : f32) -> u32 {
    let near = f32(cameraUniforms.nearPlane);
    let far = f32(cameraUniforms.farPlane);
    let numSlices = f32(${numClustersZ});

    let farnear = log2(far / near);
    let lognear = log2(near);

    let slice = (log2(z) - lognear) / farnear * numSlices;
    return clamp(u32(slice), 0u, ${numClustersZ} - 1u);
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{

    // find x and y cluster
    let screenPos = cameraUniforms.viewProjMat * vec4f(in.pos, 1.0);
    let ndcPos = screenPos.xyz / screenPos.w;
    let xCluster = clamp(u32((ndcPos.x + 1.0) * 0.5 * f32(${numClustersX})), 0u, ${numClustersX} - 1u);
    let yCluster = clamp(u32((ndcPos.y + 1.0) * 0.5 * f32(${numClustersY})), 0u, ${numClustersY} - 1u);
    
    // find z cluster
    let zView = max(-in.viewPos.z, 0.001);
    let near = 0.1;
    let far = 1000.0;

    let logDepthRange = log2(far / near);
    let logZ = log2(zView);
    let logNear = log2(near);
    let slice = (logZ - logNear) / logDepthRange * f32(${numClustersZ}u);
    let zCluster = clamp(u32(slice), 0u, ${numClustersZ} - 1u);

    //help
    //lewt

    return vec4f(debugColor(xCluster, yCluster, zCluster), 1.0);

    // let screenPos = cameraUniforms.viewProjMat * vec4f(in.pos, 1.0);
    // let ndcPos = screenPos.xyz / screenPos.w;

    // let zView = in.viewPos.z; // view-space Z (positive)

    // let xCluster = clamp(u32((ndcPos.x + 1.0) * 0.5 * f32(${numClustersX})), 0u, ${numClustersX} - 1u);
    // let yCluster = clamp(u32((ndcPos.y + 1.0) * 0.5 * f32(${numClustersY})), 0u, ${numClustersY} - 1u);

    //return vec4(depthZ, depthZ, depthZ, 1.0);

    // let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    // if (diffuseColor.a < 0.5f) {
    //     discard;
    // }

    // var totalLightContrib = vec3f(0, 0, 0);
    // for (var lightIdx = 0u; lightIdx < lightSet.numLights; lightIdx++) {
    //     let light = lightSet.lights[lightIdx];
    //     totalLightContrib += calculateLightContrib(light, in.pos, normalize(in.nor));
    // }

    // var finalColor = diffuseColor.rgb * totalLightContrib;
    // return vec4(finalColor, 1);
}
