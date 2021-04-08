//
//  Camera.m
//  common
//
//  Created by Jacob Su on 3/8/21.
//

#import <Foundation/Foundation.h>
#import "Camera.h"
#import "OrbitCamera.h"

// Camera Factory

@implementation CameraFactory

+ (id<Camera>_Nonnull) generateRoundOrbitCameraWithPosition:(vector_float3) position
                                                     target:(vector_float3)target
                                                         up:(vector_float3)up {
    return [[OrbitCamera alloc] initWithPosition:position withTarget:target withUp:up];
}

@end
