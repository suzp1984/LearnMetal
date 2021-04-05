//
//  Renderer.swift
//  ShadowMapping
//
//  Created by Jacob Su on 4/2/21.
//

import Foundation
import MetalKit
import common

class Renderer: NSObject {
    
    private var camera: Camera!
    private var device: MTLDevice!
    private var depthState: MTLDepthStencilState!
    private var renderPipelineState: MTLRenderPipelineState!
    private var depthMapPipelineState: MTLRenderPipelineState!
    private var planeMesh: MTKMesh!
    private var wood: Texture!
    private var viewPort: MTLViewport!
    private var commandQueue: MTLCommandQueue!
    private var uniform: Uniforms!
    private var argumentBuffer: MTLBuffer!
    private var viewPosBuffer: MTLBuffer!
    private var cameraPos: vector_float3!
    private var cubeMesh: MTKMesh!
    private var depthTexture: MTLTexture!
    private var cubeUniforms: [Uniforms]!
    private var lightSpaceUniform: LightSpaceUniforms!
    private var cubeLightSpaceUniforms: [LightSpaceUniforms]!
    private let lightPosition = vector_float3(-2.0, 4.0, -1.0)
    
    init(metalView: MTKView) {
        super.init()
        
        device = metalView.device!
        metalView.sampleCount = 4
        metalView.delegate = self
        
        camera = Camera(position: vector_float3(0.0, 0.0, 3.0),
                        withTarget: vector_float3(0.0, 0.0, 0.0),
                        withUp: vector_float3(0.0, 1.0, 0.0))
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
        
        planeMesh = try! MTKMesh.newPlane(withVertexDescriptor: mtlVertexDescriptor,
                                     withAttributesMap: [
                                        Int(ModelVertexAttributePosition.rawValue): MDLVertexAttributePosition,
                                        Int(ModelVertexAttributeNormal.rawValue): MDLVertexAttributeNormal,
                                        Int(ModelVertexAttributeTexCoord.rawValue): MDLVertexAttributeTextureCoordinate],
                                     withDevice: device)
        
        cubeMesh = try! MTKMesh.newBox(withVertexDescriptor: mtlVertexDescriptor,
                                       withAttributesMap: [
                                        Int(ModelVertexAttributePosition.rawValue): MDLVertexAttributePosition,
                                        Int(ModelVertexAttributeNormal.rawValue): MDLVertexAttributeNormal,
                                        Int(ModelVertexAttributeTexCoord.rawValue): MDLVertexAttributeTextureCoordinate],
                                       withDevice: device)
        
        wood = try! Texture.newTextureWithName("wood",
                                               scaleFactor: 1.0,
                                               device: device,
                                               options: [MTKTextureLoader.Option.SRGB: NSNumber.init(value: true)])

        let library = device.makeDefaultLibrary()!
        let vertexFunc = library.makeFunction(name: "vertexShader")!
        let fragmentFunc = library.makeFunction(name: "blinnPhongWithGammaCorrectionFragmentShader")!
        
        let renderDescriptor = MTLRenderPipelineDescriptor()
        renderDescriptor.label = "Render descriptor"
        renderDescriptor.vertexFunction = vertexFunc
        renderDescriptor.fragmentFunction = fragmentFunc
        renderDescriptor.vertexDescriptor = mtlVertexDescriptor
        renderDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        renderDescriptor.depthAttachmentPixelFormat = metalView.depthStencilPixelFormat
        renderDescriptor.sampleCount = metalView.sampleCount
        
        renderPipelineState = try! device.makeRenderPipelineState(descriptor: renderDescriptor)
        
        let depthVertexFunc = library.makeFunction(name: "depthVertexShader")!
        let depthFragmentFunc = library.makeFunction(name: "depthFragmentShader")!
        
        let depthPipelineDescriptor = MTLRenderPipelineDescriptor()
        depthPipelineDescriptor.label = "depth pipeline"
        depthPipelineDescriptor.vertexFunction = depthVertexFunc
        depthPipelineDescriptor.fragmentFunction = depthFragmentFunc
        depthPipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        depthPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        depthMapPipelineState = try! device.makeRenderPipelineState(descriptor: depthPipelineDescriptor)
        
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .notMipmapped
        samplerDescriptor.normalizedCoordinates = true
        samplerDescriptor.supportArgumentBuffers = true
        samplerDescriptor.sAddressMode = .repeat
        samplerDescriptor.tAddressMode = .repeat
        
        let sampler = device.makeSamplerState(descriptor: samplerDescriptor)
        let argumentEncoder = fragmentFunc.makeArgumentEncoder(bufferIndex: Int(FragmentInputIndexArgumentBuffer.rawValue))
        argumentBuffer = device.makeBuffer(length: argumentEncoder.encodedLength, options: .storageModeShared)
        argumentBuffer.label = "ArgumentBuffer"
        
        argumentEncoder.setArgumentBuffer(argumentBuffer, offset: 0)
        argumentEncoder.setSamplerState(sampler, index: Int(FragmentArgumentBufferIndexSampler.rawValue))
        cameraPos = camera.getPosition()
        viewPosBuffer = device.makeBuffer(bytes: &cameraPos,
                                          length: MemoryLayout<vector_float3>.stride,
                                          options: .storageModeShared)
        argumentEncoder.setBuffer(viewPosBuffer,
                                  offset: 0,
                                  index: Int(FragmentArgumentBufferIndexViewPosition.rawValue))
        
        let lightPosPtr = argumentEncoder.constantData(at: Int(FragmentArgumentBufferIndexLightPosition.rawValue))
        withUnsafePointer(to: lightPosition) {
            lightPosPtr.copyMemory(from: $0,
                                   byteCount: MemoryLayout<vector_float3>.stride)
        }
        
        let lightColor = vector_float3(0.8, 0.8, 0.8)
        
        let lightColorPtr = argumentEncoder.constantData(at: Int(FragmentArgumentBufferIndexLightColor.rawValue))
        withUnsafePointer(to: lightColor) {
            lightColorPtr.copyMemory(from: $0,
                                      byteCount: MemoryLayout<vector_float3>.stride)
        }
        
        let width = metalView.frame.width
        let height = metalView.frame.height
        viewPort = MTLViewport(originX: 0.0,
                               originY: 0.0,
                               width: Double(width),
                               height: Double(height),
                               znear: 0.0,
                               zfar: 1.0)
        commandQueue = device.makeCommandQueue()!
        let modelMatrix = matrix_multiply(matrix4x4_translation(0.0, -0.5, 0.0),
                                          matrix4x4_scale(50.0, 1.0, 50.0))
        let projectionMatrix = matrix_perspective_left_hand(Float.pi / 4.0,
                                                            Float(width) / Float(height),
                                                            0.1,
                                                            100.0)
        
        let lightProjection = matrix_ortho_left_hand(-20.0, 20.0, -20.0, 20.0, 1.0, 7.5)
//        let lightProjection = matrix_perspective_left_hand(PI/4.0, Float(width)/Float(height), 0.1, 100.0)
        let lightView = matrix_look_at_left_hand(lightPosition,
                                                 vector_float3(0.0, 0.0, 0.0),
                                                 vector_float3(0.0, 1.0, 0.0))
        let lightSpaceMatrix = lightProjection * lightView

    
        lightSpaceUniform = LightSpaceUniforms(lightSpaceMatrix: lightSpaceMatrix, modelMatrix: modelMatrix)
        
        uniform = Uniforms(modelMatrix: modelMatrix,
                           viewMatrix: camera.getViewMatrix(),
                           projectionMatrix: projectionMatrix,
                           inverseModelMatrix: modelMatrix.inverse,
                           lightSpaceMatrix: lightSpaceMatrix,
                           texCoordScale: 25.0)
        
        let cube1ModelMatrix = matrix_multiply(matrix4x4_translation(0.0, 1.0, 0.0),
                                               matrix4x4_scale(0.5, 0.5, 0.5))
        let cube2ModelMatrix = matrix_multiply(matrix4x4_translation(1.0, 0.0, 0.5),
                                               matrix4x4_scale(0.5, 0.5, 0.5))
        let cube3ModelMatrix = matrix_multiply(matrix4x4_translation(-0.2, 0.0, 0.2),
                                               matrix_multiply(matrix4x4_rotation(Float.pi * 60.0 / 180.0, vector_float3(1.0, 0.0, 1.0)),
                                                               matrix4x4_scale(0.25, 0.25, 0.25)))
        
        cubeUniforms = [
            Uniforms(modelMatrix: cube1ModelMatrix,
                     viewMatrix: camera.getViewMatrix(),
                     projectionMatrix: projectionMatrix,
                     inverseModelMatrix: cube1ModelMatrix.inverse,
                     lightSpaceMatrix: lightSpaceMatrix,
                     texCoordScale: 1.0),
            Uniforms(modelMatrix: cube2ModelMatrix,
                     viewMatrix: camera.getViewMatrix(),
                     projectionMatrix: projectionMatrix,
                     inverseModelMatrix: cube2ModelMatrix.inverse,
                     lightSpaceMatrix: lightSpaceMatrix,
                     texCoordScale: 1.0),
            Uniforms(modelMatrix: cube3ModelMatrix,
                     viewMatrix: camera.getViewMatrix(),
                     projectionMatrix: projectionMatrix,
                     inverseModelMatrix: cube3ModelMatrix.inverse,
                     lightSpaceMatrix: lightSpaceMatrix,
                     texCoordScale: 1.0)
        ]
        
        cubeLightSpaceUniforms = [
            LightSpaceUniforms(lightSpaceMatrix: lightSpaceMatrix, modelMatrix: cube1ModelMatrix),
            LightSpaceUniforms(lightSpaceMatrix: lightSpaceMatrix, modelMatrix: cube2ModelMatrix),
            LightSpaceUniforms(lightSpaceMatrix: lightSpaceMatrix, modelMatrix: cube3ModelMatrix),
        ]
        
        depthTexture = buildDepthTexture(width: Int(width),
                                         height: Int(height),
                                         depthFormat: metalView.depthStencilPixelFormat)
    }
    
