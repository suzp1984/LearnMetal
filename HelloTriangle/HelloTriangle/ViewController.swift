//
//  ViewController.swift
//  HelloTriangle
//
//  Created by Jacob Su on 3/2/21.
//

import Cocoa
import MetalKit

class ViewController: NSViewController {

    var triangleRenderer: TriangleRenderer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 960),
            view.heightAnchor.constraint(equalToConstant: 960)
        ])
        
        guard let metalView = view as? MTKView else {
            return
        }
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            return
        }
        
        metalView.device = device
        metalView.enableSetNeedsDisplay = true
        metalView.preferredFramesPerSecond = 30
        metalView.isPaused = false
        
        metalView.clearColor = MTLClearColor(red: 0.2, green: 0.3, blue: 0.3, alpha: 1.0)
        
        triangleRenderer = TriangleRenderer(metalKitView: metalView)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

