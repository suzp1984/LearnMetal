//
//  Renderer.swift
//  GeometryHouses
//
//  Created by Jacob Su on 3/26/21.
//

import Foundation
import MetalKit

class Renderer: NSObject {
    
    private var device: MTLDevice!
    private var computePipelineState: MTLComputePipelineState!
    private var renderPipelineState: MTLRenderPipelineState!
    private var housePostionBuffer: MTLBuffer!
    private var housesVertexBuffer: MTLBuffer!
    private var viewPortSize: vector_uint2!
    private var commandQueue: MTLCommandQueue!
    private let threadGroupsPerGrid: MTLSize = MTLSizeMake(1, 1, 1)
    private let threadsPerGroup: MTLSize = MTLSizeMake(Int(NumOfHouses), 1, 1)
    private let vertexCount = Int(NumOfHouses) * Int(VertexNumberOfOneHouse)
    
    init(metalView: MTKView) {
        super.init()
        
        metalView.delegate = self
        device = metalView.device
        
        let library = device.makeDefaultLibrary()!
        let computeFunc = library.makeFunction(name: "computeHouses")!
        
        computePipelineState = try! device.makeComputePipelineState(function: computeFunc)
        
        let vertexFunc = library.makeFunction(name: "vertexShader")!
        let fragmentFunc = library.makeFunction(name: "fragmentShader")!
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.label = "render pipeline"
        renderPipelineDescriptor.vertexFunction = vertexFunc
        renderPipelineDescriptor.fragmentFunction = fragmentFunc
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        
        renderPipelineState = try! device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        
        let housePositions : [HouseVertex] = [
            HouseVertex(position: vector_float2(-0.5,  0.5), color: vector_float3(1.0, 0.0, 0.0)),
            HouseVertex(position: vector_float2( 0.5,  0.5), color: vector_float3(0.0, 1.0, 0.0)),
            HouseVertex(position: vector_float2( 0.5, -0.5), color: vector_float3(0.0, 0.0, 1.0)),
            HouseVertex(position: vector_float2(-0.5, -0.5), color: vector_float3(1.0, 1.0, 0.0)),
        ]
        
        housePostionBuffer = device.makeBuffer(bytes: housePositions,
                                            length: MemoryLayout<HouseVertex>.stride * housePositions.count,
                                            options: .storageModeShared)!
        
        housesVertexBuffer = device.makeBuffer(length: MemoryLayout<HouseVertex>.stride * vertexCount,
                                               options: .storageModePrivate)!
        
        viewPortSize = vector_uint2(UInt32(metalView.frame.width), UInt32(metalView.frame.height))
        commandQueue = device.makeCommandQueue()!
    }
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewPortSize.x = UInt32(size.width)
        viewPortSize.y = UInt32(size.height)
    }
    
    func draw(in view: MTKView) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        commandBuffer.label = "house render"
        
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeEncoder.label = "compute command"
        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setBuffer(housePostionBuffer, offset: 0, index: Int(ComputeInputIndexHousePosition.rawValue))
        computeEncoder.setBuffer(housesVertexBuffer, offset: 0, index: Int(ComputeInputIndexHouseVertex.rawValue))
        computeEncoder.dispatchThreadgroups(threadGroupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        let renderPassDescriptor = view.currentRenderPassDescriptor!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.setViewport(MTLViewport(originX: 0,
                                              originY: 0,
                                              width: Double(viewPortSize.x),
                                              height: Double(viewPortSize.y),
                                              znear: 0.0,
                                              zfar: 1.0))
        
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setVertexBuffer(housesVertexBuffer, offset: 0, index: Int(VertexInputIndexVertices.rawValue))
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
        renderEncoder.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    
}
