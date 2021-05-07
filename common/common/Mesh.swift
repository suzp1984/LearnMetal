//
//  Mesh.swift
//  common
//
//  Created by Jacob Su on 5/6/21.
//

import Foundation
import MetalKit

@objc
open class Mesh: Transform {
    
    private var geometry: Geometry!
    
    public init(geometry: Geometry) {
        super.init()
        
        self.geometry = geometry
    }
    
}

extension Mesh: Geometry {
    public func setVertexTo(_ renderEncoder: MTLRenderCommandEncoder, index: Int) {
        geometry.setVertexTo(renderEncoder, index: index)
    }

    public func drawTo(_ renderEncoder: MTLRenderCommandEncoder) {
        geometry.drawTo(renderEncoder)
    }
}
