//
//  GeometryMesh+Lines.swift
//  common
//
//  Created by Jacob Su on 4/30/21.
//

import Foundation
import MetalKit
import simd

@objc
extension MTKMesh {
    
    public class func new3DLines(withVertexDescriptor vertexDescriptor: MTLVertexDescriptor,
                                 withAttributesMap attributesMap: [Int: String],
                                 device: MTLDevice,
                                 rawPtr: UnsafeRawPointer,
                                 count: Int,
                                 radii: Float = 0.1,
                                 radialSegments: Int = 60,
                                 geometryType: MDLGeometryType = .triangles,
                                 inwardNormals: Bool = false) throws -> MTKMesh {
        let isAttributesInvalide = attributesMap.values.contains(where: { name in
            name != MDLVertexAttributePosition &&
            name != MDLVertexAttributeNormal
        })
        
        if isAttributesInvalide {
            throw Errors.runtimeError("Attribute only support Position & Normal")
        }
        
        var vertices: [vector_float3] = []
        var normals: [vector_float3] = []
        var indices: [UInt32] = []
        
        var circlePoints: [vector_float3] = []
        
        for i in 0..<radialSegments {
            let x = cos(Float.pi * 2.0 * Float(i) / Float(radialSegments)) * radii
            let y = sin(Float.pi * 2.0 * Float(i) / Float(radialSegments)) * radii
            circlePoints.append(vector_float3(x, y, 0))
        }
        
        var float3Point = rawPtr.assumingMemoryBound(to: vector_float3.self)
        
        let a = float3Point.pointee
        let b = float3Point.advanced(by: 1).pointee
        float3Point = float3Point.advanced(by: 1)
        let ab = normalize(a - b)
        
        let rotateAxi = normalize(cross(ab, vector_float3(0, 0, 1.0)))
        let rotateRadiant = acos(dot(ab, vector_float3(0, 0, 1.0)))
        
        let mat = matrix_multiply(matrix4x4_translation(a), matrix4x4_rotation(Float.pi * 2.0 - rotateRadiant, rotateAxi))
        
        circlePoints.forEach {
            let t = mat * vector_float4($0, 1.0)
            let vert = vector_float3(t.x, t.y, t.z)
            // verties
            vertices.append(vert)
            normals.append(normalize(inwardNormals ? a - vert : vert - a))
        }
        
        for _ in 1..<count {
            let a = float3Point.pointee
            let b = float3Point.advanced(by: -1).pointee
            float3Point = float3Point.advanced(by: 1)
            let ab = normalize(b - a)
            
            let rotateAxi = normalize(cross(ab, vector_float3(0, 0, 1.0)))
            let rotateRadiant = acos(dot(ab, vector_float3(0, 0, 1.0)))
            
            let mat = matrix_multiply(matrix4x4_translation(a), matrix4x4_rotation(Float.pi * 2.0 - rotateRadiant, rotateAxi))
            
            let prevCircleStartIndex = vertices.count - radialSegments
            for (i, point) in circlePoints.enumerated() {
                let t = mat * vector_float4(point, 1.0)
                let prevCircleIdx = prevCircleStartIndex + i
                let vert = vector_float3(t.x, t.y, t.z)
                
                vertices.append(vert)
                normals.append(normalize(inwardNormals ? a - vert : vert - a))
                
                if i > 0 {
                    indices.append(contentsOf: [UInt32(prevCircleIdx), UInt32(prevCircleIdx + radialSegments), UInt32(prevCircleIdx + radialSegments - 1),
                                                UInt32(prevCircleIdx - 1), UInt32(prevCircleIdx), UInt32(prevCircleIdx + radialSegments - 1)])
                }
            }
            
            indices.append(contentsOf: [UInt32(vertices.count - radialSegments), UInt32(vertices.count - 1), UInt32(vertices.count - radialSegments - 1),
                                        UInt32(vertices.count - radialSegments - 1), UInt32(vertices.count - 2 * radialSegments), UInt32(vertices.count - radialSegments)])
        }
        
        // allocate data
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        
        let vertiesPtr = UnsafeMutableRawPointer.allocate(byteCount: vertices.count * 16 * attributesMap.count, alignment: 1)
        defer {
            vertiesPtr.deallocate()
        }
        
        for i in 0..<vertices.count {
            let dataPtr = vertiesPtr.advanced(by: i * 16 * attributesMap.count)
            for j in 0..<attributesMap.count {
                if attributesMap[j] == MDLVertexAttributePosition {
                    withUnsafePointer(to: vertices[i]) {
                        dataPtr.advanced(by: j * 16).copyMemory(from: $0, byteCount: MemoryLayout<vector_float3>.stride)
                    }
                } else if attributesMap[j] == MDLVertexAttributeNormal {
                    withUnsafePointer(to: normals[i]) {
                        dataPtr.advanced(by: j * 16).copyMemory(from: $0, byteCount: MemoryLayout<vector_float3>.stride)
                    }
                }
            }
        }
        
        let vertiesData = Data(bytes: vertiesPtr, count: vertices.count * 16 * attributesMap.count)
        
        let vertexBuffer = metalAllocator.newBuffer(with: vertiesData, type: .vertex)
        
        let indexData = Data(bytes: indices, count: MemoryLayout<Int32>.stride * indices.count)
        let indexBuffer = metalAllocator.newBuffer(with: indexData, type: .index)
        
        let submesh = MDLSubmesh(indexBuffer: indexBuffer, indexCount: indices.count, indexType: .uInt32, geometryType: geometryType, material: nil)
        
        let modelIOVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)
        for attr in attributesMap {
            (modelIOVertexDescriptor.attributes[attr.key] as! MDLVertexAttribute).name = attr.value
        }
        
