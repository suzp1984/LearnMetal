//
//  SatelliteController.m
//  common
//
//  Created by Jacob Su on 4/25/21.
//

#import <Foundation/Foundation.h>
#import "SatelliteCameraController.h"
#import <simd/simd.h>

@interface SatelliteCameraController ()

@property id<Camera> _Nonnull camera;

@end

@implementation SatelliteCameraController
{
    // spherical coordinate system: (r, theta, phi): theta: (-pi/2, pi / 2), phi (0, 2*pi)
    float _r;
    float _theta;
    float _phi;
}

@synthesize camera;

- (nonnull instancetype) initWithCamera:(id<Camera>_Nonnull) camera {
    self = [super init];
    
    if (self) {
        self.camera = camera;
        
        vector_float3 direction = camera.cameraPosition - camera.target;
        _r = vector_length(direction);
        
        // y axis around
        _theta = asin(direction.y / _r);
        _phi = atan2(direction.z, direction.x);
    }
    
    return self;
}

- (void) rotateCameraAroundTargetWithDeltaPhi:(float) deltaPhi deltaTheta:(float) deltaTheta {
    _theta += deltaTheta * 0.01;
    if (_theta < - M_PI / 2.0) {
        _theta = - M_PI / 2.0 + 0.01;
    }
    
    if (_theta > M_PI / 2.0) {
        _theta = M_PI / 2.0 - 0.01;
    }
    
    _phi = _phi - deltaPhi * 0.01;
    
//    if (fabsf(deltaY) >= fabsf(deltaX)) {
//        _a = _a + deltaY * 0.01;
//    } else {
//        _theta = _theta + deltaX * 0.01;
//    }
    
    // z aixs around
//    _position.z = _r * sin(_a);
//    _position.x = _r * cos(_a) * cos(_theta);
//    _position.y = _r * cos(_a) * sin(_theta);
    
    // y aixs around
    vector_float3 target = camera.target;
    vector_float3 cameraPosition;
    cameraPosition.y = target.y + _r * sin(_theta);
    cameraPosition.x = target.x + _r * cos(_theta) * cos(_phi);
    cameraPosition.z = target.z + _r * cos(_theta) * sin(_phi);
    [camera setCameraPosition:cameraPosition];
    // Don't change CameraUp, otherwise it's difficult to control
//    vector_float3 cameraFront = [camera getFrontDirection];
//    vector_float3 cameraUp = camera.cameraUp;
//    vector_float3 cameraRight = vector_normalize(simd_cross(cameraFront, cameraUp));
//    cameraUp = vector_normalize(simd_cross(cameraRight, cameraFront));
//    [camera setCameraUp:cameraUp];
}


@end
