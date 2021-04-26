//
//  Renderer.swift
//  FrameBuffers
//
//  Created by Jacob Su on 3/23/21.
//
import Foundation
import MetalKit
import common

enum PostProcess : String, CaseIterable {
    case None
    case Inversion
    case GrayScale
    case Sharpen
    case Blur
    case EdgeDetect
    
    var fragmentFuncName: String {
        switch self {
        case .None:
            return "postFragmentShader"
        case .Inversion:
            return "inversionFragmentShader"
        case .GrayScale:
            return "grayscaleFragmentShader"
        case .Sharpen:
            return "sharpenFragmentShader"
        case .Blur:
            return "blurFragmentShader"
        case .EdgeDetect:
            return "edgeDetectFragmentShader"
        }
    }
    
    private static var cachedLookup: [String: PostProcess] = [:]
    
    init?(rawValue: String) {
        if Self.cachedLookup.isEmpty {
            Self.cachedLookup = Dictionary(uniqueKeysWithValues: Self.allCases.map { ("\($0)", $0) })
        }
        
        if let value = Self.cachedLookup[rawValue] {
            self = value
            return
        } else {
            return nil
        }
    }
}

class Renderer: NSObject {
    
    private var device: MTLDevice!
    private var library: MTLLibrary!
    private var renderPipelineState: MTLRenderPipelineState!
    private var postProcessingPipelineState: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!
    private var commandQueue: MTLCommandQueue!
    private var viewportSize: vector_uint2!
    private var camera: Camera!
    private var cameraController: SatelliteCameraController!
    private var cubeMesh: MTKMesh!
    private var planeMesh: MTKMesh!
    private var cubeTexture: MTLTexture!
    private var floorTexture: MTLTexture!
    private var depthTexture: MTLTexture!
    private var colorTexture: MTLTexture!
    private var cubeOneUniforms: Uniforms!
    private var cubeTwoUniforms: Uniforms!
    private var floorUniforms: Uniforms!
    private var quadBuffer: MetalBuffer<QuadVertex>!
    private var colorTextureFormat: MTLPixelFormat!
    
    var postProcessMethod: PostProcess = .None {
        didSet {
            let postVertexFunc = library.makeFunction(name: "postVertexShader")!
            let postFragmentFunc = library.makeFunction(name: postProcessMethod.fragmentFuncName)!
            
            // post processing piple line
            let postProcessingPipelineDescriptor = MTLRenderPipelineDescriptor()
            postProcessingPipelineDescriptor.label = "post processing pipeline"
            postProcessingPipelineDescriptor.vertexFunction = postVertexFunc
            postProcessingPipelineDescriptor.fragmentFunction = postFragmentFunc
            postProcessingPipelineDescriptor.colorAttachments[0].pixelFormat = colorTextureFormat
            
            postProcessingPipelineState = try! device.makeRenderPipelineState(descriptor: postProcessingPipelineDescriptor)
        }
    }
    
