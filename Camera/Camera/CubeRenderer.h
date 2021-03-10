//
//  CubeRenderer.h
//  12.Camera
//
//  Created by Jacob Su on 3/8/21.
//

#ifndef CubeRenderer_h
#define CubeRenderer_h

@import MetalKit;

@interface CubeRenderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView;

- (void) handleMouseScrollDeltaX:(float) deltaX deltaY:(float) deltaY;

@end


#endif /* CubeRenderer_h */
