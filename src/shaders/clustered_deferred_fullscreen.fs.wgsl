// TODO-3: implement the Clustered Deferred fullscreen fragment shader

// Similar to the Forward+ fragment shader, but with vertex information coming from the G-buffer instead.
@group(${bindGroup_scene}) @binding(0) 
var<uniform> cameraUniforms: CameraUniforms;

@group(${bindGroup_scene}) @binding(1) 
var<storage, read> lightSet: LightSet;

@group(${bindGroup_scene}) @binding(2) 
var<storage, read> clusterSet: ClusterSet;

@group(${bindGroup_scene}) @binding(3) var positionTex : texture_2d<f32>;
@group(${bindGroup_scene}) @binding(4) var colorTex : texture_2d<f32>;
@group(${bindGroup_scene}) @binding(5) var normalTex : texture_2d<f32>;
@group(${bindGroup_scene}) @binding(6) var textureSampler : sampler;

struct FragmentInput
{
    @builtin(position) fragPos: vec4f,
    @location(0) uv: vec2f
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let uv = vec2f(in.uv.x, 1.0 - in.uv.y);
    let pos = textureSample(positionTex, textureSampler, uv).xyz;
    let col = textureSample(colorTex, textureSampler, uv).xyz;
    let nor = textureSample(normalTex, textureSampler, uv).xyz;

    let view = cameraUniforms.viewMat * vec4f(pos, 1.0);
    let screenWidth = cameraUniforms.cameraWidth;
    let screenHeight = cameraUniforms.cameraHeight;

    // find x and y cluster
    let clipPos = cameraUniforms.viewProjMat * vec4f(pos, 1.0);
    let ndcPos = clipPos.xyz / clipPos.w;
    var xCluster = u32(in.fragPos.x / screenWidth * f32(${numClustersX})); 
    var yCluster = u32(in.fragPos.y / screenHeight * f32(${numClustersY})); 
    // var xCluster = u32((ndcPos.x + 1.0) * 0.5 * f32(${numClustersX})); 
    // var yCluster = u32((ndcPos.y + 1.0) * 0.5 * f32(${numClustersY})); 
    xCluster = clamp(xCluster, 0u, ${numClustersX} - 1u); 
    yCluster = clamp(yCluster, 0u, ${numClustersY} - 1u);
    
    // find z cluster
    let near = f32(cameraUniforms.nearPlane);
    let far = f32(cameraUniforms.farPlane);
    let viewZ = max(-view.z, 1e-4);
    var zCluster = u32(log2(viewZ / near) / log2(far / near) * f32(${numClustersZ}));
    zCluster = clamp(zCluster, 0u, ${numClustersZ} - 1u);

    // Determine which cluster contains the current fragment.
    let clusterIndex = xCluster + yCluster * ${numClustersX}u + zCluster * ${numClustersX}u * ${numClustersY}u;
    
    // Retrieve the number of lights that affect the current fragment from the cluster’s data.
    let numLights = clusterSet.clusters[clusterIndex].numLights;

    // Initialize a variable to accumulate the total light contribution for the fragment.
    var totalLightContrib = vec3f(0, 0, 0);

    // For each light in the cluster:
    for (var i = 0u; i < numLights; i++) {
        // Access the light's properties using its index.
        let lightIdx = clusterSet.clusters[clusterIndex].lights[i];
        let light = lightSet.lights[lightIdx];

        // Calculate the contribution of the light based on its position, the fragment’s position, and the surface normal.
        // Add the calculated contribution to the total light accumulation.
        totalLightContrib += calculateLightContrib(light, pos, normalize(nor));
    }

    // Multiply the fragment’s diffuse color by the accumulated light contribution.
    var finalColor = col * totalLightContrib;

    // Return the final color, ensuring that the alpha component is set appropriately (typically to 1).
    return vec4f(finalColor, 1.0);

}