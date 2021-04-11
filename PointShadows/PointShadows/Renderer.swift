//
//  Renderer.swift
//  PointShadows
//
//  Created by Jacob Su on 4/4/21.
//

import Foundation
import MetalKit
import common

class Renderer: NSObject {
    
    private var device: MTLDevice!
    private var camera: Camera!
    private var depthState: MTLDepthStencilState!
    private var colorRenderPipelineState: MTLRenderPipelineState!
    private var depthMapPipelineState: MTLRenderPipelineState!
    private var cubeMesh: MTKMesh!
    private var wood: Texture!
    private var lightPos: vector_float3!
    private var commandQueue: MTLCommandQueue!
    private var cubeMapDepthTexture: MTLTexture!
    private let PI: Float = Float.pi
    private var instanceParamsBuffer: MTLBuffer!
    private var containerModelUniform: ModelUniform!
    private var cubesModelUniforms: [ModelUniform]!
    private var cubesUniforms: [Uniforms]!
    private let cubeMapSize: Float = 1024
    private var depthViewPort: MTLViewport!
    private var viewPort: MTLViewport!
    private let farPlane: Float = 25.0
    private var date: Date!
    
    init(metalView: MTKView) {
        super.init()
        
        date = Date()
        device = metalView.device!
        metalView.delegate = self
        
        camera = CameraFactory.generateRoundOrbitCamera(withPosition: vector_float3(0.0, 0.0, 3.0),
                                                        target: vector_float3(0.0, 0.0, 0.0),
                                                        up: vector_float3(0.0, 1.0, 0.0))
        
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
                                  inwardNormals: false)
        
        wood = try! Texture.newTextureWithName("wood",
                                               scaleFactor: 1.0,
                                               device: device,
                                               options: [MTKTextureLoader.Option.SRGB: NSNumber.init(value: false)])
        
        let library = device.makeDefaultLibrary()!
        let depthVertexFunc = library.makeFunction(name: "depthVertexShader")!
        let depthFragmentFunc = library.makeFunction(name: "depthFragmentShader")!
        let renderVertexFunc = library.makeFunction(name: "shadowVertexShader")!
        let renderFragmentFunc = library.makeFunction(name: "shadowFragmentShader")!
        
        let depthPipelineDescriptor = MTLRenderPipelineDescriptor()
        depthPipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        depthPipelineDescriptor.vertexFunction = depthVertexFunc
        depthPipelineDescriptor.fragmentFunction = depthFragmentFunc
        depthPipelineDescriptor.inputPrimitiveTopology = .triangle
        depthPipelineDescriptor.sampleCount = 1
        depthPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        depthMapPipelineState = try! device.makeRenderPipelineState(descriptor: depthPipelineDescriptor)
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        renderPipelineDescriptor.vertexFunction = renderVertexFunc
        renderPipelineDescriptor.fragmentFunction = renderFragmentFunc
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        
        colorRenderPipelineState = try! device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        
        lightPos = vector_float3(0.0, 0.0, 0.0)
        commandQueue = device.makeCommandQueue()!
                
        let shadowProj = matrix_perspective_left_hand(PI / 2.0, 1.0, 1.0, 25.0)
        
        let instanceParams: [InstanceParams] = [
            InstanceParams(lightSpaceMatrix: shadowProj *
                            matrix_look_at_left_hand(lightPos,
                                                     lightPos + vector_float3(1.0, 0.0, 0.0),
                                                     vector_float3(0.0, -1.0, 0.0)),
                           layer: 0),
            InstanceParams(lightSpaceMatrix: shadowProj *
                            matrix_look_at_left_hand(lightPos,
                                                     lightPos + vector_float3(-1.0, 0.0, 0.0),
                                                     vector_float3(0.0, -1.0, 0.0)),
                           layer: 1),
            InstanceParams(lightSpaceMatrix: shadowProj *
                            matrix_look_at_left_hand(lightPos,
                                                     lightPos + vector_float3(0.0, 1.0, 0.0),
                                                     vector_float3(0.0, 0.0, 1.0)),
                           layer: 2),
            InstanceParams(lightSpaceMatrix: shadowProj *
                            matrix_look_at_left_hand(lightPos,
                                                     lightPos + vector_float3(0.0, -1.0, 0.0),
                                                     vector_float3(0.0, 0.0, -1.0)),
                           layer: 3),
            InstanceParams(lightSpaceMatrix: shadowProj *
                            matrix_look_at_left_hand(lightPos,
                                                     lightPos + vector_float3(0.0, 0.0, 1.0),
                                                     vector_float3(0.0, -1.0, 0.0)),
                           layer: 4),
            InstanceParams(lightSpaceMatrix: shadowProj *
                            matrix_look_at_left_hand(lightPos,
                                                     lightPos + vector_float3(0.0, 0.0, -1.0),
                                                     vector_float3(0.0, -1.0, 0.0)),
                           layer: 5),
        ]
        
