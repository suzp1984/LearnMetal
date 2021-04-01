//
//  Renderer.h
//  BlinnPhong
//
//  Created by Jacob Su on 4/1/21.
//

#ifndef Renderer_h
#define Renderer_h

@import MetalKit;

@interface Renderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView;
- (void) handleMouseScrollDeltaX:(float) deltaX deltaY:(float) deltaY;
- (void) enableBlinnPhong:(BOOL) enabled;

@end

#endif /* Renderer_h */
