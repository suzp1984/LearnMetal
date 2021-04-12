//
//  ViewController.swift
//  DeferredShading
//
//  Created by Jacob Su on 4/10/21.
//

import Cocoa
import MetalKit

class ViewController: NSViewController {

    private var renderer: Renderer!
    private var lightVolumnSwitch: NSSwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(greaterThanOrEqualToConstant: 760),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: 760),
        ])
        
        guard let metalView = view as? MTKView else {
            assert(false, "can not cast root view as MTKView")
        }
    
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.enableSetNeedsDisplay = false
        metalView.preferredFramesPerSecond = 30
        metalView.isPaused = false
        metalView.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        
        renderer = Renderer(metalView: metalView)
        
        lightVolumnSwitch = NSSwitch()
        lightVolumnSwitch.target = self
        lightVolumnSwitch.action = #selector(lightVolumnStateChanged)
        lightVolumnSwitch.state = .on
        
        self.view.addSubview(lightVolumnSwitch)
        lightVolumnSwitch.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            lightVolumnSwitch.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 20.0),
            lightVolumnSwitch.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 20.0)
        ])
        
        let label = NSTextField(labelWithString: "Enable Light Volumns")
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = nil
        
        self.view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: lightVolumnSwitch.trailingAnchor, constant: 10.0),
            label.centerYAnchor.constraint(equalTo: lightVolumnSwitch.centerYAnchor)
        ])
    }

    override func mouseDragged(with event: NSEvent) {
        if event.type == .leftMouseDragged ||
            event.type == .rightMouseDragged ||
            event.type == .otherMouseDragged {
            renderer.handleCameraEvent(deltaX: Float(event.deltaX), deltaY: Float(event.deltaY))
        }
    }

    override func scrollWheel(with event: NSEvent) {
        if event.hasPreciseScrollingDeltas {
            renderer.handleCameraEvent(deltaX: Float(event.scrollingDeltaX),
                                       deltaY: Float(event.scrollingDeltaY))
        }
    }
    
    @objc
    func lightVolumnStateChanged() {
        renderer.enableLightVolumns(enable: lightVolumnSwitch.state == .on)
    }
}