        instanceParamsBuffer = device.makeBuffer(bytes: instanceParams,
                                                 length: MemoryLayout<InstanceParams>.stride * instanceParams.count,
                                                 options: .storageModeShared)!
        
        containerModelUniform = ModelUniform(modelMatrix: matrix4x4_scale(5.0, 5.0, 5.0))
        
        cubesModelUniforms = [
            ModelUniform(modelMatrix: matrix_multiply(matrix4x4_translation(4.0, -3.5, 0.0), matrix4x4_scale(0.5, 0.5, 0.5))),
            ModelUniform(modelMatrix: matrix_multiply(matrix4x4_translation(2.0,  3.0, 1.0), matrix4x4_scale(0.75, 0.75, 0.75))),
            ModelUniform(modelMatrix: matrix_multiply(matrix4x4_translation(-3.0, -1.0, 0.0), matrix4x4_scale(0.5, 0.5, 0.5))),
            ModelUniform(modelMatrix: matrix_multiply(matrix4x4_translation(-1.5, 1.0, 1.5), matrix4x4_scale(0.5, 0.5, 0.5))),
            ModelUniform(modelMatrix: matrix_multiply(matrix4x4_translation(-1.5, 2.0, -3.0),
                                                      matrix_multiply(matrix4x4_rotation(PI * 60.0 / 180.0, normalize(vector_float3(1.0, 0.0, 1.0))), matrix4x4_scale(0.75, 0.75, 0.75)))),
        ]
        
        let projectionMatrix = matrix_perspective_left_hand(PI / 4.0, Float(metalView.frame.width)/Float(metalView.frame.height), 0.1, 100.0)
        
        cubesUniforms = [
            Uniforms(modelMatrix: containerModelUniform.modelMatrix,
                     viewMatrix: camera.getViewMatrix(),
                     projectionMatrix: projectionMatrix,
                     inverseModelMatrix: containerModelUniform.modelMatrix.inverse,
                     isContainer: 1),
            Uniforms(modelMatrix: cubesModelUniforms[0].modelMatrix,
                     viewMatrix: camera.getViewMatrix(),
                     projectionMatrix: projectionMatrix,
                     inverseModelMatrix: cubesModelUniforms[0].modelMatrix.inverse,
                     isContainer: 0),
            Uniforms(modelMatrix: cubesModelUniforms[1].modelMatrix,
                     viewMatrix: camera.getViewMatrix(),
                     projectionMatrix: projectionMatrix,
                     inverseModelMatrix: cubesModelUniforms[1].modelMatrix.inverse,
                     isContainer: 0),
            Uniforms(modelMatrix: cubesModelUniforms[2].modelMatrix,
                     viewMatrix: camera.getViewMatrix(),
                     projectionMatrix: projectionMatrix,
                     inverseModelMatrix: cubesModelUniforms[2].modelMatrix.inverse,
                     isContainer: 0),
            Uniforms(modelMatrix: cubesModelUniforms[3].modelMatrix,
                     viewMatrix: camera.getViewMatrix(),
                     projectionMatrix: projectionMatrix,
                     inverseModelMatrix: cubesModelUniforms[3].modelMatrix.inverse,
                     isContainer: 0),
            Uniforms(modelMatrix: cubesModelUniforms[4].modelMatrix,
                     viewMatrix: camera.getViewMatrix(),
                     projectionMatrix: projectionMatrix,
                     inverseModelMatrix: cubesModelUniforms[4].modelMatrix.inverse,
                     isContainer: 0),
        ]
        
        
        let textureDescritpor = MTLTextureDescriptor.textureCubeDescriptor(pixelFormat: .depth32Float,
                                                                           size: Int(cubeMapSize),
                                                                           mipmapped: true)
        textureDescritpor.usage = [.renderTarget, .shaderRead]
        textureDescritpor.resourceOptions = .storageModePrivate
        
