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
    
    public class func newLines(withVertexDescriptor vertexDescriptor: MTLVertexDescriptor,
                               withAttributesMap attributesMap: [Int: String],
                               rawPtr: UnsafeRawPointer,
                               count: Int,
                               device: MTLDevice) throws -> MTKMesh {
        if attributesMap.count != 1 ||
            attributesMap.first?.value != MDLVertexAttributePosition {
            throw Errors.runtimeError("Lines only support Position attribute.")
        }
        
        var pointStride: Int = 0
        let format = vertexDescriptor.attributes[attributesMap.first!.key].format
        
        switch format {
        case .float:
            pointStride = MemoryLayout<Float>.stride
        case .float2:
            pointStride = MemoryLayout<vector_float2>.stride
        case .float3:
            pointStride = MemoryLayout<vector_float3>.stride
        case .float4:
            pointStride = MemoryLayout<vector_float4>.stride
        default:
            throw Errors.runtimeError("can not recognized format \(format)")
        }
        
        let metalAllocator = MTKMeshBufferAllocator(device: device)

        let linesData = Data(bytes: rawPtr, count: count * pointStride)
        
        let vertexBuffer = metalAllocator.newBuffer(with: linesData, type: .vertex)
        var indexes: [UInt32] = Array(repeating: 0, count: (count - 1) * 2)
        for i in 0..<(count-1) {
            indexes[i * 2] = UInt32(i)
            indexes[i * 2 + 1] = UInt32(i) + 1
        }
        
        let indexData = Data(bytes: indexes, count: indexes.count * MemoryLayout<UInt32>.stride)

        let indexBuffer = metalAllocator.newBuffer(with: indexData, type: .index)
        
        let submesh = MDLSubmesh(indexBuffer: indexBuffer, indexCount: indexes.count, indexType: .uInt32, geometryType: .lines, material: nil)
        
        let modelIOVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)
        for attr in attributesMap {
            (modelIOVertexDescriptor.attributes[attr.key] as! MDLVertexAttribute).name = attr.value
        }
        
        let linesMesh = MDLMesh(vertexBuffer: vertexBuffer,
                                vertexCount: count,
                                descriptor: modelIOVertexDescriptor,
                                submeshes: [submesh])
        
        return try MTKMesh(mesh: linesMesh, device: device)
    }
    
    public class func newCubicBezierCurve(withVertexDescriptor vertexDescriptor: MTLVertexDescriptor,
                                          withAttributesMap attributesMap: [Int: String],
                                          rawPtr: UnsafeRawPointer,
                                          count: Int,
                                          segments: Int,
                                          device: MTLDevice) throws -> MTKMesh {
        if attributesMap.count != 1 ||
            attributesMap.first?.value != MDLVertexAttributePosition {
            throw Errors.runtimeError("Lines only support Position attribute.")
        }
        
        switch vertexDescriptor.attributes[attributesMap.first!.key].format {
        case .float2:
            return try newCubicBezierCurve2D(withVertexDescriptor: vertexDescriptor,
                                             withAttributesMap: attributesMap,
                                             rawPtr: rawPtr,
                                             count: count,
                                             segments: segments,
                                             device: device)
        case .float3:
            return try newCubicBezierCurve3D(withVertexDescriptor: vertexDescriptor,
                                             withAttributesMap: attributesMap,
                                             rawPtr: rawPtr,
                                             count: count,
                                             segments: segments,
                                             device: device)
        default:
            throw Errors.runtimeError("can not recognized mtlVertexDescriptor attributes format")
        }
    }
    
    private class func newCubicBezierCurve2D(withVertexDescriptor vertexDescriptor: MTLVertexDescriptor,
                                             withAttributesMap attributesMap: [Int: String],
                                             rawPtr: UnsafeRawPointer,
                                             count: Int,
                                             segments: Int,
                                             device: MTLDevice) throws -> MTKMesh {
        if let key = attributesMap.first?.key {
            let format = vertexDescriptor.attributes[key].format
            if format != .float2 {
                throw Errors.runtimeError("2D beizer curve don't support vertex format \(format) ")
            }
        }
        
        if attributesMap.count != 1 ||
            attributesMap.first?.value != MDLVertexAttributePosition {
            throw Errors.runtimeError("Lines only support Position attribute.")
        }
        
        var points: [vector_float2] = []
        
        var float2Ptr = rawPtr.assumingMemoryBound(to: vector_float2.self)
        
        var p0 = float2Ptr.pointee
        var c0 = float2Ptr.advanced(by: 1).pointee
        var c1 = float2Ptr.advanced(by: 2).pointee
        var p1 = float2Ptr.advanced(by: 3).pointee
        float2Ptr = float2Ptr.advanced(by: 4)
        
        for i in 0...segments {
            points.append(getCubicBeizerPoint(t: Float(i) / Float(segments), p0: p0, c0: c0, c1: c1, p1: p1))
        }
        
        
        var index = 3
        while index < (count - 2){
            p0 = p1
            c0 = p1 - c1 + p1
            c1 = float2Ptr.pointee
            p1 = float2Ptr.advanced(by: 1).pointee
            float2Ptr = float2Ptr.advanced(by: 2)
            
            for i in 0...segments {
                points.append(getCubicBeizerPoint(t: Float(i) / Float(segments), p0: p0, c0: c0, c1: c1, p1: p1))
            }
            
            index += 2
        }
        
        return try newLines(withVertexDescriptor: vertexDescriptor,
                            withAttributesMap: attributesMap,
                            rawPtr: points,
                            count: points.count,
                            device: device)
    }
    
    private class func newCubicBezierCurve3D(withVertexDescriptor vertexDescriptor: MTLVertexDescriptor,
                                             withAttributesMap attributesMap: [Int: String],
                                             rawPtr: UnsafeRawPointer,
                                             count: Int,
                                             segments: Int,
                                             device: MTLDevice) throws -> MTKMesh {
        if let key = attributesMap.first?.key {
            let format = vertexDescriptor.attributes[key].format
            if format != .float3 {
                throw Errors.runtimeError("3D beizer curve don't support vertex format \(format) ")
            }
        }
        
        if attributesMap.count != 1 ||
            attributesMap.first?.value != MDLVertexAttributePosition {
            throw Errors.runtimeError("Lines only support Position attribute.")
        }
        
        var points: [vector_float3] = []
        
        var float3Ptr = rawPtr.assumingMemoryBound(to: vector_float3.self)
        
        var p0 = float3Ptr.pointee
        var c0 = float3Ptr.advanced(by: 1).pointee
        var c1 = float3Ptr.advanced(by: 2).pointee
        var p1 = float3Ptr.advanced(by: 3).pointee
        float3Ptr = float3Ptr.advanced(by: 4)
        
        for i in 0...segments {
            points.append(getCubicBeizerPoint(t: Float(i) / Float(segments), p0: p0, c0: c0, c1: c1, p1: p1))
        }
        
        
        var index = 3
        while index < (count - 2){
            p0 = p1
            c0 = p1 - c1 + p1
            c1 = float3Ptr.pointee
            p1 = float3Ptr.advanced(by: 1).pointee
            float3Ptr = float3Ptr.advanced(by: 2)
            
            for i in 0...segments {
                points.append(getCubicBeizerPoint(t: Float(i) / Float(segments), p0: p0, c0: c0, c1: c1, p1: p1))
            }
            
            index += 2
        }
        
        return try newLines(withVertexDescriptor: vertexDescriptor,
                            withAttributesMap: attributesMap,
                            rawPtr: points,
                            count: points.count,
                            device: device)
    }
    
    public class func newQuadraticBezierCurve(withVertexDescriptor vertexDescriptor: MTLVertexDescriptor,
                               withAttributesMap attributesMap: [Int: String],
                               rawPtr: UnsafeRawPointer,
                               count: Int,
                               segments: Int,
                               device: MTLDevice) throws -> MTKMesh {
        if attributesMap.count != 1 ||
            attributesMap.first?.value != MDLVertexAttributePosition {
            throw Errors.runtimeError("Lines only support Position attribute.")
        }
                
        let format = vertexDescriptor.attributes[attributesMap.first!.key].format
        
        switch format {
        case .float2:
            return try newQuadraticBezierCurve2D(withVertexDescriptor: vertexDescriptor,
                                             withAttributesMap: attributesMap,
                                             rawPtr: rawPtr,
                                             count: count,
                                             segments: segments,
                                             device: device)
        case .float3:
            return try newQuadraticBezierCurve3D(withVertexDescriptor: vertexDescriptor,
                                             withAttributesMap: attributesMap,
                                             rawPtr: rawPtr,
                                             count: count,
                                             segments: segments,
                                             device: device)
        default:
            throw Errors.runtimeError("can not recognized format \(format)")
        }
        
    }
    
    private class func newQuadraticBezierCurve2D(withVertexDescriptor vertexDescriptor: MTLVertexDescriptor,
                               withAttributesMap attributesMap: [Int: String],
                               rawPtr: UnsafeRawPointer,
                               count: Int,
                               segments: Int,
                               device: MTLDevice) throws -> MTKMesh {
        if let key = attributesMap.first?.key {
            let format = vertexDescriptor.attributes[key].format
            if format != .float2 {
                throw Errors.runtimeError("2D beizer curve don't support vertex format \(format) ")
            }
        }
        
        if attributesMap.count != 1 ||
            attributesMap.first?.value != MDLVertexAttributePosition {
            throw Errors.runtimeError("Lines only support Position attribute.")
        }
        
        var points: [vector_float2] = []
        
        var float2Ptr = rawPtr.assumingMemoryBound(to: vector_float2.self)
        
        var p0 = float2Ptr.pointee
        var c0 = float2Ptr.advanced(by: 1).pointee
        var p1 = float2Ptr.advanced(by: 2).pointee
        float2Ptr = float2Ptr.advanced(by: 3)
        
        for i in 0...segments {
            points.append(getQuadraticBeizerPoint(t: Float(i) / Float(segments), p0: p0, c0: c0, p1: p1))
        }
        
        
        var index = 2
        while index < (count - 1){
            p0 = p1
            c0 = p1 - c0 + p1
            p1 = float2Ptr.pointee
            float2Ptr = float2Ptr.advanced(by: 1)
            
            for i in 0...segments {
                points.append(getQuadraticBeizerPoint(t: Float(i) / Float(segments), p0: p0, c0: c0, p1: p1))
            }
            
            index += 1
        }
        
        return try newLines(withVertexDescriptor: vertexDescriptor,
                            withAttributesMap: attributesMap,
                            rawPtr: points,
                            count: points.count,
                            device: device)
    }
    
    private class func newQuadraticBezierCurve3D(withVertexDescriptor vertexDescriptor: MTLVertexDescriptor,
                               withAttributesMap attributesMap: [Int: String],
                               rawPtr: UnsafeRawPointer,
                               count: Int,
                               segments: Int,
                               device: MTLDevice) throws -> MTKMesh {
        if let key = attributesMap.first?.key {
            let format = vertexDescriptor.attributes[key].format
            if format != .float3 {
                throw Errors.runtimeError("2D beizer curve don't support vertex format \(format) ")
            }
        }
        
        if attributesMap.count != 1 ||
            attributesMap.first?.value != MDLVertexAttributePosition {
            throw Errors.runtimeError("Lines only support Position attribute.")
        }
        
        var points: [vector_float3] = []
        
        var float3Ptr = rawPtr.assumingMemoryBound(to: vector_float3.self)
        
        var p0 = float3Ptr.pointee
        var c0 = float3Ptr.advanced(by: 1).pointee
        var p1 = float3Ptr.advanced(by: 2).pointee
        float3Ptr = float3Ptr.advanced(by: 3)
        
        for i in 0...segments {
            points.append(getQuadraticBeizerPoint(t: Float(i) / Float(segments), p0: p0, c0: c0, p1: p1))
        }
        
        
        var index = 2
        while index < (count - 1){
            p0 = p1
            c0 = p1 - c0 + p1
            p1 = float3Ptr.pointee
            float3Ptr = float3Ptr.advanced(by: 1)
            
            for i in 0...segments {
                points.append(getQuadraticBeizerPoint(t: Float(i) / Float(segments), p0: p0, c0: c0, p1: p1))
            }
            
            index += 1
        }
        
        return try newLines(withVertexDescriptor: vertexDescriptor,
                            withAttributesMap: attributesMap,
                            rawPtr: points,
                            count: points.count,
                            device: device)
    }
    
}

