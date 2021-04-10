//
//  Renderer.swift
//  DeferredShading
//
//  Created by Jacob Su on 4/10/21.
//

import Foundation
import MetalKit
import common

class Renderer: NSObject {
    
    private var device: MTLDevice!
    private var backPackMesh: MetalMesh!
    private var camera: Camera!
    private var uniforms: Uniforms!
    private var depthState: MTLDepthStencilState!
    private var gBufferPipelineState: MTLRenderPipelineState!
    private var deferredPipelineState: MTLRenderPipelineState!
    private var lightBoxPipelineState: MTLRenderPipelineState!
    private var commandQueue: MTLCommandQueue!
    private var viewPort: MTLViewport!
    private var gPositionTexture : MTLTexture!
    private var gNormalTexture: MTLTexture!
    private var gAlbedoTexture: MTLTexture!
    private var depthTexture: MTLTexture!
    private var modelsMatrixes: [matrix_float4x4] = []
    private var normalsMatrixes: [matrix_float3x3] = []
    private var lights: [Light] = []
    private var quadVertexBuffer: MTLBuffer!
    private var lightsBuffer: MTLBuffer!
    private var cubeMesh: MTKMesh!
    private var lightCubeModelMatrixes: [matrix_float4x4] = []
    private var lightCubeUniforms: LightCubeUniforms!
    
