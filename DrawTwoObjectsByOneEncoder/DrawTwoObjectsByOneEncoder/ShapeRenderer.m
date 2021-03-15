//
//  ShapeRenderer.m
//  DrawTwoObjectsByOneEncoder
//
//  Created by Jacob Su on 3/15/21.
//

#import <Foundation/Foundation.h>
#import <common/common.h>
#import "ShapeRenderer.h"
#import "ShapeShaderType.h"

@implementation ShaperRenderer
{
    id<MTLDevice> _device;
    id<MTLRenderPipelineState> _renderPipelineState;
    
    id<MTLCommandQueue> _commandQueue;
    id<MTLBuffer> _squareBuffer;
    id<MTLBuffer> _triangleBuffer;

    id<MTLTexture> _textureContainer;
    id<MTLTexture> _textureFace;
    vector_uint2 _viewportSize;
    Uniforms _squareUniform;
    Uniforms _triangleUniform;
    vector_float3 _size;
}

- (nonnull instancetype) initWithMetalKitView:(nonnull MTKView*)mtkView
{
    self = [super init];
    
    if (self) {
        mtkView.delegate = self;
        
        id<MTLDevice> device = [mtkView device];
        _device = device;
        
        static const Vertex squareVertices[] = {

            { { -0.5, -0.5, 0.0 }, { 0.0, 0.0 } },
            { {  0.5, -0.5, 0.0 }, { 1.0, 0.0 } },
            { {  0.5,  0.5, 0.0 }, { 1.0, 1.0 } },
            { {  0.5,  0.5, 0.0 }, { 1.0, 1.0 } },
            { { -0.5,  0.5, 0.0 }, { 0.0, 1.0 } },
            { { -0.5, -0.5, 0.0 }, { 0.0, 0.0 } },

        };
        
        static const Vertex triangleVertices[] = {
            { { -0.5, -0.5, 0.0 }, { 0.0, 0.0 } },
            { {  0.5, -0.5, 0.0 }, { 1.0, 0.0 } },
            { {  0.0,  0.5, 0.0 }, { 0.5, 1.0 } },
        };
        
        _size = (vector_float3) { 200.0, 200.0, 1.0 };

        static const vector_float3 squarePosition = {
            280.0, 280.0, 0.0,
        };
        
        static const vector_float3 trianglePosition = {
            600, 600, 0.0,
        };

        _squareBuffer = [device newBufferWithBytes:squareVertices length:sizeof(squareVertices) options:MTLResourceStorageModeShared];
        _triangleBuffer = [device newBufferWithBytes:triangleVertices length:sizeof(triangleVertices) options:MTLResourceStorageModeShared];
        
        NSBundle *bundle = [NSBundle bundleWithIdentifier:@"io.github.suzp1984.common"];
        
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
        pipelineStateDescriptor.label = @"shape pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunc;
        pipelineStateDescriptor.fragmentFunction = fragmentFunc;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
    
        _renderPipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
        
        NSAssert(_renderPipelineState, @"Failed to create square pipeline state: %@", error);
        
        _commandQueue = [_device newCommandQueue];
        
        _viewportSize = (vector_uint2){ (int) (mtkView.frame.size.width), (int) (mtkView.frame.size.height) };
        
        float width = mtkView.frame.size.width;
        float height = mtkView.frame.size.height;
        
        _squareUniform.modelMatrix = simd_mul(matrix4x4_translation(squarePosition), matrix4x4_scale(_size));
        
//        _squareUniform.viewMatrix = matrix_look_at_left_hand(
//                                 (vector_float3) {0.0, 0.0, 1.0},
//                                 (vector_float3) {0.0, 0.0, 0.0},
//                                 (vector_float3) {0.0, 1.0, 0.0});
        _squareUniform.viewMatrix = matrix4x4_translation(300.0, 0.0, 0.0);

        _squareUniform.projectionMatrix = matrix_ortho_left_hand(0.0, width, height, 0.0, -100.0, 100.0);
        
        _triangleUniform.modelMatrix = simd_mul(matrix4x4_translation(trianglePosition), matrix4x4_scale(_size));
        
        _triangleUniform.viewMatrix = matrix4x4_identity();

        _triangleUniform.projectionMatrix = matrix_ortho_left_hand(0.0, width, height, 0.0, -1.0, 1.0);
        
    }
    
    return self;
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;

    _squareUniform.projectionMatrix = matrix_ortho_left_hand(0.0, size.width, size.height, 0.0, -1.0, 1.0);
    
    _triangleUniform.projectionMatrix = matrix_ortho_left_hand(0.0, size.width, size.height, 0.0, -1.0, 1.0);
}

- (void)drawInMTKView:(nonnull MTKView *)view
{
    [self rotate];
    
    // NSLog(@"render tick");
    
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"Square Command";
    
    MTLRenderPassDescriptor *descriptor = [view currentRenderPassDescriptor];
    
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    [renderEncoder setLabel:@"Render Encoder"];
    
    // render square
    [renderEncoder setViewport:(MTLViewport){ 0.0, 0.0, _viewportSize.x, _viewportSize.y, 0.0, 1.0 }];
    [renderEncoder setRenderPipelineState:_renderPipelineState];
    
    [renderEncoder setVertexBuffer:_squareBuffer offset:0 atIndex:VertexInputIndexVertices];
    [renderEncoder setVertexBytes:&_squareUniform length:sizeof(_squareUniform) atIndex:VertexInputIndexUniforms];
    
    [renderEncoder setFragmentTexture:_textureContainer atIndex:FragmentInputIndexTexture];
    
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                      vertexStart:0
                      vertexCount:6];
    // render triangle
    [renderEncoder setVertexBuffer:_triangleBuffer offset:0 atIndex:VertexInputIndexVertices];
    [renderEncoder setVertexBytes:&_triangleUniform length:sizeof(_triangleUniform) atIndex:VertexInputIndexUniforms];
    [renderEncoder setFragmentTexture:_textureFace atIndex:FragmentInputIndexTexture];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    
    [renderEncoder endEncoding];

    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}

- (void)rotate {
    _triangleUniform.modelMatrix = simd_mul(_triangleUniform.modelMatrix, matrix4x4_rotation(0.05, 0.0, 0.0, 1.0));
    
    _squareUniform.modelMatrix = simd_mul(_squareUniform.modelMatrix, matrix4x4_rotation(-0.02, 0.0, 0.0, 1.0));
}


@end
