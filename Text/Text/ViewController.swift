//
//  ViewController.swift
//  Text
//
//  Created by Jacob Su on 4/21/21.
//

import Cocoa
import MetalKit

class ViewController: NSViewController {

    private var renderer: Renderer!
    
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
        
        renderer = Renderer(mtkView: metalView)
        
    }
}