    func handleCameraEvent(deltaX: Float, deltaY: Float) -> Void {
        camera.handleMouseScrollDeltaX(deltaX, deltaY: deltaY)
        
        uniform.viewMatrix = camera.getViewMatrix()
        cameraPos = camera.getPosition()
        let viewPosPtr = viewPosBuffer.contents()
        withUnsafePointer(to: cameraPos) {
            viewPosPtr.copyMemory(from: $0, byteCount: MemoryLayout<vector_float3>.stride)
        }
        
        for i in 0..<cubeUniforms.count {
            cubeUniforms[i].viewMatrix = camera.getViewMatrix()
        }
    }
    
    func buildDepthTexture(width: Int, height: Int, depthFormat: MTLPixelFormat) -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2D
        descriptor.pixelFormat = depthFormat
        descriptor.width = width
        descriptor.height = height
        descriptor.mipmapLevelCount = 1
        descriptor.usage = MTLTextureUsage(rawValue: MTLTextureUsage.shaderRead.rawValue | MTLTextureUsage.renderTarget.rawValue)
        descriptor.storageMode = .private
        
        let depthTexture = device.makeTexture(descriptor: descriptor)!
        depthTexture.label = "Depth Texture"
        return depthTexture
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
        depthTexture = buildDepthTexture(width: Int(size.width),
                                         height: Int(size.height),
                                         depthFormat: view.depthStencilPixelFormat)
        
