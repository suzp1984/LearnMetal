//
//  Renderer.swift
//  Asteroids
//
//  Created by Jacob Su on 3/28/21.
//

import Foundation
import MetalKit
import common
import ModelIO

class Renderer: NSObject {
    
    private var device: MTLDevice!
    private var camera: Camera!
    private var depthStencilState: MTLDepthStencilState!
    private var renderPipelineState: MTLRenderPipelineState!
    private var rockPipelineState: MTLRenderPipelineState!
    private var planetMesh: MetalMesh!
    private var rockMesh: MetalMesh!
    private var rockModelsBuffer: MTLBuffer!
    private var commandQueue: MTLCommandQueue!
    private var viewPort: MTLViewport!
    private var uniforms: Uniforms!
    private var rockUniform: RockUniforms!
    private let rocksAmount: Int = 10000
    
    init(metalView: MTKView) {
        super.init()
        
        camera = CameraFactory.generateRoundOrbitCamera(withPosition: vector_float3(0.0, 0.0, 155.0),
                                                        target: vector_float3(0.0, 0.0, 0.0),
                                                        up: vector_float3(0.0, 1.0, 0.0))
        
        device = metalView.device!

        metalView.delegate = self
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.clearDepth = 1.0
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        
        depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)!
        
        let mtlVertexDescriptor = MTLVertexDescriptor()
        // position
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].format = .float3
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].offset = 0
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].bufferIndex = Int(ModelVertexInputIndexPosition.rawValue);
        
        // texture coordinate
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeTexcoord.rawValue)].format = .float2
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeTexcoord.rawValue)].offset = 16
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeTexcoord.rawValue)].bufferIndex = Int(ModelVertexInputIndexPosition.rawValue)
        
        // normal
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeNormal.rawValue)].format = .float3
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeNormal.rawValue)].offset = 32
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeNormal.rawValue)].bufferIndex = Int(ModelVertexInputIndexPosition.rawValue)
        
        // layout
        mtlVertexDescriptor.layouts[Int(ModelVertexInputIndexPosition.rawValue)].stride = 48
        mtlVertexDescriptor.layouts[Int(ModelVertexInputIndexPosition.rawValue)].stepRate = 1
        mtlVertexDescriptor.layouts[Int(ModelVertexInputIndexPosition.rawValue)].stepFunction = .perVertex

        let planetUrl = Bundle.common.url(forResource: "planet.obj", withExtension: nil, subdirectory: "planet")!

        planetMesh = try! MetalMesh(withUrl: planetUrl,
                               device: device,
                               mtlVertexDescriptor: mtlVertexDescriptor,
                               attributeMap: [
                                Int(ModelVertexAttributePosition.rawValue) : MDLVertexAttributePosition,
                                Int(ModelVertexAttributeTexcoord.rawValue) : MDLVertexAttributeTextureCoordinate,
                                Int(ModelVertexAttributeNormal.rawValue)   : MDLVertexAttributeNormal
                               ])
        
        let rockUrl = Bundle.common.url(forResource: "rock.obj", withExtension: nil, subdirectory: "rock")!
        rockMesh = try! MetalMesh(withUrl: rockUrl,
                                  device: device,
                                  mtlVertexDescriptor: mtlVertexDescriptor,
                                  attributeMap: [
                                    Int(ModelVertexAttributePosition.rawValue) : MDLVertexAttributePosition,
                                    Int(ModelVertexAttributeTexcoord.rawValue) : MDLVertexAttributeTextureCoordinate,
                                    Int(ModelVertexAttributeNormal.rawValue)   : MDLVertexAttributeNormal])
        
        let library = device.makeDefaultLibrary()!
        let vertexFunc = library.makeFunction(name: "vertexShader")!
        let fragmentFunc = library.makeFunction(name: "fragmentShader")!
        let rockVertexFunc = library.makeFunction(name: "rockVertexShader")!
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.label = "model"
        renderPipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        renderPipelineDescriptor.vertexFunction = vertexFunc
        renderPipelineDescriptor.fragmentFunction = fragmentFunc
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = metalView.depthStencilPixelFormat
        
        renderPipelineState = try! device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        
        let rockRenderPipelineDescriptor = MTLRenderPipelineDescriptor()
        rockRenderPipelineDescriptor.label = "model"
        rockRenderPipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        rockRenderPipelineDescriptor.vertexFunction = rockVertexFunc
        rockRenderPipelineDescriptor.fragmentFunction = fragmentFunc
        rockRenderPipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        rockRenderPipelineDescriptor.depthAttachmentPixelFormat = metalView.depthStencilPixelFormat
        
        rockPipelineState = try! device.makeRenderPipelineState(descriptor: rockRenderPipelineDescriptor)
    
        commandQueue = device.makeCommandQueue()!
        
        viewPort = MTLViewport(originX: 0.0, originY: 0.0,
                               width: Double(metalView.frame.width),
                               height: Double(metalView.frame.height),
                               znear: 0.0, zfar: 1.0)
        
        let width : Float = Float(metalView.frame.width)
        let height: Float = Float(metalView.frame.height)
        
        uniforms = Uniforms(modelMatrix: matrix_multiply(matrix4x4_translation(0.0, -3.0, 0.0),
                                                         matrix4x4_scale(4.0, 4.0, 4.0)),
                            viewMatrix: camera.getViewMatrix(),
                            projectionMatrix: matrix_perspective_left_hand(Float.pi / 4.0, width / height, 0.1, 1000.0))
        rockUniform = RockUniforms(viewMatrix: camera.getViewMatrix(),
                                   projectionMatrix: matrix_perspective_left_hand(Float.pi / 4.0, width / height, 0.1, 1000.0))
        fillModelsBuffer()
    }
    
    func handleCameraEvent(deltaX: Float, deltaY: Float) -> Void {
        camera.rotateCameraAroundTarget(withDeltaPhi: deltaX * 0.2, deltaTheta: deltaY * 0.2)
        
        uniforms.viewMatrix = camera.getViewMatrix()
        rockUniform.viewMatrix = camera.getViewMatrix()
    }
    
    private func fillModelsBuffer() {
        var models : [RockModel] = [RockModel]()
        let radius : Float = 150.0
        let offset : Float = 25.0
        for i in 0..<rocksAmount {
            let angle = Float(i) / Float(rocksAmount) * 360.0
            var displacement = Float(Int.random(in: 0..<(2 * Int(offset) * 100))) / 100.0 - offset
            let x = sin(angle) * radius + displacement
            displacement = Float(Int.random(in: 0..<(2 * Int(offset) * 100))) / 100.0 - offset
            let y = displacement * 0.4
            displacement = Float(Int.random(in: 0..<(2 * Int(offset) * 100))) / 100.0 - offset
            let z = cos(angle) * radius + displacement
            
            let scale = Float(Int.random(in: 0..<40)) / 100.0 + 0.05
            let rotAngle = Float(Int.random(in: 0..<360)) / 360.0 * 2.0 * Float.pi
            
            let model = matrix_multiply(matrix4x4_translation(x, y, z),
                                        matrix_multiply(matrix4x4_scale(scale, scale, scale),
                                                        matrix4x4_rotation(rotAngle, vector_float3(0.4, 0.6, 0.8))))
            models.append(RockModel(modelMatrix: model))
        }
        
        let tmpBuffer = device.makeBuffer(bytes: models,
                                             length: MemoryLayout<RockModel>.stride * models.count,
                                             options: .storageModeShared)!
        rockModelsBuffer = device.makeBuffer(length: tmpBuffer.length, options: .storageModePrivate)!
        
        rockModelsBuffer.label = "Rocks Models"
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        blitEncoder.copy(from: tmpBuffer, sourceOffset: 0, to: rockModelsBuffer, destinationOffset: 0, size: tmpBuffer.length)
        blitEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}

