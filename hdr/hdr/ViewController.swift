//
//  ViewController.swift
//  hdr
//
//  Created by Jacob Su on 4/7/21.
//

import Cocoa
import MetalKit

class ViewController: NSViewController {

    private var renderer: Renderer!
    private var hdrSwitch: NSSwitch!
    private var exposureSlider: NSSlider!
    
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
        
        hdrSwitch = NSSwitch()
        hdrSwitch.state = .on
        hdrSwitch.target = self
        hdrSwitch.action = #selector(hdrSwitchChanged)
        
        hdrSwitch.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(hdrSwitch)
        
        NSLayoutConstraint.activate([
            hdrSwitch.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 20.0),
            hdrSwitch.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 20.0),
        ])
        
        let switchLable = NSTextField(labelWithString: "Enable HDR")
        switchLable.isEditable = false
        switchLable.isBordered = false
        switchLable.backgroundColor = nil
        switchLable.alignment = .center

        switchLable.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(switchLable)

        NSLayoutConstraint.activate([
            switchLable.centerYAnchor.constraint(equalTo: hdrSwitch.centerYAnchor, constant: 0.0),
            switchLable.leftAnchor.constraint(equalTo: hdrSwitch.rightAnchor, constant: 10.0),
        ])
        
        exposureSlider = NSSlider(value: 1.0,
                                  minValue: 0.0,
                                  maxValue: 2.0,
                                  target: self,
                                  action: #selector(exposureSliderValueChanged))
        exposureSlider.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(exposureSlider)
        
        NSLayoutConstraint.activate([
            exposureSlider.topAnchor.constraint(equalTo: hdrSwitch.bottomAnchor, constant: 20.0),
            exposureSlider.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 20.0),
            exposureSlider.widthAnchor.constraint(equalToConstant: 200)
        ])
        
        let exposureLabel = NSTextField(labelWithString: "Exposure")
        exposureLabel.isEditable = false
        exposureLabel.isBordered = false
        exposureLabel.backgroundColor = nil
        exposureLabel.alignment = .center
        
        exposureLabel.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(exposureLabel)
        
        NSLayoutConstraint.activate([
            exposureLabel.topAnchor.constraint(equalTo: exposureSlider.topAnchor),
            exposureLabel.leftAnchor.constraint(equalTo: exposureSlider.rightAnchor, constant: 10.0),
            exposureLabel.heightAnchor.constraint(equalTo: exposureSlider.heightAnchor),
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
    func hdrSwitchChanged() {
        renderer.enableHDR(enable: hdrSwitch.state == .on)
    }
    
    @objc
    func exposureSliderValueChanged() {
        renderer.setExposure(exposure: exposureSlider.floatValue)
    }
}

