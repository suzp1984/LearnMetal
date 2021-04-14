//
//  Renderer.swift
//  Mesh
//
//  Created by Jacob Su on 4/14/21.
//

import Foundation
import MetalKit
import common

class Renderer: NSObject {
    
    private var device: MTLDevice!
    private var sphereMesh: MTKMesh!
    private var icosaHedronMesh: MTKMesh!
    private var cylinderMesh: MTKMesh!
    private var camera: Camera!
    private var viewPort: MTLViewport!
    private var renderPipelineState: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!
    private var uniform: Uniforms!
    private var material: Material!
    private var light: Light!
    private var commandQueue: MTLCommandQueue!
    private var sphereModelMatrix: matrix_float4x4!
    private var sphereNormalMatrix: matrix_float3x3!
    private var icosahedronModelMatrix: matrix_float4x4!
    private var icosahedronNormalMatrix: matrix_float3x3!
    private var cylinderModelMatrix: matrix_float4x4!
    private var cylinderNormalMatrix: matrix_float3x3!
    
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
        
        let attributesMap = [
            Int(ModelVertexAttributePosition.rawValue): MDLVertexAttributePosition,
            Int(ModelVertexAttributeTexcoord.rawValue): MDLVertexAttributeTextureCoordinate,
            Int(ModelVertexAttributeNormal.rawValue): MDLVertexAttributeNormal
        ]
        sphereMesh = try! MTKMesh.newEllipsoid(withVertexDescriptor: mtlVertexDescriptor,
                                               withAttributesMap: attributesMap,
                                               withDevice: device,
                                               radii: vector_float3(1.0, 1.0, 1.0),
                                               radialSegments: 60,
                                               verticalSegments: 60,
                                               geometryType: .triangles,
                                               inwardNormals: false,
                                               hemisphere: false)
        
        icosaHedronMesh = try! MTKMesh.newIcosahedron(withVertexDescriptor: mtlVertexDescriptor,
                                                      withAttributesMap: attributesMap,
                                                      withDevice: device,
                                                      radius: 1.0,
                                                      geometryType: .triangles,
                                                      inwardNormals: false)
        
        cylinderMesh = try! MTKMesh.newCylinder(withVertexDescriptor: mtlVertexDescriptor,
                                            withAttributesMap: attributesMap,
                                            withDevice: device,
                                            height: 1.0,
                                            radii: vector_float2(0.5, 0.5),
                                            radialSegments: 60,
                                            verticalSegments: 60,
                                            geometryType: .triangles,
                                            inwardNormals: false)
        
        camera = CameraFactory.generateRoundOrbitCamera(withPosition: vector_float3(0.0, 0.0, 8.0),
                                                        target: vector_float3(0.0, 0.0, 0.0),
                                                        up: vector_float3(0.0, 1.0, 0.0))
        let width = mtkView.frame.width
        let height = mtkView.frame.height
        
        viewPort = MTLViewport(originX: 0.0, originY: 0.0, width: Double(width), height: Double(height), znear: 0.0, zfar: 1.0)
        
        let library = device.makeDefaultLibrary()!
        let vertexFunc = library.makeFunction(name: "vertexShader")!
        let fragmentFunc = library.makeFunction(name: "fragmentShader")!
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        renderPipelineDescriptor.vertexFunction = vertexFunc
        renderPipelineDescriptor.fragmentFunction = fragmentFunc
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        renderPipelineDescriptor.sampleCount = mtkView.sampleCount
        
        renderPipelineState = try! device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        
        uniform = Uniforms(modelMatrix: matrix4x4_identity(),
                           viewMatrix: camera.getViewMatrix(),
                           projectionMatrix: matrix_perspective_left_hand(Float.pi / 4.0,
                                                                          Float(width) / Float(height),
                                                                          0.1,
                                                                          100.0),
                           normalMatrix: matrix3x3_upper_left(matrix4x4_identity()))
        
        material = Material(ambient: vector_float3(0.2, 0.2, 0.5),
                            diffuse: vector_float3(0.9, 0.2, 0.8),
                            specular: vector_float3(1.0, 1.0, 1.0),
                            shininess: 32.0)
        light = Light(position: vector_float3(5.0, 5.0, 5.0),
                      ambient: vector_float3(1.0, 1.0, 1.0),
                      diffuse: vector_float3(0.9, 0.2, 0.7),
                      specular: vector_float3(0.9, 0.9, 0.9))
        commandQueue = device.makeCommandQueue()!
        
        sphereModelMatrix = matrix4x4_translation(1.0, 1.0, 0.0)
        sphereNormalMatrix = matrix3x3_upper_left(sphereModelMatrix).inverse.transpose
        
        icosahedronModelMatrix = matrix4x4_translation(-1.0, 1.0, 0.0)
        icosahedronNormalMatrix = matrix3x3_upper_left(icosahedronModelMatrix).inverse.transpose
        
        cylinderModelMatrix = matrix4x4_translation(1.0, -1.0, 0.0)
        cylinderNormalMatrix = matrix3x3_upper_left(cylinderModelMatrix).inverse.transpose
    }
    
    func handleCameraEvent(deltaX: Float, deltaY: Float) {
        camera.rotateCameraAroundTarget(withDeltaPhi: deltaX, deltaTheta: deltaY)
        
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
        
        let renderDescriptor = view.currentRenderPassDescriptor!
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderDescriptor)!
        
        renderEncoder.setViewport(viewPort)
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setDepthStencilState(depthState)
        
        light.position.x = Float(sin(CFAbsoluteTimeGetCurrent())) * 5.0
        light.position.y = Float(cos(CFAbsoluteTimeGetCurrent())) * 5.0
        // sphere
        renderEncoder.setVertexMesh(sphereMesh, index: Int(VertexInputIndexPosition.rawValue))
        uniform.modelMatrix = sphereModelMatrix
        uniform.normalMatrix = sphereNormalMatrix
        
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
        withUnsafePointer(to: light) {
            renderEncoder.setFragmentBytes($0,
                                           length: MemoryLayout<Light>.stride,
                                           index: Int(FragmentInputIndexLight.rawValue))
        }
        withUnsafePointer(to: camera.cameraPosition) {
            renderEncoder.setFragmentBytes($0,
                                           length: MemoryLayout<vector_float3>.stride,
                                           index: Int(FragmentInputIndexViewPos.rawValue))
        }
        renderEncoder.drawMesh(sphereMesh)
        
        // icosahedron
        renderEncoder.setVertexMesh(icosaHedronMesh, index: Int(VertexInputIndexPosition.rawValue))
        uniform.modelMatrix = icosahedronModelMatrix
        uniform.normalMatrix = icosahedronNormalMatrix
        withUnsafePointer(to: uniform) {
            renderEncoder.setVertexBytes($0,
                                         length: MemoryLayout<Uniforms>.stride,
                                         index: Int(VertexInputIndexUniforms.rawValue))
        }
        
        renderEncoder.drawMesh(icosaHedronMesh)
        
        // cylinder
        renderEncoder.setVertexMesh(cylinderMesh, index: Int(VertexInputIndexPosition.rawValue))
        uniform.modelMatrix = cylinderModelMatrix
        uniform.normalMatrix = cylinderNormalMatrix
        withUnsafePointer(to: uniform) {
            renderEncoder.setVertexBytes($0,
                                         length: MemoryLayout<Uniforms>.stride,
                                         index: Int(VertexInputIndexUniforms.rawValue))
        }
        renderEncoder.drawMesh(cylinderMesh)
        
        renderEncoder.endEncoding()
        
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    
}