        let linesMesh = MDLMesh(vertexBuffer: vertexBuffer,
                                vertexCount: vertices.count,
                                descriptor: modelIOVertexDescriptor,
                                submeshes: [submesh])
        
        return try MTKMesh(mesh: linesMesh, device: device)
    }
    
    public class func newCubicBezier3DCurve(withVertexDescriptor vertexDescriptor: MTLVertexDescriptor,
                                          withAttributesMap attributesMap: [Int: String],
                                          device: MTLDevice,
                                          rawPtr: UnsafeRawPointer,
                                          count: Int,
                                          lineSegments: Int = 20,
                                          radii: Float = 0.01,
                                          radialSegments: Int = 60,
                                          geometryType: MDLGeometryType = .triangles,
                                          inwardNormals: Bool = false) throws -> MTKMesh {
        let isAttributesInvalide = attributesMap.values.contains(where: { name in
            name != MDLVertexAttributePosition &&
            name != MDLVertexAttributeNormal
        })
        
        if isAttributesInvalide {
            throw Errors.runtimeError("Attribute only support Position & Normal")
        }
        
        try attributesMap.forEach { (key, value) in
            let format = vertexDescriptor.attributes[key].format
            if format != .float3 {
                throw Errors.runtimeError("3D beizer curve don't support vertex format \(format) ")
            }
        }
        
        var points: [vector_float3] = []
        
        var float3Ptr = rawPtr.assumingMemoryBound(to: vector_float3.self)
        
        var p0 = float3Ptr.pointee
        var c0 = float3Ptr.advanced(by: 1).pointee
        var c1 = float3Ptr.advanced(by: 2).pointee
        var p1 = float3Ptr.advanced(by: 3).pointee
        float3Ptr = float3Ptr.advanced(by: 4)
        
        for i in 0...lineSegments {
            points.append(getCubicBeizerPoint(t: Float(i) / Float(lineSegments), p0: p0, c0: c0, c1: c1, p1: p1))
        }
        
        
        var index = 3
        while index < (count - 2){
            p0 = p1
            c0 = p1 - c1 + p1
            c1 = float3Ptr.pointee
            p1 = float3Ptr.advanced(by: 1).pointee
            float3Ptr = float3Ptr.advanced(by: 2)
            
            for i in 0...lineSegments {
                points.append(getCubicBeizerPoint(t: Float(i) / Float(lineSegments), p0: p0, c0: c0, c1: c1, p1: p1))
            }
            
            index += 2
        }
        
        return try new3DLines(withVertexDescriptor: vertexDescriptor,
                              withAttributesMap: attributesMap,
                              device: device,
                              rawPtr: points,
                              count: points.count,
                              radii: radii,
                              radialSegments: radialSegments,
                              geometryType: geometryType,
                              inwardNormals: inwardNormals)
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
