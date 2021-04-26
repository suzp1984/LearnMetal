//
//  Renderer.m
//  Bloom
//
//  Created by Jacob Su on 4/8/21.
//

#import <Foundation/Foundation.h>
#import "Renderer.h"
#import <common/common.h>
#import "ShaderType.h"
@import MetalKit;

@implementation Renderer
{
    id<MTLDevice> _device;
    id<MTLDepthStencilState> _depthState;
    MTKMesh *_cubeMesh;
    id<MTLRenderPipelineState> _renderPipelineState;
    id<MTLRenderPipelineState> _lightPipelineState;
    id<MTLRenderPipelineState> _blurPipelineState;
    id<MTLRenderPipelineState> _quadPipelineState;
    id<MTLRenderPipelineState> _bloomPipelineState;
    id<MTLTexture> _colorTexture;
    id<MTLTexture> _lightTexture;
    id<MTLTexture> _pingpongTextures[2];
    MTLViewport _viewport;
    id<MTLBuffer> _quadVertexBuffer;
    id<MTLTexture> _woodTexture;
    id<MTLTexture> _containerTexture;
    id<MTLBuffer> _lightsBuffer;
    int _lightsCount;
    Uniforms _uniforms;
    id<Camera> _camera;
    SatelliteCameraController *_cameraController;
    matrix_float4x4 modelsMatrixes[7];
    matrix_float3x3 normalMatrixes[7];
    matrix_float4x4 lightModelMatrixes[4];
    matrix_float3x3 lightNormalMatrixes[4];
    Light _lights[4];
    id<MTLCommandQueue> _commandQueue;
}


- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView {
    self = [super init];
    
    if (self) {
        _device = mtkView.device;
        mtkView.delegate = self;
        _bloom = true;
        _exposure = 1.0;
        
        mtkView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
        mtkView.clearDepth = 1.0;
        
        _camera = [[SimpleCamera alloc] initWithPosition:(vector_float3) {0.0, 0.0, 5.0}
                                              withTarget:(vector_float3) {0.0, 0.0, 0.0}
                                                      up:true];
        _cameraController = [[SatelliteCameraController alloc] initWithCamera:_camera];
        
        
        MTLDepthStencilDescriptor *depthDescriptor = [MTLDepthStencilDescriptor new];
        depthDescriptor.depthCompareFunction = MTLCompareFunctionLessEqual;
        depthDescriptor.depthWriteEnabled = TRUE;
        
        _depthState = [_device newDepthStencilStateWithDescriptor:depthDescriptor];
        
        MTLVertexDescriptor *mtlVertexDescriptor = [[MTLVertexDescriptor alloc] init];
        // position
        mtlVertexDescriptor.attributes[ModelVertexAttributePosition].format = MTLVertexFormatFloat3;
        mtlVertexDescriptor.attributes[ModelVertexAttributePosition].offset = 0;
        mtlVertexDescriptor.attributes[ModelVertexAttributePosition].bufferIndex = VertexInputIndexPosition;
        
        // normal
        mtlVertexDescriptor.attributes[ModelVertexAttributeNormal].format = MTLVertexFormatFloat3;
        mtlVertexDescriptor.attributes[ModelVertexAttributeNormal].offset = 16;
        mtlVertexDescriptor.attributes[ModelVertexAttributeNormal].bufferIndex = VertexInputIndexPosition;
        
        // texture coordinate
        mtlVertexDescriptor.attributes[ModelVertexAttributeTexCoord].format = MTLVertexFormatFloat2;
        mtlVertexDescriptor.attributes[ModelVertexAttributeTexCoord].offset = 32;
        mtlVertexDescriptor.attributes[ModelVertexAttributeTexCoord].bufferIndex = VertexInputIndexPosition;
        
        // layout
        mtlVertexDescriptor.layouts[VertexInputIndexPosition].stride = 48;
        mtlVertexDescriptor.layouts[VertexInputIndexPosition].stepRate = 1;
        mtlVertexDescriptor.layouts[VertexInputIndexPosition].stepFunction = MTLVertexStepFunctionPerVertex;
        
        NSError *error;
        _cubeMesh = [MTKMesh newBoxWithVertexDescriptor:mtlVertexDescriptor
                                      withAttributesMap:@{
            [NSNumber numberWithInt:ModelVertexAttributePosition] : MDLVertexAttributePosition,
            [NSNumber numberWithInt:ModelVertexAttributeNormal]   : MDLVertexAttributeNormal,
            [NSNumber numberWithInt:ModelVertexAttributeTexCoord] : MDLVertexAttributeTextureCoordinate }
                                             withDevice:_device
                                         withDimensions:(vector_float3) { 2.0, 2.0, 2.0 }
                                               segments:(vector_uint3) {1, 1, 1}
                                           geometryType:MDLGeometryTypeTriangles
                                          inwardNormals:FALSE
                                                  error:&error];
        
        UInt width = mtkView.frame.size.width;
        UInt height = mtkView.frame.size.height;
        
        _colorTexture = [self createTextureWithWidth:width height:height];
        _lightTexture = [self createTextureWithWidth:width height:height];
        _pingpongTextures[0] = [self createTextureWithWidth:width height:height];
        _pingpongTextures[1] = [self createTextureWithWidth:width height:height];
        
        id<MTLLibrary> library = [_device newDefaultLibrary];
        id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertexShader"];
        id<MTLFunction> fragmentFunc = [library newFunctionWithName:@"fragmentShader"];
        
        MTLRenderPipelineDescriptor *renderPipelineDescriptor = [MTLRenderPipelineDescriptor new];
        renderPipelineDescriptor.vertexDescriptor = mtlVertexDescriptor;
        renderPipelineDescriptor.vertexFunction = vertexFunc;
        renderPipelineDescriptor.fragmentFunction = fragmentFunc;
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float;
        renderPipelineDescriptor.colorAttachments[1].pixelFormat = MTLPixelFormatRGBA16Float;
        renderPipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat;
        
        _renderPipelineState = [_device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor error:&error];
        NSAssert(_renderPipelineState, @"can not create render pipeline state: %@", error);
        
        id<MTLFunction> lightFragmentFunc = [library newFunctionWithName:@"lightFragmentShader"];
        renderPipelineDescriptor.fragmentFunction = lightFragmentFunc;
        
        _lightPipelineState = [_device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor error:&error];
        NSAssert(_lightPipelineState, @"can not create light pipeline state: %@", error);
        
        
        id<MTLFunction> quadVertexfunc = [library newFunctionWithName:@"quadVertexShader"];
        id<MTLFunction> quadFragmentFunc = [library newFunctionWithName:@"quadFragmentShader"];
        
        MTLRenderPipelineDescriptor *quadPipelineDescriptor = [MTLRenderPipelineDescriptor new];
        quadPipelineDescriptor.vertexFunction = quadVertexfunc;
        quadPipelineDescriptor.fragmentFunction = quadFragmentFunc;
        quadPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        quadPipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat;
        
        _quadPipelineState = [_device newRenderPipelineStateWithDescriptor:quadPipelineDescriptor error:&error];
        NSAssert(_quadPipelineState, @"can not create quad pipeline state: %@", error);
        
        id<MTLFunction> blurFragmentFunc = [library newFunctionWithName:@"blurFragmentShader"];
        
        MTLRenderPipelineDescriptor *blurPipelineDescriptor = [MTLRenderPipelineDescriptor new];
        blurPipelineDescriptor.vertexFunction = quadVertexfunc;
        blurPipelineDescriptor.fragmentFunction = blurFragmentFunc;
        blurPipelineDescriptor.colorAttachments[0].pixelFormat = _lightTexture.pixelFormat;
        
        _blurPipelineState = [_device newRenderPipelineStateWithDescriptor:blurPipelineDescriptor error:&error];
        NSAssert(_blurPipelineState, @"can not create blurPipeline state: %@", error);
        
        id<MTLFunction> bloomFragmentFunc = [library newFunctionWithName:@"bloomFragmentShader"];
        
        MTLRenderPipelineDescriptor *bloomPipelineDescriptor = [MTLRenderPipelineDescriptor new];
        bloomPipelineDescriptor.vertexFunction = quadVertexfunc;
        bloomPipelineDescriptor.fragmentFunction = bloomFragmentFunc;
        bloomPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        
        _bloomPipelineState = [_device newRenderPipelineStateWithDescriptor:bloomPipelineDescriptor error:&error];
        NSAssert(_bloomPipelineState, @"can not create bloom pipeline state: %@", error);
        
        _viewport = (MTLViewport) {0.0, 0.0, width, height, 0.0, 1.0};
        
        QuadVertex quadVertices[] = {
            {{-1.0,  1.0}, {0.0, 0.0}},
            {{-1.0, -1.0}, {0.0, 1.0}},
            {{ 1.0,  1.0}, {1.0, 0.0}},
            {{ 1.0, -1.0}, {1.0, 1.0}},
        };
        
        _quadVertexBuffer = [_device newBufferWithBytes:quadVertices
                                                 length:sizeof(quadVertices)
                                                options:MTLResourceStorageModeShared];
        MTKTextureLoader *textureLoader = [[MTKTextureLoader alloc] initWithDevice:_device];
        NSBundle *bundle = [NSBundle bundleForClass:[TextureCubeLoader class]];
        _woodTexture = [textureLoader newTextureWithName:@"wood"
                                      scaleFactor:1.0
                                           bundle:bundle
                                          options:@{ MTKTextureLoaderOptionSRGB: [NSNumber numberWithBool:NO] }
                                            error:&error];
        _containerTexture = [textureLoader newTextureWithName:@"container2"
                                      scaleFactor:1.0
                                           bundle:bundle
                                          options:@{ MTKTextureLoaderOptionSRGB: [NSNumber numberWithBool:NO] }
                                            error:&error];
        
        _lights[0] = (Light) {{ 0.0, 0.5,  1.5}, { 5.0, 5.0, 5.0}};
        _lights[1] = (Light) {{-4.0, 0.5, -3.0}, {10.0, 0.0, 0.0}};
        _lights[2] = (Light) {{ 3.0, 0.5,  1.0}, { 0.0, 0.0, 15.0}};
        _lights[3] = (Light) {{-0.8, 2.4, -1.0}, { 0.0, 5.0, 0.0}};
        
        _lightsCount = 4;
        
        _lightsBuffer = [_device newBufferWithBytes:_lights
                                             length:sizeof(_lights)
                                            options:MTLResourceStorageModeShared];
        _uniforms.projectionMatrix = matrix_perspective_left_hand(M_PI / 4.0,
                                                                  (float)width / (float)height,
                                                                  0.1,
                                                                  100.0);
        _uniforms.viewMatrix = [_camera getViewMatrix];
        
        modelsMatrixes[0] = matrix_multiply(matrix4x4_translation(0.0, -1.0, 0.0),
                                          matrix4x4_scale(12.5, 0.5, 12.5));
        modelsMatrixes[1] = matrix_multiply(matrix4x4_translation(0.0, 1.5, 0.0),
                                          matrix4x4_scale(0.5, 0.5, 0.5));
        modelsMatrixes[2] = matrix_multiply(matrix4x4_translation(2.0, 0.0, 1.0),
                                          matrix4x4_scale(0.5, 0.5, 0.5));
        modelsMatrixes[3] = matrix_multiply(matrix4x4_translation(-1.0, -1.0, 2.0),
                                          matrix4x4_rotation(M_PI * 60.0 / 180.0, 1.0, 0.0, 1.0));
        modelsMatrixes[4] = matrix_multiply(matrix4x4_translation(0.0, 2.7, 4.0),
                                          matrix_multiply(matrix4x4_rotation(M_PI * 23.0 / 180.0, 1.0, 0.0, 1.0),
                                                          matrix4x4_scale(1.25, 1.25, 1.25)));
        modelsMatrixes[5] = matrix_multiply(matrix4x4_translation(-2.0, 1.0, -3.0),
                                          matrix4x4_rotation(M_PI * 124.0 / 180.0, 1.0, 0.0, 1.0));
        modelsMatrixes[6] = matrix_multiply(matrix4x4_translation(-3.0, 0.0, 0.0),
                                          matrix4x4_scale(0.5, 0.5, 0.5));
        for(int i = 0; i < 7; i++) {
            normalMatrixes[i] = simd_transpose(simd_inverse(matrix3x3_upper_left(modelsMatrixes[i])));
        }
        
        for(int i = 0; i < 4; i++) {
            lightModelMatrixes[i] = matrix_multiply(matrix4x4_translation(_lights[i].position),
                                                    matrix4x4_scale(0.25));
            lightNormalMatrixes[i] = simd_transpose(simd_inverse(matrix3x3_upper_left(lightModelMatrixes[i])));
        }
        
        _commandQueue = [_device newCommandQueue];
    }
    
    return self;
}