    init(metalView: MTKView) {
        super.init()
        
        metalView.delegate = self
        device = metalView.device
        colorTextureFormat = metalView.colorPixelFormat
        
        camera = SimpleCamera(position: vector_float3(0.0, 0.0, 6.0),
                              withTarget: vector_float3(0.0, 0.0, 0.0),
                              up: true)
        cameraController = SatelliteCameraController(camera: camera)
        
        let mtlVertexDescriptor = MTLVertexDescriptor()
        // positions
        mtlVertexDescriptor.attributes[Int(VertexAttributeIndexPosition.rawValue)].format = MTLVertexFormat.float3
        mtlVertexDescriptor.attributes[Int(VertexAttributeIndexPosition.rawValue)].offset = 0
        mtlVertexDescriptor.attributes[Int(VertexAttributeIndexPosition.rawValue)].bufferIndex = Int(VertexInputIndexPosition.rawValue)
        
        // texture coordinates
        mtlVertexDescriptor.attributes[Int(VertexAttributeIndexTexcoord.rawValue)].format = MTLVertexFormat.float2
        mtlVertexDescriptor.attributes[Int(VertexAttributeIndexTexcoord.rawValue)].offset = 16
        mtlVertexDescriptor.attributes[Int(VertexAttributeIndexTexcoord.rawValue)].bufferIndex = Int(VertexInputIndexPosition.rawValue)
        
        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stride = 32
        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stepRate = 1
        mtlVertexDescriptor.layouts[Int(VertexInputIndexPosition.rawValue)].stepFunction = MTLVertexStepFunction.perVertex
        
        library = device.makeDefaultLibrary()!
        let vertexFunc = library.makeFunction(name: "vertexShader")!
        
        let fragmentFunc = library.makeFunction(name: "fragmentShader")!
        
        let postVertexFunc = library.makeFunction(name: "postVertexShader")!
        let postFragmentFunc = library.makeFunction(name: postProcessMethod.fragmentFuncName)!
        
        let width = metalView.frame.width
        let height = metalView.frame.height
        
        depthTexture = buildDepthTexture(Int(width), Int(height))
        colorTexture = buildColorTexture(Int(width), Int(height))
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "render Pipeline"
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = colorTexture.pixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = depthTexture.pixelFormat
        
        renderPipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        // post processing piple line
        let postProcessingPipelineDescriptor = MTLRenderPipelineDescriptor()
        postProcessingPipelineDescriptor.label = "post processing pipeline"
        postProcessingPipelineDescriptor.vertexFunction = postVertexFunc
        postProcessingPipelineDescriptor.fragmentFunction = postFragmentFunc
        postProcessingPipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        
        postProcessingPipelineState = try! device.makeRenderPipelineState(descriptor: postProcessingPipelineDescriptor)
        
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = MTLCompareFunction.lessEqual
        depthStateDescriptor.isDepthWriteEnabled = true
        
        depthState = device.makeDepthStencilState(descriptor: depthStateDescriptor)
        
        commandQueue = device.makeCommandQueue()
        viewportSize = vector_uint2(UInt32(metalView.frame.width), UInt32(metalView.frame.height))
        
        let modelIOVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)
        (modelIOVertexDescriptor.attributes[Int(VertexAttributeIndexPosition.rawValue)] as! MDLVertexAttribute).name = MDLVertexAttributePosition
        (modelIOVertexDescriptor.attributes[Int(VertexAttributeIndexTexcoord.rawValue)] as! MDLVertexAttribute).name = MDLVertexAttributeTextureCoordinate
        
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        let cubeMDLMesh = MDLMesh.newBox(withDimensions: vector_float3(1.0, 1.0, 1.0),
                                  segments: vector_uint3(1, 1, 1),
                                  geometryType: MDLGeometryType.triangles,
                                  inwardNormals: false,
                                  allocator: metalAllocator)
        
        cubeMDLMesh.vertexDescriptor = modelIOVertexDescriptor
        
        cubeMesh = try! MTKMesh(mesh: cubeMDLMesh, device: device)
        
        let planeMDLMesh = MDLMesh.newPlane(withDimensions: vector_float2(1.0, 1.0),
                                            segments: vector_uint2(1, 1),
                                            geometryType: MDLGeometryType.triangles,
                                            allocator: metalAllocator)
        planeMDLMesh.vertexDescriptor = modelIOVertexDescriptor
        planeMesh = try! MTKMesh(mesh: planeMDLMesh, device: device)
        
        let quadVerties = [
            QuadVertex(position: vector_float3(-1.0, 1.0, 0.0), texCoord: vector_float2(0.0, 0.0)),
            QuadVertex(position: vector_float3(-1.0, -1.0, 0.0), texCoord: vector_float2(0.0, 1.0)),
            QuadVertex(position: vector_float3( 1.0, -1.0, 0.0), texCoord: vector_float2(1.0, 1.0)),
            
            QuadVertex(position: vector_float3(-1.0,  1.0, 0.0), texCoord: vector_float2(0.0, 0.0)),
            QuadVertex(position: vector_float3( 1.0, -1.0, 0.0), texCoord: vector_float2(1.0, 1.0)),
            QuadVertex(position: vector_float3( 1.0,  1.0, 0.0), texCoord: vector_float2(1.0, 0.0))
        ]
        
        quadBuffer = MetalBuffer(device: device, array: quadVerties, index: UInt32(Int(VertexInputIndexPosition.rawValue)), options: MTLResourceOptions.storageModeShared)
        
        let bundle = Bundle.common
        let textureLoader = MTKTextureLoader(device: device)
        
        cubeTexture = try! textureLoader.newTexture(name: "container", scaleFactor: 1.0, bundle: bundle, options: nil)
        
