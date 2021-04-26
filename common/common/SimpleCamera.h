//
//  FixedUpCamera.h
//  common
//
//  Created by Jacob Su on 4/26/21.
//

#ifndef FixedUpCamera_h
#define FixedUpCamera_h

#import <common/Camera.h>

@interface SimpleCamera : Camera

- (nonnull instancetype) initWithPosition:(vector_float3) position
                               withTarget:(vector_float3) target
                                       up:(BOOL) up;
                                
@end

#endif /* FixedUpCamera_h */
