//
//  Renderer.m
//  PBRTextured
//
//  Created by Jacob Su on 4/16/21.
//

#import <Foundation/Foundation.h>
#import "Renderer.h"
#import <common/common.h>
#import "ShaderType.h"
@import MetalKit;

@implementation Renderer
{
    id<MTLDevice> _device;
    id<Camera> _camera;
    id<MTLDepthStencilState> _depthState;
    MTKMesh *_sphereMesh;
    id<MTLTexture> _albedoTexture;
    id<MTLTexture> _metallicTexture;
    id<MTLTexture> _normalTexture;
    id<MTLTexture> _roughnessTexture;
    id<MTLTexture> _aoTexture;
    id<MTLRenderPipelineState> _renderPipelineState;
    id<MTLBuffer> _materialBuffer;
    id<MTLCommandQueue> _commandQueue;
    
    Uniforms _uniform;
    Light _light;
    MTLViewport _viewPort;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView {
    self = [super init];
    
    if (self) {
        _device = mtkView.device;
        mtkView.delegate = self;
        mtkView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
        mtkView.clearDepth = 1.0;
        
        _camera = [CameraFactory generateRoundOrbitCameraWithPosition:(vector_float3) {0.0, 0.0, 10.0}
                                                               target:(vector_float3){0.0, 0.0, 0.0}
                                                                   up:(vector_float3){0.0, 1.0, 0.0}];
        MTLDepthStencilDescriptor *depthDescriptor = [MTLDepthStencilDescriptor new];
        depthDescriptor.depthCompareFunction = MTLCompareFunctionLessEqual;
        depthDescriptor.depthWriteEnabled = TRUE;
        
        _depthState = [_device newDepthStencilStateWithDescriptor:depthDescriptor];
        
        MTLVertexDescriptor *mtlVertexDescriptor = [MTLVertexDescriptor new];
        // position
        mtlVertexDescriptor.attributes[ModelVertexAttributePosition].format = MTLVertexFormatFloat3;
        mtlVertexDescriptor.attributes[ModelVertexAttributePosition].offset = 0;
        mtlVertexDescriptor.attributes[ModelVertexAttributePosition].bufferIndex = VertexInputIndexPosition;

        // texture coordinate
        mtlVertexDescriptor.attributes[ModelVertexAttributeTexcoord].format = MTLVertexFormatFloat2;
        mtlVertexDescriptor.attributes[ModelVertexAttributeTexcoord].offset = 16;
        mtlVertexDescriptor.attributes[ModelVertexAttributeTexcoord].bufferIndex = VertexInputIndexPosition;

        // normal
        mtlVertexDescriptor.attributes[ModelVertexAttributeNormal].format = MTLVertexFormatFloat3;
        mtlVertexDescriptor.attributes[ModelVertexAttributeNormal].offset = 32;
        mtlVertexDescriptor.attributes[ModelVertexAttributeNormal].bufferIndex = VertexInputIndexPosition;

        // layout
        mtlVertexDescriptor.layouts[VertexInputIndexPosition].stride = 48;
        mtlVertexDescriptor.layouts[VertexInputIndexPosition].stepRate = 1;
        mtlVertexDescriptor.layouts[VertexInputIndexPosition].stepFunction = MTLVertexStepFunctionPerVertex;
        
        NSDictionary *attributeMap = @{
            [NSNumber numberWithInt:ModelVertexAttributePosition]: MDLVertexAttributePosition,
            [NSNumber numberWithInt:ModelVertexAttributeNormal]: MDLVertexAttributeNormal,
            [NSNumber numberWithInt:ModelVertexAttributeTexcoord]: MDLVertexAttributeTextureCoordinate
        };
        
        NSError *error;
        
        _sphereMesh = [MTKMesh newEllipsoidWithVertexDescriptor:mtlVertexDescriptor
                                              withAttributesMap:attributeMap
                                                     withDevice:_device
                                                          radii:(vector_float3) {1.0, 1.0, 1.0}
                                                 radialSegments:60
                                               verticalSegments:60
                                                   geometryType:MDLGeometryTypeTriangles
                                                  inwardNormals:NO
                                                     hemisphere:NO
                                                          error:&error];
        MTKTextureLoader *textureLoader = [[MTKTextureLoader alloc] initWithDevice:_device];
        NSURL *albedoUrl = [[NSBundle common] URLForResource:@"rusted_iron/albedo.png" withExtension:nil];
        NSURL *aoUrl = [[NSBundle common] URLForResource:@"rusted_iron/ao.png" withExtension:nil];
        NSURL *metallicUrl = [[NSBundle common] URLForResource:@"rusted_iron/metallic.png" withExtension:nil];
        NSURL *normalUrl = [[NSBundle common] URLForResource:@"rusted_iron/normal.png" withExtension:nil];
        NSURL *roughnessUrl = [[NSBundle common] URLForResource:@"rusted_iron/roughness.png" withExtension:nil];
        
        _albedoTexture = [textureLoader newTextureWithContentsOfURL:albedoUrl options:nil error:&error];
        NSAssert(_albedoTexture, @"albedo texture error:%@", error);
        _aoTexture = [textureLoader newTextureWithContentsOfURL:aoUrl options:nil error:&error];
        NSAssert(_aoTexture, @"ao texture error: %@", error);
        _metallicTexture = [textureLoader newTextureWithContentsOfURL:metallicUrl options:nil error:&error];
        NSAssert(_metallicTexture, @"metallic texture error: %@", error);
        _normalTexture = [textureLoader newTextureWithContentsOfURL:normalUrl options:nil error:&error];
        NSAssert(_normalTexture, @"normal texture error: %@", error);
        _roughnessTexture = [textureLoader newTextureWithContentsOfURL:roughnessUrl options:nil error:&error];
        NSAssert(_roughnessTexture, @"roughness texture error: %@", error);
        
        id<MTLLibrary> library = [_device newDefaultLibrary];
        id<MTLFunction> vertexFunc = [library newFunctionWithName:@"pbrVertexShader"];
        id<MTLFunction> fragmentFunc = [library newFunctionWithName:@"pbrFragmentShader"];
        
        MTLRenderPipelineDescriptor *renderPipelineDescriptor = [MTLRenderPipelineDescriptor new];
        renderPipelineDescriptor.vertexDescriptor = mtlVertexDescriptor;
        renderPipelineDescriptor.vertexFunction = vertexFunc;
        renderPipelineDescriptor.fragmentFunction = fragmentFunc;
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        renderPipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat;
        
        _renderPipelineState = [_device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor error:&error];
        NSAssert(_renderPipelineState, @"create render pipeline state error: %@", error);
        
        id<MTLArgumentEncoder> materialArgumentEncoder = [fragmentFunc newArgumentEncoderWithBufferIndex:FragmentInputIndexMaterial];
        _materialBuffer = [_device newBufferWithLength:materialArgumentEncoder.encodedLength options:MTLResourceStorageModeShared];
        _materialBuffer.label = @"material";
        
        [materialArgumentEncoder setArgumentBuffer:_materialBuffer offset:0];
        [materialArgumentEncoder setTexture:_albedoTexture atIndex:MaterialArgumentIndexAlbedo];
        [materialArgumentEncoder setTexture:_metallicTexture atIndex:MaterialArgumentIndexMetallic];
        [materialArgumentEncoder setTexture:_normalTexture atIndex:MaterialArgumentIndexNormal];
        [materialArgumentEncoder setTexture:_roughnessTexture atIndex:MaterialArgumentIndexRoughness];
        [materialArgumentEncoder setTexture:_aoTexture atIndex:MaterialArgumentIndexAO];
        
        int width = mtkView.frame.size.width;
        int height = mtkView.frame.size.height;
        
        _uniform.modelMatrix = matrix4x4_identity();
        _uniform.viewMatrix = [_camera getViewMatrix];
        _uniform.projectionMatrix = matrix_perspective_left_hand(M_PI/4.0, (float)width/(float)height, 0.1, 100.0);
        
        _light.position = (vector_float3) {0.0, 0.0, 10.0};
        _light.color = (vector_float3) {150.0, 150.0, 150.0};
        
        _viewPort = (MTLViewport) { 0.0, 0.0, width, height, 0.0, 1.0 };
        
        _commandQueue = [_device newCommandQueue];
    }
    
    return self;
}

- (void) handleMouseScrollDeltaX:(float) deltaX deltaY:(float) deltaY {
    [_camera rotateCameraAroundTargetWithDeltaPhi:deltaX * 0.2 deltaTheta:deltaY * 0.2];
    
    _uniform.viewMatrix = [_camera getViewMatrix];
}


- (void)drawInMTKView:(nonnull MTKView *)view {
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [renderEncoder setViewport:_viewPort];
    [renderEncoder setRenderPipelineState:_renderPipelineState];
    [renderEncoder setDepthStencilState:_depthState];
    
    [_sphereMesh setVertexBufferInRenderCommandEncoder:renderEncoder index:VertexInputIndexPosition];
    [renderEncoder useResource:_albedoTexture usage:MTLResourceUsageSample];
    [renderEncoder useResource:_normalTexture usage:MTLResourceUsageSample];
    [renderEncoder useResource:_metallicTexture usage:MTLResourceUsageSample];
    [renderEncoder useResource:_roughnessTexture usage:MTLResourceUsageSample];
    [renderEncoder useResource:_aoTexture usage:MTLResourceUsageSample];
    
    [renderEncoder setFragmentBuffer:_materialBuffer offset:0 atIndex:FragmentInputIndexMaterial];
    [renderEncoder setFragmentBytes:&_light length:sizeof(_light) atIndex:FragmentInputIndexLight];
    vector_float3 cameraPos = _camera.cameraPosition;
    [renderEncoder setFragmentBytes:&cameraPos length:sizeof(vector_float3) atIndex:FragmentInputIndexCameraPostion];
    
    for (int row = 0; row < 7; row++) {
        for (int col = 0; col < 7; col++) {
            _uniform.modelMatrix = matrix4x4_translation((col - 7.0 / 2.0) * 2.5,
                                                         (row - 7.0 / 2.0) * 2.5,
                                                         0.0);
            [renderEncoder setVertexBytes:&_uniform length:sizeof(_uniform) atIndex:VertexInputIndexUniforms];
            [_sphereMesh drawInRenderCommandEncoder:renderEncoder];
        }
    }
    
    [renderEncoder endEncoding];
    
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    _viewPort.width = size.width;
    _viewPort.height = size.height;
    
    _uniform.projectionMatrix = matrix_perspective_left_hand(M_PI / 4.0, (float)size.width/(float)size.height, 0.1, 100.0);
}

@end
