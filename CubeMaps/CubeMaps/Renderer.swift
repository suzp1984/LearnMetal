//
//  Renderer.swift
//  4.7.CubeMaps
//
//  Created by Jacob Su on 3/23/21.
//

import Foundation
import common
import Metal
import MetalKit

let PI : Float = 3.1415926

class Renderer : NSObject {
    
    private var device: MTLDevice!
    private var camera: Camera!
    
    private var renderPipelineState: MTLRenderPipelineState!
    private var skyBoxPipelineState: MTLRenderPipelineState!
    private var lessEqualDepthState: MTLDepthStencilState!
    private var lessDepthState: MTLDepthStencilState!
    private var commandQueue: MTLCommandQueue!
    private var viewportSize: vector_uint2!
    private var cubeMesh: MTKMesh!
    private var skyBoxBuffer: MetalBuffer<CubeMapVertex>!
    private var skyBoxTexture: MTLTexture!
    private var depthTexture: MTLTexture!
    private var containerTexture: Texture!
    private var uniform: Uniforms!
    private let depthFormat: MTLPixelFormat = .depth32Float

    init(metalView: MTKView) {
        super.init()
        
        device = metalView.device!
        metalView.delegate = self
        
        camera = Camera(position: vector_float3(0.0, 0.0, 3.0),
                        withTarget: vector_float3(0.0, 0.0, 0.0),
                        withUp: vector_float3(0.0, 1.0, 0.0))
        
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
        
        let library = device.makeDefaultLibrary()!
        let vertexFunc = library.makeFunction(name: "vertexShader")!
        let fragmentFunc = library.makeFunction(name: "fragmentShader")!
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "cube container"
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = depthFormat
        
        renderPipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        let lessEqualDepthStateDescritpor = MTLDepthStencilDescriptor()
        lessEqualDepthStateDescritpor.depthCompareFunction = .lessEqual
        lessEqualDepthStateDescritpor.isDepthWriteEnabled = true
        
        lessEqualDepthState = device.makeDepthStencilState(descriptor: lessEqualDepthStateDescritpor)
        
        let lessDepthStateDescriptor = MTLDepthStencilDescriptor()
        lessDepthStateDescriptor.depthCompareFunction = .less
        lessDepthStateDescriptor.isDepthWriteEnabled = true
        
        lessDepthState = device.makeDepthStencilState(descriptor: lessDepthStateDescriptor)
        
        let cubeMapVertexFunc = library.makeFunction(name: "cubeMapVertexShader")
        let cubeMapFragmentFunc = library.makeFunction(name: "cubeMapFragmentShader")
        
        let skyBoxPipelineDescriptor = MTLRenderPipelineDescriptor()
        skyBoxPipelineDescriptor.label = "sky box"
        skyBoxPipelineDescriptor.vertexFunction = cubeMapVertexFunc
        skyBoxPipelineDescriptor.fragmentFunction = cubeMapFragmentFunc
        skyBoxPipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        skyBoxPipelineDescriptor.depthAttachmentPixelFormat = depthFormat
        
        skyBoxPipelineState = try! device.makeRenderPipelineState(descriptor: skyBoxPipelineDescriptor)
        
        commandQueue = device.makeCommandQueue()!
        viewportSize = vector_uint2(UInt32(metalView.frame.width), UInt32(metalView.frame.height))
        
        cubeMesh = try! MTKMesh.newBox(withVertexDescriptor: mtlVertexDescriptor,
                                       withAttributesMap: [
            Int(VertexAttributeIndexPosition.rawValue): MDLVertexAttributePosition,
            Int(VertexAttributeIndexTexcoord.rawValue): MDLVertexAttributeTextureCoordinate],
                                       withDevice: device)
        
        let skyboxVertices: [CubeMapVertex] = [
            CubeMapVertex(position: vector_float3(-1.0,  1.0, -1.0)),
            CubeMapVertex(position: vector_float3(-1.0, -1.0, -1.0)),
            CubeMapVertex(position: vector_float3( 1.0, -1.0, -1.0)),
            CubeMapVertex(position: vector_float3( 1.0, -1.0, -1.0)),
            CubeMapVertex(position: vector_float3( 1.0,  1.0, -1.0)),
            CubeMapVertex(position: vector_float3(-1.0,  1.0, -1.0)),
            
            CubeMapVertex(position: vector_float3(-1.0, -1.0,  1.0)),
            CubeMapVertex(position: vector_float3(-1.0, -1.0, -1.0)),
            CubeMapVertex(position: vector_float3(-1.0,  1.0, -1.0)),
            CubeMapVertex(position: vector_float3(-1.0,  1.0, -1.0)),
            CubeMapVertex(position: vector_float3(-1.0,  1.0,  1.0)),
            CubeMapVertex(position: vector_float3(-1.0, -1.0,  1.0)),

            CubeMapVertex(position: vector_float3( 1.0, -1.0, -1.0)),
            CubeMapVertex(position: vector_float3( 1.0, -1.0,  1.0)),
            CubeMapVertex(position: vector_float3( 1.0,  1.0,  1.0)),
            CubeMapVertex(position: vector_float3( 1.0,  1.0,  1.0)),
            CubeMapVertex(position: vector_float3( 1.0,  1.0, -1.0)),
            CubeMapVertex(position: vector_float3( 1.0, -1.0, -1.0)),
            
            CubeMapVertex(position: vector_float3(-1.0, -1.0,  1.0)),
            CubeMapVertex(position: vector_float3(-1.0,  1.0,  1.0)),
            CubeMapVertex(position: vector_float3( 1.0,  1.0,  1.0)),
            CubeMapVertex(position: vector_float3( 1.0,  1.0,  1.0)),
            CubeMapVertex(position: vector_float3( 1.0, -1.0,  1.0)),
            CubeMapVertex(position: vector_float3(-1.0, -1.0,  1.0)),

            CubeMapVertex(position: vector_float3(-1.0,  1.0, -1.0)),
            CubeMapVertex(position: vector_float3( 1.0,  1.0, -1.0)),
            CubeMapVertex(position: vector_float3( 1.0,  1.0,  1.0)),
            CubeMapVertex(position: vector_float3( 1.0,  1.0,  1.0)),
            CubeMapVertex(position: vector_float3(-1.0,  1.0,  1.0)),
            CubeMapVertex(position: vector_float3(-1.0,  1.0, -1.0)),

            CubeMapVertex(position: vector_float3(-1.0, -1.0, -1.0)),
            CubeMapVertex(position: vector_float3(-1.0, -1.0,  1.0)),
            CubeMapVertex(position: vector_float3( 1.0, -1.0, -1.0)),
            CubeMapVertex(position: vector_float3( 1.0, -1.0, -1.0)),
            CubeMapVertex(position: vector_float3(-1.0, -1.0,  1.0)),
            CubeMapVertex(position: vector_float3( 1.0, -1.0,  1.0)),
        ]
        
        skyBoxBuffer = MetalBuffer(device: device,
                                   array: skyboxVertices,
                                   index: UInt32(VertexInputIndexPosition.rawValue))
        
        containerTexture = try! Texture.newTextureWithName("container", scaleFactor: 1.0, device: device, index: Int(FragmentInputIndexDiffuseTexture.rawValue))
        
        skyBoxTexture = try! TextureCubeLoader.load(withImageNames: [
                                                "skybox/right.jpg",
                                                "skybox/left.jpg",
                                                "skybox/top.jpg",
                                                "skybox/bottom.jpg",
                                                "skybox/front.jpg",
                                                "skybox/back.jpg"],
                                               device: device, commandQueue: commandQueue)
        let width = metalView.frame.width
        let height = metalView.frame.height
        
        depthTexture = buildDepthTexture(Int(width), Int(height))
        
        uniform = Uniforms(
            modelMatrix: matrix4x4_identity(),
            viewMatrix: camera.getViewMatrix(),
            projectionMatrix: matrix_perspective_left_hand(PI / 4.0, Float(width) / Float(height), 0.1, 100.0))
    }
    
