//
//  MetalMesh.swift
//  common
//
//  Created by Jacob Su on 3/19/21.
//

import Foundation
import Metal
import MetalKit

public class MetalMesh : NSObject {

    fileprivate var mtkMesh: MTKMesh!
    fileprivate var baseColorTextures: [String : MTLTexture] = [:]
    fileprivate var specularTextures: [String : MTLTexture] = [:]
    fileprivate var texturesCache : [URL: MTLTexture] = [:]

    public init(withUrl url: URL,
                device: MTLDevice,
                mtlVertexDescriptor: MTLVertexDescriptor,
                attributeMap: [Int : String]) throws {
        // model io vertex descriptor
        let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)
        for attr in attributeMap {
            (mdlVertexDescriptor.attributes[attr.key] as! MDLVertexAttribute).name = attr.value
        }
        
        // mesh allocator
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        
        let mdlAsset = MDLAsset(url: url,
                                  vertexDescriptor: mdlVertexDescriptor,
                                  bufferAllocator: metalAllocator)
        
        var mdlMesh : MDLMesh? = nil
        
        for i in 0..<mdlAsset.count {
            guard let mdlObject = mdlAsset.object(at: i) as? MDLMesh else {
                continue
            }
            
            mdlMesh = mdlObject
            let textureLoader = MTKTextureLoader(device: device)
            
            for subMesh in mdlObject.submeshes! {
                guard let subMesh = subMesh as? MDLSubmesh else {
                    break
                }
                
                guard let material = subMesh.material else {
                    break
                }
                
                if let baseColorProperty = material.property(with: .baseColor),
                   let baseColorUrl = baseColorProperty.urlValue {
                    if !texturesCache.keys.contains(baseColorUrl),
                       let baseColorTexture = try? textureLoader.newTexture(URL: baseColorUrl, options: nil) {
                        texturesCache[baseColorUrl] = baseColorTexture
                        
                    }
                    
                    baseColorTextures[subMesh.name] = texturesCache[baseColorUrl]!
                }
                
                if let specularProperty = material.property(with: .specular),
                   let specularUrl = specularProperty.urlValue {
                    if !texturesCache.keys.contains(specularUrl),
                       let specularTexture = try? textureLoader.newTexture(URL: specularUrl, options: nil) {
                        texturesCache[specularUrl] = specularTexture
                    }
                    
                    specularTextures[subMesh.name] = texturesCache[specularUrl]!
                }
                
            }
            
            // only read first mdl mesh
            break
        }
        
        if mdlMesh == nil {
            throw Errors.runtimeError("can not read mdl mesh from \(url)")
        }
        
        mtkMesh = try! MTKMesh(mesh: mdlMesh!, device: device)
    }
    
    func getDiffuseTextures() -> [String : MTLTexture] {
        return baseColorTextures
    }
    
    func getSpecularTextures() -> [String : MTLTexture] {
        return specularTextures
    }

}

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
    public func setVertexMesh(_ mesh: MTKMesh, index: Int, offset: Int = 0) {
        for vertexBuffer in mesh.vertexBuffers {
            setVertexBuffer(vertexBuffer.buffer, offset: offset + vertexBuffer.offset, index: index)
        }
    }
    
    public func drawMesh(_ mesh: MTKMesh, instanceCount: Int? = nil) {
        for subMesh in mesh.submeshes {
            drawIndexedPrimitives(type: subMesh.primitiveType,
                                  indexCount: subMesh.indexCount,
                                  indexType: subMesh.indexType,
                                  indexBuffer: subMesh.indexBuffer.buffer,
                                  indexBufferOffset: subMesh.indexBuffer.offset,
                                  instanceCount: instanceCount ?? 1)
        }
    }
    
    public func setVertexMesh(_ mesh: MetalMesh, index: Int) {
        for buffer in mesh.mtkMesh.vertexBuffers {
            setVertexBuffer(buffer.buffer, offset: buffer.offset, index: index)
        }
    }
    
    public func drawMesh(_ mesh: MetalMesh, textureHandler: (_ type: MDLMaterialSemantic, _ texture: MTLTexture, _ subMeshName: String) -> Void) {
        for subMesh in mesh.mtkMesh.submeshes {
            if let diffuseTexture = mesh.baseColorTextures[subMesh.name] {
                textureHandler(.baseColor, diffuseTexture, subMesh.name)
            }
            
            if let specularTexture = mesh.specularTextures[subMesh.name] {
                textureHandler(.specular, specularTexture, subMesh.name)
            }

            drawIndexedPrimitives(type: subMesh.primitiveType,
                                  indexCount: subMesh.indexCount,
                                  indexType: subMesh.indexType,
                                  indexBuffer: subMesh.indexBuffer.buffer,
                                  indexBufferOffset: subMesh.indexBuffer.offset)
        }
    }
    
    public func drawMesh(_ mesh: MetalMesh, instanceCount: Int, textureHandler: (_ type: MDLMaterialSemantic, _ texture: MTLTexture, _ subMeshName: String) -> Void) {
        for subMesh in mesh.mtkMesh.submeshes {
            if let diffuseTexture = mesh.baseColorTextures[subMesh.name] {
                textureHandler(.baseColor, diffuseTexture, subMesh.name)
            }
            
            if let specularTexture = mesh.specularTextures[subMesh.name] {
                textureHandler(.specular, specularTexture, subMesh.name)
            }

            drawIndexedPrimitives(type: subMesh.primitiveType,
                                  indexCount: subMesh.indexCount,
                                  indexType: subMesh.indexType,
                                  indexBuffer: subMesh.indexBuffer.buffer,
                                  indexBufferOffset: subMesh.indexBuffer.offset,
                                  instanceCount: instanceCount)
        }
    }
}
