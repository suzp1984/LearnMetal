//
//  Renderer.swift
//  DiffuseMap
//
//  Created by Jacob Su on 3/10/21.
//

import Foundation
import MetalKit
import common

class Renderer: NSObject {
    
    private let date = Date()
    private var cubeVertexBuffer: MetalBuffer<Vertex>!
    private var depthState: MTLDepthStencilState!
    private var objectRenderPipelineState: MTLRenderPipelineState!
    private var lampRenderPipelineState: MTLRenderPipelineState!
    private var commandQueue: MTLCommandQueue!
    private var objectUniforms: Uniforms = Uniforms()
    private var lampUniforms: Uniforms = Uniforms()
    private var camera: Camera!
    private var cameraController: SatelliteCameraController!
    private var viewportSize: vector_float2!
    private var objectColor = vector_float3(1.0, 0.5, 0.31)
    private var lightColor = vector_float3(1.0, 1.0, 1.0)
    private let objectPosition = vector_float3(-300, -300, -500.0)
    private var lampPosition = vector_float3(200.0, 400.0, -100.0)

    private var materialArgumentBuffer: MTLBuffer!
    private var diffuseTexture: MTLTexture!
    
    private var light: Light = Light()
    
    static let cubeVerties: [Vertex] = [
        Vertex(position: vector_float3(-0.5, -0.5, -0.5), normal: vector_float3( 0.0,  0.0, -1.0), texCoords: vector_float2(0.0, 0.0)),
        Vertex(position: vector_float3( 0.5, -0.5, -0.5), normal: vector_float3( 0.0,  0.0, -1.0), texCoords: vector_float2(1.0, 0.0)),
        Vertex(position: vector_float3( 0.5,  0.5, -0.5), normal: vector_float3( 0.0,  0.0, -1.0), texCoords: vector_float2(1.0, 1.0)),
        Vertex(position: vector_float3( 0.5,  0.5, -0.5), normal: vector_float3( 0.0,  0.0, -1.0), texCoords: vector_float2(1.0, 1.0)),
        Vertex(position: vector_float3(-0.5,  0.5, -0.5), normal: vector_float3( 0.0,  0.0, -1.0), texCoords: vector_float2(0.0, 1.0)),
        Vertex(position: vector_float3(-0.5, -0.5, -0.5), normal: vector_float3( 0.0,  0.0, -1.0), texCoords: vector_float2(0.0, 0.0)),
        
        Vertex(position: vector_float3(-0.5, -0.5,  0.5), normal: vector_float3( 0.0,  0.0,  1.0), texCoords: vector_float2(0.0, 0.0)),
        Vertex(position: vector_float3( 0.5, -0.5,  0.5), normal: vector_float3( 0.0,  0.0,  1.0), texCoords: vector_float2(1.0, 0.0)),
        Vertex(position: vector_float3( 0.5,  0.5,  0.5), normal: vector_float3( 0.0,  0.0,  1.0), texCoords: vector_float2(1.0, 1.0)),
        Vertex(position: vector_float3( 0.5,  0.5,  0.5), normal: vector_float3( 0.0,  0.0,  1.0), texCoords: vector_float2(1.0, 1.0)),
        Vertex(position: vector_float3(-0.5,  0.5,  0.5), normal: vector_float3( 0.0,  0.0,  1.0), texCoords: vector_float2(0.0, 1.0)),
        Vertex(position: vector_float3(-0.5, -0.5,  0.5), normal: vector_float3( 0.0,  0.0,  1.0), texCoords: vector_float2(0.0, 0.0)),
        
        Vertex(position: vector_float3(-0.5,  0.5,  0.5), normal: vector_float3(-1.0,  0.0,  0.0), texCoords: vector_float2(1.0, 0.0)),
        Vertex(position: vector_float3(-0.5,  0.5, -0.5), normal: vector_float3(-1.0,  0.0,  0.0), texCoords: vector_float2(1.0, 1.0)),
        Vertex(position: vector_float3(-0.5, -0.5, -0.5), normal: vector_float3(-1.0,  0.0,  0.0), texCoords: vector_float2(0.0, 1.0)),
        Vertex(position: vector_float3(-0.5, -0.5, -0.5), normal: vector_float3(-1.0,  0.0,  0.0), texCoords: vector_float2(0.0, 1.0)),
        Vertex(position: vector_float3(-0.5, -0.5,  0.5), normal: vector_float3(-1.0,  0.0,  0.0), texCoords: vector_float2(0.0, 0.0)),
        Vertex(position: vector_float3(-0.5,  0.5,  0.5), normal: vector_float3(-1.0,  0.0,  0.0), texCoords: vector_float2(1.0, 0.0)),
        
        Vertex(position: vector_float3( 0.5,  0.5,  0.5), normal: vector_float3( 1.0,  0.0,  0.0), texCoords: vector_float2(1.0, 0.0)),
        Vertex(position: vector_float3( 0.5,  0.5, -0.5), normal: vector_float3( 1.0,  0.0,  0.0), texCoords: vector_float2(1.0, 1.0)),
        Vertex(position: vector_float3( 0.5, -0.5, -0.5), normal: vector_float3( 1.0,  0.0,  0.0), texCoords: vector_float2(0.0, 1.0)),
        Vertex(position: vector_float3( 0.5, -0.5, -0.5), normal: vector_float3( 1.0,  0.0,  0.0), texCoords: vector_float2(0.0, 1.0)),
        Vertex(position: vector_float3( 0.5, -0.5,  0.5), normal: vector_float3( 1.0,  0.0,  0.0), texCoords: vector_float2(0.0, 0.0)),
        Vertex(position: vector_float3( 0.5,  0.5,  0.5), normal: vector_float3( 1.0,  0.0,  0.0), texCoords: vector_float2(1.0, 0.0)),
        
        Vertex(position: vector_float3(-0.5, -0.5, -0.5), normal: vector_float3( 0.0, -1.0,  0.0), texCoords: vector_float2(0.0, 1.0)),
        Vertex(position: vector_float3( 0.5, -0.5, -0.5), normal: vector_float3( 0.0, -1.0,  0.0), texCoords: vector_float2(1.0, 1.0)),
        Vertex(position: vector_float3( 0.5, -0.5,  0.5), normal: vector_float3( 0.0, -1.0,  0.0), texCoords: vector_float2(1.0, 0.0)),
        Vertex(position: vector_float3( 0.5, -0.5,  0.5), normal: vector_float3( 0.0, -1.0,  0.0), texCoords: vector_float2(1.0, 0.0)),
        Vertex(position: vector_float3(-0.5, -0.5,  0.5), normal: vector_float3( 0.0, -1.0,  0.0), texCoords: vector_float2(0.0, 0.0)),
        Vertex(position: vector_float3(-0.5, -0.5, -0.5), normal: vector_float3( 0.0, -1.0,  0.0), texCoords: vector_float2(0.0, 1.0)),
        
        Vertex(position: vector_float3(-0.5,  0.5, -0.5), normal: vector_float3( 0.0,  1.0,  0.0), texCoords: vector_float2(0.0, 1.0)),
        Vertex(position: vector_float3( 0.5,  0.5, -0.5), normal: vector_float3( 0.0,  1.0,  0.0), texCoords: vector_float2(1.0, 1.0)),
        Vertex(position: vector_float3( 0.5,  0.5,  0.5), normal: vector_float3( 0.0,  1.0,  0.0), texCoords: vector_float2(1.0, 0.0)),
        Vertex(position: vector_float3( 0.5,  0.5,  0.5), normal: vector_float3( 0.0,  1.0,  0.0), texCoords: vector_float2(1.0, 0.0)),
        Vertex(position: vector_float3(-0.5,  0.5,  0.5), normal: vector_float3( 0.0,  1.0,  0.0), texCoords: vector_float2(0.0, 0.0)),
        Vertex(position: vector_float3(-0.5,  0.5, -0.5), normal: vector_float3( 0.0,  1.0,  0.0), texCoords: vector_float2(0.0, 1.0)),
    ]
    
