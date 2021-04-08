//
//  OrbitCamera.h
//  common
//
//  Created by Jacob Su on 4/8/21.
//

#ifndef OrbitCamera_h
#define OrbitCamera_h

#import "Camera.h"

@interface OrbitCamera : NSObject<Camera>

- (nonnull instancetype) initWithPosition:(vector_float3) position
                                withTarget:(vector_float3) target
                                withUp:(vector_float3) up;

@end

#endif /* OrbitCamera_h */
