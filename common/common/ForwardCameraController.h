//
//  ForwardMoveController.h
//  common
//
//  Created by Jacob Su on 4/25/21.
//

#ifndef ForwardMoveController_h
#define ForwardMoveController_h

#import <common/Camera.h>

@interface ForwardCameraController : NSObject<CameraController>

- (nonnull instancetype) initWithCamera:(id<Camera>_Nonnull) camera;

- (void) moveAlongCameraDirection:(float)translation;

@end

#endif /* ForwardMoveController_h */
