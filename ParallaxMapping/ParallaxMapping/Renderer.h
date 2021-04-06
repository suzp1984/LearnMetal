//
//  Renderer.h
//  ParallaxMapping
//
//  Created by Jacob Su on 4/6/21.
//

#ifndef Renderer_h
#define Renderer_h

@import MetalKit;

@interface Renderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView;
- (void) handleMouseScrollDeltaX:(float) deltaX deltaY:(float) deltaY;
- (void) setHeightScale:(float) scale;
- (void) setParallaxMethod:(uint) methodType;

@end

#endif /* Renderer_h */
