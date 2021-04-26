//
//  Renderer.m
//  SSAO
//
//  Created by Jacob Su on 4/13/21.
//

#import <Foundation/Foundation.h>
#import <common/common.h>
#import "Renderer.h"
#import "ShaderType.h"

@implementation Renderer
{
    id<MTLDevice> _device;
    id<Camera> _camera;
    SatelliteCameraController *_cameraController;
    id<MTLDepthStencilState> _depthState;
    id<MetalMesh> _backpackMesh;
    MTKMesh *_cubeMesh;
    id<MTLTexture> _gPosition;
    id<MTLTexture> _gNormal;
    id<MTLTexture> _gAlbedo;
    id<MTLTexture> _ssaoColorTexture;
    id<MTLTexture> _ssaoBlurTexture;
    id<MTLTexture> _depthTexture;
    id<MTLTexture> _noiseTexture;
    
    Uniforms _uniforms;
    matrix_float4x4 _cubeModelMatrix;
    matrix_float4x4 _meshModelMatrix;
    matrix_float3x3 _cubeNormalMatrix;
    matrix_float3x3 _meshNormalMatrix;
    vector_float3 _ssaoKernel[64];
    int _ssaoKernelCount;
    vector_float2 _noiseScale;
    vector_float2 _textureSize;
    matrix_float4x4 _projectionMatrix;
    
    id<MTLRenderPipelineState> _gBufferPipelineState;
    id<MTLRenderPipelineState> _ssaoPipelineState;
    id<MTLRenderPipelineState> _blurPipelineState;
    id<MTLRenderPipelineState> _lightPipelineState;
    id<MTLRenderPipelineState> _quadPipelineState;
    id<MTLBuffer> _quadVertexBuffer;
    id<MTLCommandQueue> _commandQueue;
    MTLViewport _viewport;
    
    Light _light;
    vector_float3 _lightPos;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView {
    self = [super init];
    
    if (self) {
        _device = mtkView.device;
        mtkView.delegate = self;
        
        _camera = [[SimpleCamera alloc] initWithPosition:(vector_float3) {0.0, 0.0, 6.0}
                                              withTarget:(vector_float3) {0.0, 0.0, 0.0}
                                                      up:YES];
        _cameraController = [[SatelliteCameraController alloc] initWithCamera:_camera];
        
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
        
        NSURL *backpackUrl = [[NSBundle common] URLForResource:@"backpack.obj"
                                                 withExtension:nil
                                                  subdirectory:@"backpack"];
        NSError *error;
        NSDictionary *mdlAttributeMap = @{
            [NSNumber numberWithInt:ModelVertexAttributePosition]: MDLVertexAttributePosition,
            [NSNumber numberWithInt:ModelVertexAttributeTexcoord]:MDLVertexAttributeTextureCoordinate,
            [NSNumber numberWithInt:ModelVertexAttributeNormal]:MDLVertexAttributeNormal,
        };
        
        _backpackMesh = [[ModelIOMesh alloc]
                                   initWithUrl:backpackUrl
                                        device:_device
                                   mtlVertexDescriptor:mtlVertexDescriptor
                                   attributeMap:mdlAttributeMap
                                   error:&error];
        
        _cubeMesh = [MTKMesh newBoxWithVertexDescriptor:mtlVertexDescriptor
                                      withAttributesMap:mdlAttributeMap
                                             withDevice:_device
                                         withDimensions:(vector_float3){2.0, 2.0, 2.0}
                                               segments:(vector_uint3){1, 1, 1}
                                           geometryType:MDLGeometryTypeTriangles
                                          inwardNormals:TRUE
                                                  error:&error];
        
        float width = mtkView.frame.size.width;
        float height = mtkView.frame.size.height;
        
        _gPosition = [self createColorTextureWithWidth:width
                                                height:height
                                           pixelFormat:MTLPixelFormatRGBA16Float
                                           storageMode:MTLStorageModePrivate
                                                 label:@"gPosition"];
        _gNormal = [self createColorTextureWithWidth:width
                                              height:height
                                         pixelFormat:MTLPixelFormatRGBA16Float
                                         storageMode:MTLStorageModePrivate
                                               label:@"gNormal"];
        _gAlbedo = [self createColorTextureWithWidth:width
                                              height:height
                                         pixelFormat:MTLPixelFormatRGBA16Float
                                         storageMode:MTLStorageModePrivate
                                               label:@"gAlbedo"];
        _ssaoColorTexture = [self createColorTextureWithWidth:width
                                                       height:height
                                                  pixelFormat:MTLPixelFormatR16Float
                                                  storageMode:MTLStorageModePrivate
                                                        label:@"ssaoColor"];
        _ssaoBlurTexture = [self createColorTextureWithWidth:width
                                                      height:height
                                                 pixelFormat:MTLPixelFormatR16Float
                                                 storageMode:MTLStorageModePrivate
                                                       label:@"ssaoBlur"];
        
        _depthTexture = [self createDepthTextureWithWidth:width height:height label:@"depth"];
        
        _projectionMatrix = matrix_perspective_left_hand(M_PI / 4.0,
                                                         width / height,
                                                         0.1,
                                                         50.0);
        _uniforms.projectionMatrix = _projectionMatrix;
        _uniforms.viewMatrix = [_camera getViewMatrix];
        _cubeModelMatrix = matrix_multiply(matrix4x4_translation(0.0, 7.0, 0.0),
                                           matrix4x4_scale(7.5, 7.5, 7.5));
        _cubeNormalMatrix = simd_transpose(simd_inverse(matrix3x3_upper_left(_cubeModelMatrix)));
        
        _meshModelMatrix = matrix_multiply(matrix4x4_translation(0.0, 0.5, 0.0),
                                           matrix4x4_rotation(-M_PI/2.0, 1.0, 0.0, 0.0));
        _meshNormalMatrix = simd_transpose(simd_inverse(matrix3x3_upper_left(_meshModelMatrix)));
    
        for (int i = 0; i < 64; i++) {
            vector_float3 sample = {
                [self randomFloatBetween:-1.0 and:1.0],
                [self randomFloatBetween:-1.0 and:1.0],
                [self randomFloatBetween:0.0 and:1.0]};
            sample = simd_normalize(sample);
            sample *= [self randomFloatBetween:0.0 and:1.0];
            float scale = (float) i / 64.0;
            
            scale = [self lerp:0.1 :1.0 :scale*scale];
            sample *= scale;
            _ssaoKernel[i] = sample;
        }
        
        _ssaoKernelCount = 64;
        
        vector_float4 ssaoNoise[16];
        for (int i = 0; i < 16; i++) {
            vector_float4 noise = {
                [self randomFloatBetween:-1.0 and:1.0],
                [self randomFloatBetween:-1.0 and:1.0],
                0.0, 0.0
            };
            ssaoNoise[i] = noise;
        }
        _noiseTexture = [self createColorTextureWithWidth:4
                                                   height:4
                                              pixelFormat:MTLPixelFormatRGBA16Float
                                              storageMode:MTLStorageModeManaged
                                                    label:@"noise"];
        [_noiseTexture replaceRegion:MTLRegionMake2D(0, 0, 4, 4)
                         mipmapLevel:0
                           withBytes:ssaoNoise
                         bytesPerRow:sizeof(vector_float4) * 4];
        _noiseScale = (vector_float2) { width / 4.0, height / 4.0};
        _textureSize = (vector_float2) { width, height };
        
        QuadVertex quadVerties[] = {
            {{-1.0,  1.0}, {0.0, 0.0}},
            {{-1.0, -1.0}, {0.0, 1.0}},
            {{ 1.0,  1.0}, {1.0, 0.0}},
            {{ 1.0, -1.0}, {1.0, 1.0}},
        };
        
        _quadVertexBuffer = [_device newBufferWithBytes:quadVerties
                                                 length:sizeof(quadVerties)
                                                options:MTLResourceStorageModeShared];
        
        id<MTLLibrary> library = [_device newDefaultLibrary];
        id<MTLFunction> gBufferVertexShader = [library newFunctionWithName:@"gBufferVertexShader"];
        id<MTLFunction> gBufferFragmentShader = [library newFunctionWithName:@"gBufferFragmentShader"];
        
        MTLRenderPipelineDescriptor *gBufferPipelineDescriptor = [MTLRenderPipelineDescriptor new];
        gBufferPipelineDescriptor.vertexDescriptor = mtlVertexDescriptor;
        gBufferPipelineDescriptor.vertexFunction = gBufferVertexShader;
        gBufferPipelineDescriptor.fragmentFunction = gBufferFragmentShader;
        gBufferPipelineDescriptor.colorAttachments[0].pixelFormat = _gPosition.pixelFormat;
        gBufferPipelineDescriptor.colorAttachments[1].pixelFormat = _gNormal.pixelFormat;
        gBufferPipelineDescriptor.colorAttachments[2].pixelFormat = _gAlbedo.pixelFormat;
        gBufferPipelineDescriptor.depthAttachmentPixelFormat = _depthTexture.pixelFormat;
        
        _gBufferPipelineState = [_device newRenderPipelineStateWithDescriptor:gBufferPipelineDescriptor
                                                                        error:&error];
        NSAssert(_gBufferPipelineState, @"gbuffer pipeline state error: %@", error);
        
        id<MTLFunction> quadVertexShader = [library newFunctionWithName:@"quadVertexShader"];
        id<MTLFunction> ssaoFragmentShader = [library newFunctionWithName:@"ssaoFragmentShader"];
        
        MTLRenderPipelineDescriptor *ssaoPipelineDescriptor = [MTLRenderPipelineDescriptor new];
        ssaoPipelineDescriptor.vertexFunction = quadVertexShader;
        ssaoPipelineDescriptor.fragmentFunction = ssaoFragmentShader;
        ssaoPipelineDescriptor.colorAttachments[0].pixelFormat = _ssaoColorTexture.pixelFormat;
        
        _ssaoPipelineState = [_device newRenderPipelineStateWithDescriptor:ssaoPipelineDescriptor error:&error];
        NSAssert(_ssaoPipelineState, @"ssao pipeline state error: %@", error);
        
        id<MTLFunction> blurFragmentShader = [library newFunctionWithName:@"blurFragmentShader"];
        
        MTLRenderPipelineDescriptor *blurPipelineDescriptor = [MTLRenderPipelineDescriptor new];
        blurPipelineDescriptor.vertexFunction = quadVertexShader;
        blurPipelineDescriptor.fragmentFunction = blurFragmentShader;
        blurPipelineDescriptor.colorAttachments[0].pixelFormat = _ssaoBlurTexture.pixelFormat;
        
        _blurPipelineState = [_device newRenderPipelineStateWithDescriptor:blurPipelineDescriptor
                                                                     error:&error];
        NSAssert(_blurPipelineState, @"ssao blur pipeline state error: %@", error);
        
        id<MTLFunction> lightingFragmentShader = [library newFunctionWithName:@"lightingFragmentShader"];
        
        MTLRenderPipelineDescriptor *lightPipelineDescriptor = [MTLRenderPipelineDescriptor new];
        lightPipelineDescriptor.vertexFunction = quadVertexShader;
        lightPipelineDescriptor.fragmentFunction = lightingFragmentShader;
        lightPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        
        _lightPipelineState = [_device newRenderPipelineStateWithDescriptor:lightPipelineDescriptor error:&error];
        NSAssert(_lightPipelineState, @"light pipeline state error: %@", error);
        
        id<MTLFunction> quadFragmentShader = [library newFunctionWithName:@"quadFragmentShader"];
        
        MTLRenderPipelineDescriptor *quadPipelineDescriptor = [MTLRenderPipelineDescriptor new];
        quadPipelineDescriptor.vertexFunction = quadVertexShader;
        quadPipelineDescriptor.fragmentFunction = quadFragmentShader;
        quadPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        
        _quadPipelineState = [_device newRenderPipelineStateWithDescriptor:quadPipelineDescriptor error:&error];
        NSAssert(_quadPipelineState, @"quad pipeline create error:%@", error);
        
        _commandQueue = [_device newCommandQueue];
        
        _lightPos = (vector_float3){ 2.0, 4.0, -2.0 };
        _light.color = (vector_float3) {0.2, 0.2, 0.7};
    
        _light.position = simd_mul([_camera getViewMatrix],
                                   (vector_float4) {_lightPos.x, _lightPos.y, _lightPos.z, 1.0}).xyz;
        _light.linear = 0.09;
        _light.quadratic = 0.032;
        
        _viewport = (MTLViewport) { 0.0, 0.0, width, height, 0.0, 1.0 };
    }
    
    return self;
}

- (float) lerp:(float)a :(float)b :(float)f {
    return a + f * (b-a);
}

- (id<MTLTexture>) createColorTextureWithWidth:(int)width
                                        height:(int) height
                                   pixelFormat:(MTLPixelFormat)pixelFormat
                                   storageMode:(MTLStorageMode)storageMode
                                         label:(NSString*)label {
    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor new];
    descriptor.width = width;
    descriptor.height = height;
    descriptor.pixelFormat = pixelFormat;
    descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    descriptor.textureType = MTLTextureType2D;
    descriptor.storageMode = storageMode;
    
    id<MTLTexture> texture = [_device newTextureWithDescriptor:descriptor];
    texture.label = label;
    
    return texture;
}

