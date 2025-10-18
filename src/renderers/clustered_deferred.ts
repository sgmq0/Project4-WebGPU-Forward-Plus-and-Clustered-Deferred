import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ClusteredDeferredRenderer extends renderer.Renderer {
    // TODO-3: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution

    gBufferWriteBindGroupLayout: GPUBindGroupLayout;
    gBufferWriteBindGroup: GPUBindGroup;
    gBufferWritePipeline: GPURenderPipeline;

    depthTexture: GPUTexture;
    depthTextureView: GPUTextureView;

    // add extra pipeline stuff needed for deferred
    gBufferReadBindGroupLayout: GPUBindGroupLayout;
    gBufferReadBindGroup: GPUBindGroup;
    gBufferReadPipeline: GPURenderPipeline;

    posTexture: GPUTexture;
    posTextureView: GPUTextureView;
    colTexture: GPUTexture;
    colTextureView: GPUTextureView;
    norTexture: GPUTexture;
    norTextureView: GPUTextureView;

    textureSampler: GPUSampler;

    constructor(stage: Stage) {
        super(stage);

        // TODO-3: initialize layouts, pipelines, textures, etc. needed for Forward+ here
        // you'll need two pipelines: one for the G-buffer pass and one for the fullscreen pass

        // --------- g-buffer render targets -----------
        // depth
        this.depthTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT,
            label: "depth texture"
        });
        this.depthTextureView = this.depthTexture.createView();

        // position
        this.posTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING,
            label: "position texture"
        });
        this.posTextureView = this.posTexture.createView({ label: "gbuffer texture pos" });

        // color
        this.colTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING,
            label: "color texture"
        });
        this.colTextureView = this.colTexture.createView({ label: "gbuffer texture col" });

        // normal
        this.norTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING,
            label: "normal texture"
        });
        this.norTextureView = this.norTexture.createView({ label: "gbuffer texture nor" });

        // texture sampler for all the textures
        this.textureSampler = renderer.device.createSampler({
            label: 'texture sampler',
            magFilter: 'nearest',
            minFilter: 'nearest',
            addressModeU: 'clamp-to-edge',
            addressModeV: 'clamp-to-edge'
        });

        // --------------- initialize bind group layout for g-buffer pass ----------------
        this.gBufferWriteBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "g-buffer write bind group layout",
            entries: [
                {   // camera uniforms
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: {
                        type: "uniform"
                    }
                }, { // lightSet
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { 
                        type: "read-only-storage" 
                    }
                }, { // clusterSet
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { 
                        type: "read-only-storage"
                    }
                }
            ]
        });
        
        // --------------- initialize bind group for g-buffer pass ----------------
        this.gBufferWriteBindGroup = renderer.device.createBindGroup({
            label: "g-buffer write bind group",
            layout: this.gBufferWriteBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: {
                        buffer: this.camera.uniformsBuffer
                    }
                }, {
                    binding: 1,
                    resource: { buffer: this.lights.lightSetStorageBuffer }
                }, {
                    binding: 2,
                    resource: { buffer: this.lights.clusterSetStorageBuffer }
                }
            ]
        });

         // --------------- initialize pipeline for g-buffer pass ----------------
        this.gBufferWritePipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "g-buffer write pipeline layout",
                bindGroupLayouts: [
                    this.gBufferWriteBindGroupLayout,
                    renderer.modelBindGroupLayout,
                    renderer.materialBindGroupLayout
                ]
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "clustered deferred vert shader",
                    code: shaders.naiveVertSrc
                }),
                buffers: [ renderer.vertexBufferLayout ]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "clustered deferred frag shader",
                    code: shaders.clusteredDeferredFragSrc,
                }),
                targets: [
                    { format: 'rgba16float' }, //pos
                    { format: 'rgba16float' }, //col
                    { format: 'rgba16float' }  //nor
                ]
            }
        });


        // initialize pipeline for fullscreen pass. 
        // --------------- initialize bind group layout for fullscreen pass ----------------
        this.gBufferReadBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "scene uniforms bind group layout (forward+)",
            entries: [
                {   // camera uniforms
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: {
                        type: "uniform"
                    }
                }, { // lightSet
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { 
                        type: "read-only-storage" 
                    }
                }, { // clusterSet
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { 
                        type: "read-only-storage"
                    }
                }, {   //pos
                    binding: 3,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {
                        sampleType: 'float',
                    },
                }, {   //col
                    binding: 4,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {
                        sampleType: 'float',
                    },
                }, {   //nor
                    binding: 5,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {
                        sampleType: 'float',
                    },
                },{
                    binding: 6, 
                    visibility: GPUShaderStage.FRAGMENT,
                    sampler: {
                        type: 'filtering'
                    }
                }
            ]
        });

        this.gBufferReadBindGroup = renderer.device.createBindGroup({
            label: "scene uniforms bind group (forward+)",
            layout: this.gBufferReadBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: {
                        buffer: this.camera.uniformsBuffer
                    }
                }, {
                    binding: 1,
                    resource: { buffer: this.lights.lightSetStorageBuffer }
                }, {
                    binding: 2,
                    resource: { buffer: this.lights.clusterSetStorageBuffer }
                }, {
                    binding: 3,
                    resource: this.posTextureView,
                }, {
                    binding: 4,
                    resource: this.colTextureView,
                }, {
                    binding: 5,
                    resource: this.norTextureView,
                }, {
                    binding: 6,
                    resource: this.textureSampler,
                }
            ]
        });

        this.gBufferReadPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "forward+ pipeline layout",
                bindGroupLayouts: [
                    this.gBufferReadBindGroupLayout,
                    renderer.modelBindGroupLayout,
                    renderer.materialBindGroupLayout
                ]
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "forward+ vert shader",
                    code: shaders.clusteredDeferredFullscreenVertSrc
                }),
                buffers: [ renderer.vertexBufferLayout ]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "forward+ frag shader",
                    code: shaders.clusteredDeferredFullscreenFragSrc,
                }),
                targets: [
                    {
                        format: renderer.canvasFormat,
                    }
                ]
            }
        });

    }

    override draw() {
        // TODO-3: run the Forward+ rendering pass:
        // - run the clustering compute shader
        // - run the G-buffer pass, outputting position, albedo, and normals
        // - run the fullscreen pass, which reads from the G-buffer and performs lighting calculations

        const encoder = renderer.device.createCommandEncoder();
        const canvasTextureView = renderer.context.getCurrentTexture().createView();

        // run the clustering compute shader:
        this.lights.doLightClustering(encoder);

        // run the g-buffer pass
        const renderPass = encoder.beginRenderPass({
            label: "forward+ render pass",
            colorAttachments: [
                {
                    view: this.posTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                },
                {
                    view: this.colTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                },
                {
                    view: this.norTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                }
            ],
            depthStencilAttachment: {
                view: this.depthTextureView,
                depthClearValue: 1.0,
                depthLoadOp: "clear",
                depthStoreOp: "store"
            }
        });
        renderPass.setPipeline(this.gBufferWritePipeline);

        renderPass.setBindGroup(shaders.constants.bindGroup_scene, this.gBufferWriteBindGroup);
        
        this.scene.iterate(node => {
            renderPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
        }, material => {
            renderPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
        }, primitive => {
            renderPass.setVertexBuffer(0, primitive.vertexBuffer);
            renderPass.setIndexBuffer(primitive.indexBuffer, 'uint32');
            renderPass.drawIndexed(primitive.numIndices);
        });

        renderPass.end();

        // run the fullscreen pass 
        const pass = encoder.beginRenderPass({
            label: "forward+ render pass",
            colorAttachments: [
                {
                    view: canvasTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                }
            ],
            depthStencilAttachment: {
                view: this.depthTextureView,
                depthClearValue: 1.0,
                depthLoadOp: "clear",
                depthStoreOp: "store"
            }
        });
        pass.setPipeline(this.gBufferReadPipeline);

        pass.setBindGroup(shaders.constants.bindGroup_scene, this.gBufferReadBindGroup);

        this.scene.iterate(node => {
            pass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
        }, material => {
            pass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
        }, primitive => {
            pass.setVertexBuffer(0, primitive.vertexBuffer);
            pass.setIndexBuffer(primitive.indexBuffer, 'uint32');
            pass.drawIndexed(primitive.numIndices);
        });

        pass.end();

        renderer.device.queue.submit([encoder.finish()]);
        
    }
}
