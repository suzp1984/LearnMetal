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

- (void) moveCameraWithTranslation:(vector_float3)translation;

- (void) moveAlongCameraDirection:(float)translation;

- (void) rotateCameraAroundTargetWithDeltaPhi:(float) deltaPhi deltaTheta:(float) deltaTheta;

@end

// CameraFactory
@interface CameraFactory : NSObject

+ (id<Camera>_Nonnull) generateRoundOrbitCameraWithPosition:(vector_float3) position target:(vector_float3)target up:(vector_float3)up;

@end

#endif /* Camera_h */
