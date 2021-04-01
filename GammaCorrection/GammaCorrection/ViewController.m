//
//  ViewController.m
//  GammaCorrection
//
//  Created by Jacob Su on 4/1/21.
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
    NSSwitch *gammaCorrectionSwitch;
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
    
    gammaCorrectionSwitch = [NSSwitch new];
    gammaCorrectionSwitch.state = NSControlStateValueOn;
    gammaCorrectionSwitch.target = self;
    gammaCorrectionSwitch.action = @selector(blinnSwitchChanged);
    
    NSTextField *label = [NSTextField new];
    [label setStringValue:@"enable gamma correction"];
    [label setEditable:false];
    [label setBordered:false];
    [label setBackgroundColor:nil];
    
    [self.view addSubview:gammaCorrectionSwitch];
    gammaCorrectionSwitch.translatesAutoresizingMaskIntoConstraints = FALSE;
    [self.view addSubview:label];
    label.translatesAutoresizingMaskIntoConstraints = FALSE;
    
    [NSLayoutConstraint activateConstraints:@[
        [gammaCorrectionSwitch.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:20.0],
        [gammaCorrectionSwitch.leftAnchor constraintEqualToAnchor:self.view.leftAnchor constant:20.0],
        [label.topAnchor constraintEqualToAnchor:gammaCorrectionSwitch.topAnchor constant:5.0],
        [label.leftAnchor constraintEqualToAnchor:gammaCorrectionSwitch.rightAnchor]
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
    [renderer enableGammaCorrection:(gammaCorrectionSwitch.state == NSControlStateValueOn)];
}

@end
