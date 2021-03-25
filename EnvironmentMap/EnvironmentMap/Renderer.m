//
//  Renderer.m
//  4.8.EnvironmentMap
//
//  Created by Jacob Su on 3/24/21.
//

@import MetalKit;
#import <Foundation/Foundation.h>
#import "Renderer.h"
#import <common/common.h>
#import "ShaderType.h"
#include <simd/simd.h>

static const float PI = 3.1415926;

@implementation Renderer
{
    Camera *_camera;
    id<MTLDevice> _device;
    Uniforms _uniform;
    id<MTLTexture> _skyBoxTexture;
    id<MTLTexture> _depthTexture;
    id<MTLRenderPipelineState> _boxRenderPipelineState;
    id<MTLRenderPipelineState> _skyRenderPipelineState;
    id<MTLDepthStencilState> _lessEqualDepthState;
    id<MTLDepthStencilState> _lessDepthState;
    vector_uint2 _viewportSize;
    id<MTLCommandQueue> _commandQueue;
    MTKMesh *_cubeMesh;
    id<MTLBuffer> _skyBoxBuffer;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView {
    self = [super init];
    if (self) {
        _device = mtkView.device;
        mtkView.delegate = self;
        mtkView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
        
        _camera = [[Camera alloc] initWithPosition:(vector_float3) {0.0, 0.0, 5.0}
                                        withTarget:(vector_float3) {0.0, 0.0, 0.0}
                                            withUp:(vector_float3) {0.0, 1.0, 0.0}];
        
        MTLVertexDescriptor *mtlVertexDescriptor = [MTLVertexDescriptor new];
        mtlVertexDescriptor.attributes[VertexAttributeIndexPosition].format = MTLVertexFormatFloat3;
        mtlVertexDescriptor.attributes[VertexAttributeIndexPosition].offset = 0;
        mtlVertexDescriptor.attributes[VertexAttributeIndexPosition].bufferIndex = VertexInputIndexPosition;
        
        mtlVertexDescriptor.attributes[VertexAttributeIndexNormal].format = MTLVertexFormatFloat3;
        mtlVertexDescriptor.attributes[VertexAttributeIndexNormal].offset = 16;
        mtlVertexDescriptor.attributes[VertexAttributeIndexNormal].bufferIndex = VertexInputIndexPosition;
        
        mtlVertexDescriptor.layouts[VertexInputIndexPosition].stride = 32;
        mtlVertexDescriptor.layouts[VertexInputIndexPosition].stepRate = 1;
        mtlVertexDescriptor.layouts[VertexInputIndexPosition].stepFunction = MTLStepFunctionPerVertex;
        
        int width = mtkView.frame.size.width;
        int height = mtkView.frame.size.height;
        
        _depthTexture = [self buildDepthTextureWithWidth:width height:height];
        id<MTLLibrary> library = [_device newDefaultLibrary];
        id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertexShader"];
        id<MTLFunction> fragmentFunc = [library newFunctionWithName:@"fragmentShader"];
        
        MTLRenderPipelineDescriptor *boxPipelineDescriptor = [MTLRenderPipelineDescriptor new];
        boxPipelineDescriptor.label = @"box pipeline";
        boxPipelineDescriptor.vertexFunction = vertexFunc;
        boxPipelineDescriptor.fragmentFunction = fragmentFunc;
        boxPipelineDescriptor.vertexDescriptor = mtlVertexDescriptor;
        boxPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        boxPipelineDescriptor.depthAttachmentPixelFormat = _depthTexture.pixelFormat;
        
        NSError *error;
        _boxRenderPipelineState = [_device newRenderPipelineStateWithDescriptor:boxPipelineDescriptor error:&error];
        
        NSAssert(_boxRenderPipelineState, @"new box render pipeline state error %@", error);
        
        id<MTLFunction> cubeMapVertexFunc = [library newFunctionWithName:@"cubeMapVertexShader"];
        id<MTLFunction> cubeMapFragmentFunc = [library newFunctionWithName:@"cubeMapFragmentShader"];
        
        MTLRenderPipelineDescriptor *skyPipelineDescriptor = [MTLRenderPipelineDescriptor new];
        skyPipelineDescriptor.label = @"sky pipeline";
        skyPipelineDescriptor.vertexFunction = cubeMapVertexFunc;
        skyPipelineDescriptor.fragmentFunction = cubeMapFragmentFunc;
        skyPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        skyPipelineDescriptor.depthAttachmentPixelFormat = _depthTexture.pixelFormat;
        
        _skyRenderPipelineState = [_device newRenderPipelineStateWithDescriptor:skyPipelineDescriptor error:&error];
        NSAssert(_skyRenderPipelineState, @"new sky render pipeline state error %@", error);
        
        MTLDepthStencilDescriptor *lessEqualDepthDescriptor = [MTLDepthStencilDescriptor new];
        lessEqualDepthDescriptor.depthCompareFunction = MTLCompareFunctionLessEqual;
        lessEqualDepthDescriptor.depthWriteEnabled = YES;
        
        _lessEqualDepthState = [_device newDepthStencilStateWithDescriptor:lessEqualDepthDescriptor];
        
        MTLDepthStencilDescriptor *lessDepthDescriptor = [MTLDepthStencilDescriptor new];
        lessDepthDescriptor.depthCompareFunction = MTLCompareFunctionLess;
        lessDepthDescriptor.depthWriteEnabled = YES;
        
        _lessDepthState = [_device newDepthStencilStateWithDescriptor:lessDepthDescriptor];
        
        _viewportSize = (vector_uint2) { mtkView.frame.size.width, mtkView.frame.size.height };
        _commandQueue = [_device newCommandQueue];
        
        _cubeMesh = [MTKMesh newBoxWithVertexDescriptor:mtlVertexDescriptor
                                      withAttributesMap:@{
                                          [NSNumber numberWithInt:VertexAttributeIndexPosition]: MDLVertexAttributePosition,
                                          [NSNumber numberWithInt:VertexAttributeIndexNormal]: MDLVertexAttributeNormal
                                                    }
                                             withDevice:_device
                                         withDimensions:(vector_float3) {1.0, 1.0, 1.0}
                                               segments:(vector_uint3) {1, 1, 1}
                                           geometryType:MDLGeometryTypeTriangles
                                          inwardNormals:false
                                                  error:&error];
        NSAssert(_cubeMesh, @"cube mesh error: %@", error);
        
        CubeMapVertex skyboxVertices[] =
        {
            {{-1.0,  1.0, -1.0}},
            {{-1.0, -1.0, -1.0}},
            {{ 1.0, -1.0, -1.0}},
            {{ 1.0, -1.0, -1.0}},
            {{ 1.0,  1.0, -1.0}},
            {{-1.0,  1.0, -1.0}},
            
            {{-1.0, -1.0,   1.0}},
            {{-1.0, -1.0,  -1.0}},
            {{-1.0,  1.0,  -1.0}},
            {{-1.0,  1.0,  -1.0}},
            {{-1.0,  1.0,   1.0}},
            {{-1.0, -1.0,   1.0}},
            
            {{ 1.0, -1.0, -1.0}},
            {{ 1.0, -1.0,  1.0}},
            {{ 1.0,  1.0,  1.0}},
            {{ 1.0,  1.0,  1.0}},
            {{ 1.0,  1.0, -1.0}},
            {{ 1.0, -1.0, -1.0}},

            {{-1.0, -1.0,  1.0}},
            {{-1.0,  1.0,  1.0}},
            {{ 1.0,  1.0,  1.0}},
            {{ 1.0,  1.0,  1.0}},
            {{ 1.0, -1.0,  1.0}},
            {{-1.0, -1.0,  1.0}},
            
            {{-1.0,  1.0, -1.0}},
            {{ 1.0,  1.0, -1.0}},
            {{ 1.0,  1.0,  1.0}},
            {{ 1.0,  1.0,  1.0}},
            {{-1.0,  1.0,  1.0}},
            {{-1.0,  1.0, -1.0}},

            {{-1.0, -1.0, -1.0}},
            {{-1.0, -1.0,  1.0}},
            {{ 1.0, -1.0, -1.0}},
            {{ 1.0, -1.0, -1.0}},
            {{-1.0, -1.0,  1.0}},
            {{ 1.0, -1.0,  1.0}},
        };
        
        _skyBoxBuffer = [_device newBufferWithBytes:skyboxVertices
                                             length:sizeof(skyboxVertices)
                                            options:MTLResourceStorageModeShared];
        
        _skyBoxTexture = [TextureCubeLoader
                            loadWithImageNames:@[
                                @"skybox/right.jpg",
                                @"skybox/left.jpg",
                                @"skybox/top.jpg",
                                @"skybox/bottom.jpg",
                                @"skybox/front.jpg",
                                @"skybox/back.jpg" ]
                          device:_device
                          commandQueue:_commandQueue
                          error:&error];
        _uniform.cameraPos = [_camera getCameraPosition];
        _uniform.viewMatrix = [_camera getViewMatrix];
        _uniform.modelMatrix = matrix4x4_identity();
        _uniform.projectionMatrix = matrix_perspective_left_hand(PI / 4.0, (float) width / (float) height, 0.1, 100.0);;
        _uniform.inverseModelMatrix = simd_inverse(_uniform.modelMatrix);
    }
    
    return self;
}

- (id<MTLTexture>) buildDepthTextureWithWidth:(int) width height:(int) height {
    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor new];
   
    descriptor.pixelFormat = MTLPixelFormatDepth32Float;
    descriptor.width = width;
    descriptor.height = height;
    descriptor.mipmapLevelCount = 1;
    descriptor.usage = MTLTextureUsageRenderTarget;
    descriptor.storageMode = MTLStorageModePrivate;
    
    id<MTLTexture> depthTexture = [_device newTextureWithDescriptor:descriptor];
    depthTexture.label = @"Depth Texture";
    
    return depthTexture;
}

