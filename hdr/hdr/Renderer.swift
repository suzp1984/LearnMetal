//
//  Renderer.swift
//  hdr
//
//  Created by Jacob Su on 4/7/21.
//

import Foundation
import MetalKit
import common
import simd

class Renderer: NSObject {
    
    private var device: MTLDevice!
    private var depthState: MTLDepthStencilState!
    private var cubeMesh: MTKMesh!
    private var wood: Texture!
    private var lightRenderPipelineState: MTLRenderPipelineState!
    private var hdrRenderPipelineState: MTLRenderPipelineState!
    private var lightsBuffer: MetalBuffer<Light>!
    private var lightPos: vector_float3!
    private var camera: Camera!
    private var viewPort: MTLViewport!
    private var uniforms: Uniforms!
    private var commandQueue: MTLCommandQueue!
    private var hdrTexture: MTLTexture!
    private var depthTexture: MTLTexture!
    private let colorTextureFormat: MTLPixelFormat = .rgba16Float
    private var hdrVertexBuffer: MetalBuffer<HDRVertex>!
    private var isHDREnable: Int!
    private var exposure: Float!
    
    init(metalView: MTKView) {
        super.init()
        
        isHDREnable = 1
        exposure = 1.0
        
        camera = Camera(position: vector_float3(0.0, 0.0, 5.0),
                        withTarget: vector_float3(0.0, 0.0, 5.1),
                        withUp: vector_float3(0.0, 1.0, 0.0));
    
        device = metalView.device!
        metalView.delegate = self
        
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.clearDepth = 1.0
        
        let depthStencilDesc = MTLDepthStencilDescriptor()
        depthStencilDesc.depthCompareFunction = .less
        depthStencilDesc.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depthStencilDesc)
        
