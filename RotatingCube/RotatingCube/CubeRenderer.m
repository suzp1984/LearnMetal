//
//  CubeRenderer.m
//  RotatingCube
//
//  Created by Jacob Su on 3/17/21.
//
#import <Foundation/Foundation.h>
#import <common/common.h>
#import "CubeRenderer.h"
#import "CubeShaderType.h"

static const float PI = 3.1415926;

@implementation CubeRenderer
{
    id<MTLDevice> _device;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLDepthStencilState> _depthState;
    id<MTLCommandQueue> _commandQueue;
    id<MTLBuffer> _verticesBuffer;
    id<MTLTexture> _textureContainer;
    id<MTLTexture> _textureFace;
    vector_uint2 _viewportSize;
    Uniforms _uniforms;
    Uniforms _uniforms2;
    vector_float3 _size;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView
{
    self = [super init];
    
    if (self) {
        mtkView.delegate = self;
        mtkView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
        mtkView.clearDepth = 1.0;
        
        id<MTLDevice> device = [mtkView device];
        _device = device;
        
        MTLDepthStencilDescriptor *depthDescriptor = [MTLDepthStencilDescriptor new];
        depthDescriptor.depthCompareFunction = MTLCompareFunctionLessEqual;
        depthDescriptor.depthWriteEnabled = YES;
        
        _depthState = [device newDepthStencilStateWithDescriptor:depthDescriptor];
        
        static const Vertex cubeVertices[] = {
            { { -0.5, -0.5, -0.5 }, { 0.0, 0.0 } },
            { {  0.5, -0.5, -0.5 }, { 1.0, 0.0 } },
            { {  0.5,  0.5, -0.5 }, { 1.0, 1.0 } },
            { {  0.5,  0.5, -0.5 }, { 1.0, 1.0 } },
            { { -0.5,  0.5, -0.5 }, { 0.0, 1.0 } },
            { { -0.5, -0.5, -0.5 }, { 0.0, 0.0 } },

            { { -0.5, -0.5, 0.5 }, { 0.0, 0.0 } },
            { {  0.5, -0.5, 0.5 }, { 1.0, 0.0 } },
            { {  0.5,  0.5, 0.5 }, { 1.0, 1.0 } },
            { {  0.5,  0.5, 0.5 }, { 1.0, 1.0 } },
            { { -0.5,  0.5, 0.5 }, { 0.0, 1.0 } },
            { { -0.5, -0.5, 0.5 }, { 0.0, 0.0 } },

            { { -0.5,  0.5,  0.5 }, { 1.0, 0.0 } },
            { { -0.5,  0.5, -0.5 }, { 1.0, 1.0 } },
            { { -0.5, -0.5, -0.5 }, { 0.0, 1.0 } },
            { { -0.5, -0.5, -0.5 }, { 0.0, 1.0 } },
            { { -0.5, -0.5,  0.5 }, { 0.0, 0.0 } },
            { { -0.5,  0.5,  0.5 }, { 1.0, 0.0 } },

            { {  0.5,  0.5,  0.5 }, { 1.0, 0.0 } },
            { {  0.5,  0.5, -0.5 }, { 1.0, 1.0 } },
            { {  0.5, -0.5, -0.5 }, { 0.0, 1.0 } },
            { {  0.5, -0.5, -0.5 }, { 0.0, 1.0 } },
            { {  0.5, -0.5,  0.5 }, { 0.0, 0.0 } },
            { {  0.5,  0.5,  0.5 }, { 1.0, 0.0 } },

            { { -0.5, -0.5, -0.5 }, { 0.0, 1.0 } },
            { {  0.5, -0.5, -0.5 }, { 1.0, 1.0 } },
            { {  0.5, -0.5,  0.5 }, { 1.0, 0.0 } },
            { {  0.5, -0.5,  0.5 }, { 1.0, 0.0 } },
            { { -0.5, -0.5,  0.5 }, { 0.0, 0.0 } },
            { { -0.5, -0.5, -0.5 }, { 0.0, 1.0 } },

            { { -0.5,  0.5, -0.5 }, { 0.0, 1.0 } },
            { {  0.5,  0.5, -0.5 }, { 1.0, 1.0 } },
            { {  0.5,  0.5,  0.5 }, { 1.0, 0.0 } },
            { {  0.5,  0.5,  0.5 }, { 1.0, 0.0 } },
            { { -0.5,  0.5,  0.5 }, { 0.0, 0.0 } },
            { { -0.5,  0.5, -0.5 }, { 0.0, 1.0 } },
        };
        
        _verticesBuffer = [device newBufferWithBytes:cubeVertices
                                    length:sizeof(cubeVertices)
                                    options:MTLResourceStorageModeShared];

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
        pipelineStateDescriptor.label = @"Triangle pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunc;
        pipelineStateDescriptor.fragmentFunction = fragmentFunc;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        pipelineStateDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat;
        
        
        _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
        
        NSAssert(_pipelineState, @"Failed to create pipeline state: %@", error);
        
        _commandQueue = [_device newCommandQueue];
        
        _viewportSize = (vector_uint2){ (int) (mtkView.frame.size.width), (int) (mtkView.frame.size.height) };
        
        float width = mtkView.frame.size.width;
        float height = mtkView.frame.size.height;
        
        _size = (vector_float3) { 100.0, 100.0, 100.0 };

        _uniforms.modelMatrix = matrix4x4_scale(_size.x, _size.y, _size.z);
        _uniforms.viewMatrix = matrix_look_at_left_hand((vector_float3) {0.0, 0.0, -300.0},
                                                        (vector_float3) {0.0, 0.0, 0.0 },
                                                        (vector_float3) {0.0, 1.0, 0.0});

        _uniforms.projectionMatrix = matrix_perspective_left_hand(PI / 3.0, width / height, 0.1, 1000.0);
    }
    
    return self;
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;

    _uniforms.projectionMatrix = matrix_perspective_left_hand(PI / 3.0, size.width / size.height, 0.1, 1000.0);
}

- (void)drawInMTKView:(nonnull MTKView *)view
{
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"Square Command";
    
    MTLRenderPassDescriptor *descriptor = [view currentRenderPassDescriptor];
    
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    [renderEncoder setLabel:@"MyRenderEncoder"];
        
    [renderEncoder setViewport:(MTLViewport){ 0.0, 0.0, _viewportSize.x, _viewportSize.y, 0.0, 1.0 }];
    [renderEncoder setRenderPipelineState:_pipelineState];
    [renderEncoder setDepthStencilState:_depthState];
    
    [renderEncoder setVertexBuffer:_verticesBuffer offset:0 atIndex:VertexInputIndexVertices];
    _uniforms.modelMatrix = simd_mul(_uniforms.modelMatrix, matrix4x4_rotation(0.05, 0.0, 1.0, 1.0));
    [renderEncoder setVertexBytes:&_uniforms length:sizeof(_uniforms) atIndex:VertexInputIndexUniforms];
    
    [renderEncoder setFragmentTexture:_textureContainer atIndex:FragmentInputIndexTexture];
    [renderEncoder setFragmentTexture:_textureFace atIndex:FragmentInputIndexTexture2];
        
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:36];
    
    [renderEncoder endEncoding];
    
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}

@end