        cubeMapDepthTexture = device.makeTexture(descriptor: textureDescritpor)!
        
        depthViewPort = MTLViewport(originX: 0.0,
                                    originY: 0.0,
                                    width: Double(cubeMapSize),
                                    height: Double(cubeMapSize),
                                    znear: 0.0,
                                    zfar: 1.0);
        
        viewPort = MTLViewport(originX: 0.0,
                               originY: 0.0,
                               width: Double(metalView.frame.width),
                               height: Double(metalView.frame.height),
                               znear: 0.0,
                               zfar: 1.0);
    }
    
    func handleCameraEvent(deltaX: Float, deltaY: Float) -> Void {
        camera.rotateCameraAroundTarget(withDeltaPhi: deltaX, deltaTheta: deltaY)
        
        for i in 0..<cubesUniforms.count {
            cubesUniforms[i].viewMatrix = camera.getViewMatrix()
        }
    }
}

extension Renderer : MTKViewDelegate
{
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewPort.width = Double(size.width);
        viewPort.height = Double(size.height);
        
        let projectionMatrix = matrix_perspective_left_hand(PI / 4.0,
                                                            Float(size.width)/Float(size.height),
                                                            0.1,
                                                            100.0)
        
        for i in 0..<cubesUniforms.count {
            cubesUniforms[i].projectionMatrix = projectionMatrix
        }
        
    }
    
    func prepareData() {
        lightPos.z = Float(sin(date.timeIntervalSinceNow * 0.5)) * 3.0
        
        let shadowProj = matrix_perspective_left_hand(PI / 2.0, 1.0, 1.0, 25.0)
        
        let instanceParams: [InstanceParams] = [
            InstanceParams(lightSpaceMatrix: shadowProj *
                            matrix_look_at_left_hand(lightPos,
                                                     lightPos + vector_float3(1.0, 0.0, 0.0),
                                                     vector_float3(0.0, -1.0, 0.0)),
                           layer: 0),
            InstanceParams(lightSpaceMatrix: shadowProj *
                            matrix_look_at_left_hand(lightPos,
                                                     lightPos + vector_float3(-1.0, 0.0, 0.0),
                                                     vector_float3(0.0, -1.0, 0.0)),
                           layer: 1),
            InstanceParams(lightSpaceMatrix: shadowProj *
                            matrix_look_at_left_hand(lightPos,
                                                     lightPos + vector_float3(0.0, 1.0, 0.0),
                                                     vector_float3(0.0, 0.0, 1.0)),
                           layer: 2),
            InstanceParams(lightSpaceMatrix: shadowProj *
                            matrix_look_at_left_hand(lightPos,
                                                     lightPos + vector_float3(0.0, -1.0, 0.0),
                                                     vector_float3(0.0, 0.0, -1.0)),
                           layer: 3),
            InstanceParams(lightSpaceMatrix: shadowProj *
                            matrix_look_at_left_hand(lightPos,
                                                     lightPos + vector_float3(0.0, 0.0, 1.0),
                                                     vector_float3(0.0, -1.0, 0.0)),
                           layer: 4),
            InstanceParams(lightSpaceMatrix: shadowProj *
                            matrix_look_at_left_hand(lightPos,
                                                     lightPos + vector_float3(0.0, 0.0, -1.0),
                                                     vector_float3(0.0, -1.0, 0.0)),
                           layer: 5),
        ]
        
        let ptr = instanceParamsBuffer.contents()
        ptr.copyMemory(from: instanceParams, byteCount: MemoryLayout<InstanceParams>.stride * instanceParams.count)
    }
    
    func draw(in view: MTKView) {
        prepareData()
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        // draw depth map
        let depthRenderPassDescriptor = MTLRenderPassDescriptor()
        depthRenderPassDescriptor.colorAttachments[0].texture = nil
        depthRenderPassDescriptor.colorAttachments[0].loadAction = .clear
        depthRenderPassDescriptor.colorAttachments[0].storeAction = .store
        depthRenderPassDescriptor.depthAttachment.texture = cubeMapDepthTexture
        depthRenderPassDescriptor.renderTargetArrayLength = 6
        depthRenderPassDescriptor.depthAttachment.loadAction = .clear
        depthRenderPassDescriptor.depthAttachment.storeAction = .store
        depthRenderPassDescriptor.depthAttachment.clearDepth = 1.0

        let depthMapRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: depthRenderPassDescriptor)!
        depthMapRenderEncoder.setViewport(depthViewPort)
        depthMapRenderEncoder.setRenderPipelineState(depthMapPipelineState)
        depthMapRenderEncoder.setDepthStencilState(depthState)

        depthMapRenderEncoder.setVertexMesh(cubeMesh, index: Int(DepthVertexIndexPosition.rawValue))

        // draw container
        depthMapRenderEncoder.setVertexBytes(&containerModelUniform,
                                             length: MemoryLayout<ModelUniform>.stride,
                                             index: Int(DepthVertexIndexModelUniform.rawValue))
        depthMapRenderEncoder.setVertexBuffer(instanceParamsBuffer,
                                              offset: 0,
                                              index: Int(DepthVertexIndexInstanceParams.rawValue))
        depthMapRenderEncoder.setFragmentBytes(&lightPos, length: MemoryLayout<vector_float3>.stride, index: Int(DepthFragmentIndexLightPos.rawValue))
        withUnsafePointer(to: farPlane) {
            depthMapRenderEncoder.setFragmentBytes($0, length: MemoryLayout<Float>.stride, index: Int(DepthFragmentIndexFarPlane.rawValue))
        }
