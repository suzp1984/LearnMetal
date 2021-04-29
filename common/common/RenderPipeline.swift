//
//  RenderPipeline.swift
//  common
//
//  Created by Jacob Su on 4/27/21.
//

import Foundation
import Metal
import MetalKit

public enum RenderTarget {
    case ColorTarget(texture: MTLTexture, loadAction: MTLLoadAction, storeAction: MTLStoreAction, clearColor: MTLClearColor)
    case DepthTarget(texture: MTLTexture, loadAction: MTLLoadAction, storeAction: MTLStoreAction, clearDepth: Double)
}

public indirect enum MetalResource {
    case ByteResource(model: Model)
    case BufferResource(buffer: MTLBuffer, offset: Int)
    case TextureResouce(MTLTexture)
    case MeshResource(MetalMesh)
    case MTKMeshResource(MTKMesh)
    case SubMeshResource(name: String, resource: MetalResource)
}

public enum DrawCommand {
    case Vertex(vertexStart: Int, vertexCount: Int)
//    case MetalMesh(MetalMesh)
//    case MTKMesh(MTKMesh)
    case MTKSubMesh([MTKSubmesh])
    case IndirectBuffer(indirectBuffer: MTLBuffer, offset: Int)
    case IndexBuffer(indexBuffer: MTLBuffer, indexCount: Int, indexType: MTLIndexType, indexBufferOffset: Int)
    case IndexedIndirectBuffer(indirectBuffer: MTLBuffer,
                               indirectBufferOffset: Int,
                               indexBuffer: MTLBuffer,
                               indexType: MTLIndexType,
                               indexBufferOffset: Int)
}

public protocol Model {
    var vertexInputs: [(Int, MetalResource)]! { get }
    var fragmentInputs: [(Int, MetalResource)]! { get }
    var drawResource: DrawCommand! { get }
    var primitiveType: MTLPrimitiveType? { get }
    var resources: [(MTLResource, MTLResourceUsage)]? { get } // TODO: +MTLRenderStages
    var heaps: [MTLHeap]? { get }
    var instanceCount: Int? { get }
    var name: String { get }
    
    func setVertexBytes(in renderEncoder: MTLRenderCommandEncoder, index: Int)
    func setFragmentBytes(in renderEncoder: MTLRenderCommandEncoder, index: Int)
}

public extension MTLRenderCommandEncoder {
    func setVertexResource(_ resource: MetalResource, index: Int) {
        switch resource {
        case let .ByteResource(model: model):
            model.setVertexBytes(in: self, index: index)
//            setVertexBytes(rawPtr, length: length, index: index)
        case let .BufferResource(buffer: buffer, offset: offset):
            setVertexBuffer(buffer, offset: offset, index: index)
        case let .TextureResouce(texture):
            setVertexTexture(texture, index: index)
        case let .MeshResource(mesh):
            setVertexMesh(mesh, index: index)
        case let .MTKMeshResource(mesh):
            setVertexMesh(mesh, index: index)
        case .SubMeshResource(name: _, resource: _):
            // SubMesh Resource setup before submesh drawing
            break
        }
    }
    
    func setFragmentResouce(_ resource: MetalResource, index: Int) throws {
        switch resource {
        case let .ByteResource(model: model):
            model.setFragmentBytes(in: self, index: index)
//            setFragmentBytes(rawPtr, length: length, index: index)
            
        case let .BufferResource(buffer: buffer, offset: offset):
            setFragmentBuffer(buffer, offset: offset, index: index)
        case let .TextureResouce(texture):
            setFragmentTexture(texture, index: index)
        case .SubMeshResource(name: _, resource: _):
            // SubMesh Resource setup before submesh drawing
            break
        case .MTKMeshResource(_):
            throw Errors.runtimeError("fragment shader don't support MTKMesh Resource.")
        case .MeshResource(_):
            throw Errors.runtimeError("fragment shader don't support Mesh Resource")
        }
    }
    
