//
//  ViewController.swift
//  HelloWindow
//
//  Created by Jacob Su on 3/2/21.
//

import Cocoa
import MetalKit

class ViewController: NSViewController {

    var commandQueue: MTLCommandQueue!
    
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
        
        commandQueue = device.makeCommandQueue()
        
        metalView.device = device
        metalView.clearColor = MTLClearColor(red: 0.2, green: 0.3, blue: 0.3, alpha: 1.0)
        metalView.delegate = self
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

extension ViewController : MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        guard let descriptor = view.currentRenderPassDescriptor else {
            return
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        guard let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }
        
        commandEncoder.endEncoding()
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
    }
    
    
}
