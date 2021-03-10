//
//  SquareRenderer.h
//  5.TextureMix
//
//  Created by Jacob Su on 3/3/21.
//

#ifndef SquareRenderer_h
#define SquareRenderer_h
@import MetalKit;

@interface SquareRenderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView;

@end

#endif /* SquareRenderer_h */