    func handleCameraEvent(deltaX: Float, deltaY: Float) -> Void {
        camera.handleMouseScrollDeltaX(deltaX, deltaY: deltaY)
        
        uniform.viewMatrix = camera.getViewMatrix()
    }
    
    fileprivate func buildDepthTexture(_ width: Int, _ height: Int) -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = depthFormat
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

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize.x = UInt32(size.width)
        viewportSize.y = UInt32(size.height)
        
        if (depthTexture.width != Int(size.width) ||
                depthTexture.height != Int(size.height))  {
            depthTexture = buildDepthTexture(Int(size.width), Int(size.height))
        }
        
        let projectionMatrix = matrix_perspective_left_hand(PI / 4.0, Float(size.width) / Float(size.height), 0.1, 100.0)
        uniform.projectionMatrix = projectionMatrix
    }
    
    func draw(in view: MTKView) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
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
        renderEncoder.label = "cube render"
        
        renderEncoder.setViewport(MTLViewport(originX: 0, originY: 0,
                                              width: Double(viewportSize.x),
                                              height: Double(viewportSize.y),
                                              znear: 0.0, zfar: 1.0))
        
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setDepthStencilState(lessDepthState)

        for i in 0..<cubeMesh.vertexBuffers.count {
            let mtkMeshBuffer = cubeMesh.vertexBuffers[i]
            renderEncoder.setVertexBuffer(mtkMeshBuffer.buffer,
                                          offset: mtkMeshBuffer.offset,
                                          index: Int(VertexInputIndexPosition.rawValue))
        }
        
        renderEncoder.setVertexBytes(&uniform,
                                     length: MemoryLayout<Uniforms>.stride,
                                     index: Int(VertexInputIndexUniforms.rawValue))
        try! renderEncoder.setFragmentTexture(containerTexture)

        // draw cube
        for i in 0..<cubeMesh.submeshes.count {
            let submesh = cubeMesh.submeshes[i]
            renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset)
        }
        
        
        // draw sky
        renderEncoder.setRenderPipelineState(skyBoxPipelineState)
        renderEncoder.setDepthStencilState(lessEqualDepthState)
        
        renderEncoder.setVertexBuffer(skyBoxBuffer)
        
        renderEncoder.setVertexBytes(&uniform,
                                     length: MemoryLayout<Uniforms>.stride,
                                     index: Int(VertexInputIndexUniforms.rawValue))
        renderEncoder.setFragmentTexture(skyBoxTexture, index: Int(CubeMapFragmentInputIndexCubeMap.rawValue))
        
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: skyBoxBuffer.count)
        
        renderEncoder.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
    }
    
    
}
