//
//  Renderer.m
//  IBLSpecular
//
//  Created by Jacob Su on 4/19/21.
//

#import <Foundation/Foundation.h>
#import "Renderer.h"
#import "ShaderType.h"
#import <common/common.h>

#define CUBE_MAP_SIZE 512
#define IRRADIANCE_CUBE_MAP_SIZE 32
#define PREFILTER_MAP_SIZE 128

@implementation Renderer
{
    id<MTLDevice> _device;
    id<Camera> _camera;
    SatelliteCameraController *_cameraController;
    id<MTLCommandQueue> _commandQueue;
    id<MTLTexture> _hdrTexture;
    id<MTLTexture> _cubeEnvTexture;
    id<MTLTexture> _irradianceTexture;
    id<MTLTexture> _preFilterTexture;
    id<MTLTexture> _brdfLUTexture;
    id<MTLDepthStencilState> _depthState;
    
    MTKMesh *_sphereMesh;
    MTKMesh *_cubeMesh;
    id<MTLRenderPipelineState> _cubeMapPipelineState;
    id<MTLRenderPipelineState> _irradiancePipelineState;
    id<MTLRenderPipelineState> _backgroundPipelineState;
    id<MTLRenderPipelineState> _pbrRenderPipelineState;
    id<MTLRenderPipelineState> _prefilterPipelineState;
    id<MTLRenderPipelineState> _brdfPipelineState;
    id<MTLBuffer> _quadVertexBuffer;
    id<MTLBuffer> _instanceParamsBuffer;
    Uniforms _uniform;
    MTLViewport _viewport;
    Material _material;
    Light _lights[4];
    id<MTLBuffer> _argumentBuffer;
}


- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView {
    self = [super init];
    if (self) {
        _device = mtkView.device;
        mtkView.delegate = self;
        mtkView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
        mtkView.clearDepth = 1.0;
        
        _camera = [[SimpleCamera alloc] initWithPosition:(vector_float3) {0.0, 0.0, 10.0}
                                              withTarget:(vector_float3) {0.0, 0.0, 0.0}
                                                      up:YES];
        _cameraController = [[SatelliteCameraController alloc] initWithCamera:_camera];
        
        _commandQueue = [_device newCommandQueue];
        
        _hdrTexture = [self loadHdrTexture:_commandQueue];
        
        MTLTextureDescriptor *cubeTextureDescriptor = [MTLTextureDescriptor
                                                       textureCubeDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
                                                       size:CUBE_MAP_SIZE
                                                       mipmapped:false];
        cubeTextureDescriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        cubeTextureDescriptor.storageMode = MTLStorageModePrivate;
        
        _cubeEnvTexture = [_device newTextureWithDescriptor:cubeTextureDescriptor];
        
        MTLTextureDescriptor *irradianceTextureDescriptor = [MTLTextureDescriptor
                                                       textureCubeDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
                                                       size:IRRADIANCE_CUBE_MAP_SIZE
                                                       mipmapped:false];
        irradianceTextureDescriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        irradianceTextureDescriptor.storageMode = MTLStorageModePrivate;
        _irradianceTexture = [_device newTextureWithDescriptor:irradianceTextureDescriptor];
        
        MTLTextureDescriptor *prefilterTextureDescriptor = [MTLTextureDescriptor
                                                            textureCubeDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
                                                            size:PREFILTER_MAP_SIZE
                                                            mipmapped:false];
        prefilterTextureDescriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        prefilterTextureDescriptor.storageMode = MTLStorageModePrivate;
        _preFilterTexture = [_device newTextureWithDescriptor:prefilterTextureDescriptor];
        
        MTLTextureDescriptor *brdfTextureDescriptor = [MTLTextureDescriptor
                                                       texture2DDescriptorWithPixelFormat:MTLPixelFormatRG16Float
                                                       width:CUBE_MAP_SIZE
                                                       height:CUBE_MAP_SIZE
                                                       mipmapped:false];
        brdfTextureDescriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        brdfTextureDescriptor.storageMode = MTLStorageModePrivate;
        _brdfLUTexture = [_device newTextureWithDescriptor:brdfTextureDescriptor];
        
        MTLDepthStencilDescriptor *depthDescriptor = [MTLDepthStencilDescriptor new];
        depthDescriptor.depthCompareFunction = MTLCompareFunctionLessEqual;
        [depthDescriptor setDepthWriteEnabled:true];
        
        _depthState = [_device newDepthStencilStateWithDescriptor:depthDescriptor];
        
        MTLVertexDescriptor *mtlVertexDescriptor = [MTLVertexDescriptor new];
        // position
        mtlVertexDescriptor.attributes[ModelVertexAttributePosition].format = MTLVertexFormatFloat3;
        mtlVertexDescriptor.attributes[ModelVertexAttributePosition].offset = 0;
        mtlVertexDescriptor.attributes[ModelVertexAttributePosition].bufferIndex = VertexInputIndexPosition;

        // texture coordinate
        mtlVertexDescriptor.attributes[ModelVertexAttributeTexcoord].format = MTLVertexFormatFloat2;
        mtlVertexDescriptor.attributes[ModelVertexAttributeTexcoord].offset = 16;
        mtlVertexDescriptor.attributes[ModelVertexAttributeTexcoord].bufferIndex = VertexInputIndexPosition;

        // normal
        mtlVertexDescriptor.attributes[ModelVertexAttributeNormal].format = MTLVertexFormatFloat3;
        mtlVertexDescriptor.attributes[ModelVertexAttributeNormal].offset = 32;
        mtlVertexDescriptor.attributes[ModelVertexAttributeNormal].bufferIndex = VertexInputIndexPosition;

        // layout
        mtlVertexDescriptor.layouts[VertexInputIndexPosition].stride = 48;
        mtlVertexDescriptor.layouts[VertexInputIndexPosition].stepRate = 1;
        mtlVertexDescriptor.layouts[VertexInputIndexPosition].stepFunction = MTLVertexStepFunctionPerVertex;
        
        NSDictionary *attributeMap = @{
            [NSNumber numberWithInt:ModelVertexAttributePosition]: MDLVertexAttributePosition,
            [NSNumber numberWithInt:ModelVertexAttributeNormal]: MDLVertexAttributeNormal,
            [NSNumber numberWithInt:ModelVertexAttributeTexcoord]: MDLVertexAttributeTextureCoordinate
        };
        
        NSError *error;
        _sphereMesh = [MTKMesh newSphereWithVertexDescriptor:mtlVertexDescriptor
                                           withAttributesMap:attributeMap
                                                  withDevice:_device
                                                       radii:1.0
                                              radialSegments:60
                                            verticalSegments:60
                                                geometryType:MDLGeometryTypeTriangles
                                               inwardNormals:NO
                                                  hemisphere:NO
                                                       error:&error];
        NSAssert(_sphereMesh, @"create sphere mesh error: %@", error);
        
        _cubeMesh = [MTKMesh newBoxWithVertexDescriptor:mtlVertexDescriptor
                                      withAttributesMap:attributeMap
                                             withDevice:_device
                                         withDimensions:(vector_float3) {2.0, 2.0, 2.0}
                                               segments:(vector_uint3) {1, 1, 1}
                                           geometryType:MDLGeometryTypeTriangles
                                          inwardNormals:false
                                                  error:&error];
        NSAssert(_cubeMesh, @"create cube mesh error: %@", error);
        
        id<MTLLibrary> library = [_device newDefaultLibrary];
        id<MTLFunction> cubeVertexFunc = [library newFunctionWithName:@"cubeMapVertexShader"];
        id<MTLFunction> cubeFragmentFunc = [library newFunctionWithName:@"cubeMapFragmentShader"];
        
        MTLRenderPipelineDescriptor *cubeRenderDescriptor = [MTLRenderPipelineDescriptor new];
        cubeRenderDescriptor.vertexDescriptor = mtlVertexDescriptor;
        cubeRenderDescriptor.vertexFunction = cubeVertexFunc;
        cubeRenderDescriptor.fragmentFunction = cubeFragmentFunc;
        cubeRenderDescriptor.colorAttachments[0].pixelFormat = _cubeEnvTexture.pixelFormat;
        cubeRenderDescriptor.inputPrimitiveTopology = MTLPrimitiveTopologyClassTriangle;
        
        _cubeMapPipelineState = [_device newRenderPipelineStateWithDescriptor:cubeRenderDescriptor
                                                                        error:&error];
        NSAssert(_cubeMapPipelineState, @"CubeMap Pipeline State Error: %@", error);

        id<MTLFunction> irradianceFragmentFunc = [library newFunctionWithName:@"irradianceFragmentShader"];
        MTLRenderPipelineDescriptor *irradianceDescriptor = [MTLRenderPipelineDescriptor new];
        irradianceDescriptor.vertexDescriptor = mtlVertexDescriptor;
        irradianceDescriptor.vertexFunction = cubeVertexFunc;
        irradianceDescriptor.fragmentFunction = irradianceFragmentFunc;
        irradianceDescriptor.colorAttachments[0].pixelFormat = _irradianceTexture.pixelFormat;
        irradianceDescriptor.inputPrimitiveTopology = MTLPrimitiveTopologyClassTriangle;
        
        _irradiancePipelineState = [_device newRenderPipelineStateWithDescriptor:irradianceDescriptor
                                                                           error:&error];
        NSAssert(_irradiancePipelineState, @"irradiance pipeline state create error: %@", error);
        
        id<MTLFunction> bgVertexFunc = [library newFunctionWithName:@"backgroundVertexShader"];
        id<MTLFunction> bgFragmentFunc = [library newFunctionWithName:@"backgroundFragmentShader"];
        
        MTLRenderPipelineDescriptor *bgRenderDescriptor = [MTLRenderPipelineDescriptor new];
        bgRenderDescriptor.vertexDescriptor = mtlVertexDescriptor;
        bgRenderDescriptor.vertexFunction = bgVertexFunc;
        bgRenderDescriptor.fragmentFunction = bgFragmentFunc;
        bgRenderDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        bgRenderDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat;
        
        _backgroundPipelineState = [_device newRenderPipelineStateWithDescriptor:bgRenderDescriptor
                                                                           error:&error];
        NSAssert(_backgroundPipelineState, @"background pipeline state error: %@", error);

        id<MTLFunction> pbrVertexFunc = [library newFunctionWithName:@"pbrVertexShader"];
        id<MTLFunction> pbrFragmentFunc = [library newFunctionWithName:@"pbrFragmentShader"];
        MTLRenderPipelineDescriptor *pbrRenderDescriptor = [MTLRenderPipelineDescriptor new];
        pbrRenderDescriptor.vertexDescriptor = mtlVertexDescriptor;
        pbrRenderDescriptor.vertexFunction = pbrVertexFunc;
        pbrRenderDescriptor.fragmentFunction = pbrFragmentFunc;
        pbrRenderDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        pbrRenderDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat;
        
        _pbrRenderPipelineState = [_device newRenderPipelineStateWithDescriptor:pbrRenderDescriptor
                                                                          error:&error];
        NSAssert(_pbrRenderPipelineState, @"create pbr pipeline state error: %@", error);
        
        id<MTLFunction> preFilterFragmentFunc = [library newFunctionWithName:@"preFilterFragmentShader"];
        
        MTLRenderPipelineDescriptor *preFilterRenderDescriptor = [MTLRenderPipelineDescriptor new];
        preFilterRenderDescriptor.vertexDescriptor = mtlVertexDescriptor;
        preFilterRenderDescriptor.vertexFunction = cubeVertexFunc;
        preFilterRenderDescriptor.fragmentFunction = preFilterFragmentFunc;
        preFilterRenderDescriptor.colorAttachments[0].pixelFormat = _preFilterTexture.pixelFormat;
        preFilterRenderDescriptor.inputPrimitiveTopology = MTLPrimitiveTopologyClassTriangle;
        
        _prefilterPipelineState = [_device newRenderPipelineStateWithDescriptor:preFilterRenderDescriptor error:&error];
        NSAssert(_prefilterPipelineState, @"create prefilter pipeline state error: %@", error);
        
        id<MTLFunction> brdfVertexFunc = [library newFunctionWithName:@"brdfVertexShader"];
        id<MTLFunction> brdfFragmentFunc = [library newFunctionWithName:@"brdfFragmentShader"];
        MTLRenderPipelineDescriptor *brdfPipelineDescriptor = [MTLRenderPipelineDescriptor new];
        brdfPipelineDescriptor.vertexFunction = brdfVertexFunc;
        brdfPipelineDescriptor.fragmentFunction = brdfFragmentFunc;
        brdfPipelineDescriptor.colorAttachments[0].pixelFormat = _brdfLUTexture.pixelFormat;
        
        _brdfPipelineState = [_device newRenderPipelineStateWithDescriptor:brdfPipelineDescriptor
                                                                     error:&error];
        NSAssert(_brdfPipelineState, @"create brdf pipeline state error: %@", error);
        
        QuadVertex quadVerties[] = {
            {{-1.0,  1.0}, {0.0, 0.0}},
            {{-1.0, -1.0}, {0.0, 1.0}},
            {{ 1.0,  1.0}, {1.0, 0.0}},
            {{ 1.0, -1.0}, {1.0, 1.0}},
        };
        
        _quadVertexBuffer = [_device newBufferWithBytes:quadVerties
                                                 length:sizeof(quadVerties)
                                                options:MTLResourceStorageModeShared];
    
        CubeMapParams instanceCubeMapParams[] = {
            { matrix_look_at_right_hand((vector_float3) { 0.0,  0.0, 0.0},
                                        (vector_float3) {-1.0,  0.0, 0.0},
                                        (vector_float3) { 0.0, -1.0, 0.0}), 0},
            { matrix_look_at_right_hand((vector_float3) {0.0,  0.0, 0.0},
                                        (vector_float3) {1.0,  0.0, 0.0},
                                        (vector_float3) {0.0, -1.0, 0.0}), 1},
            { matrix_look_at_right_hand((vector_float3) {0.0, 0.0, 0.0},
                                        (vector_float3) {0.0, 1.0, 0.0},
                                        (vector_float3) {0.0, 0.0, 1.0}), 2},
            { matrix_look_at_right_hand((vector_float3) {0.0,  0.0,  0.0},
                                        (vector_float3) {0.0, -1.0,  0.0},
                                        (vector_float3) {0.0,  0.0, -1.0}), 3},
            { matrix_look_at_right_hand((vector_float3) {0.0,  0.0, 0.0},
                                        (vector_float3) {0.0,  0.0, 1.0},
                                        (vector_float3) {0.0, -1.0, 0.0}), 4},
            { matrix_look_at_right_hand((vector_float3) {0.0, 0.0,  0.0},
                                        (vector_float3) {0.0, 0.0, -1.0},
                                        (vector_float3) {0.0, -1.0, 0.0}), 5}
        };
        
        _instanceParamsBuffer = [_device newBufferWithBytes:instanceCubeMapParams
                                                     length:sizeof(instanceCubeMapParams)
                                                    options:MTLResourceStorageModeShared];
        
        id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
        
        MTLRenderPassDescriptor *cubeMapRenderDescriptor = [MTLRenderPassDescriptor new];
        cubeMapRenderDescriptor.colorAttachments[0].texture = _cubeEnvTexture;
        cubeMapRenderDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        cubeMapRenderDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        cubeMapRenderDescriptor.renderTargetArrayLength = 6;
        
        id<MTLRenderCommandEncoder> cubeMapRenderEncoder = [commandBuffer
                                                            renderCommandEncoderWithDescriptor:cubeMapRenderDescriptor];
        [cubeMapRenderEncoder setViewport:(MTLViewport){0.0, 0.0, CUBE_MAP_SIZE, CUBE_MAP_SIZE, 0.0, 1.0}];
        [cubeMapRenderEncoder setRenderPipelineState:_cubeMapPipelineState];
        [_cubeMesh setVertexBufferInRenderCommandEncoder:cubeMapRenderEncoder index:CubeMapVertexIndexPosition];
        matrix_float4x4 cubemapProjection = matrix_perspective_left_hand(M_PI / 2.0, 1.0, 0.1, 10.0);
        [cubeMapRenderEncoder setVertexBytes:&cubemapProjection
                                      length:sizeof(cubemapProjection)
                                     atIndex:CubeMapVertexIndexProjection];
        [cubeMapRenderEncoder setVertexBuffer:_instanceParamsBuffer
                                       offset:0
                                      atIndex:CubeMapVertexIndexInstanceParams];
        [cubeMapRenderEncoder setFragmentTexture:_hdrTexture atIndex:0];
        [_cubeMesh drawInRenderCommandEncoder:cubeMapRenderEncoder instanceCount:6];
        [cubeMapRenderEncoder endEncoding];

        // irradiance
        MTLRenderPassDescriptor *irradianceRenderDescriptor = [MTLRenderPassDescriptor new];
        irradianceRenderDescriptor.colorAttachments[0].texture = _irradianceTexture;
        irradianceRenderDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        irradianceRenderDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        irradianceRenderDescriptor.renderTargetArrayLength = 6;
        
        id<MTLRenderCommandEncoder> irradianceEncoder = [commandBuffer renderCommandEncoderWithDescriptor:irradianceRenderDescriptor];
        [irradianceEncoder setViewport:(MTLViewport){0.0, 0.0, IRRADIANCE_CUBE_MAP_SIZE, IRRADIANCE_CUBE_MAP_SIZE, 0.0, 1.0}];
        [irradianceEncoder setRenderPipelineState:_irradiancePipelineState];
        [_cubeMesh setVertexBufferInRenderCommandEncoder:irradianceEncoder index:CubeMapVertexIndexPosition];
        [irradianceEncoder setVertexBytes:&cubemapProjection
                                   length:sizeof(cubemapProjection)
                                  atIndex:CubeMapVertexIndexProjection];
        [irradianceEncoder setVertexBuffer:_instanceParamsBuffer offset:0 atIndex:CubeMapVertexIndexInstanceParams];
        [irradianceEncoder setFragmentTexture:_cubeEnvTexture atIndex:0];
        [_cubeMesh drawInRenderCommandEncoder:irradianceEncoder instanceCount:6];
        [irradianceEncoder endEncoding];
        
        // prefilter
        MTLRenderPassDescriptor *prefilterRenderDescriptor = [MTLRenderPassDescriptor new];
        prefilterRenderDescriptor.colorAttachments[0].texture = _preFilterTexture;
        prefilterRenderDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        prefilterRenderDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        prefilterRenderDescriptor.renderTargetArrayLength = 6;
        
        id<MTLRenderCommandEncoder> prefilterEncoder = [commandBuffer renderCommandEncoderWithDescriptor:prefilterRenderDescriptor];
        [prefilterEncoder setViewport:(MTLViewport) {0.0, 0.0, PREFILTER_MAP_SIZE, PREFILTER_MAP_SIZE, 0.0, 1.0}];
        [prefilterEncoder setRenderPipelineState:_prefilterPipelineState];
        [_cubeMesh setVertexBufferInRenderCommandEncoder:prefilterEncoder index:CubeMapVertexIndexPosition];
        [prefilterEncoder setVertexBytes:&cubemapProjection
                                  length:sizeof(cubemapProjection)
                                 atIndex:CubeMapVertexIndexProjection];
        [prefilterEncoder setVertexBuffer:_instanceParamsBuffer offset:0 atIndex:CubeMapVertexIndexInstanceParams];
        [prefilterEncoder setFragmentTexture:_cubeEnvTexture atIndex:0];
        float roughness = 1.0;
        [prefilterEncoder setFragmentBytes:&roughness length:sizeof(roughness) atIndex:1];
        [_cubeMesh drawInRenderCommandEncoder:prefilterEncoder instanceCount:6];
        [prefilterEncoder endEncoding];
        
        // brdf
        MTLRenderPassDescriptor *brdfRenderDescriptor = [MTLRenderPassDescriptor new];
        brdfRenderDescriptor.colorAttachments[0].texture = _brdfLUTexture;
        brdfRenderDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        brdfRenderDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        
        id<MTLRenderCommandEncoder> brdfEncoder = [commandBuffer renderCommandEncoderWithDescriptor:brdfRenderDescriptor];
        [brdfEncoder setViewport:(MTLViewport) {0.0, 0.0, CUBE_MAP_SIZE, CUBE_MAP_SIZE, 0.0, 1.0}];
        [brdfEncoder setRenderPipelineState:_brdfPipelineState];
        [brdfEncoder setVertexBuffer:_quadVertexBuffer offset:0 atIndex:0];
        [brdfEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
        [brdfEncoder endEncoding];
        
        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];
        
        _uniform.modelMatrix = matrix4x4_identity();
        _uniform.viewMatrix = [_camera getViewMatrix];
        int width = mtkView.frame.size.width;
        int height = mtkView.frame.size.height;
        _uniform.projectionMatrix = matrix_perspective_left_hand(M_PI / 4.0, (float) width/(float)height, 0.1, 1000.0);
        _material.albedo = (vector_float3) {0.5, 0.0, 0.0};
        _material.ao = 1.0;
        _material.roughness = 0.0;
        
        _lights[0] = (Light) {{-10.0, 10.0, 10.0 }, { 300.0, 300.0, 300.0 }};
        _lights[1] = (Light) {{ 10.0, 10.0, 10.0 }, { 300.0, 300.0, 300.0 }};
        _lights[2] = (Light) {{-10.0, -10.0, 10.0}, { 300.0, 300.0, 300.0 }};
        _lights[3] = (Light) {{ 10.0, -10.0, 10.0}, { 300.0, 300.0, 300.0 }};
        
    
        id<MTLArgumentEncoder> pbrArgumentEncoder = [pbrFragmentFunc newArgumentEncoderWithBufferIndex:FragmentInputIndexArguments];
        _argumentBuffer = [_device newBufferWithLength:pbrArgumentEncoder.encodedLength options:MTLResourceStorageModeShared];
        _argumentBuffer.label = @"argument";
        
        [pbrArgumentEncoder setArgumentBuffer:_argumentBuffer offset:0];
        [pbrArgumentEncoder setTexture:_irradianceTexture atIndex:PBRArgumentIndexIrradianceMap];
        [pbrArgumentEncoder setTexture:_preFilterTexture atIndex:PBRArgumentIndexPrefilterMap];
        [pbrArgumentEncoder setTexture:_brdfLUTexture atIndex:PBRArgumentIndexBrdfLUT];
        
        _viewport = (MTLViewport) {0.0, 0.0, width, height, 0.0, 1.0};
    }
    
    return self;
}

