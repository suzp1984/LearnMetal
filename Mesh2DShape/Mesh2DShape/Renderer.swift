//
//  Renderer.swift
//  3.5.Mesh2DShape
//
//  Created by Jacob Su on 5/5/21.
//

import Foundation
import MetalKit
import common

class Renderer: NSObject {
    
    private var device: MTLDevice!
    private var viewport: MTLViewport!
    private var uniform: Uniforms!
    private var camera: Camera!
    private var cameraController: SatelliteCameraController!
    private var linesMesh: MTKMesh!
    private var line2Mesh: MTKMesh!
    private var renderPipelineState: MTLRenderPipelineState!
    private var commandQueue: MTLCommandQueue!
    
    init(mtkView: MTKView) {
        super.init()
        
        device = mtkView.device!
        mtkView.delegate = self
        
        camera = SimpleCamera(position: vector_float3(0.0, 0.0, 5.0),
                              withTarget: vector_float3(0.0, 0.0, 0.0),
                              up: true)
        cameraController = SatelliteCameraController(camera: camera)
        
        let width = mtkView.frame.width
        let height = mtkView.frame.height
        
        viewport = MTLViewport(originX: 0.0,
                               originY: 0.0,
                               width: Double(width),
                               height: Double(height),
                               znear: 0.0,
                               zfar: 1.0)
        
        uniform = Uniforms(modelMatrix: matrix4x4_identity(),
                           viewMatrix: matrix4x4_identity(),
                           projectionMatrix: matrix_ortho_left_hand(0.0, Float(width), Float(height), 0.0, -100.0, 100.0))
        
        let mtlVertexDescriptor = MTLVertexDescriptor()
        // position
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].format = .float2
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].offset = 0
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].bufferIndex = Int(VertexInputIndexPosition.rawValue)

        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stride = MemoryLayout<vector_float2>.stride
        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stepRate = 1
        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stepFunction = .perVertex
        
        let attributesMap = [
            Int(ModelVertexAttributePosition.rawValue): MDLVertexAttributePosition
        ]
        
        let points = [
//            vector_float2(0.0, 0.0),
//            vector_float2(500.0, 500.0),
            vector_float2(100.0, 100.0),
            vector_float2(500.0, 300.0),
            vector_float2(500.0, 600.0),
            vector_float2(100.0, 700.0)
        ]
        
//        linesMesh = try! MTKMesh.new2DLines(withVertexDescriptor: mtlVertexDescriptor,
//                                            withAttributesMap: attributesMap,
//                                            device: device,
//                                            rawPtr: points,
//                                            count: points.count,
//                                            startWidth: 10.0,
//                                            endWidth: 20.0,
//                                            geometryType: .triangles)
        linesMesh = try! MTKMesh.newCubicBezier2DCurve(withVertexDescriptor: mtlVertexDescriptor,
                                                       withAttributesMap: attributesMap,
                                                       device: device,
                                                       rawPtr: points,
                                                       count: points.count,
                                                       lineSegments: 60,
                                                       startWidth: 2.0,
                                                       endWidth: 20.0,
                                                       geometryType: .triangles)
        
        let points2 = [
            vector_float2(400.0, 400.0),
            vector_float2(500.0, 400.0),
            vector_float2(500.0, 450.0),
            vector_float2(600.0, 300.0),
            vector_float2(600.0, 400.0),
            vector_float2(800.0, 300.0),
        ]
        
        line2Mesh = try! MTKMesh.newCubicBezier2DCurve(withVertexDescriptor: mtlVertexDescriptor,
                                                           withAttributesMap: attributesMap,
                                                           device: device,
                                                           rawPtr: points2,
                                                           count: points2.count,
                                                           lineSegments: 10,
                                                           startWidth: 2.0,
                                                           endWidth: 2.0,
                                                           geometryType: .triangles)

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
    
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewport.width = Double(size.width)
        viewport.height = Double(size.height)
        uniform.projectionMatrix = matrix_ortho_left_hand(0.0, Float(size.width), Float(size.height), 0.0, -1.0, 1.0)
    }
    
    func draw(in view: MTKView) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        let renderPassDescriptor = view.currentRenderPassDescriptor!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        renderEncoder.setViewport(viewport)
        renderEncoder.setRenderPipelineState(renderPipelineState)
        
        // draw lines
        renderEncoder.pushDebugGroup("Lines 1")
        renderEncoder.setVertexMesh(linesMesh, index: Int(VertexInputIndexPosition.rawValue))
        uniform.modelMatrix = matrix4x4_identity()
        withUnsafePointer(to: uniform) {
            renderEncoder.setVertexBytes($0, length: MemoryLayout<Uniforms>.stride, index: Int(VertexInputIndexUniforms.rawValue))
        }
        var color = vector_float3(1.0, 0.0, 0.0)
        withUnsafePointer(to: color) {
            renderEncoder.setFragmentBytes($0, length: MemoryLayout<vector_float3>.stride, index: 0)
        }

        renderEncoder.drawMesh(linesMesh)
        renderEncoder.popDebugGroup()
    
        // draw lines2
        renderEncoder.pushDebugGroup("Lines 2")
        renderEncoder.setVertexMesh(line2Mesh, index: Int(VertexInputIndexPosition.rawValue))
        uniform.modelMatrix = matrix4x4_identity()
        withUnsafePointer(to: uniform) {
            renderEncoder.setVertexBytes($0, length: MemoryLayout<Uniforms>.stride, index: Int(VertexInputIndexUniforms.rawValue))
        }
        color = vector_float3(0.0, 1.0, 0.0)
        withUnsafePointer(to: color) {
            renderEncoder.setFragmentBytes($0, length: MemoryLayout<vector_float3>.stride, index: 0)
        }
        
        renderEncoder.drawMesh(line2Mesh)
        renderEncoder.popDebugGroup()
        
        renderEncoder.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    
}