//        depthMapRenderEncoder.drawMesh(cubeMesh, instanceCount: 6)

        // draw cubes
        for uniform in cubesModelUniforms {
            withUnsafePointer(to: uniform) {
                depthMapRenderEncoder.setVertexBytes($0,
                                                     length: MemoryLayout<ModelUniform>.stride,
                                                     index: Int(DepthVertexIndexModelUniform.rawValue))
                depthMapRenderEncoder.drawMesh(cubeMesh, instanceCount: 6)
            }
        }
        depthMapRenderEncoder.endEncoding()
        
        // draw color buffer
        let colorRenderPassDescriptor = view.currentRenderPassDescriptor!
    
        let colorRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: colorRenderPassDescriptor)!
        colorRenderEncoder.setViewport(viewPort)
        colorRenderEncoder.setRenderPipelineState(colorRenderPipelineState)
        colorRenderEncoder.setDepthStencilState(depthState)
        
        colorRenderEncoder.setVertexMesh(cubeMesh, index: Int(VertexInputIndexPosition.rawValue))
        colorRenderEncoder.setFragmentTexture(wood.texture, index: Int(FragmentInputIndexTexture.rawValue))
        colorRenderEncoder.setFragmentTexture(cubeMapDepthTexture, index: Int(FragmentInputIndexDepthMap.rawValue))
        colorRenderEncoder.setFragmentBytes(&lightPos,
                                            length: MemoryLayout<vector_float3>.stride,
                                            index: Int(FragmentInputIndexLightPos.rawValue))
        withUnsafePointer(to: camera.cameraPosition) {
            colorRenderEncoder.setFragmentBytes($0,
                                                length: MemoryLayout<vector_float3>.stride,
                                                index: Int(FragmentInputIndexViewPos.rawValue))
        }
        
        withUnsafePointer(to: farPlane) {
            colorRenderEncoder.setFragmentBytes($0,
                                                length: MemoryLayout<Float>.stride,
                                                index: Int(FragmentInputindexFarPlane.rawValue))
        }
        
        for uniform in cubesUniforms {
            withUnsafePointer(to: uniform) {
                colorRenderEncoder.setVertexBytes($0,
                                                  length: MemoryLayout<Uniforms>.stride,
                                                  index: Int(VertexInputIndexUniform.rawValue))
            }
            
            colorRenderEncoder.drawMesh(cubeMesh)
        }
        
        colorRenderEncoder.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
}
