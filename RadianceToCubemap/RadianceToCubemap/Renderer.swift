//
//  Renderer.swift
//  RadianceToCubemap
//
//  Created by Jacob Su on 4/17/21.
//

import Foundation
import MetalKit
import common

class Renderer: NSObject {
    private var device: MTLDevice!
    private var camera: Camera!
    private var cameraController: SatelliteCameraController!
    private var hdrTexture: MTLTexture!
    private var cubeTexture: MTLTexture!
    private var depthState: MTLDepthStencilState!
    private var cubeMesh: MTKMesh!
    private var sphereMesh: MTKMesh!
    private var cubeMapPipelineState: MTLRenderPipelineState!
    private var backgroundPipelineState: MTLRenderPipelineState!
    private var pbrRenderPipelineState: MTLRenderPipelineState!
    private var commandQueue: MTLCommandQueue!
    private var viewPort: MTLViewport!
    private var uniform: Uniforms!
    private var instanceParamsBuffer: MTLBuffer!
    private var material: Material!
    private var lights: [Light]!
    
    init(mtkView: MTKView) {
        super.init()
        
        device = mtkView.device!
        mtkView.delegate = self
        mtkView.depthStencilPixelFormat = .depth32Float
        
        camera = SimpleCamera(position: vector_float3(0.0, 0.0, 8.0),
                              withTarget: vector_float3(0.0, 0.0, 0.0),
                              up: true)
        cameraController = SatelliteCameraController(camera: camera)
        
        commandQueue = device.makeCommandQueue()!
        loadHdrTexture(commandQueue: commandQueue)
        
        let textureDescritpor = MTLTextureDescriptor.textureCubeDescriptor(pixelFormat: .rgba16Float,
                                                                           size: 512,
                                                                           mipmapped: false)
        textureDescritpor.usage = [.renderTarget, .shaderRead]
        textureDescritpor.storageMode = .private
        
        cubeTexture = device.makeTexture(descriptor: textureDescritpor)!
        
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
        
        cubeMesh = try! MTKMesh.newBox(withVertexDescriptor: mtlVertexDescriptor,
                                  withAttributesMap: mtlAttributesMap,
                                  withDevice: device,
                                  withDimensions: vector_float3(2.0, 2.0, 2.0),
                                  segments: vector_uint3(1, 1, 1),
                                  geometryType: .triangles,
                                  inwardNormals: false)
        
        sphereMesh = try! MTKMesh.newSphere(withVertexDescriptor: mtlVertexDescriptor,
                                               withAttributesMap: mtlAttributesMap,
                                               withDevice: device,
                                               radii: 1.0,
                                               radialSegments: 60,
                                               verticalSegments: 60,
                                               geometryType: .triangles,
                                               inwardNormals: false,
                                               hemisphere: false)
        
        let library = device.makeDefaultLibrary()!
        let cubeVertexFunc = library.makeFunction(name: "cubeMapVertexShader")
        let cubeFragmentFunc = library.makeFunction(name: "cubeMapFragmentShader")
        
        let cubeRenderDescriptor = MTLRenderPipelineDescriptor()
        cubeRenderDescriptor.vertexDescriptor = mtlVertexDescriptor
        cubeRenderDescriptor.vertexFunction = cubeVertexFunc
        cubeRenderDescriptor.fragmentFunction = cubeFragmentFunc
        cubeRenderDescriptor.colorAttachments[0].pixelFormat = cubeTexture.pixelFormat
        cubeRenderDescriptor.inputPrimitiveTopology = .triangle
        
        cubeMapPipelineState = try! device.makeRenderPipelineState(descriptor: cubeRenderDescriptor)
        
        let bgVertexFunc = library.makeFunction(name: "backgroundVertexShader")
        let bgFragmentFunc = library.makeFunction(name: "backgroundFragmentShader")
        
        let bgRenderDescriptor = MTLRenderPipelineDescriptor()
        bgRenderDescriptor.vertexDescriptor = mtlVertexDescriptor
        bgRenderDescriptor.vertexFunction = bgVertexFunc
        bgRenderDescriptor.fragmentFunction = bgFragmentFunc
        bgRenderDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        bgRenderDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        
        backgroundPipelineState = try! device.makeRenderPipelineState(descriptor: bgRenderDescriptor)
        
        let pbrVertexFunc = library.makeFunction(name: "pbrVertexShader")!
        let pbrFragmentFunc = library.makeFunction(name: "pbrFragmentShader")!
        
        let renderDescriptor = MTLRenderPipelineDescriptor()
        renderDescriptor.vertexDescriptor = mtlVertexDescriptor
        renderDescriptor.vertexFunction = pbrVertexFunc
        renderDescriptor.fragmentFunction = pbrFragmentFunc
        renderDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        renderDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        
        pbrRenderPipelineState = try! device.makeRenderPipelineState(descriptor: renderDescriptor)
        
        material = Material(albedo: vector_float3(0.5, 0.0, 0.0), metallic: 1.0, roughness: 0.0, ao: 1.0)
        
        lights = [
            Light(position: vector_float3(-10.0, 10.0, 10.0), color: vector_float3(300.0, 300.0, 300.0)),
            Light(position: vector_float3( 10.0, 10.0, 10.0), color: vector_float3(300.0, 300.0, 300.0)),
            Light(position: vector_float3(-10.0,-10.0, 10.0), color: vector_float3(300.0, 300.0, 300.0)),
            Light(position: vector_float3( 10.0,-10.0, 10.0), color: vector_float3(300.0, 300.0, 300.0))
        ]
        
        // render to cubemap texture
        let cubemapParams = [
            CubeMapParams(viewMatrix: matrix_look_at_right_hand(vector_float3(0.0, 0.0, 0.0),
                                                               vector_float3(-1.0, 0.0, 0.0),
                                                               vector_float3(0.0, -1.0, 0.0)),
                          layerId: 0),
            CubeMapParams(viewMatrix: matrix_look_at_right_hand(vector_float3(0.0, 0.0, 0.0),
                                                               vector_float3(1.0, 0.0, 0.0),
                                                               vector_float3(0.0, -1.0, 0.0)),
                          layerId: 1),
            CubeMapParams(viewMatrix: matrix_look_at_right_hand(vector_float3(0.0, 0.0, 0.0),
                                                               vector_float3(0.0, 1.0, 0.0),
                                                               vector_float3(0.0, 0.0, 1.0)),
                          layerId: 2),
            CubeMapParams(viewMatrix: matrix_look_at_right_hand(vector_float3(0.0, 0.0, 0.0),
                                                               vector_float3(0.0, -1.0, 0.0),
                                                               vector_float3(0.0, 0.0, -1.0)),
                          layerId: 3),
            CubeMapParams(viewMatrix: matrix_look_at_right_hand(vector_float3(0.0, 0.0, 0.0),
                                                               vector_float3(0.0, 0.0, 1.0),
                                                               vector_float3(0.0, -1.0, 0.0)),
                          layerId: 4),
            CubeMapParams(viewMatrix: matrix_look_at_right_hand(vector_float3(0.0, 0.0, 0.0),
                                                               vector_float3(0.0, 0.0, -1.0),
                                                               vector_float3(0.0, -1.0, 0.0)),
                          layerId: 5),
        ]
        
        instanceParamsBuffer = device.makeBuffer(bytes: cubemapParams,
                                                 length: MemoryLayout<CubeMapParams>.stride * cubemapParams.count,
                                                 options: .storageModeShared)

        let commandBuffer = commandQueue.makeCommandBuffer()!

        let cubeMapRenderDescriptor = MTLRenderPassDescriptor()
        cubeMapRenderDescriptor.colorAttachments[0].texture = cubeTexture
        cubeMapRenderDescriptor.colorAttachments[0].loadAction = .clear
        cubeMapRenderDescriptor.colorAttachments[0].storeAction = .store
        cubeMapRenderDescriptor.renderTargetArrayLength = 6

        let cubeMapRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: cubeMapRenderDescriptor)!

