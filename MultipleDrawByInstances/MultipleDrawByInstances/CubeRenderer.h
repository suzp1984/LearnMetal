//
//  CubeRenderer.h
//  10.MultipleDrawByInstances
//
//  Created by Jacob Su on 3/6/21.
//

#ifndef CubeRenderer_h
#define CubeRenderer_h

@import MetalKit;

@interface CubeRenderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView;

@end

#endif /* CubeRenderer_h */
