//
//  MetalMesh.swift
//  common
//
//  Created by Jacob Su on 3/19/21.
//

import Foundation
import Metal
import MetalKit

//public class MetalMesh {
//
//    fileprivate let mesh: MTKMesh
//    fileprivate let index: Int
//
//    public init(mesh: MTKMesh, index: Int) {
//        self.mesh = mesh
//        self.index = index
//    }
//
//}

@objc
extension MTKMesh {
    public class func newBox(withVertexDescriptor vertexDescriptor: MTLVertexDescriptor,
                             withAttributesMap attributesMap: [Int: String],
                             withDevice device: MTLDevice,
                             withDimensions dimensions: vector_float3 = vector_float3(1.0, 1.0, 1.0),
                             segments: vector_uint3 = vector_uint3(1, 1, 1),
                             geometryType: MDLGeometryType = .triangles,
                             inwardNormals: Bool = false) throws -> MTKMesh {
        if !checkVertexDescriptor(vertexAttributesMap: attributesMap) {
            throw Errors.runtimeError("vertex Descriptor invalid. \(attributesMap)")
        }
        
        let modelIOVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)
        for attr in attributesMap {
            (modelIOVertexDescriptor.attributes[attr.key] as! MDLVertexAttribute).name = attr.value
        }
        
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        let cubeMDLMesh = MDLMesh.newBox(withDimensions: dimensions,
                                  segments: segments,
                                  geometryType: geometryType,
                                  inwardNormals: inwardNormals,
                                  allocator: metalAllocator)
        
        cubeMDLMesh.vertexDescriptor = modelIOVertexDescriptor
        
