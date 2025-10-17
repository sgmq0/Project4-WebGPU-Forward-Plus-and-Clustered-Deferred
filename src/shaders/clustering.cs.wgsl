// TODO-2: implement the light clustering compute shader

@group(${bindGroup_scene}) @binding(0) 
var<uniform> cameraUniforms: CameraUniforms;

@group(${bindGroup_scene}) @binding(1) 
var<storage, read> lightSet: LightSet;

@group(${bindGroup_scene}) @binding(2) 
var<storage, read_write> clusterSet: ClusterSet;

// ------------------------------------
// Calculating cluster bounds:
// ------------------------------------
// For each cluster (X, Y, Z):
//     - Calculate the screen-space bounds for this cluster in 2D (XY).
//     - Calculate the depth bounds for this cluster in Z (near and far planes).
//     - Convert these screen and depth bounds into view-space coordinates.
//     - Store the computed bounding box (AABB) for the cluster.

// helper function to convert screen space to view space
fn screenToView(screen: vec3f) -> vec3f {
    // convert to NDC
    let ndcX = (screen.x / f32(cameraUniforms.cameraWidth)) * 2.0 - 1.0;
    let ndcY = 1.0 - (screen.y / f32(cameraUniforms.cameraHeight)) * 2.0;
    // this goes from [0,1] to [-1,1]
    let ndcZ =  screen.z * 2.0 - 1.0;

    // convert to view space
    let ndc = vec4f(ndcX, ndcY, ndcZ, 1.0);
    let view = cameraUniforms.invProjMat * ndc;

    // perspective divide
    return view.xyz / view.w; 
}

// helper function to test intersection between sphere and AABB
fn testSphereAABB(bboxMin: vec4f, bboxMax: vec4f, center: vec3f, radius: f32) -> bool {
    var dmin = 0.0;

    for (var i = 0; i < 3; i++) {
        if (center[i] < bboxMin[i]) {
            dmin += (center[i] - bboxMin[i]) * (center[i] - bboxMin[i]);
        } else if (center[i] > bboxMax[i]) {
            dmin += (center[i] - bboxMax[i]) * (center[i] - bboxMax[i]);
        }
    }

    return dmin <= radius * radius;
}

@compute
@workgroup_size(${clusteringWorkgroupSize})
fn main(@builtin(global_invocation_id) globalIdx: vec3u) {
    let clusterX = globalIdx.x;
    let clusterY = globalIdx.y;
    let clusterZ = globalIdx.z;

    if (clusterX >= ${numClustersX}u || clusterY >= ${numClustersY}u || clusterZ >= ${numClustersZ}u) {
        return;
    }

    let clusterIdx = clusterX + clusterY * ${numClustersX}u + clusterZ * ${numClustersX}u * ${numClustersY}u;

    // Calculate the screen-space bounds for this cluster in 2D (XY).
    let screenWidth = cameraUniforms.cameraWidth;
    let screenHeight = cameraUniforms.cameraHeight;
    let clusterWidth = f32(screenWidth) / f32(${numClustersX});
    let clusterHeight = f32(screenHeight) / f32(${numClustersY});

    let xMin = f32(clusterX) * clusterWidth;
    let xMax = f32(clusterX + 1u) * clusterWidth;
    let yMin = f32(clusterY) * clusterHeight;
    let yMax = f32(clusterY + 1u) * clusterHeight;

    // Calculate the depth bounds for this cluster in Z (near and far planes).
    let near = f32(cameraUniforms.nearPlane);
    let far = f32(cameraUniforms.farPlane);
    let zMin = near * pow(far / near, f32(clusterZ) / f32(${numClustersZ}));
    let zMax = near * pow(far / near, f32(clusterZ + 1u) / f32(${numClustersZ}));

    // Convert these screen and depth bounds into view-space coordinates.
    let viewSpacePoints = array<vec3f, 8>(
        screenToView(vec3f(xMin, yMin, zMin)),
        screenToView(vec3f(xMax, yMin, zMin)),
        screenToView(vec3f(xMin, yMax, zMin)),
        screenToView(vec3f(xMax, yMax, zMin)),
        screenToView(vec3f(xMin, yMin, zMax)),
        screenToView(vec3f(xMax, yMin, zMax)),
        screenToView(vec3f(xMin, yMax, zMax)),
        screenToView(vec3f(xMax, yMax, zMax))
    );

    // find min and max point
    var bboxMin = vec3f(1e10, 1e10, 1e10);
    var bboxMax = vec3f(-1e10, -1e10, -1e10);
    for (var i = 0; i < 8; i++) {
        let p = viewSpacePoints[i];
        bboxMin = min(bboxMin, p);
        bboxMax = max(bboxMax, p);
    }

    // Store the computed bounding box (AABB) for the cluster.
    clusterSet.clusters[clusterIdx].AABB_min = vec4f(bboxMin, 1.0);
    clusterSet.clusters[clusterIdx].AABB_max = vec4f(bboxMax, 1.0);

    // Initialize a counter for the number of lights in this cluster.
    var lightCount = 0u;
    let maxLights = ${maxLightsPerCluster}u;
    
    for (var lightIdx = 0u; lightIdx < lightSet.numLights; lightIdx++) {
        // Stop adding lights if the maximum number of lights is reached.
        if (lightCount >= maxLights) {
            break;
        }

        let light = lightSet.lights[lightIdx];
        var lightPosView = cameraUniforms.viewMat * vec4f(light.pos, 1.0);

        // check if the light intersects with the cluster's bounding box
        if (testSphereAABB(clusterSet.clusters[clusterIdx].AABB_min, clusterSet.clusters[clusterIdx].AABB_max, lightPosView.xyz, ${lightRadius})) {
            // If it does, add the light to the cluster's light list
            clusterSet.clusters[clusterIdx].lights[lightCount] = lightIdx;
            lightCount = lightCount + 1u;
        }
    }

    // Store the number of lights assigned to this cluster.
    clusterSet.clusters[clusterIdx].numLights = u32(lightCount);
}

// ------------------------------------
// Assigning lights to clusters:
// ------------------------------------
// For each cluster:
//     - Initialize a counter for the number of lights in this cluster.

//     For each light:
//         - Check if the light intersects with the cluster’s bounding box (AABB).
//         - If it does, add the light to the cluster's light list.
//         - Stop adding lights if the maximum number of lights is reached.

//     - Store the number of lights assigned to this cluster.
