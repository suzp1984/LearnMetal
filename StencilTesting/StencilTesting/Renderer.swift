//
//  Renderer.swift
//  StencilTesting
//
//  Created by Jacob Su on 3/17/21.
//

import Foundation
import MetalKit
import common

let PI : Float = 3.1415926

class Renderer: NSObject {
    
    private var device: MTLDevice!
    private var renderPipelineState: MTLRenderPipelineState!
    private var borderRenderPipelineState: MTLRenderPipelineState!
    private var cubeDepthStencilState: MTLDepthStencilState!
    private var stencilWriteDisabledState: MTLDepthStencilState!
    private var borderStencilState: MTLDepthStencilState!
    
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
    private var borderOneUniforms: Uniforms!
    private var borderTwoUniforms: Uniforms!
    private var floorUniforms: Uniforms!
    
    init(metalView: MTKView) {
        super.init()
        
        metalView.delegate = self
        device = metalView.device
        
        camera = Camera(position: vector_float3(0.0, 0.0, 5.0),
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
    
        let fragmentBorderFunc = library.makeFunction(name: "fragmentBorderShader")!
        
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
        pipelineDescriptor.stencilAttachmentPixelFormat = depthTexture.pixelFormat
        
        renderPipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        let borderPipelineDescriptor = MTLRenderPipelineDescriptor()
        borderPipelineDescriptor.label = "render Pipeline"
        borderPipelineDescriptor.vertexFunction = vertexFunc
        borderPipelineDescriptor.fragmentFunction = fragmentBorderFunc
        borderPipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        borderPipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        borderPipelineDescriptor.depthAttachmentPixelFormat = depthTexture.pixelFormat
        borderPipelineDescriptor.stencilAttachmentPixelFormat = depthTexture.pixelFormat
        
        borderRenderPipelineState = try! device.makeRenderPipelineState(descriptor: borderPipelineDescriptor)
        
        // cube draw depth stencil state
        let cubeDepthStateDescriptor = MTLDepthStencilDescriptor()
        cubeDepthStateDescriptor.depthCompareFunction = MTLCompareFunction.lessEqual
        cubeDepthStateDescriptor.isDepthWriteEnabled = true
        
        let stencilDescriptor = MTLStencilDescriptor()
        stencilDescriptor.stencilCompareFunction = .always
        stencilDescriptor.depthStencilPassOperation = .replace
        stencilDescriptor.depthFailureOperation = .keep
        stencilDescriptor.stencilFailureOperation = .keep
        stencilDescriptor.writeMask = 0xFFFF
        stencilDescriptor.readMask = 0xFFFF
        
        cubeDepthStateDescriptor.frontFaceStencil = stencilDescriptor
        cubeDepthStateDescriptor.backFaceStencil = stencilDescriptor
        
        cubeDepthStencilState = device.makeDepthStencilState(descriptor: cubeDepthStateDescriptor)
        
        // floor draw depth stencil state
        let stencilWriteDisableStateDescriptor = MTLDepthStencilDescriptor()
        stencilWriteDisableStateDescriptor.depthCompareFunction = MTLCompareFunction.lessEqual
        stencilWriteDisableStateDescriptor.isDepthWriteEnabled = true
        
        let stencilDisableDescriptor = MTLStencilDescriptor()
        stencilDisableDescriptor.stencilCompareFunction = .always
        stencilDisableDescriptor.depthStencilPassOperation = .replace
        stencilDisableDescriptor.depthFailureOperation = .keep
        stencilDisableDescriptor.stencilFailureOperation = .keep
        stencilDisableDescriptor.writeMask = 0x00
        stencilDisableDescriptor.readMask = 0xFFFF
        
        stencilWriteDisableStateDescriptor.frontFaceStencil = stencilDisableDescriptor
        stencilWriteDisableStateDescriptor.backFaceStencil = stencilDisableDescriptor
        
        stencilWriteDisabledState = device.makeDepthStencilState(descriptor: stencilWriteDisableStateDescriptor)
        
        // border draw depth stencil state
        let borderStencilStateDescriptor = MTLDepthStencilDescriptor()
        borderStencilStateDescriptor.depthCompareFunction = MTLCompareFunction.lessEqual
        borderStencilStateDescriptor.isDepthWriteEnabled = false
        
        let borderStencilDescritpor = MTLStencilDescriptor()
        borderStencilDescritpor.stencilCompareFunction = .notEqual
        borderStencilDescritpor.depthStencilPassOperation = .keep
        borderStencilDescritpor.depthFailureOperation = .keep
        borderStencilDescritpor.stencilFailureOperation = .keep
        borderStencilDescritpor.writeMask = 0x00
        borderStencilDescritpor.readMask = 0xFFFF
        
        borderStencilStateDescriptor.frontFaceStencil = borderStencilDescritpor
        borderStencilStateDescriptor.backFaceStencil = borderStencilDescritpor
        
        borderStencilState = device.makeDepthStencilState(descriptor: borderStencilStateDescriptor)
        
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
        
        let bundle = Bundle(identifier: "io.github.suzp1984.common")
        let textureLoader = MTKTextureLoader(device: device)
        
        cubeTexture = try! textureLoader.newTexture(name: "marble", scaleFactor: 1.0, bundle: bundle, options: nil)
        
        floorTexture = try! textureLoader.newTexture(name: "metal", scaleFactor: 1.0, bundle: bundle, options: nil)
        
        
        cubeOneUniforms = Uniforms(
            modelMatrix: matrix4x4_translation(-1.0, 0.0, -1.0),
            viewMatrix: camera.getViewMatrix(),
            projectionMatrix: matrix_perspective_left_hand(PI / 4.0, Float(width)/Float(height), 0.1, 100.0))
        
        cubeTwoUniforms = Uniforms(
            modelMatrix: matrix4x4_translation(2.0, 0.0, 0.0),
            viewMatrix: camera.getViewMatrix(),
            projectionMatrix: matrix_perspective_left_hand(PI / 4.0, Float(width)/Float(height), 0.1, 100.0))
        
        borderOneUniforms = Uniforms(
            modelMatrix: simd_mul(matrix4x4_translation(-1.0, 0.0, -1.0), matrix4x4_scale(1.1, 1.1, 1.1)),
            viewMatrix: camera.getViewMatrix(),
            projectionMatrix: matrix_perspective_left_hand(PI / 4.0, Float(width)/Float(height), 0.1, 100.0))
        
        borderTwoUniforms = Uniforms(
            modelMatrix: simd_mul(matrix4x4_translation(2.0, 0.0, 0.0), matrix4x4_scale(1.1, 1.1, 1.1)),
            viewMatrix: camera.getViewMatrix(),
            projectionMatrix: matrix_perspective_left_hand(PI / 4.0, Float(width)/Float(height), 0.1, 100.0))
        
        floorUniforms = Uniforms(
            modelMatrix: simd_mul(matrix4x4_translation(0.0, -0.51, 0.0), matrix4x4_scale(10.0, 10.0, 10.0)),
            viewMatrix: camera.getViewMatrix(),
            projectionMatrix: matrix_perspective_left_hand(PI / 4.0, Float(width) / Float(height), 0.1, 100.0))
    }
    
    func handleCameraEvent(deltaX: Float, deltaY: Float) -> Void {
        camera.handleMouseScrollDeltaX(deltaX, deltaY: deltaY)
        
        cubeOneUniforms.viewMatrix = camera.getViewMatrix()
        cubeTwoUniforms.viewMatrix = camera.getViewMatrix()
        borderOneUniforms.viewMatrix = camera.getViewMatrix()
        borderTwoUniforms.viewMatrix = camera.getViewMatrix()
        floorUniforms.viewMatrix = camera.getViewMatrix()
    }
    
    fileprivate func buildDepthTexture(_ width: Int, _ height: Int) -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = MTLPixelFormat.depth32Float_stencil8
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
        
        let projectionMatrix = matrix_perspective_left_hand(PI / 4.0, Float(size.width) / Float(size.height), 0.1, 100.0)
        cubeOneUniforms.projectionMatrix = projectionMatrix
        cubeTwoUniforms.projectionMatrix = projectionMatrix
        borderOneUniforms.projectionMatrix = projectionMatrix
        borderTwoUniforms.projectionMatrix = projectionMatrix
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
        
        renderPassDescriptor.stencilAttachment.texture = depthTexture
        renderPassDescriptor.stencilAttachment.clearStencil = 0
        renderPassDescriptor.stencilAttachment.loadAction = .clear
        renderPassDescriptor.stencilAttachment.storeAction = .store

        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.label = "depth testing"
        
        renderEncoder.setStencilReferenceValue(1)
        
        renderEncoder.setViewport(MTLViewport(originX: 0, originY: 0,
                                              width: Double(viewportSize.x),
                                              height: Double(viewportSize.y),
                                              znear: 0.0, zfar: 1.0))
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setDepthStencilState(stencilWriteDisabledState)
        
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
        
        
        // draw cube one
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setDepthStencilState(cubeDepthStencilState)
        
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
        
        // draw border one
        renderEncoder.setRenderPipelineState(borderRenderPipelineState)
        renderEncoder.setDepthStencilState(borderStencilState)
        
        for i in 0..<cubeMesh.vertexBuffers.count {
            let mtkMeshBuffer = cubeMesh.vertexBuffers[i]
            renderEncoder.setVertexBuffer(mtkMeshBuffer.buffer,
                                          offset: mtkMeshBuffer.offset,
                                          index: Int(VertexInputIndexPosition.rawValue))
        }
        

        renderEncoder.setVertexBytes(&borderOneUniforms,
                                     length: MemoryLayout<Uniforms>.stride,
                                     index: Int(VertexInputIndexUniforms.rawValue))
        renderEncoder.setFragmentTexture(cubeTexture,
                                         index: Int(FragmentInputIndexDiffuseTexture.rawValue))
        for i in 0..<cubeMesh.submeshes.count {
            let submesh = cubeMesh.submeshes[i]
            renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset)
        }
        
        // draw border two
        renderEncoder.setVertexBytes(&borderTwoUniforms,
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
        
        renderEncoder.endEncoding()
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
}