        for i in 0..<cubeUniforms.count {
            cubeUniforms[i].projectionMatrix = uniform.projectionMatrix
        }
        
//        let lightProjection = matrix_perspective_left_hand(PI/4.0, Float(size.width)/Float(size.height), 0.1, 100.0)
//        let lightView = matrix_look_at_left_hand(lightPosition,
//                                                 vector_float3(0.0, 0.0, 0.0),
//                                                 vector_float3(0.0, 1.0, 0.0))
//
//        let lightSpaceMatrix = lightProjection * lightView
//
//        lightSpaceUniform.lightSpaceMatrix = lightSpaceMatrix
//        uniform.lightSpaceMatrix = lightSpaceMatrix
//
//        for i in 0..<cubeLightSpaceUniforms.count {
//            cubeLightSpaceUniforms[i].lightSpaceMatrix = lightSpaceMatrix
//        }
//
//        for i in 0..<cubeUniforms.count {
//            cubeUniforms[i].lightSpaceMatrix = lightSpaceMatrix
//        }
    }
    
    func draw(in view: MTKView) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        // draw depth map
        let depthRenderPassDescriptor = MTLRenderPassDescriptor()
        depthRenderPassDescriptor.colorAttachments[0].texture = nil
        depthRenderPassDescriptor.colorAttachments[0].loadAction = .clear
        depthRenderPassDescriptor.colorAttachments[0].storeAction = .store
        depthRenderPassDescriptor.depthAttachment.texture = depthTexture
        depthRenderPassDescriptor.depthAttachment.loadAction = .clear
        depthRenderPassDescriptor.depthAttachment.storeAction = .store
        depthRenderPassDescriptor.depthAttachment.clearDepth = 1.0
    
        let depthRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: depthRenderPassDescriptor)!
        depthRenderEncoder.setViewport(viewPort)
        depthRenderEncoder.setRenderPipelineState(depthMapPipelineState)
        depthRenderEncoder.setDepthStencilState(depthState)
        // ignore planet draw when render depth map
