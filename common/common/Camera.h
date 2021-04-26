//
//  Camera.h
//  common
//
//  Created by Jacob Su on 3/8/21.
//

#ifndef Camera_h
#define Camera_h

#import <simd/simd.h>

@protocol Camera <NSObject>

@property vector_float3 cameraPosition;
@property vector_float3 target;
@property vector_float3 cameraUp;

- (matrix_float4x4) getViewMatrix;
- (vector_float3) getFrontDirection;

@end

@interface Camera : NSObject<Camera>

- (nonnull instancetype) initWithPosition:(vector_float3) position
                                withTarget:(vector_float3) target
                                withUp:(vector_float3) up;
@end

@protocol CameraController <NSObject>

@property (readonly) id<Camera> _Nonnull camera;

@end

#endif /* Camera_h */
