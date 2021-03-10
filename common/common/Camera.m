//
//  Camera.m
//  common
//
//  Created by Jacob Su on 3/8/21.
//

#import <Foundation/Foundation.h>
#import "Camera.h"
#import "AAPLMathUtilities.h"

const float PI = 3.1415926;

@implementation Camera
{
    vector_float3 _position;
    vector_float3 _target;
    vector_float3 _up;
    float _r;
    float _a;
    float _theta;
}

- (nonnull instancetype) initWithPosition:(vector_float3) position
                                   withTarget:(vector_float3) target
                                   withUp:(vector_float3) up
{
    self = [super init];
    if (self) {
        _position = position;
        _target = target;
        _up = up;
        
        _r = vector_length(_position);
//        // z axis around
//        _a = asin(_position.z / _r);
//        _theta = atan2(_position.y, _position.x);
        
        // y axis around
        _a = asin(_position.y / _r);
        _theta = atan2(_position.z, _position.x);
    }
    
    return self;
}

- (void) handleMouseScrollDeltaX:(float) deltaX deltaY:(float) deltaY
{
    _a += deltaY * 0.01;
    if (_a < - PI / 2.0) {
        _a = - PI / 2.0;
    }
    
    if (_a > PI / 2.0) {
        _a = PI / 2.0;
    }
    
    _theta = _theta + deltaX * 0.01;
    
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
    _position.y = _r * sin(_a);
    _position.x = _r * cos(_a) * cos(_theta);
    _position.z = _r * cos(_a) * sin(_theta);
}

- (matrix_float4x4) getViewMatrix
{
    return matrix_look_at_left_hand(_position, _target, _up);
}

- (vector_float3) getCameraPosition
{
    return _position;
}

@end
