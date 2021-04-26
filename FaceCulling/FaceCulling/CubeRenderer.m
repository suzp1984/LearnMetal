//
//  CubeRenderer.m
//  FaceCulling
//
//  Created by Jacob Su on 3/22/21.
//

@import MetalKit;
@import Metal;
#import <Foundation/Foundation.h>
#import <common/common.h>
#import <common/common-Swift.h>
#import "CubeRenderer.h"
#import "CubeShaderType.h"

@implementation CubeRenderer
{
    id<MTLDevice> _device;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLDepthStencilState> _depthState;
    id<MTLCommandQueue> _commandQueue;
    MTKMesh *_cubeMesh;
    id<Camera> _camera;
    SatelliteCameraController *_cameraController;
    
    id<MTLTexture> _textureContainer;
    vector_uint2 _viewportSize;
    Uniforms _uniforms;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView
{
    self = [super init];
    
    if (self) {
        _camera = [[SimpleCamera alloc] initWithPosition:(vector_float3) {0.0, 0.0, 3.0}
                                              withTarget:(vector_float3) {0.0, 0.0, 0.0}
                                                      up:YES];
        _cameraController = [[SatelliteCameraController alloc] initWithCamera:_camera];
        
        mtkView.delegate = self;
        mtkView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
        mtkView.clearDepth = 1.0;
        
        id<MTLDevice> device = [mtkView device];
        _device = device;
        
        MTLDepthStencilDescriptor *depthDescriptor = [MTLDepthStencilDescriptor new];
        depthDescriptor.depthCompareFunction = MTLCompareFunctionLessEqual;
        depthDescriptor.depthWriteEnabled = YES;
        
        _depthState = [device newDepthStencilStateWithDescriptor:depthDescriptor];
        
        MTLVertexDescriptor *mtlVertexDescriptor = [MTLVertexDescriptor new];
        
        // positions
        mtlVertexDescriptor.attributes[VertexAttributeIndexPosition].format = MTLVertexFormatFloat3;
        mtlVertexDescriptor.attributes[VertexAttributeIndexPosition].offset = 0;
        mtlVertexDescriptor.attributes[VertexAttributeIndexPosition].bufferIndex = VertexInputIndexPosition;
        
        // texture coordinates
        mtlVertexDescriptor.attributes[VertexAttributeIndexTexcoord].format = MTLVertexFormatFloat2;
        mtlVertexDescriptor.attributes[VertexAttributeIndexTexcoord].offset = 16;
        mtlVertexDescriptor.attributes[VertexAttributeIndexTexcoord].bufferIndex = VertexInputIndexPosition;

        mtlVertexDescriptor.layouts[VertexInputIndexPosition].stride = 32;
        mtlVertexDescriptor.layouts[VertexInputIndexPosition].stepRate = 1;
        mtlVertexDescriptor.layouts[VertexInputIndexPosition].stepFunction = MTLVertexStepFunctionPerVertex;

        NSBundle *bundle = [NSBundle common];
        
        NSError *error;
        MTKTextureLoader *textureLoader = [[MTKTextureLoader alloc] initWithDevice:_device];
        _textureContainer = [textureLoader newTextureWithName:@"container" scaleFactor:1.0 bundle:bundle options:nil error:&error];
        NSAssert(_textureContainer, @"Failed to create texture container: %@", error);
        
        id<MTLLibrary> library = [device newDefaultLibrary];
        id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertexShader"];
        id<MTLFunction> fragmentFunc = [library newFunctionWithName:@"fragmentShader"];
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"Triangle pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunc;
        pipelineStateDescriptor.fragmentFunction = fragmentFunc;
        pipelineStateDescriptor.vertexDescriptor = mtlVertexDescriptor;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        pipelineStateDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat;
        
        
        _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
        
        NSAssert(_pipelineState, @"Failed to create pipeline state: %@", error);
        
        _cubeMesh = [MTKMesh newBoxWithVertexDescriptor:mtlVertexDescriptor
                          withAttributesMap:@{
                              [NSNumber numberWithInt:VertexAttributeIndexPosition] : MDLVertexAttributePosition,
                              [NSNumber numberWithInt:VertexAttributeIndexTexcoord] : MDLVertexAttributeTextureCoordinate}
                                 withDevice:_device withDimensions:(vector_float3) {1.0, 1.0, 1.0} segments:(vector_uint3) {1, 1, 1} geometryType:MDLGeometryTypeTriangles inwardNormals:NO error:&error];
                
        _commandQueue = [_device newCommandQueue];
        
        _viewportSize = (vector_uint2){ (int) (mtkView.frame.size.width), (int) (mtkView.frame.size.height) };
        
        float width = mtkView.frame.size.width;
        float height = mtkView.frame.size.height;
        
        _uniforms.modelMatrix = matrix4x4_rotation(M_PI / 4.0, 1.0, 1.0, 0.0);
        _uniforms.viewMatrix = [_camera getViewMatrix];

        _uniforms.projectionMatrix = matrix_perspective_left_hand(M_PI / 3.0, width / height, 0.1, 100.0);
    }
    
    return self;
}

- (void) handleMouseScrollDeltaX:(float) deltaX deltaY:(float) deltaY {
    [_cameraController rotateCameraAroundTargetWithDeltaPhi:deltaX deltaTheta:deltaY];
    
    _uniforms.viewMatrix = [_camera getViewMatrix];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;

    _uniforms.projectionMatrix = matrix_perspective_left_hand(M_PI / 3.0, size.width / size.height, 0.1, 100.0);
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
    [renderEncoder setCullMode:MTLCullModeFront];
    [renderEncoder setFrontFacingWinding:MTLWindingClockwise];
    
    [_cubeMesh setVertexBufferInRenderCommandEncoder:renderEncoder index:VertexInputIndexPosition];
    
    [renderEncoder setVertexBytes:&_uniforms length:sizeof(_uniforms) atIndex:VertexInputIndexUniforms];
    
    [renderEncoder setFragmentTexture:_textureContainer atIndex:FragmentInputIndexTexture];
        
    [_cubeMesh drawInRenderCommandEncoder:renderEncoder];
    
    [renderEncoder endEncoding];
    
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}



@end
