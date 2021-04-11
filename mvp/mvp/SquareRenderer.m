//
//  SquareRenderer.m
//  mvp
//
//  Created by Jacob Su on 3/4/21.
//


@import MetalKit;
@import Metal;
@import simd;
#import <Foundation/Foundation.h>
#import <common/common.h>
#import "SquareRenderer.h"
#import "SquareShaderType.h"

@implementation SquareRenderer
{
    id<MTLDevice> _device;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLCommandQueue> _commandQueue;
    id<MTLBuffer> _verticesBuffer;
    id<MTLTexture> _textureContainer;
    id<MTLTexture> _textureFace;
    vector_uint2 _viewportSize;
    Uniforms _uniforms;
    vector_float2 _size;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView
{
    self = [super init];
    if (self) {
        mtkView.delegate = self;
        id<MTLDevice> device = [mtkView device];
        _device = device;
        
        static const Vertex squareVertices[] = {
            { {  1.0, -1.0 }, { 1.0, 1.0 } },
            { { -1.0, -1.0 }, { 0.0, 1.0 } },
            { { -1.0,  1.0 }, { 0.0, 0.0 } },
            { {  1.0,  1.0 }, { 1.0, 0.0 } },
            { {  1.0, -1.0 }, { 1.0, 1.0 } },
            { { -1.0,  1.0 }, { 0.0, 0.0 } },
        };
        
        _verticesBuffer = [device newBufferWithBytes:squareVertices
                                    length:sizeof(squareVertices)
                                    options:MTLResourceStorageModeShared];
        
        NSBundle *bundle = [NSBundle common];
        
        NSError *error;
        MTKTextureLoader *textureLoader = [[MTKTextureLoader alloc] initWithDevice:_device];
        _textureContainer = [textureLoader newTextureWithName:@"container" scaleFactor:1.0 bundle:bundle options:nil error:&error];
        NSAssert(_textureContainer, @"Failed to create texture container: %@", error);
        
        _textureFace = [textureLoader newTextureWithName:@"awesomeface" scaleFactor:1.0 bundle:bundle options:nil error:&error];
        NSAssert(_textureFace, @"Failed to create texture face: %@", error);
        
        id<MTLLibrary> library = [device newDefaultLibrary];
        id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertexShader"];
        id<MTLFunction> fragmentFunc = [library newFunctionWithName:@"fragmentShader"];
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"Triangle pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunc;
        pipelineStateDescriptor.fragmentFunction = fragmentFunc;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        
        _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
        
        NSAssert(_pipelineState, @"Failed to create pipeline state: %@", error);
        
        _commandQueue = [_device newCommandQueue];
        
        _viewportSize = (vector_uint2){ (int) (mtkView.frame.size.width), (int) (mtkView.frame.size.height) };
        
        float width = mtkView.frame.size.width;
        float height = mtkView.frame.size.height;
        
        _size = (vector_float2) { 200.0, 200.0 };

        _uniforms.modelMatrix = simd_mul(matrix4x4_translation(width / 2.0, height / 2.0, 0.0), matrix4x4_scale(_size.x, _size.y, 1.0));
        _uniforms.viewMatrix = matrix4x4_identity();
        _uniforms.projectionMatrix = matrix_ortho_left_hand(0.0, width, height, 0.0, -100.0, 100.0);
    }
    
    return self;
}


- (void)drawInMTKView:(nonnull MTKView *)view {
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"Square Command";
    
    MTLRenderPassDescriptor *descriptor = [view currentRenderPassDescriptor];
    
    id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    [commandEncoder setLabel:@"MyRenderEncoder"];
        
    [commandEncoder setViewport:(MTLViewport){ 0.0, 0.0, _viewportSize.x, _viewportSize.y, 0.0, 1.0 }];
    [commandEncoder setRenderPipelineState:_pipelineState];
    
    [commandEncoder setVertexBuffer:_verticesBuffer offset:0 atIndex:VertexInputIndexVertices];
    _uniforms.modelMatrix = simd_mul(_uniforms.modelMatrix, matrix4x4_rotation(0.05, 0.0, 0.0, 1.0));
    [commandEncoder setVertexBytes:&_uniforms length:sizeof(_uniforms) atIndex:VertexInputIndexUniforms];
    
    [commandEncoder setFragmentTexture:_textureContainer atIndex:FragmentInputIndexTexture];
    [commandEncoder setFragmentTexture:_textureFace atIndex:FragmentInputIndexTexture2];
        
    [commandEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    
    [commandEncoder endEncoding];
    
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
        
    _uniforms.modelMatrix = simd_mul(matrix4x4_translation(size.width / 2.0, size.height / 2.0, 0.0),
                                     simd_mul(matrix4x4_rotation(M_PI / 4.0, 0.0, 0.0, 1.0), matrix4x4_scale(_size.x, _size.y, 1.0)));
    _uniforms.projectionMatrix = matrix_ortho_left_hand(0.0, size.width, size.height, 0.0, -100.0, 100.0);
}

@end


