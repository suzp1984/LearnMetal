//
//  Renderer.swift
//  BlendingDiscard
//
//  Created by Jacob Su on 3/19/21.
//
import Foundation
import MetalKit
import common

class Renderer: NSObject {
    
    private var device: MTLDevice!
    private var renderPipelineState: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!
    private var commandQueue: MTLCommandQueue!
    private var viewportSize: vector_uint2!
    private var camera: Camera!
    private var cubeMesh: MTKMesh!
    private var planeMesh: MTKMesh!
    private var cubeTexture: Texture!
    private var floorTexture: Texture!
    private var grassTexture: Texture!
    private var depthTexture: MTLTexture!
    private var cubeOneUniforms: Uniforms!
    private var cubeTwoUniforms: Uniforms!
    private var floorUniforms: Uniforms!
    private var grassUnifroms: Uniforms!
    private var grassesPosition: [vector_float3]!
    
    init(metalView: MTKView) {
        super.init()
        
        metalView.delegate = self
        device = metalView.device
        
        camera = Camera(position: vector_float3(0.0, 0.0, 5.0),
                        withTarget: vector_float3(0.0, 0.0, 0.0),
                        withUp: vector_float3(0.0, 1.0, 0.0))
//        metalView.depthStencilPixelFormat = MTLPixelFormat.depth32Float
//        metalView.clearDepth = 1.0
        
        let mtlVertexDescriptor = MTLVertexDescriptor()
        // positions
        mtlVertexDescriptor.attributes[Int(VertexAttributeIndexPosition.rawValue)].format = MTLVertexFormat.float3
        mtlVertexDescriptor.attributes[Int(VertexAttributeIndexPosition.rawValue)].offset = 0
        mtlVertexDescriptor.attributes[Int(VertexAttributeIndexPosition.rawValue)].bufferIndex = Int(VertexInputIndexPosition.rawValue)
        
        // texture coordinates
        mtlVertexDescriptor.attributes[Int(VertexAttributeIndexTexcoord.rawValue)].format = MTLVertexFormat.float2
        mtlVertexDescriptor.attributes[Int(VertexAttributeIndexTexcoord.rawValue)].offset = 16
        mtlVertexDescriptor.attributes[Int(VertexAttributeIndexTexcoord.rawValue)].bufferIndex = Int(VertexInputIndexPosition.rawValue)
        
        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stride = 32
        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stepRate = 1
        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stepFunction = MTLVertexStepFunction.perVertex
        
        guard let library = device.makeDefaultLibrary() else {
            assert(false)
        }
        guard let vertexFunc = library.makeFunction(name: "vertexShader") else {
            assert(false)
        }
        
        guard let fragmentFunc = library.makeFunction(name: "fragmentShader") else {
            assert(false)
        }
        
        let width = metalView.frame.width
        let height = metalView.frame.height
        
        depthTexture = buildDepthTexture(Int(width), Int(height))
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "render Pipeline"
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = depthTexture.pixelFormat
        
        renderPipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = MTLCompareFunction.lessEqual
        depthStateDescriptor.isDepthWriteEnabled = true
        
        depthState = device.makeDepthStencilState(descriptor: depthStateDescriptor)
        
        commandQueue = device.makeCommandQueue()
        viewportSize = vector_uint2(UInt32(metalView.frame.width), UInt32(metalView.frame.height))
        
        cubeMesh = try! MTKMesh.newBox(withVertexDescriptor: mtlVertexDescriptor,
                                       withAttributesMap: [
            Int(VertexAttributeIndexPosition.rawValue): MDLVertexAttributePosition,
            Int(VertexAttributeIndexTexcoord.rawValue): MDLVertexAttributeTextureCoordinate],
                                       withDevice: device)
        
        planeMesh = try! MTKMesh.newPlane(withVertexDescriptor: mtlVertexDescriptor,
                                          withAttributesMap: [
               Int(VertexAttributeIndexPosition.rawValue): MDLVertexAttributePosition,
               Int(VertexAttributeIndexTexcoord.rawValue): MDLVertexAttributeTextureCoordinate, ],
                                          withDevice: device)
        
        cubeTexture = try! Texture.newTextureWithName("marble",
                                                      scaleFactor: 1.0,
                                                      device: device,
                                                      index: Int(FragmentInputIndexDiffuseTexture.rawValue))
        
        floorTexture = try! Texture.newTextureWithName("metal",
                                                       scaleFactor: 1.0,
                                                       device: device,
                                                       index: Int(FragmentInputIndexDiffuseTexture.rawValue))
        
        grassTexture = try! Texture.newTextureWithName("grass",
                                                       scaleFactor: 1.0,
                                                       device: device,
                                                       index: Int(FragmentInputIndexDiffuseTexture.rawValue))
        
        cubeOneUniforms = Uniforms(
            modelMatrix: matrix4x4_translation(-1.0, 0.0, -1.0),
            viewMatrix: camera.getViewMatrix(),
            projectionMatrix: matrix_perspective_left_hand(Float.pi / 4.0, Float(width)/Float(height), 0.1, 100.0))
        
        cubeTwoUniforms = Uniforms(
            modelMatrix: matrix4x4_translation(2.0, 0.0, 0.0),
            viewMatrix: camera.getViewMatrix(),
            projectionMatrix: matrix_perspective_left_hand(Float.pi / 4.0, Float(width)/Float(height), 0.1, 100.0))
        
        
        floorUniforms = Uniforms(
            modelMatrix: simd_mul(matrix4x4_translation(0.0, -0.51, 0.0), matrix4x4_scale(10.0, 10.0, 10.0)),
            viewMatrix: camera.getViewMatrix(),
            projectionMatrix: matrix_perspective_left_hand(Float.pi / 4.0, Float(width) / Float(height), 0.1, 100.0))
        
        grassUnifroms = Uniforms(
            modelMatrix: matrix4x4_identity(),
            viewMatrix: camera.getViewMatrix(),
            projectionMatrix: matrix_perspective_left_hand(Float.pi / 4.0, Float(width) / Float(height), 0.1, 100.0))
        
        grassesPosition = [
            vector_float3(-1.5,  0.0, -0.48),
            vector_float3( 1.5,  0.0,  0.51),
            vector_float3( 0.0,  0.0,  0.7),
            vector_float3(-0.3,  0.0, -2.3),
            vector_float3( 0.5,  0.0, -0.6),
        ]
    }
    
