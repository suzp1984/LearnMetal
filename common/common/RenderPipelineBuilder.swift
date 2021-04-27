//
//  RenderPipeline.swift
//  common
//
//  Created by Jacob Su on 4/27/21.
//

import Foundation
import Metal
import MetalKit

public class RenderPipelineBuilder: NSObject {
    
    private var device: MTLDevice!
    private var renderPipelineDescriptor: MTLRenderPipelineDescriptor!
    
    @objc
    public init(device: MTLDevice,
                vertexFunc: MTLFunction,
                fragmentFunc: MTLFunction) {
        super.init()
        
        self.device = device
        
        renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = vertexFunc
        renderPipelineDescriptor.fragmentFunction = fragmentFunc
    }
    
    public func setLable(_ label: String) -> RenderPipelineBuilder {
        renderPipelineDescriptor.label = label
        return self
    }
    
    public func setVertexDescriptor(_ descriptor: MTLVertexDescriptor) -> RenderPipelineBuilder {
        renderPipelineDescriptor.vertexDescriptor = descriptor
        
        return self
    }
    
    public func setSampleCount(_ count: Int) -> RenderPipelineBuilder {
        renderPipelineDescriptor.sampleCount = count
        
        return self
    }
    
    public func setIsRasterizationEnabled(_ enabled: Bool) -> RenderPipelineBuilder {
        renderPipelineDescriptor.isRasterizationEnabled = enabled
        
        return self
    }
    
    public func setIsAlphaToCoverageEnabled(_ enabled: Bool) -> RenderPipelineBuilder {
        renderPipelineDescriptor.isAlphaToCoverageEnabled = enabled
        
        return self
    }
    
    public func setIsAlphaToOneEnabled(_ enabled: Bool) -> RenderPipelineBuilder {
        renderPipelineDescriptor.isAlphaToOneEnabled = enabled
        
        return self
    }
    
    public func setDepthAttachmentPixelFormat(_ format: MTLPixelFormat) -> RenderPipelineBuilder {
        renderPipelineDescriptor.depthAttachmentPixelFormat = format
        
        return self
    }
    
    public func setStencilAttachementPixelFormat(_ format: MTLPixelFormat) -> RenderPipelineBuilder {
        renderPipelineDescriptor.stencilAttachmentPixelFormat = format
        
        return self
    }
    
    public func setInputPrimitiveTopology(_ primitiveTopology: MTLPrimitiveTopologyClass) -> RenderPipelineBuilder {
        renderPipelineDescriptor.inputPrimitiveTopology = primitiveTopology
        
        return self
    }
    
    public func setTessellationPartitionMode(_ mode: MTLTessellationPartitionMode) -> RenderPipelineBuilder {
        renderPipelineDescriptor.tessellationPartitionMode = mode
        
        return self
    }
    
    public func setMaxTessellationFactor(_ factor: Int) -> RenderPipelineBuilder {
        renderPipelineDescriptor.maxTessellationFactor = factor
        
        return self
    }
    
    public func setIsTessellationFactorScaleEnabled(_ enabled: Bool) -> RenderPipelineBuilder {
        renderPipelineDescriptor.isTessellationFactorScaleEnabled = enabled
        
        return self
    }
    
    public func setTessellationFactorFormat(_ format: MTLTessellationFactorFormat) -> RenderPipelineBuilder {
        renderPipelineDescriptor.tessellationFactorFormat = format
        
        return self
    }
    
    public func setTessellationControlPointIndexType(_ type: MTLTessellationControlPointIndexType) -> RenderPipelineBuilder {
        renderPipelineDescriptor.tessellationControlPointIndexType = type
        
        return self
    }
    
    public func setTessellationFactorStepFunction(_ function: MTLTessellationFactorStepFunction) -> RenderPipelineBuilder {
        renderPipelineDescriptor.tessellationFactorStepFunction = function
        
        return self
    }
    
    public func setTessellationOutputWindingOrder(_ windingOrder: MTLWinding) -> RenderPipelineBuilder {
        renderPipelineDescriptor.tessellationOutputWindingOrder = windingOrder
        
        return self
    }
    
    public func setColorAttachmentsPixelFormat(_ formats: [MTLPixelFormat]) -> RenderPipelineBuilder {
        for (index, pixelFormat) in formats.enumerated() {
            renderPipelineDescriptor.colorAttachments[index].pixelFormat = pixelFormat
        }
        
        return self
    }
    
    public func setBlendingEnabled(_ enables: [Bool]) -> RenderPipelineBuilder {
        for (index, isBlendingEnabled) in enables.enumerated() {
            renderPipelineDescriptor.colorAttachments[index].isBlendingEnabled = isBlendingEnabled
        }
        
        return self
    }
    
    public func setSourceRGBBlendFactor(_ factors: [MTLBlendFactor]) -> RenderPipelineBuilder {
        for (index, sourceRGBBlendFactor) in factors.enumerated() {
            renderPipelineDescriptor.colorAttachments[index].sourceRGBBlendFactor = sourceRGBBlendFactor
        }
        
        return self
    }
    
    public func setDestinationRGBBlendFactor(_ factors: [MTLBlendFactor]) -> RenderPipelineBuilder {
        for (index, destinationRGBBlendFactor) in factors.enumerated() {
            renderPipelineDescriptor.colorAttachments[index].destinationRGBBlendFactor = destinationRGBBlendFactor
        }
        
        return self
    }
    
    public func setRgbBlendOperation(_ operations: [MTLBlendOperation]) -> RenderPipelineBuilder {
        for (index, rgbBlendOperation) in operations.enumerated() {
            renderPipelineDescriptor.colorAttachments[index].rgbBlendOperation = rgbBlendOperation
        }
        
        return self
    }
    
    public func setSourceAlphaBlendFactor(_ factors: [MTLBlendFactor]) -> RenderPipelineBuilder {
        for (index, sourceAlphaBlendFactor) in factors.enumerated() {
            renderPipelineDescriptor.colorAttachments[index].sourceAlphaBlendFactor = sourceAlphaBlendFactor
        }
        
        return self
    }
    
    public func setDestinationAlphaBlendFactor(_ factors: [MTLBlendFactor]) -> RenderPipelineBuilder {
        for (index, destinationAlphaBlendFactor) in factors.enumerated() {
            renderPipelineDescriptor.colorAttachments[index].destinationAlphaBlendFactor = destinationAlphaBlendFactor
        }
        
        return self
    }
    
    public func setAlphaBlendOperation(_ operations: [MTLBlendOperation]) -> RenderPipelineBuilder {
        for (index, alphaBlendOperation) in operations.enumerated() {
            renderPipelineDescriptor.colorAttachments[index].alphaBlendOperation = alphaBlendOperation
        }
        
        return self
    }
    
    public func setColorWriteMask(_ masks: [MTLColorWriteMask]) -> RenderPipelineBuilder {
        for (index, writeMask) in masks.enumerated() {
            renderPipelineDescriptor.colorAttachments[index].writeMask = writeMask
        }
        return self
    }

    public func build() throws -> MTLRenderPipelineState {
        return try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
    }
}
