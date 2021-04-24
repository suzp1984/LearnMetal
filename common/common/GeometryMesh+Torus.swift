//
//  GeometryMesh+Torus.swift
//  common
//
//  Created by Jacob Su on 4/24/21.
//

import Foundation
import MetalKit
import simd

@objc
extension MTKMesh {
    public class func newTorus(withVertexDescriptor vertexDescriptor: MTLVertexDescriptor,
                               withAttributesMap attributesMap: [Int: String],
                               withDevice device: MTLDevice,
                               radius: Float = 0.5,
                               tube: Float = 0.2,
                               radialSegments: Int = 8,
                               tubularSegments: Int = 6,
                               geometryType: MDLGeometryType = .triangles) throws -> MTKMesh {
        let isAttributesInvalide = attributesMap.values.contains(where: { name in
            name != MDLVertexAttributePosition &&
            name != MDLVertexAttributeNormal &&
            name != MDLVertexAttributeTextureCoordinate
        })
        
        if isAttributesInvalide {
            throw Errors.runtimeError("Attribute only support Position, Normal & TexCoordinate")
        }
        
        let num = (radialSegments + 1) * (tubularSegments + 1)
        let numIndices = radialSegments * tubularSegments * 6
        var vertices: [vector_float3] = Array(repeating: vector_float3(0.0, 0.0, 0.0), count: num)
        var normals : [vector_float3] = Array(repeating: vector_float3(0.0, 0.0, 0.0), count: num)
        var uvs     : [vector_float2] = Array(repeating: vector_float2(0.0, 0.0), count: num)
        
        var idx = 0
        for j in 0...radialSegments {
            for i in 0...tubularSegments {
                let u = (Float(i) / Float(tubularSegments)) * Float.pi * 2.0
                let v = (Float(j) / Float(radialSegments)) * Float.pi * 2.0
                
                // vertex
                let vx = (radius + tube * cos(v)) * cos(u)
                let vy = (radius + tube * cos(v)) * sin(u)
                let vz = tube * sin(v)
                
                vertices[idx] = vector_float3(vx, vy, vz)
                
                // normal
                let center = vector_float3(radius * cos(u), radius * sin(u), 0.0)
                normals[idx] = normalize(vector_float3(vx - center.x, vy - center.y, vz - center.z))
                
                // uv
                uvs[idx] = vector_float2(Float(i) / Float(tubularSegments), Float(j) / Float(radialSegments))
                
                idx += 1
            }
        }
        
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        
        let vertiesPtr = UnsafeMutableRawPointer.allocate(byteCount: num * 16 * attributesMap.count, alignment: 1)
        defer {
            vertiesPtr.deallocate()
        }
        
        for i in 0..<num {
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
                } else if attributesMap[j] == MDLVertexAttributeTextureCoordinate {
                    withUnsafePointer(to: uvs[i]) {
                        dataPtr.advanced(by: j * 16).copyMemory(from: $0, byteCount: MemoryLayout<vector_float2>.stride)
                    }
                }
            }
        }
        
        let vertiesData = Data(bytes: vertiesPtr, count: num * 16 * attributesMap.count)
        
        let vertexBuffer = metalAllocator.newBuffer(with: vertiesData, type: .vertex)
        
        var indices: [Int32] = Array(repeating: 0, count: numIndices)
        idx = 0
        for j in 1...radialSegments {
            for i in 1...tubularSegments {
                let a: Int = (tubularSegments + 1) * j + i - 1
                let b: Int = (tubularSegments + 1) * (j - 1) + i - 1
                let c: Int = (tubularSegments + 1) * (j - 1) + i
                let d: Int = (tubularSegments + 1) * j + i
                
                indices[idx] = Int32(a)
                indices[idx + 1] = Int32(b)
                indices[idx + 2] = Int32(d)
                indices[idx + 3] = Int32(b)
                indices[idx + 4] = Int32(c)
                indices[idx + 5] = Int32(d)

                idx += 6
            }
        }
        
        let indexData = Data(bytes: indices, count: MemoryLayout<Int32>.stride * indices.count)
        let indexBuffer = metalAllocator.newBuffer(with: indexData, type: .index)
        
        let submesh = MDLSubmesh(indexBuffer: indexBuffer, indexCount: indices.count, indexType: .uInt32, geometryType: geometryType, material: nil)
        
        let modelIOVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)
        for attr in attributesMap {
            (modelIOVertexDescriptor.attributes[attr.key] as! MDLVertexAttribute).name = attr.value
        }
        
        let torusMesh = MDLMesh(vertexBuffer: vertexBuffer,
                                vertexCount: num,
                                descriptor: modelIOVertexDescriptor,
                                submeshes: [submesh])
        
        return try MTKMesh(mesh: torusMesh, device: device)
    }
}
