//
//  Renderer.m
//  ExploadingMesh
//
//  Created by Jacob Su on 3/27/21.
//
@import ModelIO;
@import MetalKit;
@import Metal;
#import <Foundation/Foundation.h>
#import "Renderer.h"
#import "ModelShaderType.h"
#import <common/common.h>

@implementation Renderer
{
    id<MTLDevice> _device;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLComputePipelineState> _computePipelineState;
    id<MTLCommandQueue> _commandQueue;
    id<MTLDepthStencilState> _depthState;
    id<MetalMesh> _nanoSuitMesh;
    MTKMesh *_mtkMesh;
    id<MTLBuffer> _exploadingBuffer;
    Uniforms _uniforms;
    vector_uint2 _viewportSize;
    id<Camera> _camera;
    SatelliteCameraController *_cameraController;
    NSDate *_date;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView
{
    self = [super init];
    
    if (self) {
        mtkView.delegate = self;
        id<MTLDevice> device = mtkView.device;
        _device = mtkView.device;
        _date = [NSDate new];
        
        _camera = [[SimpleCamera alloc] initWithPosition:(vector_float3) {0.0, 0.0, 3.0}
                                              withTarget:(vector_float3) {0.0, 0.0, 0.0}
                                                      up:YES];
        _cameraController = [[SatelliteCameraController alloc] initWithCamera:_camera];
        
        mtkView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
        mtkView.clearDepth = 1.0;
        MTLDepthStencilDescriptor *depthStencilDesc = [MTLDepthStencilDescriptor new];
        depthStencilDesc.depthCompareFunction = MTLCompareFunctionLess;
        depthStencilDesc.depthWriteEnabled = YES;
        _depthState = [device newDepthStencilStateWithDescriptor:depthStencilDesc];
        
        NSURL *url = [[NSBundle common] URLForResource:@"nanosuit" withExtension:@"obj" subdirectory:@"nanosuit"];
        
        NSAssert([MDLAsset canImportFileExtension:@"obj"], @"MDL Asset can not import obj file");
        
        MTLVertexDescriptor *mtlVertexDescriptor = [[MTLVertexDescriptor alloc] init];
        // position
        mtlVertexDescriptor.attributes[ModelVertexAttributePosition].format = MTLVertexFormatFloat3;
        mtlVertexDescriptor.attributes[ModelVertexAttributePosition].offset = 0;
        mtlVertexDescriptor.attributes[ModelVertexAttributePosition].bufferIndex = ModelVertexInputIndexPosition;
        
        // texture coordinate
        mtlVertexDescriptor.attributes[ModelVertexAttributeTexcoord].format = MTLVertexFormatFloat2;
        mtlVertexDescriptor.attributes[ModelVertexAttributeTexcoord].offset = 16;
        mtlVertexDescriptor.attributes[ModelVertexAttributeTexcoord].bufferIndex = ModelVertexInputIndexPosition;
        
        // normal
        mtlVertexDescriptor.attributes[ModelVertexAttributeNormal].format = MTLVertexFormatFloat3;
        mtlVertexDescriptor.attributes[ModelVertexAttributeNormal].offset = 32;
        mtlVertexDescriptor.attributes[ModelVertexAttributeNormal].bufferIndex = ModelVertexInputIndexPosition;
        
        // layout
        mtlVertexDescriptor.layouts[ModelVertexInputIndexPosition].stride = 48;
        mtlVertexDescriptor.layouts[ModelVertexInputIndexPosition].stepRate = 1;
        mtlVertexDescriptor.layouts[ModelVertexInputIndexPosition].stepFunction = MTLVertexStepFunctionPerVertex;
        
        NSError *error;
        _nanoSuitMesh = [[ModelIOMesh alloc] initWithUrl:url
                                                device:device
                                   mtlVertexDescriptor:mtlVertexDescriptor
                                          attributeMap:@{
                                              [NSNumber numberWithInt:ModelVertexAttributePosition]: MDLVertexAttributePosition,
                                              [NSNumber numberWithInt:ModelVertexAttributeTexcoord]: MDLVertexAttributeTextureCoordinate,
                                              [NSNumber numberWithInt:ModelVertexAttributeNormal]: MDLVertexAttributeNormal }
                                                 error:&error];
        _mtkMesh = [_nanoSuitMesh mtkMesh];
        
        _exploadingBuffer = [_device newBufferWithLength:_mtkMesh.vertexBuffers[0].buffer.length
                                                 options:MTLResourceStorageModePrivate];
        
        id<MTLLibrary> library = [device newDefaultLibrary];
        id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertexShader"];
        id<MTLFunction> fragmentFunc = [library newFunctionWithName:@"fragmentShader"];
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"Model pipeline";
        pipelineStateDescriptor.vertexDescriptor = mtlVertexDescriptor;
        pipelineStateDescriptor.vertexFunction = vertexFunc;
        pipelineStateDescriptor.fragmentFunction = fragmentFunc;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        pipelineStateDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat;
        
        _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
        
        NSAssert(_pipelineState, @"Failed to create pipeline state: %@", error);
        
        id<MTLFunction> computeFunc = [library newFunctionWithName:@"exploadingCompute"];
        _computePipelineState = [_device newComputePipelineStateWithFunction:computeFunc error:&error];
        NSAssert(_computePipelineState, @"Failed to create compute pipeline: %@", error);
        
        _commandQueue = [_device newCommandQueue];
        
        _viewportSize = (vector_uint2){ (int) (mtkView.frame.size.width), (int) (mtkView.frame.size.height) };
        float width = mtkView.frame.size.width;
        float height = mtkView.frame.size.height;
        
        _uniforms.modelMatrix = simd_mul(matrix4x4_translation(0.0, -1.75, 0.0), matrix4x4_scale(0.2, 0.2, 0.2));
        _uniforms.viewMatrix = [_camera getViewMatrix];
        _uniforms.projectionMatrix = matrix_perspective_left_hand(M_PI / 4.0, width / height, 0.1, 100.0);
    }
    
    return self;
}

- (void) handleMouseScrollDeltaX:(float) deltaX deltaY:(float) deltaY {
    [_cameraController rotateCameraAroundTargetWithDeltaPhi:deltaX * 0.2 deltaTheta:deltaY * 0.2];
    
    _uniforms.viewMatrix = [_camera getViewMatrix];
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"Model Command";
    
    // generate exploading buffer
    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    [computeEncoder setLabel:@"exploading compute"];
    [computeEncoder setComputePipelineState:_computePipelineState];
    float time = [_date timeIntervalSinceNow];
    
    [computeEncoder setBytes:&time length:sizeof(time) atIndex:ComputeKernelIndexInputTime];
    [computeEncoder setBuffer:_mtkMesh.vertexBuffers[0].buffer offset:0 atIndex:ComputeKernelIndexInputVertex];
    [computeEncoder setBuffer:_exploadingBuffer offset:0 atIndex:ComputeKernelIndexOutputVertex];
    
    [computeEncoder dispatchThreads:MTLSizeMake(_mtkMesh.vertexCount, 1, 1)
              threadsPerThreadgroup:MTLSizeMake(_computePipelineState.threadExecutionWidth, 1, 1)];
    [computeEncoder endEncoding];
    
    // render model
    MTLRenderPassDescriptor *descriptor = [view currentRenderPassDescriptor];
    
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    [renderEncoder setLabel:@"Model RenderEncoder"];
        
    [renderEncoder setViewport:(MTLViewport){ 0.0, 0.0, _viewportSize.x, _viewportSize.y, 0.0, 1.0 }];
    [renderEncoder setRenderPipelineState:_pipelineState];
    [renderEncoder setDepthStencilState:_depthState];
    [renderEncoder setCullMode:MTLCullModeBack];
    [renderEncoder setFrontFacingWinding:MTLWindingClockwise];
    
    [renderEncoder setVertexBuffer:_exploadingBuffer offset:0 atIndex:ModelVertexInputIndexPosition];
    
    [renderEncoder setVertexBytes:&_uniforms length:sizeof(_uniforms) atIndex:ModelVertexInputIndexUniforms];
    
    [_nanoSuitMesh drawMeshToRenderEncoder:renderEncoder textureHandler:^(MDLMaterialSemantic type, id<MTLTexture> texture, NSString* _) {
        if (type == MDLMaterialSemanticBaseColor) {
            [renderEncoder setFragmentTexture:texture atIndex:FragmentInputIndexDiffuseTexture];
        }
    }];
    
    [renderEncoder endEncoding];
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
 
    _uniforms.projectionMatrix = matrix_perspective_left_hand(M_PI / 4.0, size.width / size.height, 0.1, 100.0);
}

@end
