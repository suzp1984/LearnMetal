//
//  Geometry.swift
//  common
//
//  Created by Jacob Su on 5/6/21.
//

import Foundation
import MetalKit

@objc
public protocol Geometry {
    func setVertexTo(_ renderEncoder: MTLRenderCommandEncoder, index: Int)

    func drawTo(_ renderEncoder: MTLRenderCommandEncoder)
}

@objc
public class MTKGeometry: NSObject {
    private var mtkMesh: MTKMesh!
    
    public init(mtkMesh: MTKMesh) {
        self.mtkMesh = mtkMesh
    }
}

@objc
extension MTKGeometry : Geometry {
    public func setVertexTo(_ renderEncoder: MTLRenderCommandEncoder, index: Int) {
        renderEncoder.setVertexMesh(mtkMesh, index: index)
    }
    
    public func drawTo(_ renderEncoder: MTLRenderCommandEncoder) {
        renderEncoder.drawMesh(mtkMesh)
    }
    
}