- (id<MTLTexture>) createDepthTextureWithWidth:(int)width height:(int)height label:(NSString*)label {
    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor new];
    descriptor.width = width;
    descriptor.height = height;
    descriptor.pixelFormat = MTLPixelFormatDepth32Float;
    descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    descriptor.textureType = MTLTextureType2D;
    descriptor.storageMode = MTLStorageModePrivate;
    
    id<MTLTexture> texture = [_device newTextureWithDescriptor:descriptor];
    texture.label = label;
    
    return texture;
}

- (void) handleMouseScrollDeltaX:(float) deltaX deltaY:(float) deltaY {
    [_cameraController rotateCameraAroundTargetWithDeltaPhi:deltaX deltaTheta:deltaY];
    
    _uniforms.viewMatrix = [_camera getViewMatrix];
    _light.position = simd_mul([_camera getViewMatrix],
                               (vector_float4) {_lightPos.x, _lightPos.y, _lightPos.z, 1.0}).xyz;
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    
    // gbuffer
    MTLRenderPassDescriptor *geometryRenderDescriptor = [MTLRenderPassDescriptor new];
    geometryRenderDescriptor.colorAttachments[0].texture = _gPosition;
    geometryRenderDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    geometryRenderDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    geometryRenderDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    
    geometryRenderDescriptor.colorAttachments[1].texture = _gNormal;
    geometryRenderDescriptor.colorAttachments[1].loadAction = MTLLoadActionClear;
    geometryRenderDescriptor.colorAttachments[1].storeAction = MTLStoreActionStore;

    geometryRenderDescriptor.colorAttachments[2].texture = _gAlbedo;
    geometryRenderDescriptor.colorAttachments[2].loadAction = MTLLoadActionClear;
    geometryRenderDescriptor.colorAttachments[2].storeAction = MTLStoreActionStore;
    geometryRenderDescriptor.colorAttachments[2].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    
    geometryRenderDescriptor.depthAttachment.texture = _depthTexture;
    geometryRenderDescriptor.depthAttachment.loadAction = MTLLoadActionClear;
    geometryRenderDescriptor.depthAttachment.storeAction = MTLStoreActionDontCare;
    geometryRenderDescriptor.depthAttachment.clearDepth = 1.0;
    
    id<MTLRenderCommandEncoder> geometryRenderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:geometryRenderDescriptor];
    [geometryRenderEncoder setViewport:_viewport];
    [geometryRenderEncoder setRenderPipelineState:_gBufferPipelineState];
    [geometryRenderEncoder setDepthStencilState:_depthState];

    [_cubeMesh setVertexBufferInRenderCommandEncoder:geometryRenderEncoder index:VertexInputIndexPosition];
    _uniforms.modelMatrix = _cubeModelMatrix;
    _uniforms.normalMatrix = _cubeNormalMatrix;
    [geometryRenderEncoder setVertexBytes:&_uniforms
                                   length:sizeof(_uniforms)
                                  atIndex:VertexInputIndexUniforms];

    [_cubeMesh drawInRenderCommandEncoder:geometryRenderEncoder];
    
    [_backpackMesh setVertexMeshToRenderEncoder:geometryRenderEncoder index:VertexInputIndexPosition];
    _uniforms.modelMatrix = _meshModelMatrix;
    _uniforms.normalMatrix = _meshNormalMatrix;
    [geometryRenderEncoder setVertexBytes:&_uniforms
                                   length:sizeof(_uniforms)
                                  atIndex:VertexInputIndexUniforms];

    [_backpackMesh drawMeshToRenderEncoder:geometryRenderEncoder textureHandler:^(MDLMaterialSemantic type, id<MTLTexture> texture, NSString* _) {}];

    [geometryRenderEncoder endEncoding];
    
    // generate SSAO texture
    MTLRenderPassDescriptor *ssaoRenderDescriptor = [MTLRenderPassDescriptor new];
    ssaoRenderDescriptor.colorAttachments[0].texture = _ssaoColorTexture;
    ssaoRenderDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    ssaoRenderDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    
    id<MTLRenderCommandEncoder> ssaoRenderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:ssaoRenderDescriptor];
    
    [ssaoRenderEncoder setViewport:_viewport];
    [ssaoRenderEncoder setRenderPipelineState:_ssaoPipelineState];
    
    [ssaoRenderEncoder setVertexBuffer:_quadVertexBuffer offset:0 atIndex:0];
    [ssaoRenderEncoder setFragmentTexture:_gPosition atIndex:SSAOFragmentIndexGPosition];
    [ssaoRenderEncoder setFragmentTexture:_gNormal atIndex:SSAOFragmentIndexGNormal];
    [ssaoRenderEncoder setFragmentTexture:_noiseTexture atIndex:SSAOFragmentIndexTexNoise];
    [ssaoRenderEncoder setFragmentBytes:_ssaoKernel length:sizeof(_ssaoKernel) atIndex:SSAOFragmentIndexKernalSample];
    [ssaoRenderEncoder setFragmentBytes:&_ssaoKernelCount length:sizeof(_ssaoKernelCount) atIndex:SSAOFragmentIndexKernalSize];
    [ssaoRenderEncoder setFragmentBytes:&_noiseScale length:sizeof(_noiseScale) atIndex:SSAOFragmentIndexNoiseScale];
    [ssaoRenderEncoder setFragmentBytes:&_projectionMatrix length:sizeof(_projectionMatrix) atIndex:SSAOFragmentIndexProjectionMatrix];
    [ssaoRenderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    
    [ssaoRenderEncoder endEncoding];
    
    // blur
    MTLRenderPassDescriptor *blurRenderDescriptor = [MTLRenderPassDescriptor new];
    blurRenderDescriptor.colorAttachments[0].texture = _ssaoBlurTexture;
    blurRenderDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    blurRenderDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

    id<MTLRenderCommandEncoder> blurRenderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:blurRenderDescriptor];
    [blurRenderEncoder setViewport:_viewport];
    [blurRenderEncoder setRenderPipelineState:_blurPipelineState];

    [blurRenderEncoder setVertexBuffer:_quadVertexBuffer offset:0 atIndex:0];
    [blurRenderEncoder setFragmentTexture:_ssaoColorTexture atIndex:0];
    [blurRenderEncoder setFragmentBytes:&_textureSize length:sizeof(_textureSize) atIndex:1];
    [blurRenderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];

    [blurRenderEncoder endEncoding];
    
    // test ssao buffer
