//
//  ViewController.swift
//  InstanceQuad
//
//  Created by Jacob Su on 3/28/21.
//

import Cocoa
import MetalKit

class ViewController: NSViewController {

    private var renderer: Renderer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(greaterThanOrEqualToConstant: 960),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: 960),
        ])
        
        let metalView = self.view as! MTKView
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            return
        }
        
        metalView.device = device
        metalView.enableSetNeedsDisplay = true
        metalView.preferredFramesPerSecond = 30
        metalView.isPaused = false
        
        metalView.clearColor = MTLClearColor(red: 0.2, green: 0.3, blue: 0.3, alpha: 1.0)
        
        renderer = Renderer(metalView: metalView)
    }

}

