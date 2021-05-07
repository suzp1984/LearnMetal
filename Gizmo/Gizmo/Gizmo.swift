//
//  Gizmo.swift
//  Gizmo
//
//  Created by Jacob Su on 5/7/21.
//

import Foundation
import common
import MetalKit

class GizmoMesh: Mesh {
    var material: Material!
    
    init(geometry: Geometry, material: Material) {
        super.init(geometry: geometry)
        
        self.material = material
    }
}

class Gizmo : Transform {
    
    var vertexDescriptor: MTLVertexDescriptor!
    private var material: Material!
    private var light: Light!
    private var uniform: Uniforms!
    
    init(device: MTLDevice) {
        super.init()
        
        material = Material(ambient: vector_float3(0.2, 0.2, 0.2),
                            diffuse: vector_float3(0.9, 0.2, 0.8),
                            specular: vector_float3(1.0, 1.0, 1.0),
                            shininess: 10.0)
        
        light = Light(position: vector_float3(5.0, 5.0, 5.0),
                      ambient: vector_float3(0.4, 0.4, 0.4),
                      diffuse: vector_float3(0.8, 0.8, 0.8),
                      specular: vector_float3(0.9, 0.9, 0.9))
        
        uniform = Uniforms(modelMatrix: matrix_identity_float4x4,
                           viewMatrix: matrix_identity_float4x4,
                           projectionMatrix: matrix_identity_float4x4, normalMatrix: matrix_identity_float3x3)
        
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
        
        vertexDescriptor = mtlVertexDescriptor
        
        let attributesMap = [
            Int(ModelVertexAttributePosition.rawValue): MDLVertexAttributePosition,
            Int(ModelVertexAttributeTexcoord.rawValue): MDLVertexAttributeTextureCoordinate,
            Int(ModelVertexAttributeNormal.rawValue): MDLVertexAttributeNormal
        ]
        
        let sphereMtkMesh = try! MTKMesh.newEllipsoid(withVertexDescriptor: mtlVertexDescriptor,
                                               withAttributesMap: attributesMap,
                                               withDevice: device,
                                               radii: vector_float3(1.0, 1.0, 1.0),
                                               radialSegments: 60,
                                               verticalSegments: 60,
                                               geometryType: .triangles,
                                               inwardNormals: false,
                                               hemisphere: false)
        let sphere = MTKGeometry(mtkMesh: sphereMtkMesh)
        material.diffuse = vector_float3(1.0, 1.0, 1.0)
        material.ambient = vector_float3(1.0, 1.0, 1.0)

        let centerMesh = GizmoMesh(geometry: sphere, material: material)
        centerMesh.scale = vector_float3(0.1, 0.1, 0.1)
        self.add(child: centerMesh)
        
        let cylinderMesh = try! MTKMesh.newCylinder(withVertexDescriptor: mtlVertexDescriptor,
                                                    withAttributesMap: attributesMap,
                                                    withDevice: device,
                                                    height: 1.0,
                                                    radii: vector_float2(0.5, 0.5),
                                                    radialSegments: 60,
                                                    verticalSegments: 60,
                                                    geometryType: .triangles,
                                                    inwardNormals: false)
        let cylinder = MTKGeometry(mtkMesh: cylinderMesh)
        
        let coneMtkMesh = try! MTKMesh.newEllipticalCone(withVertexDescriptor: mtlVertexDescriptor,
                                                         withAttributesMap: attributesMap,
                                                         withDevice: device,
                                                         height: 1.0,
                                                         radii: vector_float2(0.5, 0.5),
                                                         radialSegments: 60,
                                                         verticalSegments: 60,
                                                         geometryType: .triangles,
                                                         inwardNormals: true)
        let cone = MTKGeometry(mtkMesh: coneMtkMesh)
        
        // x axis
        material.diffuse = vector_float3(1.0, 0.0, 0.0)
        material.ambient = vector_float3(1.0, 0.0, 0.0)

        let xAxisMesh = GizmoMesh(geometry: cylinder, material: material)
        xAxisMesh.position = vector_float3(0.25, 0.0, 0.0)
        xAxisMesh.quaternionVect = quaternion_from_axis_angle(vector_float3(0.0, 0.0, 1.0), Float.pi / 2.0)
        xAxisMesh.scale = vector_float3(0.1, 0.5, 0.1)
        
        self.add(child: xAxisMesh)
        
        let xAxisArrowMesh = GizmoMesh(geometry: cone, material: material)
        xAxisArrowMesh.position = vector_float3(0.5, 0.0, 0.0)
        xAxisArrowMesh.quaternionVect = quaternion_from_axis_angle(vector_float3(0.0, 0.0, 1.0), -Float.pi / 2.0)
        xAxisArrowMesh.scale = vector_float3(0.4, 0.1, 0.4)
        
        self.add(child: xAxisArrowMesh)
        
        // y axis
        material.diffuse = vector_float3(0.0, 1.0, 0.0)
        material.ambient = vector_float3(0.0, 1.0, 0.0)

        let yAxisMesh = GizmoMesh(geometry: cylinder, material: material)
        yAxisMesh.position = vector_float3(0.0, 0.25, 0.0)
        yAxisMesh.scale = vector_float3(0.1, 0.5, 0.1)
        self.add(child: yAxisMesh)
        
        let yAxisArrowMesh = GizmoMesh(geometry: cone, material: material)
        yAxisArrowMesh.position = vector_float3(0.0, 0.5, 0.0)
        yAxisArrowMesh.scale = vector_float3(0.4, 0.1, 0.4)
        self.add(child: yAxisArrowMesh)
        
        // z axis
        material.diffuse = vector_float3(0.0, 0.0, 1.0)
        material.ambient = vector_float3(0.0, 0.0, 1.0)

        let zAxisMesh = GizmoMesh(geometry: cylinder, material: material)
        zAxisMesh.position = vector_float3(0.0, 0.0, 0.25)
        zAxisMesh.quaternionVect = quaternion_from_axis_angle(vector_float3(1.0, 0.0, 0.0), -Float.pi / 2.0)
        zAxisMesh.scale = vector_float3(0.1, 0.5, 0.1)
        self.add(child: zAxisMesh)
        
        let zAxisArrowMesh = GizmoMesh(geometry: cone, material: material)
        zAxisArrowMesh.position = vector_float3(0.0, 0.0, 0.5)
        zAxisArrowMesh.quaternionVect = quaternion_from_axis_angle(vector_float3(1.0, 0.0, 0.0), Float.pi / 2.0)
        zAxisArrowMesh.scale = vector_float3(0.4, 0.1, 0.4)
        self.add(child: zAxisArrowMesh)
        
    }
    