        let mtlVertexDescriptor = MTLVertexDescriptor()
        // position
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].format = .float3
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].offset = 0
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].bufferIndex = Int(VertexInputIndexPosition.rawValue)

        // normal
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeNormal.rawValue)].format = .float3
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeNormal.rawValue)].offset = 16
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeNormal.rawValue)].bufferIndex = Int(VertexInputIndexPosition.rawValue)
        
        // texture coordinate
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeTexCoord.rawValue)].format = .float2
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeTexCoord.rawValue)].offset = 32
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeTexCoord.rawValue)].bufferIndex = Int(VertexInputIndexPosition.rawValue)
        
        // layout
        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stride = 48
        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stepRate = 1
        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stepFunction = .perVertex
        
        cubeMesh = try! MTKMesh.newBox(withVertexDescriptor: mtlVertexDescriptor,
                                  withAttributesMap: [
                                    Int(ModelVertexAttributePosition.rawValue): MDLVertexAttributePosition,
                                    Int(ModelVertexAttributeNormal.rawValue): MDLVertexAttributeNormal,
                                    Int(ModelVertexAttributeTexCoord.rawValue): MDLVertexAttributeTextureCoordinate
                                  ],
                                  withDevice: device,
                                  withDimensions: vector_float3(2.0, 2.0, 2.0),
                                  segments: vector_uint3(1, 1, 1),
                                  geometryType: .triangles,
                                  inwardNormals: true)
        
        wood = try! Texture.newTextureWithName("wood",
                                               scaleFactor: 1.0,
                                               device: device,
                                               options: [MTKTextureLoader.Option.SRGB: NSNumber.init(value: false)])
        
        let library = device.makeDefaultLibrary()!
        let lightVertexFunc = library.makeFunction(name: "lightVertexShader")!
        let lightFragmentFunc = library.makeFunction(name: "lightFragmentShader")!
        
        let lightRenderDescriptor = MTLRenderPipelineDescriptor()
        lightRenderDescriptor.vertexDescriptor = mtlVertexDescriptor
        lightRenderDescriptor.vertexFunction = lightVertexFunc
        lightRenderDescriptor.fragmentFunction = lightFragmentFunc
        lightRenderDescriptor.colorAttachments[0].pixelFormat = colorTextureFormat
        lightRenderDescriptor.depthAttachmentPixelFormat = metalView.depthStencilPixelFormat
        
        lightRenderPipelineState = try! device.makeRenderPipelineState(descriptor: lightRenderDescriptor)
        
        let hdrVertexFunc = library.makeFunction(name: "HDRVertexShader")!
        let hdrFragmentFunc = library.makeFunction(name: "HDRFragmentShader")!
        
        let hdrRenderDescriptor = MTLRenderPipelineDescriptor()
        hdrRenderDescriptor.vertexFunction = hdrVertexFunc
        hdrRenderDescriptor.fragmentFunction = hdrFragmentFunc
        hdrRenderDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        
        hdrRenderPipelineState = try! device.makeRenderPipelineState(descriptor: hdrRenderDescriptor)
        
        let lights = [
            Light(position: vector_float3( 0.0,  0.0, 49.5), color: vector_float3(200.0, 200.0, 200.0)),
            Light(position: vector_float3(-1.4, -1.9, 9.0), color: vector_float3(0.1, 0.0, 0.0)),
            Light(position: vector_float3( 0.0, -1.8, 4.0), color: vector_float3(0.0, 0.0, 0.2)),
            Light(position: vector_float3( 0.8, -1.7, 6.0), color: vector_float3(0.0, 0.1, 0.0))
        ]
        
        lightsBuffer = MetalBuffer(device: device, array: lights, index: UInt32(LightFragmentIndexLights.rawValue))
        
        let width = metalView.frame.width
        let height = metalView.frame.height
        
        viewPort = MTLViewport(originX: 0.0,
                               originY: 0.0,
                               width: Double(width),
                               height: Double(height),
                               znear: 0.0,
                               zfar: 1.0)
        let modelMatrix = matrix_multiply(matrix4x4_translation(0.0, 0.0, 25.0),
                                          matrix4x4_scale(2.5, 2.5, 27.5))
        
        let projectionMatrix = matrix_perspective_left_hand(Float.pi / 4.0,
                                                            Float(width) / Float(height),
                                                            0.1,
                                                            1000.0)
        
        var model3x3: matrix_float3x3 = matrix_float3x3()
        model3x3.columns.0 = vector_float3(modelMatrix.columns.0.x, modelMatrix.columns.0.y, modelMatrix.columns.0.z)
        model3x3.columns.1 = vector_float3(modelMatrix.columns.1.x, modelMatrix.columns.1.y, modelMatrix.columns.1.z)
        model3x3.columns.2 = vector_float3(modelMatrix.columns.2.x, modelMatrix.columns.2.y, modelMatrix.columns.2.z)
        
        let normalMatrix = simd_transpose(simd_inverse(model3x3))
        
        uniforms = Uniforms(modelMatrix: modelMatrix,
                            viewMatrix: camera.getViewMatrix(),
                            projectionMatrix: projectionMatrix,
                            normalMatrix: normalMatrix)
        commandQueue = device.makeCommandQueue()!
        
        depthTexture = buildDepthTexture(Int(width), Int(height))
        hdrTexture = buildColorTexture(Int(width), Int(height))
        
        let hdrVertices = [
            HDRVertex(position: vector_float2(-1.0,  1.0), texCoords: vector_float2(0.0, 1.0)),
            HDRVertex(position: vector_float2(-1.0, -1.0), texCoords: vector_float2(0.0, 0.0)),
            HDRVertex(position: vector_float2( 1.0,  1.0), texCoords: vector_float2(1.0, 1.0)),
            HDRVertex(position: vector_float2( 1.0, -1.0), texCoords: vector_float2(1.0, 0.0)),
        ]
        
        hdrVertexBuffer = MetalBuffer(device: device, array: hdrVertices, index: UInt32(HDRVertexInputPosition.rawValue))
    }
    
    func handleCameraEvent(deltaX: Float, deltaY: Float) -> Void {
        camera.handleMouseScrollDeltaX(deltaX, deltaY: deltaY)
        
        uniforms.viewMatrix = camera.getViewMatrix()
    }
    
    func enableHDR(enable: Bool) {
        isHDREnable = enable ? 1 : 0
    }
    
    func setExposure(exposure: Float) {
        self.exposure = exposure
    }
    
    fileprivate func buildDepthTexture(_ width: Int, _ height: Int) -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = MTLPixelFormat.depth32Float
        descriptor.width = width
        descriptor.height = height
        descriptor.mipmapLevelCount = 1
        descriptor.usage = .renderTarget
        descriptor.storageMode = .private
        
        let depthTexture = device.makeTexture(descriptor: descriptor)!
        depthTexture.label = "Depth Texture"
        return depthTexture
    }
    
    fileprivate func buildColorTexture(_ width: Int, _ height: Int) -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = colorTextureFormat
        descriptor.width = width
        descriptor.height = height
        descriptor.mipmapLevelCount = 1
        
        descriptor.usage = MTLTextureUsage(rawValue:
                                            MTLTextureUsage.renderTarget.rawValue |
                                            MTLTextureUsage.shaderRead.rawValue)
        descriptor.storageMode = .private
        
        let colorTexture = device.makeTexture(descriptor: descriptor)!
        colorTexture.label = "HDR Color Texture"
        
        return colorTexture
    }
}

