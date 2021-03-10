//
//  SquareRenderer.h
//  7.IndexedElements
//
//  Created by Jacob Su on 3/4/21.
//

#ifndef SquareRenderer_h
#define SquareRenderer_h

@import MetalKit;

@interface SquareRenderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView;

@end

#endif /* SquareRenderer_h */
