//
//  CubeRenderer.m
//  MultipleDrawByInstances
//
//  Created by Jacob Su on 3/6/21.
//

#import <Foundation/Foundation.h>
#import <common/common.h>
#import "CubeRenderer.h"
#import "CubeShaderType.h"

@implementation CubeRenderer
{
    id<MTLDevice> _device;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLDepthStencilState> _depthState;
    id<MTLCommandQueue> _commandQueue;
    id<MTLBuffer> _verticesBuffer;
    id<MTLBuffer> _indirectObjectParamsBuffer;
    id<MTLBuffer> _uniformBuffer;
    id<MTLBuffer> _fragmentArgumentBuffer;
    id<MTLTexture> _textureContainer;
    id<MTLTexture> _textureFace;
    vector_uint2 _viewportSize;
    Uniforms _uniforms;
    vector_float3 _size;
    int _cubeNum;
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
        
        _size = (vector_float3) { 100.0, 100.0, 100.0 };

        static const vector_float3 cubePositions[] = {
            {0.0, 0.0, 0.0},
            {1.0, 1.0, 0.0},
            {2.0, 5.0, -15.0},
            {-1.5, -2.2, -2.5},
            {-3.8, -2.0, -12.3},
            {2.4, -0.4, -3.5},
            {-1.7, 3.0, -7.5},
            {1.3, -2.0, -2.5},
            {1.5, 2.0, -2.5},
            {1.5, 0.2, -1.5},
            {-1.3, 1.0, -1.5},
        };
        
        _verticesBuffer = [device newBufferWithBytes:cubeVertices
                                    length:sizeof(cubeVertices)
                                    options:MTLResourceStorageModeShared];

        int cubeNum = sizeof(cubePositions) / sizeof(cubePositions[0]);
        _cubeNum = cubeNum;
        
        _indirectObjectParamsBuffer = [device newBufferWithLength:(sizeof(ObjectParams) * cubeNum) options:MTLResourceStorageModeShared];
        _indirectObjectParamsBuffer.label = @"Object Params buffer";
        
        void *objectParamsPtr = [_indirectObjectParamsBuffer contents];
        
        for (int i = 0; i < cubeNum; i++) {
            ObjectParams param;
            param.modelMatrix = simd_mul(matrix4x4_translation(cubePositions[i] * _size),
                                        simd_mul(matrix4x4_rotation(M_PI / (1.0 + arc4random() % 10),
                                                                    arc4random() % 100,
                                                                    arc4random() % 100,
                                                                    arc4random() % 100),
                                                  matrix4x4_scale(_size.x, _size.y, _size.z)));
//            param.modelMatrix = simd_mul(matrix4x4_translation(cubePositions[i] * _size),
//                                                  matrix4x4_scale(_size.x, _size.y, _size.z));

            memcpy(objectParamsPtr, &param, sizeof(param));
            objectParamsPtr += sizeof(param);
        }
        
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
        pipelineStateDescriptor.supportIndirectCommandBuffers = YES;
        
        
        _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
        
        NSAssert(_pipelineState, @"Failed to create pipeline state: %@", error);
        
        _commandQueue = [_device newCommandQueue];
        
        _viewportSize = (vector_uint2){ (int) (mtkView.frame.size.width), (int) (mtkView.frame.size.height) };
        
        float width = mtkView.frame.size.width;
        float height = mtkView.frame.size.height;
        
        _uniforms.viewMatrix = matrix_look_at_left_hand((vector_float3) {0.0, 0.0, -800.0},
                                                        (vector_float3) {0.0, 0.0, 0.0 },
                                                        (vector_float3) {0.0, 1.0, 0.0});

        _uniforms.projectionMatrix = matrix_perspective_left_hand(M_PI / 3.0, width / height, 0.1, 9000.0);
        
        _uniformBuffer = [device newBufferWithBytes:&_uniforms
                                             length:sizeof(_uniforms)
                                            options:MTLResourceStorageModeShared];
        
        id<MTLArgumentEncoder> argumentEncoder = [fragmentFunc newArgumentEncoderWithBufferIndex:FragmentInputIndexArgument];
        NSUInteger argumentBufferLength = [argumentEncoder encodedLength];
        _fragmentArgumentBuffer = [device newBufferWithLength:argumentBufferLength options:MTLResourceStorageModeShared];
        _fragmentArgumentBuffer.label = @"Argument buffer";
        
        [argumentEncoder setArgumentBuffer:_fragmentArgumentBuffer offset:0];
        [argumentEncoder setTexture:_textureContainer atIndex:ArgumentBufferIDTextureFirst];
        [argumentEncoder setTexture:_textureFace atIndex:ArgumentBufferIDTextureSecond];
        
    }
    
    return self;
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;

    _uniforms.projectionMatrix = matrix_perspective_left_hand(M_PI / 3.0, size.width / size.height, 0.1, 1000.0);
    
    void *uniformPtr = [_uniformBuffer contents];
    memcpy(uniformPtr, &_uniforms, sizeof(_uniforms));
}

- (void)drawInMTKView:(nonnull MTKView *)view
{
    [self rotate];
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"Square Command";
    
    MTLRenderPassDescriptor *descriptor = [view currentRenderPassDescriptor];
    
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    [renderEncoder setLabel:@"MyRenderEncoder"];
        
    [renderEncoder setViewport:(MTLViewport){ 0.0, 0.0, _viewportSize.x, _viewportSize.y, 0.0, 1.0 }];
    [renderEncoder setRenderPipelineState:_pipelineState];
    [renderEncoder setDepthStencilState:_depthState];
    
    [renderEncoder useResource:_textureContainer usage:MTLResourceUsageSample];
    [renderEncoder useResource:_textureFace usage:MTLResourceUsageSample];
    
    [renderEncoder setVertexBuffer:_verticesBuffer offset:0 atIndex:VertexInputIndexVertices];
    [renderEncoder setVertexBuffer:_uniformBuffer offset:0 atIndex:VertexInputIndexUniforms];
    [renderEncoder setVertexBuffer:_indirectObjectParamsBuffer
                        offset:0
                        atIndex:VertexInputIndexObjParams];
    [renderEncoder setFragmentBuffer:_fragmentArgumentBuffer
                              offset:0
                             atIndex:FragmentInputIndexArgument];
    
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:36 instanceCount:_cubeNum];
    
    [renderEncoder endEncoding];
    
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}

- (void)rotate {
    void *objectParamsPtr = [_indirectObjectParamsBuffer contents];
    
    for (int i = 0; i < _cubeNum; i++) {
        ObjectParams param;
        param.modelMatrix = simd_mul(((ObjectParams*)objectParamsPtr)->modelMatrix,
                                     matrix4x4_rotation(0.05, 0.0, 1.0, 1.0));

        memcpy(objectParamsPtr, &param, sizeof(param));
        objectParamsPtr += sizeof(param);
    }
}

@end