- (id<MTLTexture>) createTextureWithWidth:(UInt) width height:(UInt)height {
    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor new];
    descriptor.width = width;
    descriptor.height = height;
    descriptor.pixelFormat = MTLPixelFormatRGBA16Float;
    descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    descriptor.storageMode = MTLStorageModePrivate;
    descriptor.textureType = MTLTextureType2D;
    
    id<MTLTexture> texture = [_device newTextureWithDescriptor:descriptor];
    
    return texture;
}

- (void) handleMouseScrollDeltaX:(float) deltaX deltaY:(float) deltaY {
    [_cameraController rotateCameraAroundTargetWithDeltaPhi:deltaX*0.2 deltaTheta:deltaY*0.2];
    
    _uniforms.viewMatrix = [_camera getViewMatrix];
    
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    
    MTLRenderPassDescriptor *colorRenderPassDescriptor = [MTLRenderPassDescriptor new];
    colorRenderPassDescriptor.colorAttachments[0].texture = _colorTexture;
    colorRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    colorRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    colorRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.2, 0.3, 0.3, 1.0);
    colorRenderPassDescriptor.colorAttachments[1].texture = _lightTexture;
    colorRenderPassDescriptor.colorAttachments[1].loadAction = MTLLoadActionClear;
    colorRenderPassDescriptor.colorAttachments[1].storeAction = MTLStoreActionStore;
    colorRenderPassDescriptor.colorAttachments[1].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    colorRenderPassDescriptor.depthAttachment.texture = view.depthStencilTexture;
    colorRenderPassDescriptor.depthAttachment.loadAction = MTLLoadActionClear;
    colorRenderPassDescriptor.depthAttachment.storeAction = MTLStoreActionStore;
    colorRenderPassDescriptor.depthAttachment.clearDepth = 1.0;
    
    id<MTLRenderCommandEncoder> colorRenderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:colorRenderPassDescriptor];
    [colorRenderEncoder setViewport:_viewport];
    [colorRenderEncoder setRenderPipelineState:_renderPipelineState];
    [colorRenderEncoder setDepthStencilState:_depthState];
    [colorRenderEncoder setLabel:@"Color Render"];
    
    for(int i = 0; i < _cubeMesh.vertexBuffers.count; i++) {
        
        [colorRenderEncoder setVertexBuffer:_cubeMesh.vertexBuffers[i].buffer
                                     offset:0
                                    atIndex:VertexInputIndexPosition];
    }
    
    // draw first cube
    _uniforms.modelMatrix = modelsMatrixes[0];
    _uniforms.normalMatrix = normalMatrixes[0];
    [colorRenderEncoder setVertexBytes:&_uniforms length:sizeof(_uniforms) atIndex:VertexInputIndexUniform];
    [colorRenderEncoder setFragmentTexture:_woodTexture atIndex:FragmentInputIndexTexture];
    [colorRenderEncoder setFragmentBuffer:_lightsBuffer offset:0 atIndex:FragmentInputIndexLights];
    [colorRenderEncoder setFragmentBytes:&_lightsCount
                                  length:sizeof(_lightsCount)
                                 atIndex:FragmentInputIndexLightsCount];
    vector_float3 viewPos = _camera.cameraPosition;
    [colorRenderEncoder setFragmentBytes:&viewPos
                                  length:sizeof(viewPos)
                                 atIndex:FragmentInputIndexViewPos];
    
    for (int i = 0; i < _cubeMesh.submeshes.count; i++) {
        [colorRenderEncoder drawIndexedPrimitives:_cubeMesh.submeshes[i].primitiveType
                                       indexCount:_cubeMesh.submeshes[i].indexCount
                                        indexType:_cubeMesh.submeshes[i].indexType
                                      indexBuffer:_cubeMesh.submeshes[i].indexBuffer.buffer
                                indexBufferOffset:_cubeMesh.submeshes[i].indexBuffer.offset];
    }
    
    // draw another cubes
    [colorRenderEncoder setFragmentTexture:_containerTexture atIndex:FragmentInputIndexTexture];
    
    for (int i = 1; i < 7; i++) {
        _uniforms.modelMatrix = modelsMatrixes[i];
        _uniforms.normalMatrix = normalMatrixes[i];
        
        [colorRenderEncoder setVertexBytes:&_uniforms length:sizeof(_uniforms) atIndex:VertexInputIndexUniform];
        
        for (int i = 0; i < _cubeMesh.submeshes.count; i++) {
            [colorRenderEncoder drawIndexedPrimitives:_cubeMesh.submeshes[i].primitiveType
                                           indexCount:_cubeMesh.submeshes[i].indexCount
                                            indexType:_cubeMesh.submeshes[i].indexType
                                          indexBuffer:_cubeMesh.submeshes[i].indexBuffer.buffer
                                    indexBufferOffset:_cubeMesh.submeshes[i].indexBuffer.offset];
        }
    }
    
    [colorRenderEncoder endEncoding];
    
    // draw lights
    MTLRenderPassDescriptor *lightRenderPassDescriptor = [MTLRenderPassDescriptor new];
    lightRenderPassDescriptor.colorAttachments[0].texture = _colorTexture;
    lightRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionDontCare;
    lightRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    lightRenderPassDescriptor.colorAttachments[1].texture = _lightTexture;
    lightRenderPassDescriptor.colorAttachments[1].loadAction = MTLLoadActionDontCare;
    lightRenderPassDescriptor.colorAttachments[1].storeAction = MTLStoreActionStore;
    lightRenderPassDescriptor.depthAttachment.texture = view.depthStencilTexture;
    lightRenderPassDescriptor.depthAttachment.loadAction = MTLLoadActionDontCare;
    lightRenderPassDescriptor.depthAttachment.storeAction = MTLStoreActionDontCare;
    lightRenderPassDescriptor.depthAttachment.clearDepth = 1.0;
    
    id<MTLRenderCommandEncoder> lightRenderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:lightRenderPassDescriptor];
    [lightRenderEncoder setViewport:_viewport];
    [lightRenderEncoder setRenderPipelineState:_lightPipelineState];
    [lightRenderEncoder setDepthStencilState:_depthState];
    [lightRenderEncoder setLabel:@"light Render"];
    
    for(int i = 0; i < _cubeMesh.vertexBuffers.count; i++) {
        
        [lightRenderEncoder setVertexBuffer:_cubeMesh.vertexBuffers[i].buffer
                                     offset:0
                                    atIndex:VertexInputIndexPosition];
    }
    
    for (int i = 0; i < _lightsCount; i++) {
        _uniforms.modelMatrix = lightModelMatrixes[i];
        _uniforms.normalMatrix = lightNormalMatrixes[i];
        
        [lightRenderEncoder setVertexBytes:&_uniforms length:sizeof(_uniforms) atIndex:VertexInputIndexUniform];
        
        [lightRenderEncoder setFragmentBytes:&(_lights[i].color) length:sizeof(_lights[i].color) atIndex:0];
        
        for (int i = 0; i < _cubeMesh.submeshes.count; i++) {
            [lightRenderEncoder drawIndexedPrimitives:_cubeMesh.submeshes[i].primitiveType
                                           indexCount:_cubeMesh.submeshes[i].indexCount
                                            indexType:_cubeMesh.submeshes[i].indexType
                                          indexBuffer:_cubeMesh.submeshes[i].indexBuffer.buffer
                                    indexBufferOffset:_cubeMesh.submeshes[i].indexBuffer.offset];
        }
    }
    
    [lightRenderEncoder endEncoding];
    
    // blur rendering
    bool horizontal = true;
    for (int i = 0; i < 10; i++) {
        MTLRenderPassDescriptor *blurRenderPassDescriptor = [MTLRenderPassDescriptor new];
        blurRenderPassDescriptor.colorAttachments[0].texture = _pingpongTextures[horizontal ? 0 : 1];
        blurRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
        blurRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        blurRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        
        id<MTLRenderCommandEncoder> blurRenderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:blurRenderPassDescriptor];
        [blurRenderEncoder setViewport:_viewport];
        [blurRenderEncoder setRenderPipelineState:_blurPipelineState];
        
        [blurRenderEncoder setVertexBuffer:_quadVertexBuffer offset:0 atIndex:QuadVertexIndexPosition];
        
        if (i == 0) {
            [blurRenderEncoder setFragmentTexture:_lightTexture atIndex:0];
        } else {
            [blurRenderEncoder setFragmentTexture:_pingpongTextures[horizontal ? 1 : 0] atIndex:0];
        }
        
        vector_float2 textureSize = { _viewport.width, _viewport.height };
        [blurRenderEncoder setFragmentBytes:&textureSize length:sizeof(textureSize) atIndex:1];
        int isHorizental = horizontal ? 1 : 0;
        [blurRenderEncoder setFragmentBytes:&isHorizental length:sizeof(isHorizental) atIndex:2];
        [blurRenderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
        [blurRenderEncoder endEncoding];
        horizontal = !horizontal;
    }
    
    
    // draw bloom .quad
    MTLRenderPassDescriptor *bloomRenderPassDescriptor = [MTLRenderPassDescriptor new];
    bloomRenderPassDescriptor.colorAttachments[0].texture = view.currentDrawable.texture;
    bloomRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    bloomRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    
    id<MTLRenderCommandEncoder> bloomRenderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:bloomRenderPassDescriptor];
    [bloomRenderEncoder setViewport:_viewport];
    [bloomRenderEncoder setRenderPipelineState:_bloomPipelineState];
    
    [bloomRenderEncoder setVertexBuffer:_quadVertexBuffer offset:0 atIndex:QuadVertexIndexPosition];
    [bloomRenderEncoder setFragmentTexture:_colorTexture atIndex:0];
    [bloomRenderEncoder setFragmentTexture:_pingpongTextures[!horizontal ? 1 : 0] atIndex:1];

    [bloomRenderEncoder setFragmentBytes:&_bloom length:sizeof(_bloom) atIndex:2];
    [bloomRenderEncoder setFragmentBytes:&_exposure length:sizeof(_exposure) atIndex:3];
    [bloomRenderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    [bloomRenderEncoder endEncoding];
    
//    MTLRenderPassDescriptor *quadRenderPassDescriptor = [MTLRenderPassDescriptor new];
//    quadRenderPassDescriptor.colorAttachments[0].texture = view.currentDrawable.texture;
//    quadRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
//    quadRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
//    quadRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
//    quadRenderPassDescriptor.depthAttachment.texture = view.depthStencilTexture;
//    quadRenderPassDescriptor.depthAttachment.clearDepth = 1.0;
//
//    id<MTLRenderCommandEncoder> quadRenderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:quadRenderPassDescriptor];
//    [quadRenderEncoder setViewport:_viewport];
//    [quadRenderEncoder setRenderPipelineState:_quadPipelineState];
//    [quadRenderEncoder setVertexBuffer:_quadVertexBuffer offset:0 atIndex:QuadVertexIndexPosition];
//    [quadRenderEncoder setFragmentTexture:_pingpongTextures[0] atIndex:0];
//
//    [quadRenderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
//    [quadRenderEncoder endEncoding];
    
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    _colorTexture = [self createTextureWithWidth:size.width height:size.height];
    _lightTexture = [self createTextureWithWidth:size.width height:size.height];
    _pingpongTextures[0] = [self createTextureWithWidth:size.width height:size.height];
    _pingpongTextures[1] = [self createTextureWithWidth:size.width height:size.height];
    
    _viewport.width = size.width;
    _viewport.height = size.height;
    
    _uniforms.projectionMatrix = matrix_perspective_left_hand(M_PI / 4.0,
                                                              (float) size.width / (float) size.height,
                                                              0.1,
                                                              100.0);
}

@end