    func draw(to renderEncoder: MTLRenderCommandEncoder,
              viewMatrix: matrix_float4x4,
              projectionMatrix: matrix_float4x4,
              cameraPos: vector_float3) {
        
        uniform.projectionMatrix = projectionMatrix
        uniform.viewMatrix = viewMatrix
        
        withUnsafePointer(to: light) {
            renderEncoder.setFragmentBytes($0,
                                           length: MemoryLayout<Light>.stride,
                                           index: Int(FragmentInputIndexLight.rawValue))
        }
        withUnsafePointer(to: cameraPos) {
            renderEncoder.setFragmentBytes($0,
                                           length: MemoryLayout<vector_float3>.stride,
                                           index: Int(FragmentInputIndexViewPos.rawValue))
        }
        
        self.children.forEach {
            if let mesh = $0 as? GizmoMesh {
                
                withUnsafePointer(to: mesh.material) {
                    renderEncoder.setFragmentBytes($0,
                                                   length: MemoryLayout<Material>.stride,
                                                   index: Int(FragmentInputIndexMaterial.rawValue))
                }
                uniform.modelMatrix = mesh.modelMatrix
                uniform.normalMatrix = matrix3x3_upper_left(mesh.modelMatrix).inverse.transpose
                
                withUnsafePointer(to: uniform) {
                    renderEncoder.setVertexBytes($0,
                                                 length: MemoryLayout<Uniforms>.stride,
                                                 index: Int(VertexInputIndexUniforms.rawValue))
                }
                
                mesh.setVertexTo(renderEncoder, index: Int(VertexInputIndexPosition.rawValue))
                
                mesh.drawTo(renderEncoder)
                
            }
        }
    }
}
