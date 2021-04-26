//
//  SatelliteController.h
//  common
//
//  Created by Jacob Su on 4/25/21.
//

#ifndef SatelliteController_h
#define SatelliteController_h

#import <common/Camera.h>

@interface SatelliteCameraController : NSObject<CameraController>

- (nonnull instancetype) initWithCamera:(id<Camera>_Nonnull) camera;

- (void) rotateCameraAroundTargetWithDeltaPhi:(float) deltaPhi deltaTheta:(float) deltaTheta;

@end

#endif /* SatelliteController_h */
