//
//  JsonMesh.swift
//  common
//
//  Created by Jacob Su on 4/26/21.
//

import Foundation
import Metal
import MetalKit

@objc
public class JsonMesh: NSObject {
    public private(set) var mtkMesh: MTKMesh!
    
    public private(set) var baseColorTextures: [String : MTLTexture]! = [:]
    
    public private(set) var specularTextures: [String : MTLTexture]! = [:]
    
    @objc
    public init(withJson jsonURL: URL,
                withTexture textureURL: URL,
                device: MTLDevice,
                mtlVertexDescriptor: MTLVertexDescriptor,
                attributesMap: [Int : String]) throws {
        let jsonData = try Data(contentsOf: jsonURL, options: .mappedIfSafe)
        let jsonResult = try JSONSerialization.jsonObject(with: jsonData, options: .mutableLeaves)
        
        let dict = jsonResult as! Dictionary<String, Array<NSNumber>>

        let positions = dict["position"]!
        let uvs = dict["uv"]!
        let normals = dict["normal"]!
                
        let textureLoader = MTKTextureLoader(device: device)
        let colorTexture = try textureLoader.newTexture(URL: textureURL, options: nil)
        baseColorTextures[jsonURL.path] = colorTexture
        
        let isAttributesInvalide = attributesMap.values.contains(where: { name in
            name != MDLVertexAttributePosition &&
            name != MDLVertexAttributeNormal &&
            name != MDLVertexAttributeTextureCoordinate
        })
        
        if isAttributesInvalide {
            throw Errors.runtimeError("Attribute only support Position, Normal & TexCoordinate")
        }
        
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        
        let vertiesCount = positions.count / 3
        let vertiesPtr = UnsafeMutableRawPointer.allocate(byteCount: vertiesCount * 16 * attributesMap.count, alignment: 1)
        defer {
            vertiesPtr.deallocate()
        }
        
        for i in 0..<vertiesCount {
            let dataPtr = vertiesPtr.advanced(by: i * 16 * attributesMap.count)
            for j in 0..<attributesMap.count {
                if attributesMap[j] == MDLVertexAttributePosition {
                    let x = positions[i * 3].floatValue
                    let y = positions[i * 3 + 1].floatValue
                    let z = positions[i * 3 + 2].floatValue
                    let position = vector_float3(x, y, z)
                    withUnsafePointer(to: position) {
                        dataPtr.advanced(by: j * 16).copyMemory(from: $0,
                                                                byteCount: MemoryLayout<vector_float3>.stride)
                    }
                } else if attributesMap[j] == MDLVertexAttributeNormal {
                    let x = normals[i * 3].floatValue
                    let y = normals[i * 3 + 1].floatValue
                    let z = normals[i * 3 + 2].floatValue
                    let normal = vector_float3(x, y, z)
                    withUnsafePointer(to: normal) {
                        dataPtr.advanced(by: j * 16).copyMemory(from: $0, byteCount: MemoryLayout<vector_float3>.stride)
                    }
                } else if attributesMap[j] == MDLVertexAttributeTextureCoordinate {
                    let x = uvs[i * 2].floatValue
                    let y = 1.0 - uvs[i * 2 + 1].floatValue
                    let uv = vector_float2(x, y)
                    withUnsafePointer(to: uv) {
                        dataPtr.advanced(by: j * 16).copyMemory(from: $0, byteCount: MemoryLayout<vector_float2>.stride)
                    }
                }
            }
        }
        
        let vertiesData = Data(bytes: vertiesPtr, count: vertiesCount * 16 * attributesMap.count)
        
        let vertexBuffer = metalAllocator.newBuffer(with: vertiesData, type: .vertex)
        
        let numIndices = vertiesCount
        let indices: [UInt32] = Array(UInt32(0)..<UInt32(numIndices))
        let indexData = Data(bytes: indices, count: MemoryLayout<Int32>.stride * indices.count)
        let indexBuffer = metalAllocator.newBuffer(with: indexData, type: .index)
        
        let submesh = MDLSubmesh(indexBuffer: indexBuffer, indexCount: indices.count, indexType: .uInt32, geometryType: .triangles, material: nil)
        submesh.name = jsonURL.path
        
        let modelIOVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)
        for attr in attributesMap {
            (modelIOVertexDescriptor.attributes[attr.key] as! MDLVertexAttribute).name = attr.value
        }
        
        let mdlMesh = MDLMesh(vertexBuffer: vertexBuffer,
                                vertexCount: vertiesCount,
                                descriptor: modelIOVertexDescriptor,
                                submeshes: [submesh])
        mtkMesh = try MTKMesh(mesh: mdlMesh, device: device)
    }
}

extension JsonMesh: MetalMesh {

    public func setVertexMeshTo(renderEncoder: MTLRenderCommandEncoder, index: Int) {
        renderEncoder.setVertexMesh(self, index: index)
    }
    
    public func drawMeshTo(renderEncoder: MTLRenderCommandEncoder, textureHandler: ((MDLMaterialSemantic, MTLTexture, String) -> Void)?) {
        renderEncoder.drawMesh(self, textureHandler: textureHandler)

    }

}
