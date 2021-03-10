//
//  CuberRenderer.h
//  8.Exec.RotatingCube
//
//  Created by Jacob Su on 3/5/21.
//

#ifndef CuberRenderer_h
#define CuberRenderer_h


@import MetalKit;

@interface CubeRenderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView;

@end

#endif /* CuberRenderer_h */
