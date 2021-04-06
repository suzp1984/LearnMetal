//
//  Renderer.m
//  ParallaxMapping
//
//  Created by Jacob Su on 4/6/21.
//

#import <Foundation/Foundation.h>
#import "Renderer.h"
#import "ShaderType.h"
@import MetalKit;
#import <common/common.h>
#import <common/common-Swift.h>

@implementation Renderer
{
    id<MTLDevice> _device;
    Camera *_camera;
    id<MTLBuffer> _planeBuffer;
    id<MTLDepthStencilState> _depthState;
    id<MTLRenderPipelineState> _renderPipelineState;
    id<MTLTexture> _bricks;
    id<MTLTexture> _bricksNormal;
    id<MTLTexture> _bricksDepth;
    id<MTLCommandQueue> _commandQueue;
    Uniform _uniform;
    NSDate *_date;
    MTLViewport viewport;
    float _heightScale;
    uint _parallaxMethod;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView {
    self = [super init];
    
    if (self) {
        _parallaxMethod = 2;
        _heightScale = 0.1;
        _date = [[NSDate alloc] init];
        _device = mtkView.device;
        mtkView.delegate = self;
        
        _camera = [[Camera alloc] initWithPosition:(vector_float3) {0.0, 0.0, 3.0}
                                        withTarget:(vector_float3) {0.0, 0.0, 0.0}
                                            withUp:(vector_float3) {0.0, 1.0, 0.0}];
        mtkView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
        mtkView.clearDepth = 1.0;
        
        MTLDepthStencilDescriptor *depthStencilDesc = [MTLDepthStencilDescriptor new];
        depthStencilDesc.depthCompareFunction = MTLCompareFunctionLess;
        depthStencilDesc.depthWriteEnabled = YES;
        _depthState = [_device newDepthStencilStateWithDescriptor:depthStencilDesc];
        
        vector_float3 pos1 = {-1.0,  1.0, 0.0};
        vector_float3 pos2 = {-1.0, -1.0, 0.0};
        vector_float3 pos3 = { 1.0, -1.0, 0.0};
        vector_float3 pos4 = { 1.0,  1.0, 0.0};
        
        vector_float2 uv1 = {0.0, 1.0};
        vector_float2 uv2 = {0.0, 0.0};
        vector_float2 uv3 = {1.0, 0.0};
        vector_float2 uv4 = {1.0, 1.0};
        
        vector_float3 nm = {0.0, 0.0, 1.0};
        
        vector_float3 tangent1;
        vector_float3 tangent2;
        vector_float3 bitangent1;
        vector_float3 bitangent2;
        
        vector_float3 edge1 = pos2 - pos1;
        vector_float3 edge2 = pos3 - pos1;
        vector_float2 deltaUV1 = uv2 - uv1;
        vector_float2 deltaUV2 = uv3 - uv1;
        
        float f = 1.0f / (deltaUV1.x * deltaUV2.y - deltaUV2.x * deltaUV1.y);
        
        tangent1.x = f * (deltaUV2.y * edge1.x - deltaUV1.y * edge2.x);
        tangent1.y = f * (deltaUV2.y * edge1.y - deltaUV1.y * edge2.y);
        tangent1.z = f * (deltaUV2.y * edge1.z - deltaUV1.y * edge2.z);
        
        bitangent1.x = f * (-deltaUV2.x * edge1.x + deltaUV1.x * edge2.x);
        bitangent1.y = f * (-deltaUV2.x * edge1.y + deltaUV1.x * edge2.y);
        bitangent1.z = f * (-deltaUV2.x * edge1.z + deltaUV1.x * edge2.z);

        // triangle 2
        // ----------
        edge1 = pos3 - pos1;
        edge2 = pos4 - pos1;
        deltaUV1 = uv3 - uv1;
        deltaUV2 = uv4 - uv1;

        f = 1.0f / (deltaUV1.x * deltaUV2.y - deltaUV2.x * deltaUV1.y);

        tangent2.x = f * (deltaUV2.y * edge1.x - deltaUV1.y * edge2.x);
        tangent2.y = f * (deltaUV2.y * edge1.y - deltaUV1.y * edge2.y);
        tangent2.z = f * (deltaUV2.y * edge1.z - deltaUV1.y * edge2.z);


        bitangent2.x = f * (-deltaUV2.x * edge1.x + deltaUV1.x * edge2.x);
        bitangent2.y = f * (-deltaUV2.x * edge1.y + deltaUV1.x * edge2.y);
        bitangent2.z = f * (-deltaUV2.x * edge1.z + deltaUV1.x * edge2.z);
        
        Vertex vertices[6] = {
            {pos1, nm, uv1, tangent1, bitangent1},
            {pos2, nm, uv2, tangent1, bitangent1},
            {pos3, nm, uv3, tangent1, bitangent1},
            
            {pos1, nm, uv1, tangent2, bitangent2},
            {pos3, nm, uv3, tangent2, bitangent2},
            {pos4, nm, uv4, tangent2, bitangent2},
        };

        _planeBuffer = [_device newBufferWithBytes:vertices length:sizeof(vertices) options:MTLResourceStorageModeShared];
        
        id<MTLLibrary> library = [_device newDefaultLibrary];
        id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertexShader"];
        id<MTLFunction> fragmentFunc = [library newFunctionWithName:@"fragmentShader"];
        
        MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
        pipelineDescriptor.vertexFunction = vertexFunc;
        pipelineDescriptor.fragmentFunction = fragmentFunc;
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        pipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat;
        
        NSError *error;
        _renderPipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
        NSAssert(_renderPipelineState, @"error when create render pipeline state: %@", error);
        
        MTKTextureLoader *textureLoader = [[MTKTextureLoader alloc] initWithDevice:_device];
        NSBundle *bundle = [NSBundle bundleForClass:[TextureCubeLoader class]];
        _bricks = [textureLoader newTextureWithName:@"bricks2"
                                      scaleFactor:1.0
                                           bundle:bundle
                                          options:@{ MTKTextureLoaderOptionSRGB: [NSNumber numberWithBool:NO] }
                                            error:&error];
        NSAssert(_bricks, @"can not load brickwall texutre: %@", error);
        
        _bricksNormal = [textureLoader newTextureWithName:@"bricks2_normal"
                                                 scaleFactor:1.0
                                                      bundle:bundle
                                                     options:nil
                                                       error:&error];
        NSAssert(_bricksNormal, @"can not load brickwall normal texture: %@", error);
        
        _bricksDepth = [textureLoader newTextureWithName:@"bricks2_disp"
                                             scaleFactor:1.0
                                                  bundle:bundle
                                                 options:nil
                                                   error:&error];
        NSAssert(_bricksDepth, @"can not load depth map texture: %@", error);
        
        _commandQueue = [_device newCommandQueue];
        
        float width = mtkView.frame.size.width;
        float height = mtkView.frame.size.height;
        
        _uniform.lightPos = (vector_float3) { 0.5, 1.0, 0.3 };
        _uniform.viewPos = [_camera getCameraPosition];
        _uniform.viewMatrix = [_camera getViewMatrix];
        _uniform.modelMatrix = matrix4x4_rotation(0, vector_normalize((vector_float3) {1.0, 0.0, 0.0}));
        _uniform.projectionMatrix = matrix_perspective_left_hand(M_PI / 4.0, width / height, 0.1, 100.0);
        
        [self rebuildNormalMatrix];
        viewport = (MTLViewport) { 0.0, 0.0, width, height, 0.0, 1.0 };
    }
    
    return self;
}

- (void) rebuildNormalMatrix {
    matrix_float3x3 model3x3;
    model3x3.columns[0] = _uniform.modelMatrix.columns[0].xyz;
    model3x3.columns[1] = _uniform.modelMatrix.columns[1].xyz;
    model3x3.columns[2] = _uniform.modelMatrix.columns[2].xyz;
    
    _uniform.normalMatrix = simd_transpose(simd_inverse(model3x3));
}

- (void) handleMouseScrollDeltaX:(float) deltaX deltaY:(float) deltaY {
    [_camera handleMouseScrollDeltaX:deltaX deltaY:deltaY];
    
    _uniform.viewMatrix = [_camera getViewMatrix];
    _uniform.viewPos = [_camera getCameraPosition];
}

- (void) animate {
    _uniform.modelMatrix = matrix4x4_rotation([_date timeIntervalSinceNow] * -1.0, vector_normalize((vector_float3) {1.0, 0.0, 1.0}));

    [self rebuildNormalMatrix];
}

- (void) setHeightScale:(float) scale {
    _heightScale = scale;
}

- (void) setParallaxMethod:(uint) methodType {
    _parallaxMethod = methodType;
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    [self animate];
    
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    
    [renderEncoder setDepthStencilState:_depthState];
    [renderEncoder setRenderPipelineState:_renderPipelineState];
    [renderEncoder setViewport:viewport];
    
    [renderEncoder setVertexBuffer:_planeBuffer offset:0 atIndex:VertexInputIndexPosition];
    
    [renderEncoder setVertexBytes:&_uniform length:sizeof(_uniform) atIndex:VertexInputIndexUniforms];
    
    [renderEncoder setFragmentTexture:_bricks atIndex:FragmentInputIndexDiffuseMap];
    [renderEncoder setFragmentTexture:_bricksNormal atIndex:FragmentInputIndexNormalMap];
    [renderEncoder setFragmentTexture:_bricksDepth atIndex:FragmentInputIndexDepthMap];
    [renderEncoder setFragmentBytes:&_heightScale
                             length:sizeof(_heightScale)
                            atIndex:FragmentInputIndexHeightScale];
    [renderEncoder setFragmentBytes:&_parallaxMethod
                             length:sizeof(_parallaxMethod)
                            atIndex:FragmentInputIndexParallaxMethod];
    
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    
    [renderEncoder endEncoding];
    
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    viewport.width = size.width;
    viewport.height = size.height;
    
    _uniform.projectionMatrix = matrix_perspective_left_hand(M_PI / 4.0, size.width / size.height, 0.1, 100.0);
}

@end
