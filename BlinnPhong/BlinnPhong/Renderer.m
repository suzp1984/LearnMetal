//
//  Renderer.m
//  BlinnPhong
//
//  Created by Jacob Su on 4/1/21.
//

#import <Foundation/Foundation.h>
#import "Renderer.h"
#import <common/common.h>
@import MetalKit;
@import Metal;
#import "ShaderType.h"

const float PI = 3.1415926;

@implementation Renderer
{
    Camera *_camera;
    id<MTLDevice> _device;
    id<MTLDepthStencilState> _depthState;
    id<MTLRenderPipelineState> _phongRenderPipelineState;
    id<MTLRenderPipelineState> _blinnPhongPipelineState;
    MTKMesh *_planeMesh;
    id<MTLTexture> _wood;
    MTLViewport _viewPort;
    id<MTLCommandQueue> _commandQueue;
    Uniforms _uniform;
    id<MTLBuffer> _argumentBuffer;
    id<MTLBuffer> _viewPosBuffer;
    vector_float3 _lightPos;
    vector_float3 _cameraPos;
    BOOL _isBlinnPhong;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView {
    self = [super init];
    
    if (self) {
        _isBlinnPhong = true;
        mtkView.delegate = self;
        _camera = [[Camera alloc] initWithPosition:(vector_float3){0.0, 0.0, 3.0}
                                        withTarget:(vector_float3) {0.0, 0.0, 0.0}
                                            withUp:(vector_float3) {0.0, 1.0, 0.0}];
        
        _device = mtkView.device;
        _lightPos = (vector_float3) {0.0, 0.0, 0.0};
        
        mtkView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
        mtkView.clearDepth = 1.0;
        
        MTLDepthStencilDescriptor *depthStencilDesc = [MTLDepthStencilDescriptor new];
        depthStencilDesc.depthCompareFunction = MTLCompareFunctionLess;
        depthStencilDesc.depthWriteEnabled = YES;
        _depthState = [_device newDepthStencilStateWithDescriptor:depthStencilDesc];
        
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
        _planeMesh = [MTKMesh newPlaneWithVertexDescriptor:mtlVertexDescriptor
                                       withAttributesMap:@{
                                           [NSNumber numberWithInt:ModelVertexAttributePosition] : MDLVertexAttributePosition,
                                           [NSNumber numberWithInt:ModelVertexAttributeNormal] : MDLVertexAttributeNormal,
                                           [NSNumber numberWithInt:ModelVertexAttributeTexCoord] : MDLVertexAttributeTextureCoordinate
                                       }
                                              withDevice:_device withDimensions:(vector_float2) {1.0, 1.0}
                                                segments:(vector_uint2) {1, 1}
                                            geometryType:MDLGeometryTypeTriangles
                                           inwardNormals:FALSE
                                                   error:&error];
        NSAssert(_planeMesh, @"planeMesh creation error: %@", error);
        
        MTKTextureLoader *textureLoader = [[MTKTextureLoader alloc] initWithDevice:_device];
        NSBundle *bundle = [NSBundle bundleForClass:[TextureCubeLoader class]];
        _wood = [textureLoader newTextureWithName:@"wood" scaleFactor:1.0 bundle:bundle options:nil error:&error];
        NSAssert(_wood, @"can not load wood texutre: %@", error);
        
        id<MTLLibrary> library = [_device newDefaultLibrary];
        id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertexShader"];
        id<MTLFunction> blinnPhongFunc = [library newFunctionWithName:@"blinnPhongFragmentShader"];
        id<MTLFunction> phongFunc = [library newFunctionWithName:@"phongFragmentShader"];
        
        MTLRenderPipelineDescriptor *renderDescriptor = [MTLRenderPipelineDescriptor new];
        renderDescriptor.label = @"render descritpor";
        renderDescriptor.vertexFunction = vertexFunc;
        renderDescriptor.fragmentFunction = phongFunc;
        renderDescriptor.vertexDescriptor = mtlVertexDescriptor;
        renderDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        renderDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat;
        
        _phongRenderPipelineState = [_device newRenderPipelineStateWithDescriptor:renderDescriptor error:&error];
        NSAssert(_phongRenderPipelineState, @"render pipeline State error: %@", error);
        
        renderDescriptor.fragmentFunction = blinnPhongFunc;
        _blinnPhongPipelineState = [_device newRenderPipelineStateWithDescriptor:renderDescriptor error:&error];
        NSAssert(_blinnPhongPipelineState, @"render blinn phong state error: %@", error);
        
        MTLSamplerDescriptor *samplerDescriptor = [MTLSamplerDescriptor new];
        samplerDescriptor.minFilter = MTLSamplerMinMagFilterLinear;
        samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
        samplerDescriptor.mipFilter = MTLSamplerMipFilterNotMipmapped;
        samplerDescriptor.normalizedCoordinates = TRUE;
        samplerDescriptor.supportArgumentBuffers = TRUE;
        
        id<MTLSamplerState> sampler = [_device newSamplerStateWithDescriptor:samplerDescriptor];
        
        id<MTLArgumentEncoder> argumentEncoder = [blinnPhongFunc newArgumentEncoderWithBufferIndex:FragmentInputIndexArgumentBuffer];
        
        _argumentBuffer = [_device newBufferWithLength:argumentEncoder.encodedLength options:MTLResourceStorageModeShared];
        _argumentBuffer.label = @"ArgumentBuffer";
        [argumentEncoder setArgumentBuffer:_argumentBuffer offset:0];
        [argumentEncoder setTexture:_wood atIndex:FragmentArgumentBufferIndexTexture];
        [argumentEncoder setSamplerState:sampler atIndex:FragmentArgumentBufferIndexSampler];
        _cameraPos = [_camera getCameraPosition];
        _viewPosBuffer = [_device newBufferWithBytes:&_cameraPos
                                              length:sizeof([_camera getCameraPosition])
                                             options:MTLResourceStorageModeShared];
        [argumentEncoder setBuffer:_viewPosBuffer offset:0 atIndex:FragmentArgumentBufferIndexViewPosition];
        
        void* lightPosPtr = [argumentEncoder constantDataAtIndex:FragmentArgumentBufferIndexLightPosition];
        memcpy(lightPosPtr, &_lightPos, sizeof(_lightPos));
        
        double width = mtkView.frame.size.width;
        double height = mtkView.frame.size.height;
        _viewPort = (MTLViewport) { 0.0, 0.0, width, height, 0.0, 1.0 };
        
        _commandQueue = [_device newCommandQueue];
        
        _uniform.modelMatrix = matrix_multiply(matrix4x4_translation(0.0, -0.5, 0.0),
                                               matrix4x4_scale(10.0, 1.0, 10.0));
        _uniform.viewMatrix = [_camera getViewMatrix];
        _uniform.projectionMatrix = matrix_perspective_left_hand(PI / 4.0,
                                                                 (float) width / (float) height,
                                                                 0.1,
                                                                 100.0);
        _uniform.inverseModelMatrix = simd_inverse(_uniform.modelMatrix);
    }
    
    return self;
}

- (void) handleMouseScrollDeltaX:(float) deltaX deltaY:(float) deltaY {
    [_camera handleMouseScrollDeltaX:deltaX deltaY:deltaY];
    
    _uniform.viewMatrix = [_camera getViewMatrix];
    _cameraPos = [_camera getCameraPosition];
    void *viewPosPtr = [_viewPosBuffer contents];
    memcpy(viewPosPtr, &_cameraPos, sizeof(_cameraPos));
}

- (void) enableBlinnPhong:(BOOL) enabled {
    _isBlinnPhong = enabled;
}


- (void)drawInMTKView:(nonnull MTKView *)view {
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    
    [renderEncoder setLabel:@"render encoder"];
    [renderEncoder setViewport:_viewPort];
    if (_isBlinnPhong) {
        [renderEncoder setRenderPipelineState:_blinnPhongPipelineState];
    } else {
        [renderEncoder setRenderPipelineState:_phongRenderPipelineState];
    }
    [renderEncoder setDepthStencilState:_depthState];
    [renderEncoder setCullMode:MTLCullModeFront];
    [renderEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
    
    [renderEncoder useResource:_wood usage:MTLResourceUsageSample];
    [renderEncoder useResource:_viewPosBuffer usage:MTLResourceUsageRead];
    
    for (int i = 0; i < _planeMesh.vertexBuffers.count; i++) {
        [renderEncoder setVertexBuffer:_planeMesh.vertexBuffers[i].buffer
                                offset:0
                               atIndex:VertexInputIndexPosition];
    }
    
    [renderEncoder setVertexBytes:&_uniform length:sizeof(_uniform) atIndex:VertexInputIndexUniform];
    [renderEncoder setFragmentBuffer:_argumentBuffer offset:0 atIndex:FragmentInputIndexArgumentBuffer];
    
    for (int i = 0; i < _planeMesh.submeshes.count; i++) {
        MTKSubmesh *subMesh = _planeMesh.submeshes[i];
        
        [renderEncoder drawIndexedPrimitives:subMesh.primitiveType
                                  indexCount:subMesh.indexCount
                                   indexType:subMesh.indexType
                                 indexBuffer:subMesh.indexBuffer.buffer
                           indexBufferOffset:subMesh.indexBuffer.offset];
    }
    
    [renderEncoder endEncoding];
    
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    _viewPort.width = size.width;
    _viewPort.height = size.height;
    
    _uniform.projectionMatrix = matrix_perspective_left_hand(PI / 4.0,
                                                             (float) size.width / (float) size.height,
                                                             0.1,
                                                             100.0);
}

@end