    init(withMetalView metalView : MTKView) {
        super.init()
        
        light.position = lampPosition
        light.ambient = vector_float3(0.2, 0.2, 0.2)
        light.diffuse = vector_float3(0.5, 0.5, 0.5)
        light.specular = vector_float3(1.0, 1.0, 1.0)
        
        viewportSize = vector_float2(Float(metalView.frame.width),
                                     Float(metalView.frame.height))
        
        camera = SimpleCamera(position: vector_float3(0.0, 0.0, -1800.0),
                              withTarget: vector_float3(0.0, 0.0, 0.0),
                              up: true)
        cameraController = SatelliteCameraController(camera: camera)
        
        metalView.delegate = self
        
        guard let device = metalView.device else {
            assert(false, "metalView device is nil")
        }
        
        metalView.depthStencilPixelFormat = MTLPixelFormat.depth32Float;
        metalView.clearDepth = 1.0;
        
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = MTLCompareFunction.lessEqual
        depthDescriptor.isDepthWriteEnabled = true
        
        depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
        
        cubeVertexBuffer = MetalBuffer<Vertex>(device: device,
                            array: Renderer.cubeVerties,
                            index: UInt32(Int(VertexInputIndexVertices.rawValue)),
                            options: MTLResourceOptions.storageModeShared)
        
        guard let library = device.makeDefaultLibrary() else {
            assert(false, "make default library return nil")
        }
        
        guard let vertexFunc = library.makeFunction(name: "vertexShader") else {
            assert(false, "vertexShader cannot found")
        }
        
        guard let fragmentObjectFunc = library.makeFunction(name: "fragmentObjectShader") else {
            assert(false, "can not found fragmentObjectShader")
        }
        
        guard let fragmentLampFunc = library.makeFunction(name: "fragmentLampShader") else {
            assert(false, "can not found fragmentLampShader")
        }
        
        let objectRenderPipelineDescriptor = MTLRenderPipelineDescriptor()
        objectRenderPipelineDescriptor.label = "Object pipeline"
        objectRenderPipelineDescriptor.vertexFunction = vertexFunc
        objectRenderPipelineDescriptor.fragmentFunction = fragmentObjectFunc
        objectRenderPipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        objectRenderPipelineDescriptor.depthAttachmentPixelFormat = metalView.depthStencilPixelFormat

        objectRenderPipelineState = try? device.makeRenderPipelineState(descriptor: objectRenderPipelineDescriptor)
        assert(objectRenderPipelineState != nil, "Object Render Pipeline is nil")
        
        let lampRenderPipelineDescriptor = MTLRenderPipelineDescriptor()
        lampRenderPipelineDescriptor.label = "Lamp pipeline"
        lampRenderPipelineDescriptor.vertexFunction = vertexFunc
        lampRenderPipelineDescriptor.fragmentFunction = fragmentLampFunc
        lampRenderPipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        lampRenderPipelineDescriptor.depthAttachmentPixelFormat = metalView.depthStencilPixelFormat
        
        lampRenderPipelineState = try? device.makeRenderPipelineState(descriptor: lampRenderPipelineDescriptor)
        assert(lampRenderPipelineState != nil, "Lamp Render Pipeline is nil")
        
        let textureLoader = MTKTextureLoader(device: device)
        diffuseTexture = try? textureLoader.newTexture(name: "container2", scaleFactor: 1.0, bundle: Bundle.common, options: nil)
        
        let materialArgumentEncoder = fragmentObjectFunc.makeArgumentEncoder(bufferIndex: Int(FragmentInputIndexMaterial.rawValue))
        
        let materialArgumentLength = materialArgumentEncoder.encodedLength
        materialArgumentBuffer = device.makeBuffer(length: materialArgumentLength, options: MTLResourceOptions.storageModeShared)
        materialArgumentBuffer.label = "Material ArgumentBuffer"
        materialArgumentEncoder.setArgumentBuffer(materialArgumentBuffer, offset: 0)
        materialArgumentEncoder.setTexture(diffuseTexture, index: Int(FragmentArgumentMaterialBufferIDDiffuse.rawValue))
        let specularPtr = materialArgumentEncoder.constantData(at: Int(FragmentArgumentMaterialBufferIDSpecular.rawValue))
        specularPtr.assumingMemoryBound(to: vector_float3.self)
                    .initialize(to: vector_float3(0.5, 0.5, 0.5))
        let shininessPtr = materialArgumentEncoder.constantData(at: Int(FragmentArgumentMaterialBufferIDShininess.rawValue))
        shininessPtr.assumingMemoryBound(to: Float.self).initialize(to: 64.0)
        
        let width = metalView.frame.width
        let height = metalView.frame.height
        
        
        objectUniforms.modelMatrix = matrix_multiply(matrix4x4_translation(objectPosition), matrix_multiply(matrix4x4_rotation(Float.pi * 0.72, vector_float3(-0.1, 0.4, 0.2)),
                    matrix4x4_scale(400.0, 400.0, 400.0)))
        
        objectUniforms.inverseModelMatrix = simd_inverse(objectUniforms.modelMatrix)
        
        objectUniforms.viewMatrix = camera.getViewMatrix()
        objectUniforms.projectionMatrix = matrix_perspective_left_hand(Float.pi / 4.0, Float(width / height), 0.1, 8000)
        
        lampUniforms.modelMatrix = matrix_multiply(matrix4x4_translation(lampPosition), matrix_multiply(matrix4x4_rotation(Float.pi * 0.15, vector_float3(0.2, 0.1, 0.8)),
                            matrix4x4_scale(200.0, 200.0, 200.0)))
        lampUniforms.inverseModelMatrix = simd_inverse(lampUniforms.modelMatrix)
        lampUniforms.viewMatrix = camera.getViewMatrix()
        lampUniforms.projectionMatrix = matrix_perspective_left_hand(Float.pi / 4.0, Float(width / height), 0.1, 8000)
        
        commandQueue = device.makeCommandQueue()
    }
    
