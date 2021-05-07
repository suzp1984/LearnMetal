//
//  Transform.swift
//  common
//
//  Created by Jacob Su on 5/6/21.
//

import Foundation

@objc
open class Transform: NSObject {
    public private(set) var children: [Transform] = []
    private weak var parent: Transform? = nil
    
    public private(set) var modelMatrix: matrix_float4x4 = matrix_identity_float4x4
    
    public var position: vector_float3 = vector_float3(repeating: 0.0) {
        didSet {
            forceCalculateModelMatrix()
        }
    }
    
    public var quaternionVect: vector_float4 = vector_float4(0.0, 0.0, 0.0, 1.0) {
        didSet {
            forceCalculateModelMatrix()
        }
    }
    
    public var scale: vector_float3 = vector_float3(repeating: 1.0) {
        didSet {
            forceCalculateModelMatrix()
        }
    }
    
    public func add(child: Transform, notifyChild: Bool = true) {
        if (!children.contains(child)) {
            children.append(child)
            
            if notifyChild {
                child.set(parent: self, notifyParent: false)
                child.forceCalculateModelMatrix()
            }
        }
        
    }
    
    public func remove(child: Transform, notifyChild: Bool = true) {
        if children.contains(child) {
            children.removeAll(where: { $0 == child })
            
            if notifyChild {
                child.set(parent: nil, notifyParent: false)
                child.forceCalculateModelMatrix()
            }
        }
    }
    
    public func set(parent: Transform?, notifyParent: Bool = false) {
        if notifyParent {
            parent?.remove(child: self, notifyChild: false)
        }
        
        self.parent = parent
        forceCalculateModelMatrix()
        
        if (notifyParent) {
            parent?.add(child: self, notifyChild: false)
        }
    }
    
//    public func getModelMatrix() -> matrix_float4x4 {
//        return modelMatrix
//    }
    
    public func forceCalculateModelMatrix() {
        let mat = matrix_multiply(matrix4x4_translation(position),
                                  matrix_multiply(matrix4x4_from_quaternion(quaternionVect), matrix4x4_scale(scale)))
        
        if parent != nil {
            modelMatrix = matrix_multiply(parent!.modelMatrix, mat)
        } else {
            modelMatrix = mat
        }
    }
    
}
