//
//  Renderer.swift
//  MSAA
//
//  Created by Jacob Su on 3/29/21.
//

import Foundation
import MetalKit
import common

let PI: Float = 3.1415926

class Renderer: NSObject {
    
    private var device: MTLDevice!
    private var cubeMesh: MTKMesh!
    private var depthStencilState: MTLDepthStencilState!
    private var msaaPipelineState: MTLRenderPipelineState!
    private var noMsaaPipelineState: MTLRenderPipelineState!
    private var commandQueue: MTLCommandQueue!
    private var camera: Camera!
    private var viewPort: MTLViewport!
    private var uniform: Uniforms!
    private var msasTexture: MTLTexture!
    private var colorFormat: MTLPixelFormat!
    private var multiSampleCount: Int = 8
    private var sampleCount: Int! {
        didSet {
            metalView.sampleCount = sampleCount
        }
    }
    private var metalView: MTKView!
    
    init(metalView: MTKView) {
        super.init()
        
        self.metalView = metalView
        sampleCount = multiSampleCount
        device = metalView.device
        metalView.delegate = self
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.clearDepth = 1.0
        metalView.sampleCount = sampleCount
        
        camera = Camera(position: vector_float3(0.0, 0.0, 3.0),
                        withTarget: vector_float3(0.0, 0.0, 0.0),
                        withUp: vector_float3(0.0, 1.0, 0.0))
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        
        depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)!
        
        let mtlVertexDescriptor = MTLVertexDescriptor()
        // position
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].format = .float3
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].offset = 0
        mtlVertexDescriptor.attributes[Int(ModelVertexAttributePosition.rawValue)].bufferIndex = Int(VertexInputIndexPosition.rawValue);
        
        // layout
        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stride = 16
        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stepRate = 1
        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stepFunction = .perVertex
    
        cubeMesh = try! MTKMesh.newBox(withVertexDescriptor: mtlVertexDescriptor,
                                  withAttributesMap: [
                                    Int(ModelVertexAttributePosition.rawValue) : MDLVertexAttributePosition
                                  ],
                                  withDevice: device)
        
        let library = device.makeDefaultLibrary()!
        let vertexFunc = library.makeFunction(name: "vertexShader")!
        let fragmentFunc = library.makeFunction(name: "fragmentShader")!
        
        colorFormat = metalView.colorPixelFormat
        
        let msaaPipelineDescriptor = MTLRenderPipelineDescriptor()
        msaaPipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        msaaPipelineDescriptor.vertexFunction = vertexFunc
        msaaPipelineDescriptor.fragmentFunction = fragmentFunc
        msaaPipelineDescriptor.colorAttachments[0].pixelFormat = colorFormat
        msaaPipelineDescriptor.depthAttachmentPixelFormat = metalView.depthStencilPixelFormat
        msaaPipelineDescriptor.sampleCount = multiSampleCount
        
        msaaPipelineState = try! device.makeRenderPipelineState(descriptor: msaaPipelineDescriptor)
        
        msaaPipelineDescriptor.sampleCount = 1
        noMsaaPipelineState = try! device.makeRenderPipelineState(descriptor: msaaPipelineDescriptor)
        
        commandQueue = device.makeCommandQueue()!
        
        let width = metalView.frame.width
        let height = metalView.frame.height
        
        buildMSAATexture(width: Int(width), height: Int(height), sampleCount: sampleCount)
        
        viewPort = MTLViewport(originX: 0.0, originY: 0.0,
                               width: Double(width),
                               height: Double(height),
                               znear: 0.0, zfar: 1.0)
        
        uniform = Uniforms(modelMatrix: matrix4x4_identity(),
                           viewMatrix: camera.getViewMatrix(),
                           projectionMatrix: matrix_perspective_left_hand(PI / 4.0,
                                                                          Float(width) / Float(height),
                                                                          0.1,
                                                                          1000.0))
    }
    
    func handleCameraEvent(deltaX: Float, deltaY: Float) -> Void {
        camera.handleMouseScrollDeltaX(deltaX, deltaY: deltaY)
        
        uniform.viewMatrix = camera.getViewMatrix()
    }
    
    func enableMSAA(enable: Bool) -> Void {
        if enable {
            sampleCount = 8
        } else {
            sampleCount = 1
        }
        
    }
    
    private func buildMSAATexture(width: Int, height: Int, sampleCount: Int) {
        let textureDescriptor = MTLTextureDescriptor()
        if sampleCount > 1 {
            textureDescriptor.textureType = .type2DMultisample
        } else {
            textureDescriptor.textureType = .type2D
        }
        textureDescriptor.sampleCount = sampleCount
        textureDescriptor.width = width
        textureDescriptor.height = height
        textureDescriptor.pixelFormat = colorFormat
        textureDescriptor.usage = .renderTarget
        textureDescriptor.storageMode = .private
    
        msasTexture = device.makeTexture(descriptor: textureDescriptor)!
    }
}

extension Renderer : MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewPort.width = Double(size.width)
        viewPort.height = Double(size.height)
        
        uniform.projectionMatrix = matrix_perspective_left_hand(PI / 4.0, Float(size.width) / Float(size.height), 0.1, 1000.0)
        
        buildMSAATexture(width: Int(size.width), height: Int(size.height), sampleCount: sampleCount)
    }
    
    func draw(in view: MTKView) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        if msasTexture.sampleCount != sampleCount ||
            msasTexture.width != Int(view.drawableSize.width) ||
            msasTexture.height != Int(view.drawableSize.height) {
            buildMSAATexture(width: Int(view.drawableSize.width),
                             height: Int(view.drawableSize.height),
                             sampleCount: sampleCount)
        }
        
        let renderPassDescriptor = view.currentRenderPassDescriptor!
        if sampleCount > 1 {
            renderPassDescriptor.colorAttachments[0].storeAction = .multisampleResolve
            renderPassDescriptor.colorAttachments[0].texture = msasTexture
            renderPassDescriptor.colorAttachments[0].resolveTexture = view.currentDrawable!.texture
        } else {
            renderPassDescriptor.colorAttachments[0].storeAction = .store
            renderPassDescriptor.colorAttachments[0].texture = view.currentDrawable!.texture
        }
        
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.setViewport(viewPort)
        if sampleCount > 1 {
            renderEncoder.setRenderPipelineState(msaaPipelineState)
        } else {
            renderEncoder.setRenderPipelineState(noMsaaPipelineState)
        }
        
        renderEncoder.setDepthStencilState(depthStencilState)
        
        renderEncoder.setVertexMesh(cubeMesh, index: Int(VertexInputIndexPosition.rawValue))
        renderEncoder.setVertexBytes(&uniform, length: MemoryLayout<Uniforms>.stride, index: Int(VertexInputIndexUniform.rawValue))
        renderEncoder.drawMesh(cubeMesh)
        
        renderEncoder.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    
}
