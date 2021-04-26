//
//  LinearMoveCameraController.m
//  common
//
//  Created by Jacob Su on 4/25/21.
//

#import <Foundation/Foundation.h>
#import "LinearMoveCameraController.h"

@interface LinearMoveCameraController ()

@property id<Camera> _Nonnull camera;

@end

@implementation LinearMoveCameraController

- (nonnull instancetype) initWithCamera:(id<Camera>_Nonnull) camera {
    self = [super init];
    
    if (self) {
        self.camera = camera;
    }
    
    return self;
}

- (void) moveCameraWithTranslation:(vector_float3)translation {
    _camera.cameraPosition += translation;
    _camera.target += translation;
}


@end