- (void) handleMouseScrollDeltaX:(float) deltaX deltaY:(float) deltaY {
    [_camera handleMouseScrollDeltaX:deltaX deltaY:deltaY];
    
    _uniform.cameraPos = [_camera getCameraPosition];
    _uniform.viewMatrix = [_camera getViewMatrix];
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    view.clearDepth = 1.0;
    
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    
    MTLRenderPassDescriptor *renderDescriptor = [MTLRenderPassDescriptor new];
    renderDescriptor.colorAttachments[0].texture = [[view currentDrawable] texture];
    renderDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    renderDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.2, 0.3, 0.3, 1.0);
    
    renderDescriptor.depthAttachment.texture = _depthTexture;
    renderDescriptor.depthAttachment.loadAction = MTLLoadActionClear;
    renderDescriptor.depthAttachment.storeAction = MTLStoreActionDontCare;
    renderDescriptor.depthAttachment.clearDepth = 1.0;
    
    id<MTLRenderCommandEncoder> boxRenderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderDescriptor];
    boxRenderEncoder.label = @"box render";
    [boxRenderEncoder setViewport:(MTLViewport) {0.0, 0.0, _viewportSize.x, _viewportSize.y, 0.0, 1.0}];
    
    // draw box
    [boxRenderEncoder setRenderPipelineState:_boxRenderPipelineState];
    [boxRenderEncoder setDepthStencilState:_lessDepthState];

    for (int i = 0; i < _cubeMesh.vertexBuffers.count; i++) {
        [boxRenderEncoder setVertexBuffer:_cubeMesh.vertexBuffers[i].buffer offset:_cubeMesh.vertexBuffers[i].offset atIndex:VertexInputIndexPosition];
    }

    [boxRenderEncoder setVertexBytes:&_uniform length:sizeof(_uniform) atIndex:VertexInputIndexUniforms];
    [boxRenderEncoder setFragmentTexture:_skyBoxTexture atIndex:FragmentInputIndexCubeTexture];

    for (int i = 0; i < _cubeMesh.submeshes.count; i++) {
        MTKSubmesh *mesh = _cubeMesh.submeshes[i];
        [boxRenderEncoder drawIndexedPrimitives:mesh.primitiveType
                                     indexCount:mesh.indexCount
                                      indexType:mesh.indexType
                                    indexBuffer:mesh.indexBuffer.buffer
                              indexBufferOffset:mesh.indexBuffer.offset];
    }
    
    // draw sky
    [boxRenderEncoder setRenderPipelineState:_skyRenderPipelineState];
    [boxRenderEncoder setDepthStencilState:_lessEqualDepthState];

    [boxRenderEncoder setVertexBuffer:_skyBoxBuffer offset:0 atIndex:VertexInputIndexPosition];
    [boxRenderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:36];
    
    [boxRenderEncoder endEncoding];
    
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
    
    if (_depthTexture.width != size.width ||
            _depthTexture.height != size.height)  {
        _depthTexture = [self buildDepthTextureWithWidth:size.width height:size.height];
    }

    _uniform.projectionMatrix = matrix_perspective_left_hand(PI / 4.0, (float) size.width / (float) size.height, 0.1, 100.0);
}

@end
