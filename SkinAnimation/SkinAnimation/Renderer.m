//
//  Renderer.m
//  SkinAnimation
//
//  Created by Jacob Su on 5/8/21.
//

#import <Foundation/Foundation.h>
#import "Renderer.h"
#import "JsonAnimationMesh.h"
#import <common/common.h>
#import "ShaderType.h"

@implementation Renderer {
    id<MTLDevice> _device;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLCommandQueue> _commandQueue;
    id<MTLDepthStencilState> _depthState;
    JsonAnimationMesh *_mesh;
    id<Camera> _camera;
    SatelliteCameraController *_satelliteController;
    Uniforms _uniforms;
    MTLViewport _viewPort;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView {
    self = [super init];
    if (self) {
        _device = mtkView.device;
        mtkView.delegate = self;
//        mtkView.sampleCount = 4;
        
        _camera = [[SimpleCamera alloc] initWithPosition:(vector_float3) {0.0, 0.0, 8.0}
                                              withTarget:(vector_float3){0.0, 0.0, 0.0}
                                                      up:YES];
        _satelliteController = [[SatelliteCameraController alloc] initWithCamera:_camera];
        
        mtkView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
        mtkView.clearDepth = 1.0;
        MTLDepthStencilDescriptor *depthStencilDesc = [MTLDepthStencilDescriptor new];
        depthStencilDesc.depthCompareFunction = MTLCompareFunctionLess;
        depthStencilDesc.depthWriteEnabled = YES;
        _depthState = [_device newDepthStencilStateWithDescriptor:depthStencilDesc];
        
        NSBundle *bundle = NSBundle.common;
        NSURL *jsonUrl = [bundle URLForResource:@"snout-rig.json"
                                  withExtension:nil
                                   subdirectory:@"snout"];
        NSURL *animUrl = [bundle URLForResource:@"snout-anim.json"
                                  withExtension:nil
                                   subdirectory:@"snout"];
        NSURL *textureUrl = [bundle URLForResource:@"snout.jpg"
                                     withExtension:nil
                                      subdirectory:@"snout"];
        
        _mesh = [[JsonAnimationMesh alloc] initWithDevice:_device
                                                  jsonUrl:jsonUrl
                                             animationUrl:animUrl
                                               textureURL:textureUrl];
        
        id<MTLLibrary> library = [_device newDefaultLibrary];
        id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertexShader"];
        id<MTLFunction> fragmentFunc = [library newFunctionWithName:@"fragmentShader"];
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"Model pipeline";
        pipelineStateDescriptor.vertexDescriptor = _mesh.mtlVertexDescriptor;
        pipelineStateDescriptor.vertexFunction = vertexFunc;
        pipelineStateDescriptor.fragmentFunction = fragmentFunc;
        pipelineStateDescriptor.sampleCount = mtkView.sampleCount;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        pipelineStateDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat;
        
        NSError *error;
        
        _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
        
        NSAssert(_pipelineState, @"Failed to create pipeline state: %@", error);
        
        _commandQueue = [_device newCommandQueue];
        
        float width = mtkView.frame.size.width;
        float height = mtkView.frame.size.height;
        
        _uniforms.modelMatrix = matrix4x4_scale(0.01, 0.01, 0.01);
        _uniforms.viewMatrix = [_camera getViewMatrix];
        _uniforms.projectionMatrix = matrix_perspective_left_hand(M_PI / 4.0, width / height, 0.1, 1000.0);
        
        _uniforms.normalMatrix = simd_transpose(simd_inverse(matrix3x3_upper_left(matrix_multiply(_uniforms.viewMatrix, _uniforms.modelMatrix))));
        
        _viewPort = (MTLViewport) {0.0, 0.0, width, height, 0.0, 1.0};
    }
    
    return self;
}

- (void) handleMouseScrollDeltaX:(float) deltaX deltaY:(float) deltaY {
    [_satelliteController rotateCameraAroundTargetWithDeltaPhi:deltaX deltaTheta:deltaY];
    _uniforms.viewMatrix = [_camera getViewMatrix];
    
    _uniforms.normalMatrix = simd_transpose(simd_inverse(matrix3x3_upper_left(matrix_multiply(_uniforms.viewMatrix, _uniforms.modelMatrix))));
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    [_mesh update];
    
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    
    MTLRenderPassDescriptor *descriptor = [view currentRenderPassDescriptor];

    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    [renderEncoder setLabel:@"Model RenderEncoder"];
        
    [renderEncoder setViewport:_viewPort];
    [renderEncoder setRenderPipelineState:_pipelineState];
    [renderEncoder setDepthStencilState:_depthState];
    
    [renderEncoder setVertexBuffer:_mesh.geometryBuffer
                            offset:0
                           atIndex:ModelVertexInputIndexPosition];
    [renderEncoder setVertexBytes:&_uniforms
                           length:sizeof(_uniforms)
                          atIndex:ModelVertexInputIndexUniforms];
    [renderEncoder setVertexTexture:_mesh.boneTexture atIndex:ModelVertexInputIndexBoneTexture];
    int boneTextureSize = _mesh.boneTextureSize;
    [renderEncoder setVertexBytes:&boneTextureSize
                           length:sizeof(boneTextureSize)
                          atIndex:ModelVertexInputIndexBoneTextureSize];
    
    [renderEncoder setFragmentTexture:_mesh.diffuseTexture
                              atIndex:FragmentInputIndexDiffuseTexture];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                      vertexStart:0
                      vertexCount:_mesh.vertexCount];
    
    [renderEncoder endEncoding];
    
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    _viewPort.width = size.width;
    _viewPort.height = size.height;
    
    _uniforms.projectionMatrix = matrix_perspective_left_hand(M_PI / 4.0,
                                                              size.width / size.height,
                                                              0.1,
                                                              1000.0);
}

@end
