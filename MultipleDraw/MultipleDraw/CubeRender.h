//
//  CubeRender.h
//  9.MultipleDraw
//
//  Created by Jacob Su on 3/5/21.
//

#ifndef CubeRender_h
#define CubeRender_h

@import MetalKit;

@interface CubeRenderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView;

@end

#endif /* CubeRender_h */
