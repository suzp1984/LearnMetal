//
//  MetalMesh.swift
//  common
//
//  Created by Jacob Su on 3/19/21.
//

import Foundation
import Metal
import MetalKit

@objc
public protocol MetalMesh {
    var mtkMesh: MTKMesh! { get }
    var baseColorTextures: [ String : MTLTexture]! { get }
    var specularTextures: [String : MTLTexture]! { get }
    
    func setVertexMeshTo(renderEncoder: MTLRenderCommandEncoder, index: Int)
    
    func drawMeshTo(renderEncoder: MTLRenderCommandEncoder, textureHandler: (_ type: MDLMaterialSemantic,
                                                                             _ texture: MTLTexture,
                                                                             _ subMeshName: String) -> Void)
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
