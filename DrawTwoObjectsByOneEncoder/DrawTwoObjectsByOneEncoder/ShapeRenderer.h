//
//  ShapeRenderer.h
//  DrawTwoObjectsByOneEncoder
//
//  Created by Jacob Su on 3/15/21.
//

#ifndef ShapeRenderer_h
#define ShapeRenderer_h

@import MetalKit;

@interface ShaperRenderer : NSObject<MTKViewDelegate>

- (nonnull instancetype) initWithMetalKitView:(nonnull MTKView*)mtkView;

@end

#endif /* ShapeRenderer_h */
