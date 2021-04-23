//
//  Renderer.swift
//  Mesh2D
//
//  Created by Jacob Su on 4/23/21.
//

import Foundation
import MetalKit
import common

class Renderer: NSObject {
    
    private var device: MTLDevice!
    private var viewport: MTLViewport!
    private var uniform: Uniforms!
    private var camera: Camera!
    private var linesMesh: MTKMesh!
    private var renderPipelineState: MTLRenderPipelineState!
    private var commandQueue: MTLCommandQueue!
    
    init(mtkView: MTKView) {
        super.init()
        
        device = mtkView.device!
        mtkView.delegate = self
        
        camera = CameraFactory.generateRoundOrbitCamera(withPosition: vector_float3(0.0, 0.0, 5.0),
                                                        target: vector_float3(0.0, 0.0, 0.0),
                                                        up: vector_float3(0.0, 1.0, 0.0))
        let width = mtkView.frame.width
        let height = mtkView.frame.height
        
        viewport = MTLViewport(originX: 0.0,
                               originY: 0.0,
                               width: Double(width),
                               height: Double(height),
                               znear: 0.0,
                               zfar: 1.0)
        
        uniform = Uniforms(modelMatrix: matrix4x4_identity(),
                           viewMatrix: camera.getViewMatrix(),
                           projectionMatrix: matrix_perspective_left_hand(
                                Float.pi / 4.0, Float(width)/Float(height), 0.1, 100.0))
        
        let mtlVertexDescriptor = MTLVertexDescriptor()
        // position
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].format = .float3
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].offset = 0
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].bufferIndex = Int(VertexInputIndexPosition.rawValue)

        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stride = 16
        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stepRate = 1
        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stepFunction = .perVertex
        
        let points = [
            vector_float3(1.0, 1.0, 0.0),
            vector_float3(-1.0, -1.0, 0.0),
            vector_float3(1.0, 0.0, 0.0),
            vector_float3(0.0, 1.0, 0.0)
        ]
        
        linesMesh = try! MTKMesh.newLines(withVertexDescriptor: mtlVertexDescriptor,
                                          withAttributesMap: [ Int(ModelVertexAttributePosition.rawValue): MDLVertexAttributePosition],
                                          rawPtr: points,
                                          count: points.count,
                                          device: device)

        let library = device.makeDefaultLibrary()!
        let vertexFunc = library.makeFunction(name: "vertexShader")!
        let fragmentFunc = library.makeFunction(name: "fragmentShader")!
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        
        renderPipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        commandQueue = device.makeCommandQueue()!
    }
    
    func handleCameraEvent(deltaX: Float, deltaY: Float) {
        camera.rotateCameraAroundTarget(withDeltaPhi: deltaX, deltaTheta: deltaY)
        
        uniform.viewMatrix = camera.getViewMatrix()
    }
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewport.width = Double(size.width)
        viewport.height = Double(size.height)
        
        uniform.projectionMatrix = matrix_perspective_left_hand(
            Float.pi / 4.0, Float(size.width)/Float(size.height), 0.1, 100.0)
    }
    
    func draw(in view: MTKView) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        let renderPassDescriptor = view.currentRenderPassDescriptor!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        renderEncoder.setViewport(viewport)
        renderEncoder.setRenderPipelineState(renderPipelineState)
        
        renderEncoder.setVertexMesh(linesMesh, index: Int(VertexInputIndexPosition.rawValue))
        withUnsafePointer(to: uniform) {
            renderEncoder.setVertexBytes($0, length: MemoryLayout<Uniforms>.stride, index: Int(VertexInputIndexUniforms.rawValue))
        }
        
        renderEncoder.drawMesh(linesMesh)
        
        renderEncoder.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    
}
