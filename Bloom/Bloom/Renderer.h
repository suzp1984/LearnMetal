//
//  Renderer.h
//  Bloom
//
//  Created by Jacob Su on 4/8/21.
//

#ifndef Renderer_h
#define Renderer_h

@import MetalKit;

@interface Renderer : NSObject<MTKViewDelegate>

@property bool bloom;
@property float exposure;

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView;
- (void) handleMouseScrollDeltaX:(float) deltaX deltaY:(float) deltaY;


@end

#endif /* Renderer_h */