        floorTexture = try! textureLoader.newTexture(name: "metal", scaleFactor: 1.0, bundle: bundle, options: nil)
        
        
        cubeOneUniforms = Uniforms(
            modelMatrix: matrix4x4_translation(-1.0, 0.0, -1.0),
            viewMatrix: camera.getViewMatrix(),
            projectionMatrix: matrix_perspective_left_hand(Float.pi / 4.0, Float(width)/Float(height), 0.1, 100.0))
        
        cubeTwoUniforms = Uniforms(
            modelMatrix: matrix4x4_translation(2.0, 0.0, 0.0),
            viewMatrix: camera.getViewMatrix(),
            projectionMatrix: matrix_perspective_left_hand(Float.pi / 4.0, Float(width)/Float(height), 0.1, 100.0))
        
        
        floorUniforms = Uniforms(
            modelMatrix: simd_mul(matrix4x4_translation(0.0, -0.51, 0.0), matrix4x4_scale(10.0, 10.0, 10.0)),
            viewMatrix: camera.getViewMatrix(),
            projectionMatrix: matrix_perspective_left_hand(Float.pi / 4.0, Float(width) / Float(height), 0.1, 100.0))
    }
    
    func getSupportedPostProcesses() -> [PostProcess] {
        return [
            .None,
            .Inversion,
            .GrayScale,
            .Sharpen,
            .Blur,
            .EdgeDetect
        ]
    }
    
    func handleCameraEvent(deltaX: Float, deltaY: Float) -> Void {
        cameraController.rotateCameraAroundTarget(withDeltaPhi: deltaX, deltaTheta: deltaY)
        
        cubeOneUniforms.viewMatrix = camera.getViewMatrix()
        cubeTwoUniforms.viewMatrix = camera.getViewMatrix()
        floorUniforms.viewMatrix = camera.getViewMatrix()
    }
    
    fileprivate func buildDepthTexture(_ width: Int, _ height: Int) -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = MTLPixelFormat.depth32Float
        descriptor.width = width
        descriptor.height = height
        descriptor.mipmapLevelCount = 1
        descriptor.usage = .renderTarget
        descriptor.storageMode = .private
        
        let depthTexture = device.makeTexture(descriptor: descriptor)!
        depthTexture.label = "Depth Texture"
        return depthTexture
    }
    
    fileprivate func buildColorTexture(_ width: Int, _ height: Int) -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = colorTextureFormat
        descriptor.width = width
        descriptor.height = height
        descriptor.mipmapLevelCount = 1
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private
        
        let colorTexture = device.makeTexture(descriptor: descriptor)!
        colorTexture.label = "Color Texture"
        
        return colorTexture
    }
}

extension Renderer : MTKViewDelegate
{
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize.x = UInt32(size.width)
        viewportSize.y = UInt32(size.height)
        if (depthTexture.width != Int(size.width) ||
                depthTexture.height != Int(size.height))  {
            depthTexture = buildDepthTexture(Int(size.width), Int(size.height))
            colorTexture = buildColorTexture(Int(size.width), Int(size.height))
        }
        
