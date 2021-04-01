//
//  ViewController.m
//  BlinnPhong
//
//  Created by Jacob Su on 3/31/21.
//

#import "ViewController.h"
@import ModelIO;
@import MetalKit;
@import Metal;
#import "ShaderType.h"
#import "Renderer.h"

@implementation ViewController
{
    Renderer *renderer;
    NSSwitch *blinnPhongSwitch;
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
    
    renderer = [[Renderer alloc] initWithMetalKitView:metalView];
    
    blinnPhongSwitch = [NSSwitch new];
    blinnPhongSwitch.state = NSControlStateValueOn;
    blinnPhongSwitch.target = self;
    blinnPhongSwitch.action = @selector(blinnSwitchChanged);
    
    NSTextField *label = [NSTextField new];
    [label setStringValue:@"enable blinn phong"];
    [label setEditable:false];
    [label setBordered:false];
    [label setBackgroundColor:nil];
    
    [self.view addSubview:blinnPhongSwitch];
    blinnPhongSwitch.translatesAutoresizingMaskIntoConstraints = FALSE;
    [self.view addSubview:label];
    label.translatesAutoresizingMaskIntoConstraints = FALSE;
    
    [NSLayoutConstraint activateConstraints:@[
        [blinnPhongSwitch.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:20.0],
        [blinnPhongSwitch.leftAnchor constraintEqualToAnchor:self.view.leftAnchor constant:20.0],
        [label.topAnchor constraintEqualToAnchor:blinnPhongSwitch.topAnchor constant:5.0],
        [label.leftAnchor constraintEqualToAnchor:blinnPhongSwitch.rightAnchor]
    ]];
    
}

- (void)mouseDragged:(NSEvent *)event {

    if (event.type == NSEventTypeLeftMouseDragged ||
        event.type == NSEventTypeRightMouseDragged ||
        event.type == NSEventTypeOtherMouseDragged) {
        [renderer handleMouseScrollDeltaX:event.deltaX deltaY:event.deltaY];
    }
}

- (void)scrollWheel:(NSEvent *)event
{
    if ([event hasPreciseScrollingDeltas]) {
        [renderer handleMouseScrollDeltaX:event.scrollingDeltaX
                                       deltaY:event.scrollingDeltaY];
    }
}

- (void)blinnSwitchChanged {
    [renderer enableBlinnPhong:(blinnPhongSwitch.state == NSControlStateValueOn)];
}

@end
