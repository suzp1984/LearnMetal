//
//  TriangleRenderer.m
//  HelloTriangle
//
//  Created by Jacob Su on 3/2/21.
//

@import MetalKit;
@import Metal;
@import simd;

#import <Foundation/Foundation.h>
#import "TriangleRenderer.h"
#import "TriangleShaderType.h"

@implementation TriangleRenderer
{
    id<MTLDevice> _device;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLCommandQueue> _commandQueue;
    vector_uint2 _viewportSize;
    NSDate *lastDrawTime;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView
{
    self = [super init];
    if (self)
    {
        lastDrawTime = [[NSDate alloc] init];
        
        mtkView.delegate = self;
        id<MTLDevice> device = [mtkView device];
        _device = device;
        id<MTLLibrary> library = [device newDefaultLibrary];
        id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertexShader"];
        id<MTLFunction> fragmentFunc = [library newFunctionWithName:@"fragmentShader"];
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"Triangle pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunc;
        pipelineStateDescriptor.fragmentFunction = fragmentFunc;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        
        NSError *error;
        _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
        
        NSAssert(_pipelineState, @"Failed to create pipeline state: %@", error);
        
        _commandQueue = [_device newCommandQueue];
        
        _viewportSize = (vector_uint2){ (int) (mtkView.frame.size.width), (int) (mtkView.frame.size.height) };
    }
    
    return self;
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    
    NSLog(@"draw: %f", lastDrawTime.timeIntervalSinceNow * 1000);
    lastDrawTime = [[NSDate alloc] init];
    
    static const Vertex triangleVertices[] = {
        { { 250, -250 }, {1.0, 0.0, 0.0, 1.0} },
        { { -250, -250 }, {0.0, 1.0, 0.0, 1.0} },
        { { 0, 250 }, {0.0, 0.0, 1.0, 1.0} },
    };
    
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"Triangle Command";
    
    MTLRenderPassDescriptor *descriptor = [view currentRenderPassDescriptor];
    
    id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    [commandEncoder setLabel:@"MyRenderEncoder"];
    	
    [commandEncoder setViewport:(MTLViewport){ 0.0, 0.0, _viewportSize.x, _viewportSize.y, 0.0, 1.0 }];
    [commandEncoder setRenderPipelineState:_pipelineState];
    
    [commandEncoder setVertexBytes:triangleVertices length:sizeof(triangleVertices) atIndex:VertexInputIndexVertices];
    [commandEncoder setVertexBytes:&_viewportSize length:sizeof(_viewportSize) atIndex:VertexInputIndexViewportSize];
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