- (void) handleMouseScrollDeltaX:(float) deltaX deltaY:(float) deltaY {
    [_cameraController rotateCameraAroundTargetWithDeltaPhi:deltaX * 0.2 deltaTheta:deltaY * 0.2];
    
    _uniform.viewMatrix = [_camera getViewMatrix];
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    
    // render pbr
    MTLRenderPassDescriptor *pbrRenderPassDescriptor = view.currentRenderPassDescriptor;
    
    id<MTLRenderCommandEncoder> pbrRenderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:pbrRenderPassDescriptor];
    
    [pbrRenderEncoder setViewport:_viewport];
    [pbrRenderEncoder setRenderPipelineState:_pbrRenderPipelineState];
    [pbrRenderEncoder setDepthStencilState:_depthState];
    
    [_sphereMesh setVertexBufferInRenderCommandEncoder:pbrRenderEncoder index:VertexInputIndexPosition];

    [pbrRenderEncoder setFragmentBytes:_lights length:sizeof(_lights) atIndex:FragmentInputIndexLights];
    int lightsCount = 4;
    [pbrRenderEncoder setFragmentBytes:&lightsCount length:sizeof(lightsCount) atIndex:FragmentInputIndexLightsCount];

    vector_float3 cameraPosition = _camera.cameraPosition;
    [pbrRenderEncoder setFragmentBytes:&cameraPosition
                                length:sizeof(cameraPosition)
                               atIndex:FragmentInputIndexCameraPostion];
    
    [pbrRenderEncoder useResource:_irradianceTexture usage:MTLResourceUsageSample];
    [pbrRenderEncoder useResource:_preFilterTexture usage:MTLResourceUsageSample];
    [pbrRenderEncoder useResource:_brdfLUTexture usage:MTLResourceUsageSample];
    
    [pbrRenderEncoder setFragmentBuffer:_argumentBuffer offset:0 atIndex:FragmentInputIndexArguments];

    for (int row = 0; row < 7; ++row) {
        _material.metallic = (float)row / 7.0;

        for (int col = 0; col < 7; ++col) {
            _material.roughness = MAX(MIN((float) col / 7.0, 1.0), 0.05);
            _uniform.modelMatrix = matrix4x4_translation((col - 7.0 / 2.0) * 2.5,
                                                         (row - 7.0 / 2.0) * 2.5,
                                                         0.0);
            [pbrRenderEncoder setVertexBytes:&_uniform length:sizeof(_uniform) atIndex:VertexInputIndexUniforms];
            [pbrRenderEncoder setFragmentBytes:&_material length:sizeof(_material) atIndex:FragmentInputIndexMaterial];
            [_sphereMesh drawInRenderCommandEncoder:pbrRenderEncoder];
        }
    }
    
    // cube map
    [pbrRenderEncoder setRenderPipelineState:_backgroundPipelineState];
    [_cubeMesh setVertexBufferInRenderCommandEncoder:pbrRenderEncoder index:0];
    [pbrRenderEncoder setVertexBytes:&_uniform length:sizeof(_uniform) atIndex:1];
    [pbrRenderEncoder setFragmentTexture:_cubeEnvTexture atIndex:0];
    [_cubeMesh drawInRenderCommandEncoder:pbrRenderEncoder];
    
    [pbrRenderEncoder endEncoding];
    
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    _viewport.width = size.width;
    _viewport.height = size.height;
    
    _uniform.projectionMatrix = matrix_perspective_left_hand(M_PI / 4.0, (float)size.width / (float)size.height, 0.1, 1000.0);
}

- (id<MTLTexture>) loadHdrTexture:(id<MTLCommandQueue>) commandQueue {
    NSURL *hdrUrl = [[NSBundle common] URLForResource:@"newport_loft.hdr"
                                        withExtension:nil
                                         subdirectory:@"hdr"];
    NSError *error;
    id<MTLTexture> hdrTexture = [HDRTextureLoader loadWithTextureFrom:hdrUrl
                                                 device:_device
                                           commandQueue:commandQueue
                                                  error:&error];
    
    NSAssert(hdrTexture, @"load hdr newport_loft texture error: %@", error);
    
    return hdrTexture;
}

@end
