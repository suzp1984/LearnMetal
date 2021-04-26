//
//  LinearMoveCameraController.h
//  common
//
//  Created by Jacob Su on 4/25/21.
//

#ifndef LinearMoveCameraController_h
#define LinearMoveCameraController_h
#import <common/Camera.h>

@interface LinearMoveCameraController : NSObject<CameraController>

- (nonnull instancetype) initWithCamera:(id<Camera>_Nonnull) camera;

- (void) moveCameraWithTranslation:(vector_float3)translation;

@end

#endif /* LinearMoveCameraController_h */
