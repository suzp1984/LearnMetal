//
//  Renderer.h
//  SkinAnimation
//
//  Created by Jacob Su on 5/8/21.
//

#ifndef Renderer_h
#define Renderer_h

@import MetalKit;

@interface Renderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView;
- (void) handleMouseScrollDeltaX:(float) deltaX deltaY:(float) deltaY;

@end

#endif /* Renderer_h */
