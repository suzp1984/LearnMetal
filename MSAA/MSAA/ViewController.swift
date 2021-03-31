//
//  ViewController.swift
//  MSAA
//
//  Created by Jacob Su on 3/29/21.
//

import Cocoa
import MetalKit

class ViewController: NSViewController {

    private var renderer: Renderer!
    private var msaaSwitch: NSSwitch!
    
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
        
        msaaSwitch = NSSwitch()
        msaaSwitch.target = self
        msaaSwitch.action = #selector(msaaStateChanged)
        msaaSwitch.state = .on
        
        view.addSubview(msaaSwitch)
        msaaSwitch.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            msaaSwitch.topAnchor.constraint(equalTo: view.topAnchor, constant: 20.0),
            msaaSwitch.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20.0)
        ])
        
        let label = NSTextField()
        label.stringValue = "enable MSAA"
        view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 20.0),
            label.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20.0)
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
    
    @objc func msaaStateChanged() -> Void {
        renderer.enableMSAA(enable: msaaSwitch.state == .on)
    }
}