//    MTLRenderPassDescriptor *quadRenderDescriptor = [MTLRenderPassDescriptor new];
//    quadRenderDescriptor.colorAttachments[0].texture = view.currentDrawable.texture;
//    quadRenderDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
//    quadRenderDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
//
//    id<MTLRenderCommandEncoder> quadRenderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:quadRenderDescriptor];
//    [quadRenderEncoder setViewport:_viewport];
//    [quadRenderEncoder setRenderPipelineState:_quadPipelineState];
//
//    [quadRenderEncoder setVertexBuffer:_quadVertexBuffer offset:0 atIndex:0];
//    [quadRenderEncoder setFragmentTexture:_ssaoColorTexture atIndex:0];
//
//    [quadRenderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
//    [quadRenderEncoder endEncoding];
    
//    // draw
    MTLRenderPassDescriptor *lightRenderDescriptor = [MTLRenderPassDescriptor new];
    lightRenderDescriptor.colorAttachments[0].texture = view.currentDrawable.texture;
    lightRenderDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    lightRenderDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

    id<MTLRenderCommandEncoder> lightRenderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:lightRenderDescriptor];
    [lightRenderEncoder setViewport:_viewport];
    [lightRenderEncoder setRenderPipelineState:_lightPipelineState];

    [lightRenderEncoder setVertexBuffer:_quadVertexBuffer offset:0 atIndex:0];
    [lightRenderEncoder setFragmentTexture:_gPosition atIndex:LightFragmentIndexGPosition];
    [lightRenderEncoder setFragmentTexture:_gNormal atIndex:LightFragmentIndexGNormal];
    [lightRenderEncoder setFragmentTexture:_gAlbedo atIndex:LightFragmentIndexGAlbedo];
    [lightRenderEncoder setFragmentTexture:_ssaoBlurTexture atIndex:LightFragmentIndexSSAOTexture];
    [lightRenderEncoder setFragmentBytes:&_light length:sizeof(_light) atIndex:LightFragmentIndexLight];

    [lightRenderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    [lightRenderEncoder endEncoding];
    
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    int width = size.width;
    int height = size.height;
    
    _noiseScale.x = size.width / 4.0;
    _noiseScale.y = size.height / 4.0;
    
    _textureSize.x = size.width;
    _textureSize.y = size.height;
    
    _viewport.width = width;
    _viewport.height = height;
    
    _gPosition = [self createColorTextureWithWidth:width
                                            height:height
                                       pixelFormat:MTLPixelFormatRGBA16Float
                                       storageMode:MTLStorageModePrivate
                                             label:@"gPosition"];
    _gNormal = [self createColorTextureWithWidth:width
                                          height:height
                                     pixelFormat:MTLPixelFormatRGBA16Float
                                     storageMode:MTLStorageModePrivate
                                           label:@"gNormal"];
    _gAlbedo = [self createColorTextureWithWidth:width
                                          height:height
                                     pixelFormat:MTLPixelFormatRGBA16Float
                                     storageMode:MTLStorageModePrivate
                                           label:@"gAlbedo"];
    _ssaoColorTexture = [self createColorTextureWithWidth:width
                                                   height:height
                                              pixelFormat:MTLPixelFormatR16Float
                                              storageMode:MTLStorageModePrivate
                                                    label:@"ssaoColor"];
    _ssaoBlurTexture = [self createColorTextureWithWidth:width
                                                  height:height
                                             pixelFormat:MTLPixelFormatR16Float
                                             storageMode:MTLStorageModePrivate
                                                   label:@"ssaoBlur"];
    
    _depthTexture = [self createDepthTextureWithWidth:width height:height label:@"depth"];

    _projectionMatrix = matrix_perspective_left_hand(M_PI/4.0, size.width/size.height, 0.1, 50.0);
    _uniforms.projectionMatrix = _projectionMatrix;
}

- (float)randomFloatBetween:(float)smallNumber and:(float)bigNumber {
    float diff = bigNumber - smallNumber;
    return (((float) (arc4random() % ((unsigned)RAND_MAX + 1)) / RAND_MAX) * diff) + smallNumber;
}


@end