    func drawModel(_ model: Model) throws {
        pushDebugGroup("Draw Model")
        // use heap if there is one
        if let heaps = model.heaps,
           heaps.count > 0 {
            if heaps.count == 1 {
                useHeap(heaps[0])
            } else {
                useHeaps(heaps)
            }
        }
        
        // set use resources
        if let resources = model.resources {
            for (resource, usage) in resources {
                useResource(resource, usage: usage)
            }
        }
        
        // set vertex inputs
        for (index, resource) in model.vertexInputs {
            setVertexResource(resource, index: index)
        }
        
        // set fragment inputs
        for (index, resource) in model.fragmentInputs {
            try setFragmentResouce(resource, index: index)
        }
        
        // draw
        switch model.drawResource! {
        case let .Vertex(vertexStart: start, vertexCount: count):
            drawPrimitives(type: model.primitiveType ?? .triangle,
                           vertexStart: start,
                           vertexCount: count,
                           instanceCount: model.instanceCount ?? 1)
        case let .MTKSubMesh(submeshes):
            for mesh in submeshes {
                // submesh vertex resources setup
                model.vertexInputs.forEach { (index, resource) in
                    if case let .SubMeshResource(name: name, resource: subResource) = resource,
                       name == mesh.name {
                        setVertexResource(subResource, index: index)
                    }
                }
                
                // submesh fragment resource setup
                try model.fragmentInputs.forEach { (index, resource) in
                    if case let .SubMeshResource(name: name, resource: subResource) = resource,
                       name == mesh.name {
                        try setFragmentResouce(subResource, index: index)
                    }
                    
                }
                
                drawMesh(mesh, instanceCount: model.instanceCount)
            }
            
//        case let .MetalMesh(metalMesh):
//            if model.instanceCount == nil {
//                drawMesh(metalMesh, textureHandler: nil)
//            } else {
//                drawMesh(metalMesh, instanceCount: model.instanceCount!, textureHandler: nil)
//            }
//        case let .MTKMesh(mtkMesh):
//            drawMesh(mtkMesh, instanceCount: model.instanceCount)
        case let .IndirectBuffer(indirectBuffer: indirectBuffer, offset: offset):
            drawPrimitives(type: model.primitiveType ?? .triangle,
                           indirectBuffer: indirectBuffer,
                           indirectBufferOffset: offset)
        case let .IndexBuffer(indexBuffer: buffer,
                              indexCount: indexCount,
                              indexType: indexType,
                              indexBufferOffset: offset):
            drawIndexedPrimitives(type: model.primitiveType ?? .triangle,
                                  indexCount: indexCount,
                                  indexType: indexType,
                                  indexBuffer:buffer,
                                  indexBufferOffset: offset,
                                  instanceCount: model.instanceCount ?? 1)
        case let .IndexedIndirectBuffer(indirectBuffer: indirectBuffer,
                                        indirectBufferOffset: indirectBufferOffset,
                                        indexBuffer: indexBuffer,
                                        indexType: indexType,
                                        indexBufferOffset: indexBufferOffset):
            drawIndexedPrimitives(type: model.primitiveType ?? .triangle,
                                  indexType: indexType,
                                  indexBuffer: indexBuffer,
                                  indexBufferOffset: indexBufferOffset,
                                  indirectBuffer: indirectBuffer,
                                  indirectBufferOffset: indirectBufferOffset)
        }
        
        popDebugGroup()
    }
}

class RenderPipeline {
    init(renderTargets: [(Int, RenderTarget)]
         ) {
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        
        for (index, target) in renderTargets {
            switch target {
            case let .ColorTarget(texture: texture,
                                  loadAction: _,
                                  storeAction: _,
                                  clearColor: _):
                renderPipelineDescriptor.colorAttachments[index].pixelFormat = texture.pixelFormat
            case let .DepthTarget(texture: texture, loadAction: _, storeAction: _, clearDepth: _):
                renderPipelineDescriptor.depthAttachmentPixelFormat = texture.pixelFormat
            }
        }
    }
}
