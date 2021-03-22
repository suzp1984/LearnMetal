//
//  Renderer.h
//  FaceCulling
//
//  Created by Jacob Su on 3/22/21.
//

#ifndef Renderer_h
#define Renderer_h

@import MetalKit;

@interface CubeRenderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView;
- (void) handleMouseScrollDeltaX:(float) deltaX deltaY:(float) deltaY;

@end

#endif /* Renderer_h */
