//
//  ViewController.m
//  EnvironmentMap
//
//  Created by Jacob Su on 3/24/21.
//

#import "ViewController.h"
@import MetalKit;
#import "Renderer.h"

@implementation ViewController
{
    Renderer *_renderer;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.translatesAutoresizingMaskIntoConstraints = false;
    [NSLayoutConstraint activateConstraints:@[
                    [self.view.widthAnchor constraintGreaterThanOrEqualToConstant:760],
                    [self.view.heightAnchor constraintGreaterThanOrEqualToConstant:760],
    ]];
     
    MTKView *metalView = (MTKView*) self.view;
    
    metalView.device = MTLCreateSystemDefaultDevice();
    metalView.enableSetNeedsDisplay = false;
    metalView.preferredFramesPerSecond = 30;
    [metalView setPaused:false];
    [metalView setClearColor:MTLClearColorMake(0.2, 0.3, 0.3, 1.0)];
    
    _renderer = [[Renderer alloc] initWithMetalKitView:metalView];
}

- (void)mouseDragged:(NSEvent *)event {

    if (event.type == NSEventTypeLeftMouseDragged ||
        event.type == NSEventTypeRightMouseDragged ||
        event.type == NSEventTypeOtherMouseDragged) {
        [_renderer handleMouseScrollDeltaX:event.deltaX deltaY:event.deltaY];
    }
}

- (void)scrollWheel:(NSEvent *)event
{
    if ([event hasPreciseScrollingDeltas]) {
        [_renderer handleMouseScrollDeltaX:event.scrollingDeltaX
                                       deltaY:event.scrollingDeltaY];
    }
}

@end