        cubeMapRenderEncoder.setViewport(MTLViewport(originX: 0.0, originY: 0.0, width: 512, height: 512, znear: 0.0, zfar: 1.0))
        cubeMapRenderEncoder.setRenderPipelineState(cubeMapPipelineState)

        cubeMapRenderEncoder.setVertexMesh(cubeMesh, index: Int(CubeMapVertexIndexPosition.rawValue))

        let cubemapProjection = matrix_perspective_left_hand(Float.pi / 2.0, 1.0, 0.1, 10.0)
        withUnsafePointer(to: cubemapProjection) {
            cubeMapRenderEncoder.setVertexBytes($0,
                                                length: MemoryLayout<matrix_float4x4>.stride,
                                                index: Int(CubeMapVertexIndexProjection.rawValue))
        }

        cubeMapRenderEncoder.setVertexBuffer(instanceParamsBuffer,
                                             offset: 0,
                                             index: Int(CubeMapVertexIndexInstanceParams.rawValue))

        cubeMapRenderEncoder.setFragmentTexture(hdrTexture, index: 0)

        cubeMapRenderEncoder.drawMesh(cubeMesh, instanceCount: 6)
        cubeMapRenderEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    
        let width = mtkView.frame.width
        let height = mtkView.frame.height
        
        let projection = matrix_perspective_left_hand(Float.pi / 4.0,
                                                      Float(width) / Float(height),
                                                      0.1,
                                                      100.0)
        
