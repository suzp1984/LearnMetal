//
//  Camera.m
//  common
//
//  Created by Jacob Su on 3/8/21.
//

#import <Foundation/Foundation.h>
#import "Camera.h"
#import "AAPLMathUtilities.h"

@implementation Camera

@synthesize cameraPosition;

@synthesize cameraUp;

@synthesize target;

- (nonnull instancetype) initWithPosition:(vector_float3) position
                                withTarget:(vector_float3) target
                                   withUp:(vector_float3) up {
    self = [super init];
    
    if (self) {
        [self setCameraPosition:position];
        [self setTarget:target];
        [self setCameraUp:up];
    }
    
    return self;
}

- (matrix_float4x4) getViewMatrix
{
    return matrix_look_at_left_hand(cameraPosition, target, cameraUp);
}

- (vector_float3) getFrontDirection
{
    return target - cameraPosition;
}

@end