    func handleCameraEvent(deltaX: Float, deltaY: Float) -> Void {
        camera.handleMouseScrollDeltaX(deltaX, deltaY: deltaY)
        
        cubeOneUniforms.viewMatrix = camera.getViewMatrix()
        cubeTwoUniforms.viewMatrix = camera.getViewMatrix()
        floorUniforms.viewMatrix = camera.getViewMatrix()
        grassUnifroms.viewMatrix = camera.getViewMatrix()
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
}

extension Renderer : MTKViewDelegate
{
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize.x = UInt32(size.width)
        viewportSize.y = UInt32(size.height)
        if (depthTexture.width != Int(size.width) ||
                depthTexture.height != Int(size.height))  {
            depthTexture = buildDepthTexture(Int(size.width), Int(size.height))
        }
        
        let projectionMatrix = matrix_perspective_left_hand(Float.pi / 4.0, Float(size.width) / Float(size.height), 0.1, 100.0)
        cubeOneUniforms.projectionMatrix = projectionMatrix
        cubeTwoUniforms.projectionMatrix = projectionMatrix
        floorUniforms.projectionMatrix   = projectionMatrix
        grassUnifroms.projectionMatrix   = projectionMatrix
    }
    
    func draw(in view: MTKView) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        commandBuffer.label = "Depth Testing Command"
        
        if (depthTexture.width != Int(view.drawableSize.width) ||
                depthTexture.height != Int(view.drawableSize.height)) {
            assert(false)
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = view.currentDrawable!.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.2, 0.3, 0.3, 1.0)
        
        renderPassDescriptor.depthAttachment.texture = depthTexture
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.storeAction = .store
        renderPassDescriptor.depthAttachment.clearDepth = 1.0
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.label = "depth testing"
        
        renderEncoder.setViewport(MTLViewport(originX: 0, originY: 0,
                                              width: Double(viewportSize.x),
                                              height: Double(viewportSize.y),
                                              znear: 0.0, zfar: 1.0))
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setDepthStencilState(depthState)
        
        renderEncoder.setVertexMesh(cubeMesh, index: Int(VertexInputIndexPosition.rawValue))
        
        renderEncoder.setVertexBytes(&cubeOneUniforms,
                                     length: MemoryLayout<Uniforms>.stride,
                                     index: Int(VertexInputIndexUniforms.rawValue))
        try! renderEncoder.setFragmentTexture(cubeTexture,
                                         index: Int(FragmentInputIndexDiffuseTexture.rawValue))
        // draw cube one
        renderEncoder.drawMesh(cubeMesh)
        
        // draw cube two
        renderEncoder.setVertexBytes(&cubeTwoUniforms,
                                     length: MemoryLayout<Uniforms>.stride,
                                     index: Int(VertexInputIndexUniforms.rawValue))
        renderEncoder.drawMesh(cubeMesh)
        
        // draw plane
        renderEncoder.setVertexMesh(planeMesh, index: Int(VertexInputIndexPosition.rawValue))
        
        
        renderEncoder.setVertexBytes(&floorUniforms,
                                     length: MemoryLayout<Uniforms>.stride,
                                     index: Int(VertexInputIndexUniforms.rawValue))
        try! renderEncoder.setFragmentTexture(floorTexture)
        renderEncoder.drawMesh(planeMesh)
        
        // draw grass
        try! renderEncoder.setFragmentTexture(grassTexture)
        
        for i in 0..<grassesPosition.count {
            let position = grassesPosition[i]
            
            grassUnifroms.modelMatrix = simd_mul(
                matrix4x4_translation(position),
                matrix4x4_rotation(Float.pi / 2.0, 1.0, 0.0, 0.0))
            renderEncoder.setVertexBytes(&grassUnifroms, length: MemoryLayout<Uniforms>.stride, index: Int(VertexInputIndexUniforms.rawValue))
            
            renderEncoder.drawMesh(planeMesh)
        }
        
        renderEncoder.endEncoding()
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    
}
