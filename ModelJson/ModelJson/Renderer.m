//
//  Renderer.m
//  ModelJson
//
//  Created by Jacob Su on 4/26/21.
//

@import ModelIO;
@import MetalKit;
@import Metal;
#import <Foundation/Foundation.h>
#import "Renderer.h"
#import "ShaderType.h"
#import <common/common.h>

@implementation Renderer
{
    id<MTLDevice> _device;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLCommandQueue> _commandQueue;
    id<MTLDepthStencilState> _depthState;
    id<MetalMesh> _foxMesh;
    Uniforms _uniforms;
    vector_uint2 _viewportSize;
    id<Camera> _camera;
    SatelliteCameraController *_satelliteController;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView
{
    self = [super init];
    
    if (self) {
        mtkView.delegate = self;
        mtkView.sampleCount = 4;
        id<MTLDevice> device = mtkView.device;
        _device = mtkView.device;
        _camera = [[SimpleCamera alloc] initWithPosition:(vector_float3) {5.0, 0.0, 8.0}
                                              withTarget:(vector_float3){0.0, 0.0, 0.0}
                                                      up:YES];
        _satelliteController = [[SatelliteCameraController alloc] initWithCamera:_camera];
        
        mtkView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
        mtkView.clearDepth = 1.0;
        MTLDepthStencilDescriptor *depthStencilDesc = [MTLDepthStencilDescriptor new];
        depthStencilDesc.depthCompareFunction = MTLCompareFunctionLess;
        depthStencilDesc.depthWriteEnabled = YES;
        _depthState = [device newDepthStencilStateWithDescriptor:depthStencilDesc];
        
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
        
        NSDictionary *attributeMap = @{
            [NSNumber numberWithInt:ModelVertexAttributePosition]: MDLVertexAttributePosition,
            [NSNumber numberWithInt:ModelVertexAttributeTexcoord]: MDLVertexAttributeTextureCoordinate,
            [NSNumber numberWithInt:ModelVertexAttributeNormal]: MDLVertexAttributeNormal
        };
        
        NSError *error;
        
        NSURL *foxJsonUrl = [[NSBundle common] URLForResource:@"fox.json"
                                                withExtension:nil
                                                 subdirectory:@"fox"];
        NSURL *foxTextureUrl = [[NSBundle common] URLForResource:@"fox.jpg"
                                                   withExtension:nil
                                                    subdirectory:@"fox"];
        _foxMesh = [[JsonMesh alloc] initWithJson:foxJsonUrl
                                      withTexture:foxTextureUrl
                                           device:_device
                              mtlVertexDescriptor:mtlVertexDescriptor
                                     attributesMap:attributeMap
                                            error:&error];
        NSAssert(_foxMesh, @"fox mesh error: %@", error);
        
        id<MTLLibrary> library = [device newDefaultLibrary];
        id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertexShader"];
        id<MTLFunction> fragmentFunc = [library newFunctionWithName:@"fragmentShader"];
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"Model pipeline";
        pipelineStateDescriptor.vertexDescriptor = mtlVertexDescriptor;
        pipelineStateDescriptor.vertexFunction = vertexFunc;
        pipelineStateDescriptor.fragmentFunction = fragmentFunc;
        pipelineStateDescriptor.sampleCount = mtkView.sampleCount;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        pipelineStateDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat;
        
        _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
        
        NSAssert(_pipelineState, @"Failed to create pipeline state: %@", error);
        
        _commandQueue = [_device newCommandQueue];
        
        _viewportSize = (vector_uint2){ (int) (mtkView.frame.size.width), (int) (mtkView.frame.size.height) };
        float width = mtkView.frame.size.width;
        float height = mtkView.frame.size.height;
        
        _uniforms.modelMatrix = matrix4x4_translation(0.0, -1.5, 0.0);
        _uniforms.viewMatrix = [_camera getViewMatrix];
        _uniforms.projectionMatrix = matrix_perspective_left_hand(M_PI / 4.0, width / height, 0.1, 100.0);
    }
    
    return self;
}

- (void) handleMouseScrollDeltaX:(float) deltaX deltaY:(float) deltaY {
    
    if (fabsf(deltaX) >= fabsf(deltaY)) {
        [_satelliteController rotateCameraAroundTargetWithDeltaPhi:deltaX deltaTheta:0.0];
    } else {
        [_satelliteController rotateCameraAroundTargetWithDeltaPhi:0.0 deltaTheta:deltaY * 0.2];
    }
    
    _uniforms.viewMatrix = [_camera getViewMatrix];
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"Model Command";
    
    MTLRenderPassDescriptor *descriptor = [view currentRenderPassDescriptor];
    
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    [renderEncoder setLabel:@"Model RenderEncoder"];
        
    [renderEncoder setViewport:(MTLViewport){ 0.0, 0.0, _viewportSize.x, _viewportSize.y, 0.0, 1.0 }];
    [renderEncoder setRenderPipelineState:_pipelineState];
    [renderEncoder setDepthStencilState:_depthState];
    
    [_foxMesh setVertexMeshToRenderEncoder:renderEncoder index:ModelVertexInputIndexPosition];
    
    [renderEncoder setVertexBytes:&_uniforms length:sizeof(_uniforms) atIndex:ModelVertexInputIndexUniforms];
    
    [_foxMesh drawMeshToRenderEncoder:renderEncoder textureHandler:^(MDLMaterialSemantic type, id<MTLTexture> texture, NSString* _) {
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
