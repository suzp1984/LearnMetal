//
//  OrbitCamera.m
//  common
//
//  Created by Jacob Su on 4/8/21.
//

#import <Foundation/Foundation.h>
#import "OrbitCamera.h"
#import "AAPLMathUtilities.h"

@implementation OrbitCamera
{
    float _r;
    float _a;
    float _theta;
}

@synthesize cameraPosition = _cameraPosition;

@synthesize cameraUp = _cameraUp;

@synthesize target = _target;

- (nonnull instancetype) initWithPosition:(vector_float3) position
                                   withTarget:(vector_float3) target
                                   withUp:(vector_float3) up
{
    self = [super init];
    if (self) {
        _cameraPosition = position;
        _target = target;
        _cameraUp = up;
        
        vector_float3 direction = _cameraPosition - _target;
        _r = vector_length(direction);
        
//        // z axis around
//        _a = asin(_position.z / _r);
//        _theta = atan2(_position.y, _position.x);
        
        // y axis around
        _a = asin(direction.y / _r);
        _theta = atan2(direction.z, direction.x);
    }
    
    return self;
}

- (void) rotateCameraAroundTargetWithDeltaPhi:(float) deltaPhi
                                   deltaTheta:(float) deltaTheta {
    
    _a += deltaTheta * 0.01;
    if (_a < - M_PI / 2.0) {
        _a = - M_PI / 2.0;
    }
    
    if (_a > M_PI / 2.0) {
        _a = M_PI / 2.0;
    }
    
    _theta = _theta + deltaPhi * 0.01;
    
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
    _cameraPosition.y = _target.y + _r * sin(_a);
    _cameraPosition.x = _target.x + _r * cos(_a) * cos(_theta);
    _cameraPosition.z = _target.z + _r * cos(_a) * sin(_theta);
}

- (void) moveCameraWithTranslation:(vector_float3)translation {
    _cameraPosition += translation;
    _target += translation;
}

- (void) moveAlongCameraDirection:(float)translation {
    vector_float3 direction = vector_normalize([self getFrontDirection]);
    
    _cameraPosition += direction * translation;
    _target += direction * translation;
}

- (matrix_float4x4) getViewMatrix
{
    return matrix_look_at_left_hand(_cameraPosition, _target, _cameraUp);
}

- (vector_float3) getFrontDirection
{
    return _target - _cameraPosition;
}

@end