//        depthRenderEncoder.setVertexMesh(planeMesh, index: Int(DepthVertexIndexPosition.rawValue))
//        depthRenderEncoder.setVertexBytes(&lightSpaceUniform,
//                                          length: MemoryLayout<LightSpaceUniforms>.stride,
//                                          index: Int(DepthVertexIndexUniform.rawValue))
//        depthRenderEncoder.drawMesh(planeMesh)
        
        // draw cubes
        depthRenderEncoder.setVertexMesh(cubeMesh, index: Int(DepthVertexIndexPosition.rawValue))
        for uniform in cubeLightSpaceUniforms {
            withUnsafePointer(to: uniform) {
                depthRenderEncoder.setVertexBytes($0,
                                                  length: MemoryLayout<LightSpaceUniforms>.stride,
                                                  index: Int(DepthVertexIndexUniform.rawValue))
            }
            depthRenderEncoder.drawMesh(cubeMesh)
        }
        depthRenderEncoder.endEncoding()
        
        // draw with shadows
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = view.multisampleColorTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .multisampleResolve
        renderPassDescriptor.colorAttachments[0].resolveTexture = view.currentDrawable!.texture
        renderPassDescriptor.depthAttachment.texture = view.depthStencilTexture
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.storeAction = .dontCare
        renderPassDescriptor.depthAttachment.clearDepth = 1.0
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.label = "render encoder"
        renderEncoder.setViewport(viewPort)
        renderEncoder.setRenderPipelineState(renderPipelineState)

        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.useResource(viewPosBuffer, usage: .read)
        renderEncoder.setVertexMesh(planeMesh, index: Int(VertexInputIndexPosition.rawValue))
        renderEncoder.setVertexBytes(&uniform,
                                     length: MemoryLayout<Uniforms>.stride,
                                     index: Int(VertexInputIndexUniform.rawValue))
        renderEncoder.setFragmentBuffer(argumentBuffer,
                                        offset: 0,
                                        index: Int(FragmentInputIndexArgumentBuffer.rawValue))
        try! renderEncoder.setFragmentTexture(wood, index: Int(FragmentInputIndexTexture.rawValue))
        renderEncoder.setFragmentTexture(depthTexture, index: Int(FragmentInputIndexDepthMap.rawValue))

        renderEncoder.drawMesh(planeMesh)
        
        // draw cubes
        renderEncoder.setVertexMesh(cubeMesh, index: Int(VertexInputIndexPosition.rawValue))
        for cubeUniform in cubeUniforms {
            withUnsafePointer(to: cubeUniform) {
                renderEncoder.setVertexBytes($0,
                                             length: MemoryLayout<Uniforms>.stride,
                                             index: Int(VertexInputIndexUniform.rawValue))
            }
            
            renderEncoder.drawMesh(cubeMesh)
        }
        
        renderEncoder.endEncoding()
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
}