    func handleCameraEvent(deltaX: Float, deltaY: Float) -> Void {
        cameraController.rotateCameraAroundTarget(withDeltaPhi: deltaX * 0.2, deltaTheta: deltaY * 0.2)
        objectUniforms.viewMatrix = camera.getViewMatrix()
        lampUniforms.viewMatrix = camera.getViewMatrix()
    }
}

extension Renderer : MTKViewDelegate
{
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize.x = Float(size.width)
        viewportSize.y = Float(size.height)
        
        objectUniforms.projectionMatrix = matrix_perspective_left_hand(Float.pi / 4.0, Float(size.width / size.height), 0.1, 8000)
        lampUniforms.projectionMatrix = matrix_perspective_left_hand(Float.pi / 4.0, Float(size.width / size.height), 0.1, 8000)
    }
    
    func draw(in view: MTKView) {
        view.clearDepth = 1.0
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        commandBuffer.label = "Light Buffer"
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else {
            return
        }
        
        guard let objectRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        objectRenderEncoder.setViewport(MTLViewport(originX: 0.0, originY: 0.0,
                                                    width: Double(viewportSize.x),
                                                    height: Double(viewportSize.y),
                                                    znear: 0.0, zfar: 1.0))
        objectRenderEncoder.setDepthStencilState(depthState)
        objectRenderEncoder.setRenderPipelineState(objectRenderPipelineState)
        objectRenderEncoder.setVertexBuffer(cubeVertexBuffer)
        objectRenderEncoder.setVertexBytes(&objectUniforms,
                                           length: MemoryLayout<Uniforms>.stride,
                                           index: Int(VertexInputIndexUniforms.rawValue))
        
        objectRenderEncoder.useResource(diffuseTexture, usage: MTLResourceUsage.sample)
        
        objectRenderEncoder.setFragmentBuffer(materialArgumentBuffer, offset: 0, index: Int(FragmentInputIndexMaterial.rawValue))
        
        objectRenderEncoder.setFragmentBytes(&light, length: MemoryLayout<Light>.stride, index: Int(FragmentInputIndexLight.rawValue))
        
        withUnsafePointer(to: camera.cameraPosition) {
            objectRenderEncoder.setFragmentBytes($0, length: MemoryLayout<vector_float3>.size, index: Int(FragmentInputIndexViewPos.rawValue))
        }
        
        objectRenderEncoder.drawPrimitives(type: MTLPrimitiveType.triangle, vertexStart: 0, vertexCount: cubeVertexBuffer.count)
        
        // draw lamp
        objectRenderEncoder.setRenderPipelineState(lampRenderPipelineState)
        objectRenderEncoder.setVertexBuffer(cubeVertexBuffer)
        objectRenderEncoder.setVertexBytes(&lampUniforms, length: MemoryLayout<Uniforms>.stride, index: Int(VertexInputIndexUniforms.rawValue))
        objectRenderEncoder.drawPrimitives(type: MTLPrimitiveType.triangle, vertexStart: 0, vertexCount: cubeVertexBuffer.count)
        
        objectRenderEncoder.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
    }
    
}
