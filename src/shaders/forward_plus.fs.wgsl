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
var<storage, read> clusterSet: ClusterSet;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f,
    @location(3) viewPos: vec3f
}

// helper function to color the clusters
fn debugColor(clusterIndex: u32, zIndex: u32) -> vec3f {
    let test = u32(clusterIndex + zIndex);
    if (test % 6u == 0u) {
        return vec3f(1.0, 0.0, 0.0);
    } else if (test % 6u == 1u) {
        return vec3f(0.0, 1.0, 0.0);
    } else if (test % 6u == 2u) {
        return vec3f(0.0, 0.0, 1.0);
    } else if (test % 6u == 3u) {
        return vec3f(1.0, 1.0, 0.0);
    } else if (test % 6u == 4u) {
        return vec3f(1.0, 0.0, 1.0);
    } else {
        return vec3f(0.0, 1.0, 1.0);
    } 
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{

    // find x and y cluster
    let screenPos = cameraUniforms.viewProjMat * vec4f(in.pos, 1.0);
    let ndcPos = screenPos.xyz / screenPos.w;
    let xCluster = u32((ndcPos.x + 1.0) * 0.5 * f32(${numClustersX}));
    let yCluster = u32((ndcPos.y + 1.0) * 0.5 * f32(${numClustersY}));
    
    // find z cluster
    let near = cameraUniforms.nearPlane;
    let far = cameraUniforms.farPlane;
    let view = cameraUniforms.viewMat * vec4f(in.pos, 1.0);
    let zCluster = u32(log2(abs(view.z) / near) / log2(far / near) * f32(${numClustersZ}));

    // Determine which cluster contains the current fragment.
    let clusterIndex = xCluster + yCluster * ${numClustersX}u + zCluster * ${numClustersX}u * ${numClustersY}u;
    
    // Retrieve the number of lights that affect the current fragment from the cluster’s data.
    let numLights = clusterSet.clusters[clusterIndex].numLights;

    // debug clusters
    // let color = debugColor(clusterIndex, zCluster);
    // return vec4f(color, 1.0);

    // Initialize a variable to accumulate the total light contribution for the fragment.
    var totalLightContrib = vec3f(0, 0, 0);

    // For each light in the cluster:
    for (var i = 0u; i < numLights; i++) {
        // Access the light's properties using its index.
        let lightIdx = clusterSet.clusters[clusterIndex].lights[i];
        let light = lightSet.lights[lightIdx];

        // Calculate the contribution of the light based on its position, the fragment’s position, and the surface normal.
        // Add the calculated contribution to the total light accumulation.
        totalLightContrib += calculateLightContrib(light, in.pos, normalize(in.nor));
    }

    // Multiply the fragment’s diffuse color by the accumulated light contribution.
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    var finalColor = diffuseColor.rgb * totalLightContrib;

    // Return the final color, ensuring that the alpha component is set appropriately (typically to 1).
    return vec4f(finalColor, 1.0);
}
