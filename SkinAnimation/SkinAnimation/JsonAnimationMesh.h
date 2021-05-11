//
//  JsonAnimationMesh.h
//  SkinAnimation
//
//  Created by Jacob Su on 5/9/21.
//

#ifndef JsonAnimationMesh_h
#define JsonAnimationMesh_h

@import MetalKit;

@interface JsonAnimationMesh : NSObject

@property (readonly) MTLVertexDescriptor  * _Nonnull mtlVertexDescriptor;

@property (readonly) id<MTLBuffer> _Nonnull geometryBuffer;
@property (readonly) int vertexCount;

@property (readonly) id<MTLTexture> _Nonnull boneTexture;
@property (readonly) id<MTLTexture> _Nonnull diffuseTexture;

@property (readonly) int boneTextureSize;

- (nonnull instancetype)initWithDevice:(nonnull id<MTLDevice>)device
                               jsonUrl:(nonnull NSURL*)jsonUrl
                          animationUrl:(nonnull NSURL*)animationUrl
                            textureURL:(nonnull NSURL*)textureURL;

- (void) update;

@end

#endif /* JsonAnimationMesh_h */