extension Renderer : MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewPort.width = Double(size.width)
        viewPort.height = Double(size.height)
        
        uniforms.projectionMatrix =
            matrix_perspective_left_hand(Float.pi / 4.0,
                                         Float(size.width) / Float(size.height),
                                         0.1,
                                         1000.0)
        rockUniform.projectionMatrix = uniforms.projectionMatrix
    }
    
    func draw(in view: MTKView) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        let renderDescriptor = view.currentRenderPassDescriptor!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderDescriptor)!
        
        renderEncoder.setViewport(viewPort)
        // draw planet
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        
        renderEncoder.setVertexMesh(planetMesh, index: Int(ModelVertexInputIndexPosition.rawValue))
        
        renderEncoder.setVertexBytes(&uniforms,
                                     length: MemoryLayout<Uniforms>.stride,
                                     index: Int(ModelVertexInputIndexUniforms.rawValue))
        renderEncoder.drawMesh(planetMesh, textureHandler: { (type, texture, _) -> Void in
            if type == .baseColor {
                renderEncoder.setFragmentTexture(texture, index: Int(FragmentInputIndexDiffuseTexture.rawValue))
            }
        })
        
        // draw rocks
        renderEncoder.setRenderPipelineState(rockPipelineState)

        renderEncoder.setVertexMesh(rockMesh, index: Int(ModelVertexInputIndexPosition.rawValue))
        renderEncoder.setVertexBytes(&rockUniform, length: MemoryLayout<RockUniforms>.stride, index: Int(ModelVertexInputIndexUniforms.rawValue))
        renderEncoder.setVertexBuffer(rockModelsBuffer, offset: 0, index: Int(ModelVertexInputIndexModels.rawValue))

        renderEncoder.drawMesh(rockMesh, instanceCount: rocksAmount, textureHandler: { (type, texture, _) ->
            Void in
            if type == .baseColor {
                renderEncoder.setFragmentTexture(texture, index: Int(FragmentInputIndexDiffuseTexture.rawValue))
            }
        })

        renderEncoder.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}
