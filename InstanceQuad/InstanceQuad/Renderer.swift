//
//  Renderer.swift
//  InstanceQuad
//
//  Created by Jacob Su on 3/28/21.
//

import Foundation
import MetalKit
import common

class Renderer: NSObject {
    
    private var device: MTLDevice!
    private var renderPipelineState: MTLRenderPipelineState!
    private var quadsVertexBuffer : MetalBuffer<Vertex>!
    private var quadsOffsetBuffer : MetalBuffer<QuadOffset>!
    private var viewPortSize: MTLViewport!
    private var commandQueue: MTLCommandQueue!
    
    init(metalView: MTKView) {
        super.init()
        
        device = metalView.device
        metalView.delegate = self
        
        let library = device.makeDefaultLibrary()!
        let vertexFunc = library.makeFunction(name: "vertexShader")!
        let fragmentFunc = library.makeFunction(name: "fragmentShader")!
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "Quads"
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        pipelineDescriptor.sampleCount = metalView.sampleCount
        
        renderPipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        let quadsVertices: [Vertex] = [
            Vertex(position: vector_float2(-0.05,  0.05), color: vector_float3(1.0, 0.0, 0.0)),
            Vertex(position: vector_float2( 0.05, -0.05), color: vector_float3(0.0, 1.0, 0.0)),
            Vertex(position: vector_float2(-0.05, -0.05), color: vector_float3(0.0, 0.0, 1.0)),
            
            Vertex(position: vector_float2(-0.05,  0.05), color: vector_float3(1.0, 0.0, 0.0)),
            Vertex(position: vector_float2( 0.05, -0.05), color: vector_float3(0.0, 1.0, 0.0)),
            Vertex(position: vector_float2( 0.05,  0.05), color: vector_float3(0.0, 1.0, 1.0)),
        ]
        
        quadsVertexBuffer = MetalBuffer(device: device, array: quadsVertices, index: UInt32(Int(VertexIndexPosition.rawValue)))
        
        var quadsOffsets: [QuadOffset] = [QuadOffset](repeating: QuadOffset(), count: 100)
        
        var index = 0
        let offset : Float = 0.1
        
        for y in stride(from: -10, to: 10, by: 2) {
            for x in stride(from: -10, to: 10, by: 2) {
                let offsetX = Float(x) / 10.0 + offset
                let offsetY = Float(y) / 10.0 + offset
                quadsOffsets[index] = QuadOffset(offset: vector_float2(offsetX, offsetY))
                index += 1
            }
        }
        
        assert(quadsOffsets.count == 100, "quads size has equal to 100.")
        quadsOffsetBuffer = MetalBuffer(device: device, array: quadsOffsets, index: UInt32(VertexIndexOffset.rawValue))
        
        viewPortSize = MTLViewport(originX: 0, originY: 0,
                                   width: Double(metalView.frame.width),
                                   height: Double(metalView.frame.height),
                                   znear: 0.0, zfar: 1.0)
        
        commandQueue = device.makeCommandQueue()!
        
    }
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewPortSize.width = Double(size.width)
        viewPortSize.height = Double(size.height)
    }
    
    func draw(in view: MTKView) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        let renderPassDescriptor = view.currentRenderPassDescriptor!
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.label = "quad"
        renderEncoder.setViewport(viewPortSize)
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setVertexBuffer(quadsVertexBuffer)
        renderEncoder.setVertexBuffer(quadsOffsetBuffer)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: quadsVertexBuffer.count, instanceCount: 100)
        renderEncoder.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    
}
