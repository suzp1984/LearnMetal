//
//  ModelIOMesh.swift
//  common
//
//  Created by Jacob Su on 4/25/21.
//

import Foundation
import Metal
import MetalKit

/// Model IO supported 3D format file loader
/// ref https://developer.apple.com/documentation/modelio/mdlasset/1391813-canimportfileextension
/// Technically support: .obj, .abc, (.usd, .usda, .usdc, .usdz), .ply, .stl formats.
@objc
public class ModelIOMesh: NSObject {
    public private(set) var mtkMesh: MTKMesh!
    
    public private(set) var baseColorTextures: [String : MTLTexture]! = [:]
    
    public private(set) var specularTextures: [String : MTLTexture]! = [:]
    
    fileprivate var texturesCache : [URL: MTLTexture] = [:]
    
    @objc
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
    
    
}

extension ModelIOMesh: MetalMesh {
    
    @objc
    public func drawMeshTo(renderEncoder: MTLRenderCommandEncoder, textureHandler: (MDLMaterialSemantic, MTLTexture, String) -> Void) {
        renderEncoder.drawMesh(self, textureHandler: textureHandler)
    }
    
    @objc
    public func setVertexMeshTo(renderEncoder: MTLRenderCommandEncoder, index: Int) {
        renderEncoder.setVertexMesh(self, index: index)
    }
}
