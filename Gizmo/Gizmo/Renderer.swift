//
//  Renderer.swift
//  Gizmo
//
//  Created by Jacob Su on 5/6/21.
//

import Foundation
import MetalKit
import common

class Renderer: NSObject {
    
    private var device: MTLDevice!
    private var depthState: MTLDepthStencilState!
    private var gizmo: Gizmo!
    private var viewPort: MTLViewport!
    private var renderPipelineState: MTLRenderPipelineState!
    private var projectionMatrix: matrix_float4x4!
    private var camera: Camera!
    private var cameraController: SatelliteCameraController!
    private var commandQueue: MTLCommandQueue!

    init(mtkView: MTKView) {
        super.init()
        
        device = mtkView.device!
        mtkView.delegate = self
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.sampleCount = 4
        
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .lessEqual
        depthDescriptor.isDepthWriteEnabled = true
        
        depthState = device.makeDepthStencilState(descriptor: depthDescriptor)!
        gizmo = Gizmo(device: device)
        
        let width = mtkView.frame.width
        let height = mtkView.frame.height
        
        viewPort = MTLViewport(originX: 0.0,
                               originY: 0.0,
                               width: Double(width),
                               height: Double(height),
                               znear: 0.0,
                               zfar: 1.0)
        
        let library = device.makeDefaultLibrary()!
        let vertexFunc = library.makeFunction(name: "vertexShader")
        let fragmentFunc = library.makeFunction(name: "fragmentShader")
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        renderPipelineDescriptor.vertexDescriptor = gizmo.vertexDescriptor
        renderPipelineDescriptor.vertexFunction = vertexFunc
        renderPipelineDescriptor.fragmentFunction = fragmentFunc
        renderPipelineDescriptor.sampleCount = mtkView.sampleCount
        
        renderPipelineState = try! device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        projectionMatrix = matrix_perspective_left_hand(Float.pi / 4.0, Float(width) / Float(height), 0.1, 100.0)
        
        camera = Camera(position: vector_float3(0.0, 0.0, 5.0),
                        withTarget: vector_float3(0.0, 0.0, 0.0),
                        withUp: vector_float3(0.0, 1.0, 0.0))
        
        cameraController = SatelliteCameraController(camera: camera)
        
        commandQueue = device.makeCommandQueue()!
    }
    
    func handleCameraEvent(deltaX: Float, deltaY: Float) {
        cameraController.rotateCameraAroundTarget(withDeltaPhi: deltaX, deltaTheta: deltaY)
        
    }
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewPort.width = Double(size.width)
        viewPort.height = Double(size.height)
        
        projectionMatrix = matrix_perspective_left_hand(Float.pi / 4.0, Float(size.width) / Float(size.height), 0.1, 100.0)
    }
    
    func draw(in view: MTKView) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderDescriptor = view.currentRenderPassDescriptor!
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderDescriptor)!
        
        renderEncoder.setViewport(viewPort)
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setDepthStencilState(depthState)
        
        // draw gizmo
        gizmo.draw(to: renderEncoder,
                   viewMatrix: camera.getViewMatrix(),
                   projectionMatrix: projectionMatrix,
                   cameraPos: camera.cameraPosition)
        
        renderEncoder.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
}
