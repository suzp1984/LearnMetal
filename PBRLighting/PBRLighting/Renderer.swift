//
//  Renderer.swift
//  PBRLighting
//
//  Created by Jacob Su on 4/15/21.
//

import Foundation
import MetalKit
import common

class Renderer: NSObject {
    
    private var device: MTLDevice!
    private var camera: Camera!
    private var sphere: MTKMesh!
    private var depthState: MTLDepthStencilState!
    private var renderPipelineState: MTLRenderPipelineState!
    private var viewPort: MTLViewport!
    private var uniform: Uniforms!
    private var material: Material!
    private var lights: [Light]!
    private var commandQueue: MTLCommandQueue!
    
    init(mtkView: MTKView) {
        super.init()
        
        device = mtkView.device!
        mtkView.delegate = self
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        mtkView.clearDepth = 1.0
        
        camera = CameraFactory.generateRoundOrbitCamera(withPosition: vector_float3(0.0, 0.0, 20.0),
                                                        target: vector_float3(0.0, 0.0, 0.0),
                                                        up: vector_float3(0.0, 1.0, 0.0))
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .lessEqual
        depthStencilDescriptor.isDepthWriteEnabled = true
        
        depthState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)!
        
        
        let mtlVertexDescriptor = MTLVertexDescriptor()
        // position
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].format = .float3
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].offset = 0
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].bufferIndex = Int(VertexInputIndexPosition.rawValue)

        // texture coordinate
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeTexcoord.rawValue)].format = .float2
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeTexcoord.rawValue)].offset = 16
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeTexcoord.rawValue)].bufferIndex = Int(VertexInputIndexPosition.rawValue)

        // normal
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeNormal.rawValue)].format = .float3
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeNormal.rawValue)].offset = 32
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeNormal.rawValue)].bufferIndex = Int(VertexInputIndexPosition.rawValue)

        // layout
        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stride = 48
        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stepRate = 1
        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stepFunction = .perVertex
        
        let mtlAttributesMap = [
            Int(ModelVertexAttributePosition.rawValue): MDLVertexAttributePosition,
            Int(ModelVertexAttributeTexcoord.rawValue): MDLVertexAttributeTextureCoordinate,
            Int(ModelVertexAttributeNormal.rawValue): MDLVertexAttributeNormal
        ]
        
        sphere = try! MTKMesh.newEllipsoid(withVertexDescriptor: mtlVertexDescriptor,
                                      withAttributesMap: mtlAttributesMap,
                                      withDevice: device,
                                      radii: vector_float3(1.0, 1.0, 1.0),
                                      radialSegments: 60,
                                      verticalSegments: 60,
                                      geometryType: .triangles,
                                      inwardNormals: false,
                                      hemisphere: false)
        
        let library = device.makeDefaultLibrary()!
        let vertexFunc = library.makeFunction(name: "pbrVertexShader")!
        let fragmentFunc = library.makeFunction(name: "pbrFragmentShader")!
        
        let renderDescriptor = MTLRenderPipelineDescriptor()
        renderDescriptor.vertexDescriptor = mtlVertexDescriptor
        renderDescriptor.vertexFunction = vertexFunc
        renderDescriptor.fragmentFunction = fragmentFunc
        renderDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        renderDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        
        renderPipelineState = try! device.makeRenderPipelineState(descriptor: renderDescriptor)
        
        material = Material(albedo: vector_float3(0.5, 0.0, 0.0), metallic: 1.0, roughness: 0.0, ao: 1.0)
        
        let width = mtkView.frame.width
        let height = mtkView.frame.height
        viewPort = MTLViewport(originX: 0.0, originY: 0.0, width: Double(width), height: Double(height), znear: 0.0, zfar: 1.0)
        
        uniform = Uniforms(modelMatrix: matrix4x4_identity(),
                           viewMatrix: camera.getViewMatrix(),
                           projectionMatrix: matrix_perspective_left_hand(Float.pi/4.0, Float(width)/Float(height), 0.1, 100.0))
        
        lights = [
            Light(position: vector_float3(-10.0, 10.0, 10.0), color: vector_float3(300.0, 300.0, 300.0)),
            Light(position: vector_float3( 10.0, 10.0, 10.0), color: vector_float3(300.0, 300.0, 300.0)),
            Light(position: vector_float3(-10.0,-10.0, 10.0), color: vector_float3(300.0, 300.0, 300.0)),
            Light(position: vector_float3( 10.0,-10.0, 10.0), color: vector_float3(300.0, 300.0, 300.0))
        ]
        
        commandQueue = device.makeCommandQueue()!
    }
    
    func handleCameraEvent(deltaX: Float, deltaY: Float) {
        camera.rotateCameraAroundTarget(withDeltaPhi: deltaX * 0.2, deltaTheta: deltaY * 0.2)
        
        uniform.viewMatrix = camera.getViewMatrix()
    }
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewPort.width = Double(size.width)
        viewPort.height = Double(size.height)
        
        uniform.projectionMatrix = matrix_perspective_left_hand(Float.pi / 4.0, Float(size.width) / Float(size.height), 0.1, 100.0)
        
    }
    
    func draw(in view: MTKView) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        let renderPassDescriptor = view.currentRenderPassDescriptor!
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        renderEncoder.setViewport(viewPort)
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setDepthStencilState(depthState)
        
        renderEncoder.setVertexMesh(sphere, index: Int(VertexInputIndexPosition.rawValue))
        
        renderEncoder.setFragmentBytes(lights,
                                       length: MemoryLayout<Light>.stride * lights.count,
                                       index: Int(FragmentInputIndexLights.rawValue))
        
        withUnsafePointer(to: lights.count) {
            renderEncoder.setFragmentBytes($0,
                                           length: MemoryLayout<Int>.stride,
                                           index: Int(FragmentInputIndexLightsCount.rawValue))
        }
        
        withUnsafePointer(to: camera.cameraPosition) {
            renderEncoder.setFragmentBytes($0,
                                           length: MemoryLayout<vector_float3>.stride,
                                           index: Int(FragmentInputIndexCameraPostion.rawValue))
        }
        
        for row in 0..<7 {
            material.metallic = Float(row) / 7.0
            
            for col in 0..<7 {
                material.roughness = max(min(Float(col)/7.0, 1.0), 0.05)
                
                uniform.modelMatrix = matrix4x4_translation((Float(col) - (7.0 / 2.0)) * 2.5,
                                                            (Float(row) - (7.0 / 2.0)) * 2.5,
                                                            0.0)
                
                withUnsafePointer(to: uniform) {
                    renderEncoder.setVertexBytes($0,
                                                 length: MemoryLayout<Uniforms>.stride,
                                                 index: Int(VertexInputIndexUniforms.rawValue))
                }
                
                withUnsafePointer(to: material) {
                    renderEncoder.setFragmentBytes($0,
                                                   length: MemoryLayout<Material>.stride,
                                                   index: Int(FragmentInputIndexMaterial.rawValue))
                }
                
                
                renderEncoder.drawMesh(sphere)
            }
        }
        
        
        renderEncoder.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    
}
