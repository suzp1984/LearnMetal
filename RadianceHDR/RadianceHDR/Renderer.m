//
//  Renderer.m
//  RadianceHDR
//
//  Created by Jacob Su on 4/18/21.
//

#import <Foundation/Foundation.h>
#import "Renderer.h"
#import <common/common.h>
#import <common/common-Swift.h>
#import "ShaderType.h"

@implementation Renderer
{
    id<MTLDevice> _device;
    id<Camera> _camera;
    id<MTLBuffer> _skyDomeVertexBuffer;
    id<MTLCommandQueue> _commandQueue;
    Uniform _uniform;
    MTLViewport _viewport;
    id<MTLRenderPipelineState> _skyPipelineState;
    id<MTLTexture> _hdrTexture;
    matrix_float4x4 _projectionMatrix;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView {
    self = [super init];
    
    if (self) {
        _device = mtkView.device;
        mtkView.delegate = self;
        
        _camera = [CameraFactory generateRoundOrbitCameraWithPosition:(vector_float3){0.0, 0.0, 5.0}
                                                               target:(vector_float3){0.0, 0.0, 0.0}
                                                                   up:(vector_float3){0.0, 1.0, 0.0}];
        _commandQueue = [_device newCommandQueue];
        
        SkyDomeVertex skyDomeVerties[] = {
            {{-1.0,  1.0}},
            {{ 1.0,  1.0}},
            {{-1.0, -1.0}},
            {{ 1.0,  1.0}},
            {{ 1.0, -1.0}},
            {{-1.0, -1.0}}
        };
        
        _skyDomeVertexBuffer = [_device newBufferWithBytes:skyDomeVerties
                                                    length:sizeof(skyDomeVerties)
                                                   options:MTLResourceStorageModeShared];
        
        _uniform.viewMatrix = [_camera getViewMatrix];
        _uniform.inverseViewMatrix = simd_inverse(_uniform.viewMatrix);
        
        float width = mtkView.frame.size.width;
        float height = mtkView.frame.size.height;
        
        _viewport = (MTLViewport){0.0, 0.0, width, height, 0.0, 1.0};
        
        id<MTLLibrary> library = [_device newDefaultLibrary];
        id<MTLFunction> skyVertexFunc = [library newFunctionWithName:@"SkyDomeVertexShader"];
        id<MTLFunction> skyFragmentFunc = [library newFunctionWithName:@"SkyDomeFragmentShader"];
        
        MTLRenderPipelineDescriptor *skyPipelineDescriptor = [MTLRenderPipelineDescriptor new];
        skyPipelineDescriptor.vertexFunction = skyVertexFunc;
        skyPipelineDescriptor.fragmentFunction = skyFragmentFunc;
        skyPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        
        NSError *error;
        _skyPipelineState = [_device newRenderPipelineStateWithDescriptor:skyPipelineDescriptor error:&error];
        NSAssert(_skyPipelineState, @"create pipeline state error:%@", error);
        
        NSURL *url = [[NSBundle common] URLForResource:@"newport_loft.hdr" withExtension:nil subdirectory:@"hdr"];
        _hdrTexture = [HDRTextureLoader loadWithTextureFrom:url device:_device commandQueue:_commandQueue error:&error];
        NSAssert(_hdrTexture, @"load hdr texture error:%@", error);
        
        _projectionMatrix = matrix_perspective_left_hand(M_PI / 4.0, width / height, 0.1, 100.0);
        _uniform.skyDomeOffsets.y = 100.0 * tan(M_PI/4.0 * 0.5);
        _uniform.skyDomeOffsets.x = _uniform.skyDomeOffsets.y * width / height;
        _uniform.skyDomeOffsets.z = 100.0;
    }
    
    return self;
}

- (void) handleMouseScrollDeltaX:(float) deltaX deltaY:(float) deltaY {
    [_camera rotateCameraAroundTargetWithDeltaPhi:deltaX * 0.2 deltaTheta:deltaY * 0.2];
    
    _uniform.viewMatrix = [_camera getViewMatrix];
    _uniform.inverseViewMatrix = simd_inverse(_uniform.viewMatrix);
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    id<MTLRenderCommandEncoder> skyRenderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    
    [skyRenderEncoder setViewport:_viewport];
    [skyRenderEncoder setRenderPipelineState:_skyPipelineState];
    
    [skyRenderEncoder setVertexBuffer:_skyDomeVertexBuffer offset:0 atIndex:SkyDomeVertexIndexPosition];
    [skyRenderEncoder setVertexBytes:&_uniform length:sizeof(_uniform) atIndex:SkyDomeVertexIndexUniform];
    
    [skyRenderEncoder setFragmentTexture:_hdrTexture atIndex:0];
    [skyRenderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    
    [skyRenderEncoder endEncoding];
    
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    _viewport.width = size.width;
    _viewport.height = size.height;
    
    _projectionMatrix = matrix_perspective_left_hand(M_PI / 4.0, size.width / size.height, 0.1, 100.0);
    
    _uniform.skyDomeOffsets.x = _uniform.skyDomeOffsets.y * size.width / size.height;

}

@end
