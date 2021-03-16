//
//  Renderer.m
//  ModelLoadingObj
//
//  Created by Jacob Su on 3/16/21.
//

@import ModelIO;
@import MetalKit;
@import Metal;
#import <Foundation/Foundation.h>
#import "Renderer.h"
#import "ModelShaderType.h"
#import <common/common.h>

static const float PI = 3.1415926;

@implementation Renderer
{
    id<MTLDevice> _device;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLCommandQueue> _commandQueue;
    id<MTLDepthStencilState> _depthState;
    NSMutableDictionary *_textures;
    MTKMesh *_mtkMesh;
    Uniforms _uniforms;
    vector_uint2 _viewportSize;
    Camera *_camera;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView
{
    self = [super init];
    
    if (self) {
        mtkView.delegate = self;
        id<MTLDevice> device = mtkView.device;
        _device = mtkView.device;
        
        _camera = [[Camera alloc] initWithPosition:(vector_float3) {0.0, 0.0, 3.0}
                                        withTarget:(vector_float3) {0.0, 0.0, 0.0}
                                        withUp:(vector_float3) {0.0, 1.0, 0.0}];
        
        mtkView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
        mtkView.clearDepth = 1.0;
        MTLDepthStencilDescriptor *depthStencilDesc = [MTLDepthStencilDescriptor new];
        depthStencilDesc.depthCompareFunction = MTLCompareFunctionLess;
        depthStencilDesc.depthWriteEnabled = YES;
        _depthState = [device newDepthStencilStateWithDescriptor:depthStencilDesc];
        
        NSBundle *bundle = [NSBundle bundleWithIdentifier:@"io.github.suzp1984.common"];
        NSURL *url = [bundle URLForResource:@"nanosuit" withExtension:@"obj" subdirectory:@"nanosuit"];
        
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
        
        // model io vertex descriptor
        MDLVertexDescriptor *mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor);
        mdlVertexDescriptor.attributes[ModelVertexAttributePosition].name = MDLVertexAttributePosition;
        mdlVertexDescriptor.attributes[ModelVertexAttributeTexcoord].name = MDLVertexAttributeTextureCoordinate;
        mdlVertexDescriptor.attributes[ModelVertexAttributeNormal].name = MDLVertexAttributeNormal;
        
        // mesh allocator
        MTKMeshBufferAllocator *metalAllocator = [[MTKMeshBufferAllocator alloc] initWithDevice:device];
        
        MDLAsset *asset = [[MDLAsset alloc] initWithURL:url vertexDescriptor:mdlVertexDescriptor bufferAllocator:metalAllocator];
        
        MDLMesh *mdlMesh;
        NSLog(@"mdl object count = %lu", (unsigned long)asset.count);
        for (int i = 0; i < asset.count; i++) {
            
            MDLObject *object = [asset objectAtIndex:i];
            NSLog(@"object is %@", object.name);
            if ([object isKindOfClass:[MDLMesh class]]) {
                MDLMesh *mesh = (MDLMesh *) object;
                mdlMesh = mesh;
                
                _textures = [[NSMutableDictionary alloc] initWithCapacity:mesh.submeshes.count];
                MTKTextureLoader *textureLoader = [[MTKTextureLoader alloc] initWithDevice:_device];
                NSError *error;
                
                for (int j = 0; j < mesh.submeshes.count; j++) {
                    MDLSubmesh *subMesh = mesh.submeshes[j];
                    NSLog(@"submesh name = %@", [subMesh name]);
                    MDLMaterial *material = subMesh.material;
                    NSLog(@"material name: %@", material.name);
                    for (int m = 0; m < material.count; m++) {
                        MDLMaterialProperty *property = [material objectAtIndexedSubscript:m];
                        if ([property.name isEqualToString:@"baseColor"] && property.URLValue != nil) {
                            id<MTLTexture> texture = [textureLoader newTextureWithContentsOfURL:property.URLValue options:nil error:&error];
                            
                            NSAssert(texture, @"cannot load texture %@, with error: %@", property.URLValue, error);
                            
                            _textures[subMesh.name] = texture;
                            break;
                        }
                    }
                }
                
                break;
            }
        }
        
        NSAssert(mdlMesh, @"can not found MDLMesh from MDLAsset");
        
        NSError *error;
        
        // mtk mesh
        _mtkMesh = [[MTKMesh alloc] initWithMesh:mdlMesh device:device error:&error];
        NSAssert(_mtkMesh, @"Error: %@", error);
        
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
        
        _commandQueue = [_device newCommandQueue];
        
        _viewportSize = (vector_uint2){ (int) (mtkView.frame.size.width), (int) (mtkView.frame.size.height) };
        float width = mtkView.frame.size.width;
        float height = mtkView.frame.size.height;
        
        _uniforms.modelMatrix = simd_mul(matrix4x4_translation(0.0, -1.75, 0.0), matrix4x4_scale(0.2, 0.2, 0.2));
        _uniforms.viewMatrix = [_camera getViewMatrix];
        _uniforms.projectionMatrix = matrix_perspective_left_hand(PI / 4.0, width / height, 0.1, 100.0);
    }
    
    return self;
}

- (void) handleMouseScrollDeltaX:(float) deltaX deltaY:(float) deltaY {
    [_camera handleMouseScrollDeltaX:deltaX deltaY:deltaY];
    
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
    
    for (int i = 0; i < _mtkMesh.vertexBuffers.count; i++) {
        MTKMeshBuffer *buffer = _mtkMesh.vertexBuffers[i];
        
        [renderEncoder setVertexBuffer:buffer.buffer offset:buffer.offset atIndex:ModelVertexInputIndexPosition];
    }
    
    [renderEncoder setVertexBytes:&_uniforms length:sizeof(_uniforms) atIndex:ModelVertexInputIndexUniforms];
    
    for (int i = 0; i < _mtkMesh.submeshes.count; i++) {
        MTKSubmesh *subMesh = _mtkMesh.submeshes[i];
        id<MTLTexture> texture = _textures[subMesh.name];
        
        [renderEncoder setFragmentTexture:texture atIndex:FragmentInputIndexDiffuseTexture];
        [renderEncoder drawIndexedPrimitives:subMesh.primitiveType
                                  indexCount:subMesh.indexCount
                                   indexType:subMesh.indexType
                                 indexBuffer:subMesh.indexBuffer.buffer
                           indexBufferOffset:subMesh.indexBuffer.offset];
    }
    
    [renderEncoder endEncoding];
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
 
    _uniforms.projectionMatrix = matrix_perspective_left_hand(PI / 4.0, size.width / size.height, 0.1, 100.0);
}

@end
