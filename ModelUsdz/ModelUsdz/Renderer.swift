//
//  Renderer.swift
//  ModelUsdz
//
//  Created by Jacob Su on 5/19/21.
//

import Foundation
import MetalKit
import common

class Renderer: NSObject {

    private var device: MTLDevice!
    
    init(mtkView: MTKView) {
        super.init()
        
        device = mtkView.device!
        
        let url = Bundle.common.url(forResource: "toy_biplane.usdz",
                                     withExtension: nil,
                                     subdirectory: "usdz")!
        
        if (!MDLAsset.canImportFileExtension("usdz")) {
            fatalError("MDL Asset can not import usdz")
        }

        let mtlVertexDescriptor = MTLVertexDescriptor()
        // position
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].format = .float3
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].offset = 0
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].bufferIndex = Int(ModelVertexInputIndexPosition.rawValue)

        // texture coordinate
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeTexcoord.rawValue)].format = .float2
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeTexcoord.rawValue)].offset = 16
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeTexcoord.rawValue)].bufferIndex = Int(ModelVertexInputIndexPosition.rawValue)

        // normal
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeNormal.rawValue)].format = .float3
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeNormal.rawValue)].offset = 32
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributeNormal.rawValue)].bufferIndex = Int(ModelVertexInputIndexPosition.rawValue)
        
        // layout
        mtlVertexDescriptor.layouts[Int(ModelVertexInputIndexPosition.rawValue)].stride = 48
        mtlVertexDescriptor.layouts[Int(ModelVertexInputIndexPosition.rawValue)].stepRate = 1
        mtlVertexDescriptor.layouts[Int(ModelVertexInputIndexPosition.rawValue)].stepFunction = .perVertex

        let attributeMap = [
            Int(ModelVertexAttributePosition.rawValue) : MDLVertexAttributePosition,
            Int(ModelVertexAttributeTexcoord.rawValue) : MDLVertexAttributeTextureCoordinate,
            Int(ModelVertexAttributeNormal.rawValue)   : MDLVertexAttributeNormal
        ]

        let planeMesh = try! ModelIOMesh(withUrl: url,
                                         device: device,
                                         mtlVertexDescriptor: mtlVertexDescriptor,
                                         attributeMap: attributeMap)
//
//        NSError *error;
//
//        _nanoSuitMesh = [[ModelIOMesh alloc] initWithUrl:url
//                                                device:device
//                                   mtlVertexDescriptor:mtlVertexDescriptor
//                                          attributeMap:attributeMap
//                                                 error:&error];
//
//        NSAssert(_nanoSuitMesh, @"nanoSuit mesh loading error: %@", error);
    }
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        
    }

}