        let projectionMatrix = matrix_perspective_left_hand(Float.pi / 4.0, Float(size.width) / Float(size.height), 0.1, 100.0)
        cubeOneUniforms.projectionMatrix = projectionMatrix
        cubeTwoUniforms.projectionMatrix = projectionMatrix
        floorUniforms.projectionMatrix   = projectionMatrix
    }
    
    func draw(in view: MTKView) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        commandBuffer.label = "Depth Testing Command"
        
        if (depthTexture.width != Int(view.drawableSize.width) ||
                depthTexture.height != Int(view.drawableSize.height) ||
                colorTexture.width  != Int(view.drawableSize.width) ||
                colorTexture.height != Int(view.drawableSize.height)) {
            assert(false)
        }
        
        // offscreen rendering
        let offScreenRenderPassDescriptor = MTLRenderPassDescriptor()
        offScreenRenderPassDescriptor.colorAttachments[0].texture = colorTexture
        offScreenRenderPassDescriptor.colorAttachments[0].loadAction = .clear
        offScreenRenderPassDescriptor.colorAttachments[0].storeAction = .store
        offScreenRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.2, 0.3, 0.3, 1.0)
        
        offScreenRenderPassDescriptor.depthAttachment.texture = depthTexture
        offScreenRenderPassDescriptor.depthAttachment.loadAction = .clear
        offScreenRenderPassDescriptor.depthAttachment.storeAction = .store
        offScreenRenderPassDescriptor.depthAttachment.clearDepth = 1.0
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: offScreenRenderPassDescriptor)!
        renderEncoder.label = "depth testing"
        
        renderEncoder.setViewport(MTLViewport(originX: 0, originY: 0,
                                              width: Double(viewportSize.x),
                                              height: Double(viewportSize.y),
                                              znear: 0.0, zfar: 1.0))
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setDepthStencilState(depthState)
        
        for i in 0..<cubeMesh.vertexBuffers.count {
            let mtkMeshBuffer = cubeMesh.vertexBuffers[i]
            renderEncoder.setVertexBuffer(mtkMeshBuffer.buffer,
                                          offset: mtkMeshBuffer.offset,
                                          index: Int(VertexInputIndexPosition.rawValue))
        }
        
        renderEncoder.setVertexBytes(&cubeOneUniforms,
                                     length: MemoryLayout<Uniforms>.stride,
                                     index: Int(VertexInputIndexUniforms.rawValue))
        renderEncoder.setFragmentTexture(cubeTexture,
                                         index: Int(FragmentInputIndexDiffuseTexture.rawValue))
        // draw cube one
        for i in 0..<cubeMesh.submeshes.count {
            let submesh = cubeMesh.submeshes[i]
            renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset)
        }
        
        // draw cube two
        renderEncoder.setVertexBytes(&cubeTwoUniforms,
                                     length: MemoryLayout<Uniforms>.stride,
                                     index: Int(VertexInputIndexUniforms.rawValue))
        
        for i in 0..<cubeMesh.submeshes.count {
            let submesh = cubeMesh.submeshes[i]
            renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset)
        }
        
        // draw plane
        for i in 0..<planeMesh.vertexBuffers.count {
            let mtkMeshBuffer = planeMesh.vertexBuffers[i]
            renderEncoder.setVertexBuffer(mtkMeshBuffer.buffer,
                                          offset: mtkMeshBuffer.offset,
                                          index: Int(VertexInputIndexPosition.rawValue))
        }
        
        renderEncoder.setVertexBytes(&floorUniforms,
                                     length: MemoryLayout<Uniforms>.stride,
                                     index: Int(VertexInputIndexUniforms.rawValue))
        renderEncoder.setFragmentTexture(floorTexture,
                                         index: Int(FragmentInputIndexDiffuseTexture.rawValue))
        for i in 0..<planeMesh.submeshes.count {
            let subMesh = planeMesh.submeshes[i]
            renderEncoder.drawIndexedPrimitives(type: subMesh.primitiveType,
                                                indexCount: subMesh.indexCount,
                                                indexType: subMesh.indexType,
                                                indexBuffer: subMesh.indexBuffer.buffer,
                                                indexBufferOffset: subMesh.indexBuffer.offset)
        }
        
        renderEncoder.endEncoding()
        
        // draw post processing texture
        let postProcessingRenderPassDescriptor = MTLRenderPassDescriptor()
        postProcessingRenderPassDescriptor.colorAttachments[0].texture = view.currentDrawable!.texture
        postProcessingRenderPassDescriptor.colorAttachments[0].loadAction = .clear
        postProcessingRenderPassDescriptor.colorAttachments[0].storeAction = .store
        postProcessingRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.2, 0.3, 0.3, 1.0)
        
        let postProcessingRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: postProcessingRenderPassDescriptor)!
        postProcessingRenderEncoder.label = "post processing"
        
        postProcessingRenderEncoder.setViewport(MTLViewport(originX: 0, originY: 0,
                                              width: Double(viewportSize.x),
                                              height: Double(viewportSize.y),
                                              znear: 0.0, zfar: 1.0))
        postProcessingRenderEncoder.setRenderPipelineState(postProcessingPipelineState)
        
        postProcessingRenderEncoder.setVertexBuffer(quadBuffer)
        
        postProcessingRenderEncoder.setFragmentTexture(colorTexture, index: Int(FragmentInputIndexDiffuseTexture.rawValue))
    
        postProcessingRenderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: quadBuffer.count)
        postProcessingRenderEncoder.endEncoding()
        
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}
