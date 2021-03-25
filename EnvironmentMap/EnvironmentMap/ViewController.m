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
    NSPopUpButton *_popupButton;
    NSDictionary *_dictionary;
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
    
    _popupButton = [NSPopUpButton new];
    _popupButton.target = self;
    _popupButton.action = @selector(fragmentSelected);
    
    [self.view addSubview:_popupButton];
    _popupButton.translatesAutoresizingMaskIntoConstraints = false;
   
    [NSLayoutConstraint activateConstraints:@[
            [_popupButton.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:20.0],
            [_popupButton.leftAnchor constraintEqualToAnchor:self.view.leftAnchor constant:20.0]
    ]];
    
    _dictionary = @{
        @"reflect": [NSNumber numberWithInt:kFragmentReflect],
        @"refract": [NSNumber numberWithInt:kFragmentRefract]
    };
    
    [_popupButton addItemsWithTitles:[_dictionary allKeys]];
    [_popupButton selectItemAtIndex:0];
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

- (void)fragmentSelected {
    FragmentType type = (FragmentType) [_dictionary[_popupButton.titleOfSelectedItem] intValue];
    
    [_renderer setFragmentType:type];
    
}

@end
