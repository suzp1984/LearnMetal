//
//  Renderer.swift
//  SpotLightSoft
//
//  Created by Jacob Su on 3/13/21.
//
import Foundation
import MetalKit
import common

let PI = 3.1415926

class Renderer: NSObject {
    
    private let date = Date()
    private var cubeVertexBuffer: MetalBuffer<Vertex>!
    private var uniformBuffer: MetalBuffer<Uniforms>!
    private var lightBuffer: MTLBuffer!
    private var depthState: MTLDepthStencilState!
    private var objectRenderPipelineState: MTLRenderPipelineState!
    private var commandQueue: MTLCommandQueue!
    private var camera: Camera!
    private var viewportSize: vector_float2!
    private var objectColor = vector_float3(1.0, 0.5, 0.31)
    private var lightColor = vector_float3(1.0, 1.0, 1.0)
    private let objectPosition = vector_float3(-300, -300, -500.0)

    private var materialArgumentBuffer: MTLBuffer!
    private var lightArgumentBuffer: MTLBuffer!
    private var diffuseTexture: MTLTexture!
    private var specularTexture: MTLTexture!
    private var instanceNumber: Int!
    
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
    
    static let cubePositions: [vector_float3] = [
        vector_float3( 0.0,  0.0,  0.0),
        vector_float3( 2.0,  5.0, -15.0),
        vector_float3(-1.5, -2.2, -2.5),
        vector_float3(-3.8, -2.0, -12.3),
        vector_float3( 2.4, -0.4, -3.5),
        vector_float3(-1.7,  3.0, -7.5),
        vector_float3( 1.3, -2.0, -2.5),
        vector_float3( 1.5,  2.0, -2.5),
        vector_float3( 1.5,  0.2, -1.5),
        vector_float3(-1.3,  1.0, -1.5),
    ]
    
    init(withMetalView metalView : MTKView) {
        super.init()
        
        camera = Camera(position: vector_float3(0.0, 0.0, 3.0),
                        withTarget: vector_float3(0.0, 0.0, 0.0),
                        withUp: vector_float3(0.0, 1.0, 0.0))
        
        instanceNumber = Renderer.cubePositions.count
        
        light.position = camera.getPosition()
        light.direction = camera.getFrontDirection()
        light.ambient = vector_float3(0.4, 0.4, 0.4)
        light.diffuse = vector_float3(1.0, 1.0, 1.0)
        light.specular = vector_float3(1.0, 1.0, 1.0)
        light.constants = 1.0
        light.linear = 0.09
        light.quadratic = 0.032
        light.cutOff = Float(cos(12.5 * PI / 180.0))
        light.outerCutOff = Float(cos(17.5 * PI / 180.0))
        
        viewportSize = vector_float2(Float(metalView.frame.width),
                                     Float(metalView.frame.height))
        
        
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
        
        let objectRenderPipelineDescriptor = MTLRenderPipelineDescriptor()
        objectRenderPipelineDescriptor.label = "Object pipeline"
        objectRenderPipelineDescriptor.vertexFunction = vertexFunc
        objectRenderPipelineDescriptor.fragmentFunction = fragmentObjectFunc
        objectRenderPipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        objectRenderPipelineDescriptor.depthAttachmentPixelFormat = metalView.depthStencilPixelFormat

        objectRenderPipelineState = try? device.makeRenderPipelineState(descriptor: objectRenderPipelineDescriptor)
        assert(objectRenderPipelineState != nil, "Object Render Pipeline is nil")
        
        let bundle = Bundle(identifier: "io.github.suzp1984.common")
        let textureLoader = MTKTextureLoader(device: device)
        
        specularTexture = try! textureLoader.newTexture(name: "container2_specular", scaleFactor: 1.0, bundle: bundle, options: nil)
        
        diffuseTexture = try! textureLoader.newTexture(name: "container2", scaleFactor: 1.0, bundle: bundle, options: nil)
        
        let materialArgumentEncoder = fragmentObjectFunc.makeArgumentEncoder(bufferIndex: Int(FragmentInputIndexMaterial.rawValue))
        
        let materialArgumentLength = materialArgumentEncoder.encodedLength
        materialArgumentBuffer = device.makeBuffer(length: materialArgumentLength, options: MTLResourceOptions.storageModeShared)
        materialArgumentBuffer.label = "Material ArgumentBuffer"
        materialArgumentEncoder.setArgumentBuffer(materialArgumentBuffer, offset: 0)
        materialArgumentEncoder.setTexture(diffuseTexture, index: Int(FragmentArgumentMaterialBufferIDDiffuse.rawValue))
        materialArgumentEncoder.setTexture(specularTexture, index: Int(FragmentArgumentMaterialBufferIDSpecular.rawValue))
        let shininessPtr = materialArgumentEncoder.constantData(at: Int(FragmentArgumentMaterialBufferIDShininess.rawValue))
        shininessPtr.assumingMemoryBound(to: Float.self).initialize(to: 64.0)
        
        
        let lightArgumentEncoder = fragmentObjectFunc.makeArgumentEncoder(bufferIndex: Int(FragmentInputIndexLight.rawValue))
        let lightArgumentLength = lightArgumentEncoder.encodedLength
        lightArgumentBuffer = device.makeBuffer(length: lightArgumentLength, options: MTLResourceOptions.storageModeShared)
        lightArgumentBuffer.label = "Light ArgumentBuffer"
        lightArgumentEncoder.setArgumentBuffer(lightArgumentBuffer, offset: 0)
        
        lightBuffer = device.makeBuffer(bytes: &light, length: MemoryLayout<Light>.stride, options: MTLResourceOptions.storageModeShared)
        lightArgumentEncoder.setBuffer(lightBuffer, offset: 0, index: Int(FragmentArgumentLightBufferIDLight.rawValue))
        
//        let lightPtr = lightArgumentEncoder.constantData(at: Int(FragmentArgumentLightBufferIDLight.rawValue))
//        lightPtr.assumingMemoryBound(to: Light.self).initialize(to: light)
        let viewPosPtr = lightArgumentEncoder.constantData(at: Int(FragmentArgumentLightBufferIDViewPosition.rawValue))
        viewPosPtr.assumingMemoryBound(to: vector_float3.self).initialize(to: camera.getPosition())
        
        let width = metalView.frame.width
        let height = metalView.frame.height
        
        uniformBuffer = MetalBuffer<Uniforms>(device: device,
                                              count: instanceNumber,
                                              index: UInt32(VertexInputIndexUniforms.rawValue),
                                              label: "Uniform buffer",
                                              options: MTLResourceOptions.storageModeShared)
        (0 ..< instanceNumber).forEach { i in
            let angle = 20.0 * Float(i)
            let modelMatrix = matrix_multiply(
                matrix4x4_translation(Renderer.cubePositions[i]), matrix_multiply(
                    matrix4x4_rotation(Float(Double(angle) / 180.0 * PI), vector_float3(1.0, 0.3, 0.5)),
                    matrix4x4_scale(1.0, 1.0, 1.0)))
            let inverseModelMatrix = simd_inverse(modelMatrix)
            let viewMatrix = camera.getViewMatrix()
            let projectionMatrix = matrix_perspective_left_hand(Float(PI / 4.0), Float(width / height), 0.1, 100)
            let uniform = Uniforms(modelMatrix: modelMatrix,
                                   viewMatrix: viewMatrix,
                                   projectionMatrix: projectionMatrix,
                                   inverseModelMatrix: inverseModelMatrix)
            
            uniformBuffer.assign(uniform, at: i)
        }
        
        commandQueue = device.makeCommandQueue()
    }
    
