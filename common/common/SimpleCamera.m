//
//  FixedUpCamera.m
//  common
//
//  Created by Jacob Su on 4/26/21.
//

#import <Foundation/Foundation.h>
#import "SimpleCamera.h"

@implementation SimpleCamera

- (nonnull instancetype) initWithPosition:(vector_float3) position
                               withTarget:(vector_float3) target
                                       up:(BOOL) up{
    return [super initWithPosition:position
                        withTarget:target
                            withUp:(vector_float3) {0.0, up? 1.0 : -1.0, 0.0}];
    
}

@end
