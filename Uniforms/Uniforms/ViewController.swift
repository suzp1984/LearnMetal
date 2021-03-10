//
//  ViewController.swift
//  Uniforms
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
        
        guard let mtkView = view as? MTKView else {
            return
        }
        
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.enableSetNeedsDisplay = false
        mtkView.preferredFramesPerSecond = 30
        mtkView.isPaused = false
        mtkView.clearColor = MTLClearColor(red: 0.2, green: 0.3, blue: 0.3, alpha: 1.0)
        
        triangleRenderer = TriangleRenderer(metalKitView: mtkView)
        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

