//
//  GeometryMesh.swift
//  common
//
//  Created by Jacob Su on 4/23/21.
//

import Foundation
import MetalKit
import simd

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
                                     radius: Float = 1.0,
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
        let icosaHedronMesh = MDLMesh.newIcosahedron(withRadius: radius,
                                                     inwardNormals: inwardNormals,
                                                     geometryType: geometryType,
                                                     allocator: metalAllocator)
        icosaHedronMesh.vertexDescriptor = modelIOVertexDescriptor
        
        return try MTKMesh(mesh: icosaHedronMesh, device: device)
    }
    
    public class func newCylinder(withVertexDescriptor vertexDescriptor: MTLVertexDescriptor,
                                  withAttributesMap attributesMap: [Int: String],
                                  withDevice device: MTLDevice,
                                  height: Float = 1.0,
                                  radii: vector_float2 = vector_float2(0.5, 0.5),
                                  radialSegments: Int = 60,
                                  verticalSegments: Int = 60,
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
    
        let cylinder = MDLMesh.newCylinder(withHeight: height,
                                           radii: radii,
                                           radialSegments: radialSegments,
                                           verticalSegments: verticalSegments,
                                           geometryType: geometryType,
                                           inwardNormals: inwardNormals,
                                           allocator: metalAllocator)
        cylinder.vertexDescriptor = modelIOVertexDescriptor
        
        return try MTKMesh(mesh: cylinder, device: device)
    }
    
    public class func newEllipsoid(withVertexDescriptor vertexDescriptor: MTLVertexDescriptor,
                                   withAttributesMap attributesMap: [Int: String],
                                   withDevice device: MTLDevice,
                                   radii: vector_float3 = vector_float3(1.0, 1.0, 1.0),
                                   radialSegments: Int = 60,
                                   verticalSegments: Int = 60,
                                   geometryType: MDLGeometryType = .triangles,
                                   inwardNormals: Bool = false,
                                   hemisphere: Bool = false) throws -> MTKMesh {
        if !checkVertexDescriptor(vertexAttributesMap: attributesMap) {
            throw Errors.runtimeError("vertex Descriptor invalid. \(attributesMap)")
        }
        
        let modelIOVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)
        for attr in attributesMap {
            (modelIOVertexDescriptor.attributes[attr.key] as! MDLVertexAttribute).name = attr.value
        }
        
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        let ellipsoidMesh = MDLMesh.newEllipsoid(withRadii: radii,
                                                 radialSegments: radialSegments,
                                                 verticalSegments: verticalSegments,
                                                 geometryType: geometryType,
                                                 inwardNormals: inwardNormals,
                                                 hemisphere: hemisphere,
                                                 allocator: metalAllocator)
        ellipsoidMesh.vertexDescriptor = modelIOVertexDescriptor
        
        return try MTKMesh(mesh: ellipsoidMesh, device: device)
    }
    
    public class func newSphere(withVertexDescriptor vertexDescriptor: MTLVertexDescriptor,
                                withAttributesMap attributesMap: [Int: String],
                                withDevice device: MTLDevice,
                                radii: Float = 1.0,
                                radialSegments: Int = 60,
                                verticalSegments: Int = 60,
                                geometryType: MDLGeometryType = .triangles,
                                inwardNormals: Bool = false,
                                hemisphere: Bool = false) throws -> MTKMesh {
        return try newEllipsoid(withVertexDescriptor: vertexDescriptor,
                            withAttributesMap: attributesMap,
                            withDevice: device,
                            radii: vector_float3(repeating: radii),
                            radialSegments: radialSegments,
                            verticalSegments: verticalSegments,
                            geometryType: geometryType,
                            inwardNormals: inwardNormals,
                            hemisphere: hemisphere)
    }
    
    public class func newEllipticalCone(
                          withVertexDescriptor vertexDescriptor: MTLVertexDescriptor,
                          withAttributesMap attributesMap: [Int: String],
                          withDevice device: MTLDevice,
                          height: Float = 1.0,
                          radii: vector_float2 = vector_float2(1.0, 1.0),
                          radialSegments: Int = 60,
                          verticalSegments: Int = 60,
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
    
        let ellipticalCone = MDLMesh.newEllipticalCone(withHeight: height,
                                  radii: radii,
                                  radialSegments: radialSegments,
                                  verticalSegments: verticalSegments,
                                  geometryType: geometryType,
                                  inwardNormals: inwardNormals,
                                  allocator: metalAllocator)
        ellipticalCone.vertexDescriptor = modelIOVertexDescriptor
        
        return try MTKMesh(mesh: ellipticalCone, device: device)
    }
    
    public class func newCapsule(withVertexDescriptor vertexDescriptor: MTLVertexDescriptor,
                                 withAttributesMap attributesMap: [Int: String],
                                 withDevice device: MTLDevice,
                                 height: Float = 1.0,
                                 radii: vector_float2 = vector_float2(0.5, 0.5),
                                 radialSegments: Int = 60,
                                 verticalSegments: Int = 60,
                                 hemisphereSegments: Int = 60,
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
    
        let capsule = MDLMesh.newCapsule(withHeight: height,
                                         radii: radii,
                                         radialSegments: radialSegments,
                                         verticalSegments: verticalSegments,
                                         hemisphereSegments: hemisphereSegments,
                                         geometryType: geometryType,
                                         inwardNormals: inwardNormals,
                                         allocator: metalAllocator)
        capsule.vertexDescriptor = modelIOVertexDescriptor
        
        return try MTKMesh(mesh: capsule, device: device)
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
    
    public func draw(inRenderCommandEncoder encoder: MTLRenderCommandEncoder, instanceCount: Int) {
        for subMesh in submeshes {
            encoder.drawIndexedPrimitives(type: subMesh.primitiveType,
                                          indexCount: subMesh.indexCount,
                                          indexType: subMesh.indexType,
                                          indexBuffer: subMesh.indexBuffer.buffer,
                                          indexBufferOffset: subMesh.indexBuffer.offset,
                                          instanceCount: instanceCount)
        }
    }
    
}