extension Renderer : MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewPort.width = Double(size.width)
        viewPort.height = Double(size.height)
        
        uniforms.projectionMatrix = matrix_perspective_left_hand(Float.pi / 4.0,
                                                                 Float(size.width) / Float(size.height),
                                                                 0.1,
                                                                 1000.0)
        hdrTexture = buildColorTexture(Int(size.width), Int(size.height))
        depthTexture = buildDepthTexture(Int(size.width), Int(size.height))
    }
    
    func draw(in view: MTKView) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        // offscreen rendering
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = hdrTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.2, 0.3, 0.3, 1.0)
        
        renderPassDescriptor.depthAttachment.texture = depthTexture
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.storeAction = .dontCare
        renderPassDescriptor.depthAttachment.clearDepth = 1.0
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.setViewport(viewPort)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setRenderPipelineState(lightRenderPipelineState)
        
        renderEncoder.setVertexMesh(cubeMesh,
                                    index: Int(VertexInputIndexPosition.rawValue))
        
        renderEncoder.setVertexBytes(&uniforms,
                                     length: MemoryLayout<Uniforms>.stride,
                                     index: Int(VertexInputIndexUniforms.rawValue))
        
        try! renderEncoder.setFragmentTexture(wood, index: Int(LightFragmentIndexDiffuseTexture.rawValue))
        withUnsafePointer(to: camera.getPosition()) {
            renderEncoder.setFragmentBytes($0,
                                           length: MemoryLayout<vector_float3>.stride,
                                           index: Int(LightFragmentIndexViewPos.rawValue))
        }
        renderEncoder.setFragmentBuffer(lightsBuffer, offset: 0)
        withUnsafePointer(to: lightsBuffer.count) {
            renderEncoder.setFragmentBytes($0,
                                           length: MemoryLayout<Int>.stride,
                                           index: Int(LightFragmentIndexLightCount.rawValue))
        }
        
        renderEncoder.drawMesh(cubeMesh)
        
        renderEncoder.endEncoding()
        
        // hdr render
        // draw post processing texture
        let hdrRenderPassDescriptor = MTLRenderPassDescriptor()
        hdrRenderPassDescriptor.colorAttachments[0].texture = view.currentDrawable!.texture
        hdrRenderPassDescriptor.colorAttachments[0].loadAction = .clear
        hdrRenderPassDescriptor.colorAttachments[0].storeAction = .store
        hdrRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.2, 0.3, 0.3, 1.0)
        
        let hdrRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: hdrRenderPassDescriptor)!
        hdrRenderEncoder.setViewport(viewPort)
        hdrRenderEncoder.setRenderPipelineState(hdrRenderPipelineState)
        
        hdrRenderEncoder.setVertexBuffer(hdrVertexBuffer)
        hdrRenderEncoder.setFragmentTexture(hdrTexture, index: Int(HDRFragmentInputHDRTexture.rawValue))
        withUnsafePointer(to: isHDREnable) {
            hdrRenderEncoder.setFragmentBytes($0,
                                              length: MemoryLayout<Int>.stride,
                                              index: Int(HDRFragmentInputHDRSwitch.rawValue))
        }
        withUnsafePointer(to: exposure) {
            hdrRenderEncoder.setFragmentBytes($0,
                                              length: MemoryLayout<Float>.stride,
                                              index: Int(HDRFragmentInputExposure.rawValue))
        }
        
        hdrRenderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: hdrVertexBuffer.count)
        hdrRenderEncoder.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    
}
