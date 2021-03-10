//
//  TriangleRenderer.h
//  3.Uniforms
//
//  Created by Jacob Su on 3/2/21.
//

#ifndef TriangleRenderer_h
#define TriangleRenderer_h

#import <Foundation/Foundation.h>
@import MetalKit;

@interface TriangleRenderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView;

@end

#endif /* TriangleRenderer_h */