private func getQuadraticBeizerPoint(t: Float, p0: vector_float2, c0: vector_float2, p1: vector_float2) -> vector_float2 {
    let k = 1 - t
    let a0 = p0 * (k * k)
    let a1 = c0 * (2 * k * t)
    let a2 = p1 * (t * t)
    
    return a0 + a1 + a2
}

private func getQuadraticBeizerPoint(t: Float, p0: vector_float3, c0: vector_float3, p1: vector_float3) -> vector_float3 {
    let k = 1 - t
    let a0 = p0 * (k * k)
    let a1 = c0 * (2 * k * t)
    let a2 = p1 * (t * t)
    
    return a0 + a1 + a2
}

private func getCubicBeizerPoint(t: Float, p0: vector_float2, c0: vector_float2, c1: vector_float2, p1: vector_float2) -> vector_float2 {
    let k = 1 - t;
    let a0 = p0 * (k * k * k)
    let a1 = c0 * (3 * k * k * t)
    let a2 = c1 * (3 * k * t * t)
    let a3 = p1 * (t * t * t)
    
    return a0 + a1 + a2 + a3
}

private func getCubicBeizerPoint(t: Float, p0: vector_float3, c0: vector_float3, c1: vector_float3, p1: vector_float3) -> vector_float3 {
    let k = 1 - t;
    let a0 = p0 * (k * k * k)
    let a1 = c0 * (3 * k * k * t)
    let a2 = c1 * (3 * k * t * t)
    let a3 = p1 * (t * t * t)
    
    return a0 + a1 + a2 + a3
}
