//
//  Transform.swift
//  common
//
//  Created by Jacob Su on 5/6/21.
//

import Foundation

@objc
open class Transform: NSObject {
    
    @objc
    public var name: String? = nil
    
    @objc
    public var isVisible: Bool = true
    
    @objc
    public private(set) var children: [Transform] = []
    
    @objc
    public private(set) weak var parent: Transform? = nil
    
    @objc
    public private(set) var modelMatrix: matrix_float4x4 = matrix_identity_float4x4
    
    @objc
    public var position: vector_float3 = vector_float3(repeating: 0.0) {
        didSet {
            forceCalculateModelMatrix()
        }
    }
    
    @objc
    public var quaternionVect: vector_float4 = vector_float4(0.0, 0.0, 0.0, 1.0) {
        didSet {
            forceCalculateModelMatrix()
        }
    }
    
    @objc
    public var scale: vector_float3 = vector_float3(repeating: 1.0) {
        didSet {
            forceCalculateModelMatrix()
        }
    }
    
    @objc
    public func add(child: Transform, notifyChild: Bool = true) {
        if (!children.contains(child)) {
            children.append(child)
            
            if notifyChild {
                child.setParent(self, notifyParent: false)
                child.forceCalculateModelMatrix()
            }
        }
        
    }
    
    @objc
    public func remove(child: Transform, notifyChild: Bool = true) {
        if children.contains(child) {
            children.removeAll(where: { $0 == child })
            
            if notifyChild {
                child.setParent(nil, notifyParent: false)
                child.forceCalculateModelMatrix()
            }
        }
    }
    
    @objc
    public func setParent(_ parent: Transform?, notifyParent: Bool = false) {
        if notifyParent {
            parent?.remove(child: self, notifyChild: false)
        }
        
        self.parent = parent
        forceCalculateModelMatrix()
        
        if (notifyParent) {
            parent?.add(child: self, notifyChild: false)
        }
    }
    
    @objc
    public func forceCalculateModelMatrix() {
        // let translation to be the left-hand metal normlized space.
        let mat = matrix_multiply(matrix4x4_translation(vector_float3(-position.x, position.y, -position.z)),
                                  matrix_multiply(matrix4x4_from_quaternion(quaternionVect), matrix4x4_scale(scale)))
        
        if parent != nil {
            modelMatrix = matrix_multiply(parent!.modelMatrix, mat)
        } else {
            modelMatrix = mat
        }
        
        children.forEach {
            $0.forceCalculateModelMatrix()
        }
    }
    
}
