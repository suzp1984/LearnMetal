//
//  ViewController.m
//  GeometryNormals
//
//  Created by Jacob Su on 3/27/21.
//
#import "ViewController.h"
@import ModelIO;
@import MetalKit;
@import Metal;
@import AppKit;
#import "ModelShaderType.h"
#import "Renderer.h"

@implementation ViewController
{
    Renderer *renderer;
    NSSwitch *normalDrawSwitch;
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
    
    normalDrawSwitch = [[NSSwitch alloc] init];
    NSTextField *label = [NSTextField new];
    [label setEditable:false];
    [label setBordered:false];
    [label setBackgroundColor:nil];
    [label setStringValue:@"Show Normal Lines"];
    
    [self.view addSubview:normalDrawSwitch];
    [self.view addSubview:label];
    normalDrawSwitch.translatesAutoresizingMaskIntoConstraints = false;
    label.translatesAutoresizingMaskIntoConstraints = false;
    
    normalDrawSwitch.target = self;
    normalDrawSwitch.action = @selector(normalDrawAction);
    [normalDrawSwitch setState:NSControlStateValueOn];
    
    [NSLayoutConstraint activateConstraints:@[
            [normalDrawSwitch.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:20.0],
            [normalDrawSwitch.leftAnchor constraintEqualToAnchor:self.view.leftAnchor constant:20.0],
            [label.topAnchor constraintEqualToAnchor:normalDrawSwitch.topAnchor constant:3.0],
            [label.leftAnchor constraintEqualToAnchor:normalDrawSwitch.rightAnchor],
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

- (void)normalDrawAction {
    switch (normalDrawSwitch.state) {
        case NSControlStateValueOn:
            [renderer showNormalLine:true];
            break;
        case NSControlStateValueOff:
            [renderer showNormalLine:false];
            break;
        default:
            break;
    }
}


@end
