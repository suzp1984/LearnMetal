//
//  Renderer.swift
//  4.1.DepthTesting
//
//  Created by Jacob Su on 3/17/21.
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
    private var cubeTexture: MTLTexture!
    private var floorTexture: MTLTexture!
    private var depthTexture: MTLTexture!
    private var cubeOneUniforms: Uniforms!
    private var cubeTwoUniforms: Uniforms!
    private var floorUniforms: Uniforms!
    
    init(metalView: MTKView) {
        super.init()
        
        metalView.delegate = self
        device = metalView.device
        
        camera = CameraFactory.generateRoundOrbitCamera(withPosition: vector_float3(0.0, 0.0, 3.0),
                                                        target: vector_float3(0.0, 0.0, 0.0),
                                                        up: vector_float3(0.0, 1.0, 0.0))
        
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
        depthStateDescriptor.depthCompareFunction = MTLCompareFunction.always
        depthStateDescriptor.isDepthWriteEnabled = true
        
        depthState = device.makeDepthStencilState(descriptor: depthStateDescriptor)
        
        commandQueue = device.makeCommandQueue()
        viewportSize = vector_uint2(UInt32(metalView.frame.width), UInt32(metalView.frame.height))
        
        let modelIOVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)
        (modelIOVertexDescriptor.attributes[Int(VertexAttributeIndexPosition.rawValue)] as! MDLVertexAttribute).name = MDLVertexAttributePosition
        (modelIOVertexDescriptor.attributes[Int(VertexAttributeIndexTexcoord.rawValue)] as! MDLVertexAttribute).name = MDLVertexAttributeTextureCoordinate
        
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        let cubeMDLMesh = MDLMesh.newBox(withDimensions: vector_float3(1.0, 1.0, 1.0),
                                  segments: vector_uint3(1, 1, 1),
                                  geometryType: MDLGeometryType.triangles,
                                  inwardNormals: false,
                                  allocator: metalAllocator)
        
        cubeMDLMesh.vertexDescriptor = modelIOVertexDescriptor
        
        cubeMesh = try! MTKMesh(mesh: cubeMDLMesh, device: device)
        
        let planeMDLMesh = MDLMesh.newPlane(withDimensions: vector_float2(1.0, 1.0),
                                            segments: vector_uint2(1, 1),
                                            geometryType: MDLGeometryType.triangles,
                                            allocator: metalAllocator)
        planeMDLMesh.vertexDescriptor = modelIOVertexDescriptor
        planeMesh = try! MTKMesh(mesh: planeMDLMesh, device: device)
        
        let bundle = Bundle.common
        let textureLoader = MTKTextureLoader(device: device)
        
        cubeTexture = try! textureLoader.newTexture(name: "marble", scaleFactor: 1.0, bundle: bundle, options: nil)
        
        floorTexture = try! textureLoader.newTexture(name: "metal", scaleFactor: 1.0, bundle: bundle, options: nil)
        
        
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
    }
    
    func handleCameraEvent(deltaX: Float, deltaY: Float) -> Void {
        camera.rotateCameraAroundTarget(withDeltaPhi: deltaX, deltaTheta: deltaY)
        
        cubeOneUniforms.viewMatrix = camera.getViewMatrix()
        cubeTwoUniforms.viewMatrix = camera.getViewMatrix()
        floorUniforms.viewMatrix = camera.getViewMatrix()
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
        
        for i in 0..<cubeMesh.vertexBuffers.count {
            let mtkMeshBuffer = cubeMesh.vertexBuffers[i]
            renderEncoder.setVertexBuffer(mtkMeshBuffer.buffer,
                                          offset: mtkMeshBuffer.offset,
                                          index: Int(VertexInputIndexPosition.rawValue))
        }
        
        renderEncoder.setVertexBytes(&cubeOneUniforms,
                                     length: MemoryLayout<Uniforms>.stride,
                                     index: Int(VertexInputIndexUniforms.rawValue))
        renderEncoder.setFragmentTexture(cubeTexture,
                                         index: Int(FragmentInputIndexDiffuseTexture.rawValue))
        // draw cube one
        for i in 0..<cubeMesh.submeshes.count {
            let submesh = cubeMesh.submeshes[i]
            renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset)
        }
        
        // draw cube two
        renderEncoder.setVertexBytes(&cubeTwoUniforms,
                                     length: MemoryLayout<Uniforms>.stride,
                                     index: Int(VertexInputIndexUniforms.rawValue))
        
        for i in 0..<cubeMesh.submeshes.count {
            let submesh = cubeMesh.submeshes[i]
            renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset)
        }
        
        // draw plane
        for i in 0..<planeMesh.vertexBuffers.count {
            let mtkMeshBuffer = planeMesh.vertexBuffers[i]
            renderEncoder.setVertexBuffer(mtkMeshBuffer.buffer,
                                          offset: mtkMeshBuffer.offset,
                                          index: Int(VertexInputIndexPosition.rawValue))
        }
        
        renderEncoder.setVertexBytes(&floorUniforms,
                                     length: MemoryLayout<Uniforms>.stride,
                                     index: Int(VertexInputIndexUniforms.rawValue))
        renderEncoder.setFragmentTexture(floorTexture,
                                         index: Int(FragmentInputIndexDiffuseTexture.rawValue))
        for i in 0..<planeMesh.submeshes.count {
            let subMesh = planeMesh.submeshes[i]
            renderEncoder.drawIndexedPrimitives(type: subMesh.primitiveType,
                                                indexCount: subMesh.indexCount,
                                                indexType: subMesh.indexType,
                                                indexBuffer: subMesh.indexBuffer.buffer,
                                                indexBufferOffset: subMesh.indexBuffer.offset)
        }
        
        renderEncoder.endEncoding()
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    
}
