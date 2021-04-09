//
//  ViewController.m
//  Bloom
//
//  Created by Jacob Su on 4/8/21.
//

#import "ViewController.h"
#import "Renderer.h"
@import MetalKit;

@implementation ViewController
{
    Renderer *_renderer;
    NSSwitch *_bloomSwitch;
    NSSlider *_exposureSlider;
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
    
    _bloomSwitch = [NSSwitch new];
    _bloomSwitch.state = NSControlStateValueOn;
    _bloomSwitch.target = self;
    _bloomSwitch.action = @selector(bloomSwitchStateChanged);
    
    [self.view addSubview:_bloomSwitch];
    _bloomSwitch.translatesAutoresizingMaskIntoConstraints = false;
    
    NSTextField *bloomLabel = [NSTextField new];
    bloomLabel.stringValue = @"Enable Bloom";
    bloomLabel.bordered = false;
    bloomLabel.backgroundColor = nil;
    bloomLabel.editable = false;
    
    [self.view addSubview:bloomLabel];
    bloomLabel.translatesAutoresizingMaskIntoConstraints = false;
    
    [NSLayoutConstraint activateConstraints:@[
        [_bloomSwitch.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:20.0],
        [_bloomSwitch.leftAnchor constraintEqualToAnchor:self.view.leftAnchor constant:20.0],
        [bloomLabel.centerYAnchor constraintEqualToAnchor:_bloomSwitch.centerYAnchor],
        [bloomLabel.leftAnchor constraintEqualToAnchor:_bloomSwitch.rightAnchor constant:10.0]
    ]];
    
    _exposureSlider = [NSSlider new];
    _exposureSlider.sliderType = NSSliderTypeLinear;
    _exposureSlider.minValue = 0.0;
    _exposureSlider.maxValue = 2.0;
    _exposureSlider.floatValue = 1.0;
    _exposureSlider.target = self;
    _exposureSlider.action = @selector(exposureSliderValueChanged);
    _exposureSlider.doubleValue = 1.0;
    
    [self.view addSubview:_exposureSlider];
    _exposureSlider.translatesAutoresizingMaskIntoConstraints = false;
    
    NSTextField *exposureLabel = [NSTextField new];
    exposureLabel.stringValue = @"Exposure";
    exposureLabel.editable = false;
    exposureLabel.bordered = false;
    exposureLabel.backgroundColor = nil;
    
    [self.view addSubview:exposureLabel];
    exposureLabel.translatesAutoresizingMaskIntoConstraints = false;
    
    [NSLayoutConstraint activateConstraints:@[
        [_exposureSlider.topAnchor constraintEqualToAnchor:_bloomSwitch.bottomAnchor constant:20.0],
        [_exposureSlider.leftAnchor constraintEqualToAnchor:self.view.leftAnchor constant:20.0],
        [_exposureSlider.widthAnchor constraintEqualToConstant:100.0],
        [exposureLabel.centerYAnchor constraintEqualToAnchor:_exposureSlider.centerYAnchor],
        [exposureLabel.leftAnchor constraintEqualToAnchor:_exposureSlider.rightAnchor constant:10.0],
    ]];
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

- (void)bloomSwitchStateChanged {
    _renderer.bloom = _bloomSwitch.state == NSControlStateValueOn;
}

- (void)exposureSliderValueChanged {
    [_renderer setExposure:_exposureSlider.floatValue];
}

@end