        uniform = Uniforms(modelMatrix: matrix4x4_identity(),
                           viewMatrix: camera.getViewMatrix(),
                           projectionMatrix: projection)
        
        viewPort = MTLViewport(originX: 0.0, originY: 0.0, width: Double(width), height: Double(height), znear: 0.0, zfar: 1.0)
    }
    
    func handleCameraEvent(deltaX: Float, deltaY: Float) {
        cameraController.rotateCameraAroundTarget(withDeltaPhi: deltaX * 0.2, deltaTheta: deltaY * 0.2)
        
        uniform.viewMatrix = camera.getViewMatrix()
    }
    
    private func loadHdrTexture(commandQueue: MTLCommandQueue? = nil) {
        let hdrUrl = Bundle.common.url(forResource: "newport_loft.hdr", withExtension: nil, subdirectory: "hdr")!
        hdrTexture = try! HDRTextureLoader.load(textureFrom: hdrUrl, device: device, commandQueue: commandQueue)
    }
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewPort.width = Double(size.width)
        viewPort.height = Double(size.height)
        
        uniform.projectionMatrix = matrix_perspective_left_hand(Float.pi / 4.0,
                                                                Float(size.width) / Float(size.height),
                                                                0.1,
                                                                100.0)
    }
    
    func draw(in view: MTKView) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        // render pbr
        let pbrRenderPassDescriptor = view.currentRenderPassDescriptor!
        
        let pbrRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: pbrRenderPassDescriptor)!
        
        pbrRenderEncoder.setViewport(viewPort)
        pbrRenderEncoder.setRenderPipelineState(pbrRenderPipelineState)
        pbrRenderEncoder.setDepthStencilState(depthState)
        
        pbrRenderEncoder.setVertexMesh(sphereMesh, index: Int(VertexInputIndexPosition.rawValue))
        
        pbrRenderEncoder.setFragmentBytes(lights,
                                       length: MemoryLayout<Light>.stride * lights.count,
                                       index: Int(FragmentInputIndexLights.rawValue))
        
        withUnsafePointer(to: lights.count) {
            pbrRenderEncoder.setFragmentBytes($0,
                                           length: MemoryLayout<Int>.stride,
                                           index: Int(FragmentInputIndexLightsCount.rawValue))
        }
        
        withUnsafePointer(to: camera.cameraPosition) {
            pbrRenderEncoder.setFragmentBytes($0,
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
                    pbrRenderEncoder.setVertexBytes($0,
                                                 length: MemoryLayout<Uniforms>.stride,
                                                 index: Int(VertexInputIndexUniforms.rawValue))
                }
                
                withUnsafePointer(to: material) {
                    pbrRenderEncoder.setFragmentBytes($0,
                                                   length: MemoryLayout<Material>.stride,
                                                   index: Int(FragmentInputIndexMaterial.rawValue))
                }
                
                
                pbrRenderEncoder.drawMesh(sphereMesh)
            }
        }
        
        pbrRenderEncoder.setRenderPipelineState(backgroundPipelineState)
        
        pbrRenderEncoder.setVertexMesh(cubeMesh, index: 0)
        
        pbrRenderEncoder.setFragmentTexture(cubeTexture, index: 0)
        
        pbrRenderEncoder.drawMesh(cubeMesh)
        
        pbrRenderEncoder.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    
}