    func handleCameraEvent(deltaX: Float, deltaY: Float) -> Void {
        camera.handleMouseScrollDeltaX(deltaX, deltaY: deltaY)
        for i in 0..<instanceNumber {
            var uniform = uniformBuffer[i]
            uniform.viewMatrix = camera.getViewMatrix()
            
            uniformBuffer.assign(uniform, at: i)
        }
        
        light.position = camera.getPosition()
        light.direction = camera.getFrontDirection()
        lightBuffer.contents().assumingMemoryBound(to: Light.self).initialize(to: light)
    }
}

extension Renderer : MTKViewDelegate
{
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize.x = Float(size.width)
        viewportSize.y = Float(size.height)
        
        for i in 0..<instanceNumber {
            var uniform = uniformBuffer[i]
            uniform.projectionMatrix = matrix_perspective_left_hand(Float(PI / 4.0), Float(size.width / size.height), 0.1, 100)
            
            uniformBuffer.assign(uniform, at: i)
        }
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
        objectRenderEncoder.setVertexBuffer(uniformBuffer)
        
        objectRenderEncoder.useResource(diffuseTexture, usage: MTLResourceUsage.sample)
        objectRenderEncoder.useResource(specularTexture, usage: MTLResourceUsage.sample)
        objectRenderEncoder.useResource(lightBuffer, usage: MTLResourceUsage.read)
        
        objectRenderEncoder.setFragmentBuffer(materialArgumentBuffer, offset: 0, index: Int(FragmentInputIndexMaterial.rawValue))
        objectRenderEncoder.setFragmentBuffer(lightArgumentBuffer, offset: 0, index: Int(FragmentInputIndexLight.rawValue))
        
        objectRenderEncoder.drawPrimitives(type: MTLPrimitiveType.triangle, vertexStart: 0, vertexCount: cubeVertexBuffer.count, instanceCount: instanceNumber)
        
        objectRenderEncoder.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
}
