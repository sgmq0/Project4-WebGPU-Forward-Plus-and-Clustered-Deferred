// TODO-2: implement the light clustering compute shader

@group(${bindGroup_scene}) @binding(0) 
var<uniform> cameraUniforms: CameraUniforms;

@group(${bindGroup_scene}) @binding(1) 
var<storage, read_write> clusterSet: ClusterSet;

// ------------------------------------
// Calculating cluster bounds:
// ------------------------------------
// For each cluster (X, Y, Z):
//     - Calculate the screen-space bounds for this cluster in 2D (XY).
//     - Calculate the depth bounds for this cluster in Z (near and far planes).
//     - Convert these screen and depth bounds into view-space coordinates.
//     - Store the computed bounding box (AABB) for the cluster.

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

    // calculate screen space bounds
    let screenWidth = cameraUniforms.cameraWidth;
    let screenHeight = cameraUniforms.cameraHeight;
    let clusterWidth = f32(screenWidth) / f32(${numClustersX});
    let clusterHeight = f32(screenHeight) / f32(${numClustersY});

    let xMin = f32(clusterX) * clusterWidth;
    let xMax = f32(clusterX + 1u) * clusterWidth;
    let yMin = f32(clusterY) * clusterHeight;
    let yMax = f32(clusterY + 1u) * clusterHeight;

    // calculate depth bounds
    let near = 0.1; // near plane
    let far = 100.0; // far plane
    let zMin = near * pow(far / near, f32(clusterZ) / f32(${numClustersZ}));
    let zMax = near * pow(far / near, f32(clusterZ + 1u) / f32(${numClustersZ}));

    let bboxMin = vec3f(xMin, yMin, zMin);
    let bboxMax = vec3f(xMax, yMax, zMax);

    // find view space coordinates
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