        return try MTKMesh(mesh: cubeMDLMesh, device: device)
    }
    
    public class func newPlane(withVertexDescriptor vertexDescriptor: MTLVertexDescriptor,
                               withAttributesMap attributesMap: [Int: String],
                               withDevice device: MTLDevice,
                               withDimensions dimensions: vector_float2 = vector_float2(1.0, 1.0),
                               segments: vector_uint2 = vector_uint2(1, 1),
                               geometryType: MDLGeometryType = .triangles,
                               inwardNormals: Bool = false) throws -> MTKMesh {
        if !checkVertexDescriptor(vertexAttributesMap: attributesMap) {
            throw Errors.runtimeError("vertex Descriptor invalid. \(attributesMap)")
        }
        
        let modelIOVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)
        for attr in attributesMap {
            (modelIOVertexDescriptor.attributes[attr.key] as! MDLVertexAttribute).name = attr.value
        }
        
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        let cubeMDLMesh = MDLMesh.newPlane(withDimensions: dimensions,
                                  segments: segments,
                                  geometryType: geometryType,
                                  allocator: metalAllocator)
        
        cubeMDLMesh.vertexDescriptor = modelIOVertexDescriptor
        
        return try MTKMesh(mesh: cubeMDLMesh, device: device)
    }
    
    public class func newIcosahedron(withVertexDescriptor vertexDescriptor: MTLVertexDescriptor,
                                     withAttributesMap attributesMap: [Int: String],
                                     withDevice device: MTLDevice,
                                     radius: Float,
                                     inwardNormals: Bool) throws -> MTKMesh {
        throw Errors.runtimeError("not implemented yet.")
    }
    
    public class func newCylinder(withVertexDescriptor vertexDescriptor: MTLVertexDescriptor,
                                  withAttributesMap attributesMap: [Int: String],
                                  withDevice device: MTLDevice,
                                  height: Float,
                                  radii: vector_float2,
                                  radialSegments: Int,
                                  verticalSegments: Int,
                                  geometryType: MDLGeometryType,
                                  inwardNormals: Bool) throws -> MTKMesh {
        throw Errors.runtimeError("not implemented yet.")
    }
    
    public class func newEllipsoid(withVertexDescriptor vertexDescriptor: MTLVertexDescriptor,
                                   withAttributesMap attributesMap: [Int: String],
                                   withDevice device: MTLDevice,
                                   radii: vector_float3,
                                   radialSegments: Int,
                                   verticalSegments: Int,
                                   geometryType: MDLGeometryType,
                                   inwardNormals: Bool,
                                   hemisphere: Bool) throws -> MTKMesh {
        throw Errors.runtimeError("not implemented yet.")
    }
    
    public class func newEllipticalCone(
                          withVertexDescriptor vertexDescriptor: MTLVertexDescriptor,
                          withAttributesMap attributesMap: [Int: String],
                          withDevice device: MTLDevice,
                          height: Float,
                          radii: vector_float2,
                          radialSegments: Int,
                          verticalSegments: Int,
                          geometryType: MDLGeometryType,
                          inwardNormals: Bool) throws -> MTKMesh {
        throw Errors.runtimeError("not implemented yet.")
    }
    
    public class func newCapsule(withVertexDescriptor vertexDescriptor: MTLVertexDescriptor,
                                 withAttributesMap attributesMap: [Int: String],
                                 withDevice device: MTLDevice,
                                 height: Float,
                                 radii: vector_float2,
                                 radialSegments: Int,
                                 verticalSegments: Int,
                                 hemisphereSegments: Int,
                                 geometryType: MDLGeometryType,
                                 inwardNormals: Bool) throws -> MTKMesh {
        throw Errors.runtimeError("not implemented yet.")
    }
    
    private class func checkVertexDescriptor(vertexAttributesMap: Dictionary<Int, String>) -> Bool {
        for name in vertexAttributesMap.values {
            if name != MDLVertexAttributePosition &&
                name != MDLVertexAttributeTextureCoordinate &&
                name != MDLVertexAttributeNormal &&
                name != MDLVertexAttributeBinormal &&
                name != MDLVertexAttributeColor &&
                name != MDLVertexAttributeTangent &&
                name != MDLVertexAttributeBitangent &&
                name != MDLVertexAttributeAnisotropy &&
                name != MDLVertexAttributeEdgeCrease &&
                name != MDLVertexAttributeOcclusionValue &&
                name != MDLVertexAttributeJointIndices &&
                name != MDLVertexAttributeJointWeights &&
                name != MDLVertexAttributeSubdivisionStencil &&
                name != MDLVertexAttributeShadingBasisU &&
                name != MDLVertexAttributeShadingBasisV {
                
                return false
            }
        }
        
        return vertexAttributesMap.count > 0
    }
    
    public func setVertexBuffer(inRenderCommandEncoder encoder: MTLRenderCommandEncoder, index: Int) {
        for vertexBuffer in vertexBuffers {
            encoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: index)
        }
    }
    
    public func draw(inRenderCommandEncoder encoder: MTLRenderCommandEncoder) {
        for subMesh in submeshes {
            encoder.drawIndexedPrimitives(type: subMesh.primitiveType,
                                          indexCount: subMesh.indexCount,
                                          indexType: subMesh.indexType,
                                          indexBuffer: subMesh.indexBuffer.buffer,
                                          indexBufferOffset: subMesh.indexBuffer.offset)
        }
    }
}

extension MTLRenderCommandEncoder {
    // TODO: remove offset
    public func setVertexMeshBuffer(_ mesh: MTKMesh, index: Int, offset: Int = 0) {
        for vertexBuffer in mesh.vertexBuffers {
            setVertexBuffer(vertexBuffer.buffer, offset: offset + vertexBuffer.offset, index: index)
        }
    }
    
    public func drawMesh(_ mesh: MTKMesh) {
        for subMesh in mesh.submeshes {
            drawIndexedPrimitives(type: subMesh.primitiveType,
                                  indexCount: subMesh.indexCount,
                                  indexType: subMesh.indexType,
                                  indexBuffer: subMesh.indexBuffer.buffer,
                                  indexBufferOffset: subMesh.indexBuffer.offset)
        }
    }
}
