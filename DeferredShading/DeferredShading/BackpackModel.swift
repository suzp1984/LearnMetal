//
//  BackpackModel.swift
//  5.9.DeferredShading
//
//  Created by Jacob Su on 4/29/21.
//

import Foundation
import Metal
import MetalKit
import common

class BackpackModel: Model {

    var name: String
    
    private(set) var vertexInputs: [(Int, MetalResource)]!
    
    private(set) var fragmentInputs: [(Int, MetalResource)]!
    
    private(set) var drawResource: DrawCommand!
    
    var primitiveType: MTLPrimitiveType?
    
    private(set) var resources: [(MTLResource, MTLResourceUsage)]?
    
    var heaps: [MTLHeap]?
    
    var instanceCount: Int?
    
    let backPackMesh: ModelIOMesh
    
    var uniforms: Uniforms
        
    init(device: MTLDevice) {
        instanceCount = nil
        
        name = "Backpack"
        
        uniforms = Uniforms(modelMatrix: matrix4x4_identity(),
                            viewMatrix: matrix4x4_identity(),
                            projectionMatrix: matrix4x4_identity(),
                            normalMatrix: matrix3x3_upper_left(matrix4x4_identity()))
        
        let mtlVertexDescriptor = MTLVertexDescriptor()
        // position
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].format = .float3
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].offset = 0
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].bufferIndex = Int(VertexInputIndexPosition.rawValue)

        // texture coordinate
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeTexcoord.rawValue)].format = .float2
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeTexcoord.rawValue)].offset = 16
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeTexcoord.rawValue)].bufferIndex = Int(VertexInputIndexPosition.rawValue)

        // normal
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeNormal.rawValue)].format = .float3
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeNormal.rawValue)].offset = 32
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeNormal.rawValue)].bufferIndex = Int(VertexInputIndexPosition.rawValue)

        // layout
        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stride = 48
        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stepRate = 1
        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stepFunction = .perVertex

        let backPackUrl = Bundle.common.url(forResource: "backpack.obj", withExtension: nil, subdirectory: "backpack")!

        backPackMesh = try! ModelIOMesh(withUrl: backPackUrl,
                               device: device,
                               mtlVertexDescriptor: mtlVertexDescriptor,
                               attributeMap: [
                                Int(ModelVertexAttributePosition.rawValue) : MDLVertexAttributePosition,
                                Int(ModelVertexAttributeTexcoord.rawValue) : MDLVertexAttributeTextureCoordinate,
                                Int(ModelVertexAttributeNormal.rawValue)   : MDLVertexAttributeNormal
                               ])
        drawResource = .MTKSubMesh(backPackMesh.mtkMesh.submeshes)
        
        vertexInputs = []
        vertexInputs.append((Int(VertexInputIndexPosition.rawValue), .MeshResource(backPackMesh)))
                
        fragmentInputs = []
        
        backPackMesh.baseColorTextures.forEach { (name, texture) in
            fragmentInputs.append((Int(FragmentInputIndexDiffuse.rawValue),
                                   .SubMeshResource(name: name, resource: .TextureResouce(texture))))
        }
        
        backPackMesh.specularTextures.forEach { (name, texture) in
            fragmentInputs.append((Int(FragmentInputIndexSpecular.rawValue),
                                   .SubMeshResource(name: name, resource: .TextureResouce(texture))))
        }
        
    }

    func removeVertexMesh() {
        vertexInputs.removeAll { (index, _) in
            index == Int(VertexInputIndexPosition.rawValue)
        }
    }
    
    func addVertexMesh() {
        removeVertexMesh()
        
        vertexInputs.append((Int(VertexInputIndexPosition.rawValue), .MeshResource(backPackMesh)))
    }
    
    func setVertexBytes(in renderEncoder: MTLRenderCommandEncoder, index: Int) {
        withUnsafePointer(to: uniforms) {
            renderEncoder.setVertexBytes($0, length: MemoryLayout<Uniforms>.stride, index: index)
        }
    }
    
    func setFragmentBytes(in renderEncoder: MTLRenderCommandEncoder, index: Int) {
        
    }
    
    func resetUniforms(_ uniform: Uniforms) {
        
        self.uniforms.modelMatrix = uniform.modelMatrix
        self.uniforms.normalMatrix = uniform.normalMatrix
        self.uniforms.projectionMatrix = uniform.projectionMatrix
        self.uniforms.viewMatrix = uniform.viewMatrix

        vertexInputs.removeAll { (index, _) in
            index == Int(VertexInputIndexUniforms.rawValue)
        }

        vertexInputs.append((Int(VertexInputIndexUniforms.rawValue),
                             .ByteResource(model: self)))
    }
}
