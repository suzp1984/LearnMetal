//
//  ShapeRenderer.h
//  11.DrawTwoObjects
//
//  Created by Jacob Su on 3/7/21.
//

#ifndef ShapeRenderer_h
#define ShapeRenderer_h

@import MetalKit;

@interface ShaperRenderer : NSObject<MTKViewDelegate>

- (nonnull instancetype) initWithMetalKitView:(nonnull MTKView*)mtkView;

@end

#endif /* ShapeRenderer_h */
