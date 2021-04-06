//
//  ViewController.m
//  ParallaxMapping
//
//  Created by Jacob Su on 4/5/21.
//

#import "ViewController.h"
#import "ShaderType.h"
#import "Renderer.h"

@implementation ViewController
{
    Renderer *_renderer;
    NSSlider *_slider;
    NSPopUpButton *_parallaxSelectionButton;
    NSDictionary *_parrallaxOptions;
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
    
    _slider = [[NSSlider alloc] init];
    _slider.target = self;
    _slider.action = @selector(heightScaleChanged);
    _slider.minValue = 0.0;
    _slider.maxValue = 1.0;
    _slider.sliderType = NSSliderTypeLinear;
    
    [self.view addSubview:_slider];
    _slider.translatesAutoresizingMaskIntoConstraints = FALSE;
    
    [NSLayoutConstraint activateConstraints:@[
        [_slider.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:20.0],
        [_slider.leftAnchor constraintEqualToAnchor:self.view.leftAnchor constant:20.0],
        [_slider.widthAnchor constraintEqualToConstant:100.0]
    ]];
    
    NSTextField *label = [NSTextField new];
    [label setStringValue:@"Height Scale"];
    [label setBackgroundColor:nil];
    [label setBordered:false];
    [label setEditable:FALSE];
    
    [self.view addSubview:label];
    label.translatesAutoresizingMaskIntoConstraints = FALSE;
    
    [NSLayoutConstraint activateConstraints:@[
        [label.topAnchor constraintEqualToAnchor:_slider.topAnchor constant:2.0],
        [label.leftAnchor constraintEqualToAnchor:_slider.rightAnchor constant:5.0],
    ]];
    
    _parallaxSelectionButton = [NSPopUpButton new];
    _parallaxSelectionButton.target = self;
    _parallaxSelectionButton.action = @selector(parallaxSelected);
    
    [self.view addSubview:_parallaxSelectionButton];
    _parallaxSelectionButton.translatesAutoresizingMaskIntoConstraints = FALSE;
    
    [NSLayoutConstraint activateConstraints:@[
        [_parallaxSelectionButton.topAnchor constraintEqualToAnchor:_slider.bottomAnchor constant:20.0],
        [_parallaxSelectionButton.leftAnchor constraintEqualToAnchor:self.view.leftAnchor constant:20.0],
    ]];
    
    _parrallaxOptions = @{
        @"Parallax": [NSNumber numberWithInt:0],
        @"Steep Parallax": [NSNumber numberWithInt:1],
        @"Occlusion Parallax": [NSNumber numberWithInt:2],
    };
    
    [_parallaxSelectionButton addItemsWithTitles:[_parrallaxOptions allKeys]];
    [_parallaxSelectionButton selectItemAtIndex:0];
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

- (void)heightScaleChanged {
    [_renderer setHeightScale:_slider.doubleValue];
}

- (void)parallaxSelected {
    uint type = [_parrallaxOptions[_parallaxSelectionButton.titleOfSelectedItem] intValue];
    [_renderer setParallaxMethod:type];
}

@end