    init(metalView: MTKView) {
        super.init()
        
        device = metalView.device!
        metalView.delegate = self
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.clearDepth = 1.0
        
        camera = CameraFactory.generateRoundOrbitCamera(withPosition: vector_float3(0.0, 0.0, 8.0),
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

        let backPackUrl = Bundle.common.url(forResource: "backpack.obj", withExtension: nil, subdirectory: "backpack")!

        backPackMesh = try! MetalMesh(withUrl: backPackUrl,
                               device: device,
                               mtlVertexDescriptor: mtlVertexDescriptor,
                               attributeMap: [
                                Int(ModelVertexAttributePosition.rawValue) : MDLVertexAttributePosition,
                                Int(ModelVertexAttributeTexcoord.rawValue) : MDLVertexAttributeTextureCoordinate,
                                Int(ModelVertexAttributeNormal.rawValue)   : MDLVertexAttributeNormal
                               ])
        
        cubeMesh = try! MTKMesh.newBox(withVertexDescriptor: mtlVertexDescriptor,
                                  withAttributesMap: [
                                    Int(ModelVertexAttributePosition.rawValue) : MDLVertexAttributePosition,
                                    Int(ModelVertexAttributeTexcoord.rawValue) : MDLVertexAttributeTextureCoordinate,
                                    Int(ModelVertexAttributeNormal.rawValue)   : MDLVertexAttributeNormal
                                  ],
                                  withDevice: device,
                                  withDimensions: vector_float3(2.0, 2.0, 2.0))
        
        
        let width = metalView.frame.width
        let height = metalView.frame.height
        
        let modelMatrix = matrix4x4_identity()
        let projectionMatrix = matrix_perspective_left_hand(Float.pi / 4.0, Float(width)/Float(height), 0.1, 100.0)
        uniforms = Uniforms(modelMatrix: modelMatrix,
                            viewMatrix: camera.getViewMatrix(),
                            projectionMatrix: projectionMatrix,
                            normalMatrix: matrix3x3_upper_left(modelMatrix).inverse.transpose)
        
        lightCubeUniforms = LightCubeUniforms(modelMatrix: matrix4x4_identity(),
                                              viewMatrix: camera.getViewMatrix(),
                                              projectionMatrix: projectionMatrix)
        
        viewPort = MTLViewport(originX: 0.0,
                               originY: 0.0,
                               width: Double(width),
                               height: Double(height),
                               znear: 0.0,
                               zfar: 1.0)
        gPositionTexture = createColorTexture(width: Int(width), height: Int(height), label: "gPosition")
        gNormalTexture   = createColorTexture(width: Int(width), height: Int(height), label: "gNormal")
        gAlbedoTexture   = createColorTexture(width: Int(width), height: Int(height), label: "gAlbedo")
        depthTexture = createDepthTexture(width: Int(width), height: Int(height))
        
        let library = device.makeDefaultLibrary()!
        let gBufferVertexFunc = library.makeFunction(name: "gBufferVertexShader")!
        let gBufferFragmentFunc = library.makeFunction(name: "gBufferFragmentShader")!
        
        let gBufferPipelineDescriptor = MTLRenderPipelineDescriptor()
        gBufferPipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        gBufferPipelineDescriptor.vertexFunction = gBufferVertexFunc
        gBufferPipelineDescriptor.fragmentFunction = gBufferFragmentFunc
        gBufferPipelineDescriptor.colorAttachments[0].pixelFormat = gPositionTexture.pixelFormat
        gBufferPipelineDescriptor.colorAttachments[1].pixelFormat = gNormalTexture.pixelFormat
        gBufferPipelineDescriptor.colorAttachments[2].pixelFormat = gAlbedoTexture.pixelFormat
        gBufferPipelineDescriptor.depthAttachmentPixelFormat = depthTexture.pixelFormat
        
        gBufferPipelineState = try! device.makeRenderPipelineState(descriptor: gBufferPipelineDescriptor)
        
        let deferredVertexFunc = library.makeFunction(name: "deferredVertexShader")!
        let deferredFragmentFunc = library.makeFunction(name: "deferredFragmentShader")!
        
        let deferredPipelineDescriptor = MTLRenderPipelineDescriptor()
        deferredPipelineDescriptor.vertexFunction = deferredVertexFunc
        deferredPipelineDescriptor.fragmentFunction = deferredFragmentFunc
        deferredPipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        
        deferredPipelineState = try! device.makeRenderPipelineState(descriptor: deferredPipelineDescriptor)
        
        let lightBoxVertexFunc = library.makeFunction(name: "lightBoxVertexShader")!
        let lightBoxFragmentFunc = library.makeFunction(name: "lightBoxFragmentShader")!
        
        let lightBoxPipelineDescriptor = MTLRenderPipelineDescriptor()
        lightBoxPipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        lightBoxPipelineDescriptor.vertexFunction = lightBoxVertexFunc
        lightBoxPipelineDescriptor.fragmentFunction = lightBoxFragmentFunc
        lightBoxPipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        lightBoxPipelineDescriptor.depthAttachmentPixelFormat = depthTexture.pixelFormat
        
        lightBoxPipelineState = try! device.makeRenderPipelineState(descriptor: lightBoxPipelineDescriptor)
        
        commandQueue = device.makeCommandQueue()!
        
        // prepare model matrixes
        let objectPositions = [
            vector_float3(-3.0, -0.5, -3.0),
            vector_float3( 0.0, -0.5, -3.0),
            vector_float3( 3.0, -0.5, -3.0),
            vector_float3(-3.0, -0.5,  0.0),
            vector_float3( 0.0, -0.5,  0.0),
            vector_float3( 3.0, -0.5,  0.0),
            vector_float3(-3.0, -0.5,  3.0),
            vector_float3( 0.0, -0.5,  3.0),
            vector_float3( 3.0, -0.5,  3.0),
        ]
        
        objectPositions.forEach {
            let matrix = matrix_multiply(matrix4x4_translation($0),
                                         matrix4x4_scale(0.5, 0.5, 0.5))
            modelsMatrixes.append(matrix)
            normalsMatrixes.append(matrix3x3_upper_left(matrix).inverse.transpose)
        }
        
        for _ in 0..<32 {
            let xPos = Float.random(in: 0.0..<1.0) * 6.0 - 3.0
            let yPos = Float.random(in: 0.0..<1.0) * 6.0 - 4.0
            let zPos = Float.random(in: 0.0..<1.0) * 6.0 - 3.0
            
            let rColor = Float.random(in: 0.5..<1.0)
            let gColor = Float.random(in: 0.5..<1.0)
            let bColor = Float.random(in: 0.5..<1.0)

            let light = Light(position: vector_float3(xPos, yPos, zPos),
                              color: vector_float3(rColor, gColor, bColor),
                              linear: 0.7,
                              quadratic: 1.8)
            
            lights.append(light)
        }
        
        lightsBuffer = device.makeBuffer(bytes: lights,
                                         length: MemoryLayout<Light>.stride * lights.count,
                                         options: .storageModeShared)
        let quadVertices = [
            QuadVertex(position: vector_float2(-1.0,  1.0), texCoords: vector_float2(0.0, 0.0)),
            QuadVertex(position: vector_float2(-1.0, -1.0), texCoords: vector_float2(0.0, 1.0)),
            QuadVertex(position: vector_float2( 1.0,  1.0), texCoords: vector_float2(1.0, 0.0)),
            QuadVertex(position: vector_float2( 1.0, -1.0), texCoords: vector_float2(1.0, 1.0)),
        ]
        
        quadVertexBuffer = device.makeBuffer(bytes: quadVertices,
                                             length: MemoryLayout<QuadVertex>.stride * quadVertices.count,
                                             options: .storageModeShared)
        for light in lights {
            lightCubeModelMatrixes.append(matrix_multiply(matrix4x4_translation(light.position),
                                                          matrix4x4_scale(0.125, 0.125, 0.125)))
        }
    }
    
    func handleCameraEvent(deltaX: Float, deltaY: Float) -> Void {
        camera.rotateCameraAroundTarget(withDeltaPhi: deltaX * 0.2, deltaTheta: deltaY * 0.2)
        
        uniforms.viewMatrix = camera.getViewMatrix()
        lightCubeUniforms.viewMatrix = camera.getViewMatrix()
    }
    
    private func createColorTexture(width: Int, height: Int, label: String? = nil) -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.width = width
        textureDescriptor.height = height
        textureDescriptor.pixelFormat = .rgba16Float
        textureDescriptor.usage = MTLTextureUsage(rawValue: MTLTextureUsage.renderTarget.rawValue | MTLTextureUsage.shaderRead.rawValue)
        textureDescriptor.textureType = .type2D
        textureDescriptor.storageMode = .private
        
        let texture = device.makeTexture(descriptor: textureDescriptor)!
        if label != nil {
            texture.label = label
        }
        
        return texture
    }
    
