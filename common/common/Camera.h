//
//  Camera.h
//  common
//
//  Created by Jacob Su on 3/8/21.
//

#ifndef Camera_h
#define Camera_h

#import <simd/simd.h>

@interface Camera : NSObject

- (nonnull instancetype) initWithPosition:(vector_float3) position
                                withTarget:(vector_float3) target
                                withUp:(vector_float3) up;

- (void) handleMouseScrollDeltaX:(float) deltaX deltaY:(float) deltaY;
- (matrix_float4x4) getViewMatrix;
- (vector_float3) getCameraPosition;
- (vector_float3) getFrontDirection;

@end

#endif /* Camera_h */
