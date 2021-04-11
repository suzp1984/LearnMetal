//
//  TriangleRenderer.m
//  Texture
//
//  Created by Jacob Su on 3/3/21.
//

@import MetalKit;
@import Metal;
@import simd;
#import <Foundation/Foundation.h>
#import "TextureShaderType.h"
#import "TriangleRenderer.h"
#import <common/common.h>

@implementation TriangleRenderer
{
    id<MTLDevice> _device;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLCommandQueue> _commandQueue;
    id<MTLBuffer> _verticesBuffer;
    id<MTLTexture> _texture;
    vector_uint2 _viewportSize;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView {
    self = [super init];
    if (self)
    {
        mtkView.delegate = self;
        id<MTLDevice> device = [mtkView device];
        _device = device;
        
        static const Vertex triangleVertices[] = {
            { { 250, -250 }, {1.0, 1.0} },
            { { -250, -250 }, {0.0, 1.0} },
            { { 0, 250 }, {0.5, 0.0} },
        };
        
        _verticesBuffer = [device newBufferWithBytes:triangleVertices
                                    length:sizeof(triangleVertices)
                                    options:MTLResourceStorageModeShared];
        
        NSError *error;
        MTKTextureLoader *textureLoader = [[MTKTextureLoader alloc] initWithDevice:_device];
        _texture = [textureLoader newTextureWithName:@"container"
                                scaleFactor:1.0
                                bundle:[NSBundle common]
                                options:nil error:&error];
        NSAssert(_texture, @"Failed to create texture container: %@", error);
        
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
    }
    
    return self;
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"Triangle Command";
    
    MTLRenderPassDescriptor *descriptor = [view currentRenderPassDescriptor];
    
    id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    [commandEncoder setLabel:@"MyRenderEncoder"];
        
    [commandEncoder setViewport:(MTLViewport){ 0.0, 0.0, _viewportSize.x, _viewportSize.y, 0.0, 1.0 }];
    [commandEncoder setRenderPipelineState:_pipelineState];
    
    [commandEncoder setVertexBuffer:_verticesBuffer offset:0 atIndex:VertexInputIndexVertices];
    [commandEncoder setVertexBytes:&_viewportSize length:sizeof(_viewportSize) atIndex:VertexInputIndexViewportSize];
    
    [commandEncoder setFragmentTexture:_texture atIndex:FragmentInputIndexTexture];
    
        
    [commandEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [commandEncoder endEncoding];
    
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
}


@end
