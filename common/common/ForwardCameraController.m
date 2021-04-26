//
//  ForwardMoveController.m
//  common
//
//  Created by Jacob Su on 4/25/21.
//

#import <Foundation/Foundation.h>
#import "ForwardCameraController.h"

@interface ForwardCameraController ()

@property id<Camera> _Nonnull camera;

@end

@implementation ForwardCameraController

- (nonnull instancetype) initWithCamera:(id<Camera>_Nonnull) camera {
    self = [super init];
    
    if (self) {
        self.camera = camera;
    }
    
    return self;
}

- (void) moveAlongCameraDirection:(float)translation {
    vector_float3 direction = vector_normalize([_camera getFrontDirection]);
    
    _camera.cameraPosition += direction * translation;
    _camera.target += direction * translation;
}

@end