    private func createDepthTexture(width: Int, height: Int) -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.width = width
        textureDescriptor.height = height
        textureDescriptor.pixelFormat = .depth32Float
        textureDescriptor.usage = MTLTextureUsage(rawValue: MTLTextureUsage.renderTarget.rawValue | MTLTextureUsage.shaderRead.rawValue)
        textureDescriptor.textureType = .type2D
        textureDescriptor.storageMode = .private
        
        let texture = device.makeTexture(descriptor: textureDescriptor)!
        texture.label = "depth"
        
        return texture
    }
    
    private func buildNormalMatrix() {
        uniforms.normalMatrix = matrix3x3_upper_left(uniforms.modelMatrix).inverse.transpose
    }
}

extension Renderer : MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        uniforms.projectionMatrix = matrix_perspective_left_hand(Float.pi / 4.0, Float(size.width)/Float(size.height), 0.1, 100.0)
        lightCubeUniforms.projectionMatrix = uniforms.projectionMatrix
        viewPort.width = Double(size.width)
        viewPort.height = Double(size.height)
        
        gPositionTexture = createColorTexture(width: Int(size.width), height: Int(size.height), label: "gPosition")
        gNormalTexture   = createColorTexture(width: Int(size.width), height: Int(size.height), label: "gNormal")
        gAlbedoTexture   = createColorTexture(width: Int(size.width), height: Int(size.height), label: "gAlbedo")
        depthTexture = createDepthTexture(width: Int(size.width), height: Int(size.height))
    }
    
    func draw(in view: MTKView) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        // gbuffer render
        let gBufferRenderPassDescriptor = MTLRenderPassDescriptor()
        gBufferRenderPassDescriptor.colorAttachments[0].texture = gPositionTexture
        gBufferRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0)
        gBufferRenderPassDescriptor.colorAttachments[0].loadAction = .clear
        gBufferRenderPassDescriptor.colorAttachments[0].storeAction = .store
        
        gBufferRenderPassDescriptor.colorAttachments[1].texture = gNormalTexture
        gBufferRenderPassDescriptor.colorAttachments[1].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0)
        gBufferRenderPassDescriptor.colorAttachments[1].loadAction = .clear
        gBufferRenderPassDescriptor.colorAttachments[1].storeAction = .store
        
        gBufferRenderPassDescriptor.colorAttachments[2].texture = gAlbedoTexture
        gBufferRenderPassDescriptor.colorAttachments[2].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0)
        gBufferRenderPassDescriptor.colorAttachments[2].loadAction = .clear
        gBufferRenderPassDescriptor.colorAttachments[2].storeAction = .store
        
        gBufferRenderPassDescriptor.depthAttachment.texture = depthTexture
        gBufferRenderPassDescriptor.depthAttachment.loadAction = .clear
        gBufferRenderPassDescriptor.depthAttachment.storeAction = .store
        gBufferRenderPassDescriptor.depthAttachment.clearDepth = 1.0
        
        let gBufferRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: gBufferRenderPassDescriptor)!
        gBufferRenderEncoder.setViewport(viewPort)
        gBufferRenderEncoder.setRenderPipelineState(gBufferPipelineState)
        gBufferRenderEncoder.setDepthStencilState(depthState)
        
        gBufferRenderEncoder.setVertexMesh(backPackMesh, index: Int(VertexInputIndexPosition.rawValue))
        
        for i in 0..<modelsMatrixes.count {
            uniforms.modelMatrix = modelsMatrixes[i]
            uniforms.normalMatrix = normalsMatrixes[i]
            
            gBufferRenderEncoder.setVertexBytes(&uniforms,
                                                length: MemoryLayout<Uniforms>.stride,
                                                index: Int(VertexInputIndexUniforms.rawValue))
            
            gBufferRenderEncoder.drawMesh(backPackMesh) { type, texture, _ in
                if type == .baseColor {
                    gBufferRenderEncoder.setFragmentTexture(texture, index: Int(FragmentInputIndexDiffuse.rawValue))
                }
                
                if type == .specular {
                    gBufferRenderEncoder.setFragmentTexture(texture, index: Int(FragmentInputIndexSpecular.rawValue))
                }
            }
        }
        
        gBufferRenderEncoder.endEncoding()
        
        // deferred render
        let deferredRenderPassDescriptor = MTLRenderPassDescriptor()
        deferredRenderPassDescriptor.colorAttachments[0].texture = view.currentDrawable!.texture
        deferredRenderPassDescriptor.colorAttachments[0].loadAction = .clear
        deferredRenderPassDescriptor.colorAttachments[0].storeAction = .store
        
        let deferredRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: deferredRenderPassDescriptor)!
        deferredRenderEncoder.setViewport(viewPort)
        deferredRenderEncoder.setRenderPipelineState(deferredPipelineState)
        
        deferredRenderEncoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)
        deferredRenderEncoder.setFragmentTexture(gPositionTexture, index: Int(DeferredFragmentIndexGPositionTexture.rawValue))
        deferredRenderEncoder.setFragmentTexture(gNormalTexture, index: Int(DeferredFragmentIndexGNormalTexture.rawValue))
        deferredRenderEncoder.setFragmentTexture(gAlbedoTexture, index: Int(DeferredFragmentIndexGAlbedoTexture.rawValue))
        deferredRenderEncoder.setFragmentBuffer(lightsBuffer, offset: 0, index: Int(DeferredFragmentIndexLights.rawValue))
        withUnsafePointer(to: lights.count) {
            deferredRenderEncoder.setFragmentBytes($0, length: MemoryLayout<Int>.stride,
                                                   index: Int(DeferredFragmentIndexLightsCount.rawValue))
        }
        withUnsafePointer(to: camera.cameraPosition) {
            deferredRenderEncoder.setFragmentBytes($0,
                                                   length: MemoryLayout<vector_float3>.stride,
                                                   index: Int(DeferredFragmentIndexViewPosition.rawValue))
        }
        deferredRenderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        deferredRenderEncoder.endEncoding()
        
        // draw lightbox
        let lightBoxRenderPassDescriptor = MTLRenderPassDescriptor()
        lightBoxRenderPassDescriptor.colorAttachments[0].texture = view.currentDrawable!.texture
        lightBoxRenderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        lightBoxRenderPassDescriptor.colorAttachments[0].storeAction = .store
        lightBoxRenderPassDescriptor.depthAttachment.texture = depthTexture
        lightBoxRenderPassDescriptor.depthAttachment.loadAction = .dontCare
        lightBoxRenderPassDescriptor.depthAttachment.storeAction = .dontCare
        
        let lightBoxRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: lightBoxRenderPassDescriptor)!
        lightBoxRenderEncoder.setViewport(viewPort)
        lightBoxRenderEncoder.setRenderPipelineState(lightBoxPipelineState)
        lightBoxRenderEncoder.setDepthStencilState(depthState)
        
        lightBoxRenderEncoder.setVertexMesh(cubeMesh, index: 0)
        for i in 0..<lights.count {
            lightCubeUniforms.modelMatrix = lightCubeModelMatrixes[i];
            lightBoxRenderEncoder.setVertexBytes(&lightCubeUniforms,
                                                 length: MemoryLayout<LightCubeUniforms>.stride,
                                                 index: 1)
            withUnsafePointer(to: lights[i].color) {
                lightBoxRenderEncoder.setFragmentBytes($0, length: MemoryLayout<vector_float3>.stride, index: 0)
            }
            
            lightBoxRenderEncoder.drawMesh(cubeMesh)
        }
        
        lightBoxRenderEncoder.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    
}
