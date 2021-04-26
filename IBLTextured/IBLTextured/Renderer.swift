//
//  Renderer.swift
//  IBLTextured
//
//  Created by Jacob Su on 4/20/21.
//

import Foundation
import MetalKit
import common

struct MaterialTexture {
    var albedoTexture: MTLTexture
    var normalTexture: MTLTexture
    var metallicTexture: MTLTexture
    var roughnessTexture: MTLTexture
    var aoTexture: MTLTexture
}

class Renderer: NSObject {
    private var device: MTLDevice!
    private var camera: Camera!
    private var cameraController: SatelliteCameraController!
    private var hdrTexture: MTLTexture!
    private var cubeTexture: MTLTexture!
    private var irradianceTexture: MTLTexture!
    private var prefilterTexture: MTLTexture!
    private var brdfLUTexture: MTLTexture!
    private var depthState: MTLDepthStencilState!
    private var cubeMesh: MTKMesh!
    private var sphereMesh: MTKMesh!
    private var cubeMapPipelineState: MTLRenderPipelineState!
    private var irradiancePipelineState: MTLRenderPipelineState!
    private var backgroundPipelineState: MTLRenderPipelineState!
    private var pbrRenderPipelineState: MTLRenderPipelineState!
    private var commandQueue: MTLCommandQueue!
    private var viewPort: MTLViewport!
    private var uniform: Uniforms!
    private var instanceParamsBuffer: MTLBuffer!
    private var material: Material!
    private var lights: [Light]!
    
    private var rustedIronMaterial: MaterialTexture!
    private var goldMaterial: MaterialTexture!
    private var grassMaterial: MaterialTexture!
    private var plasticMaterial: MaterialTexture!
    private var wallMaterial: MaterialTexture!
    
    private var rustedIronBuffer: MTLBuffer!
    private var goldMatrialBuffer: MTLBuffer!
    private var grassMaterialBuffer: MTLBuffer!
    private var plasticMaterialBuffer: MTLBuffer!
    private var wallMaterialBuffer: MTLBuffer!
    private var argumentBuffer: MTLBuffer!
    
    init(mtkView: MTKView) {
        super.init()
        
        device = mtkView.device!
        mtkView.delegate = self
        mtkView.depthStencilPixelFormat = .depth32Float
        
        camera = SimpleCamera(position: vector_float3(0.0, 0.0, 8.0),
                              withTarget: vector_float3(0.0, 0.0, 0.0),
                              up: true)
        cameraController = SatelliteCameraController(camera: camera)
       
        commandQueue = device.makeCommandQueue()!
        loadHdrTexture(commandQueue: commandQueue)
        
        rustedIronMaterial = loadMaterialTexture(albedoPath: "rusted_iron/albedo.png",
                                                 normalPath: "rusted_iron/normal.png",
                                                 metallicPath: "rusted_iron/metallic.png",
                                                 roughnessPath: "rusted_iron/roughness.png",
                                                 aoPath: "rusted_iron/ao.png")
        
        goldMaterial = loadMaterialTexture(albedoPath: "gold/albedo.png",
                                           normalPath: "gold/normal.png",
                                           metallicPath: "gold/metallic.png",
                                           roughnessPath: "gold/roughness.png",
                                           aoPath: "gold/ao.png")
        
        grassMaterial = loadMaterialTexture(albedoPath: "grass/albedo.png",
                                            normalPath: "grass/normal.png",
                                            metallicPath: "grass/metallic.png",
                                            roughnessPath: "grass/roughness.png",
                                            aoPath: "grass/ao.png")
        
        plasticMaterial = loadMaterialTexture(albedoPath: "plastic/albedo.png",
                                              normalPath: "plastic/normal.png",
                                              metallicPath: "plastic/metallic.png",
                                              roughnessPath: "plastic/roughness.png",
                                              aoPath: "plastic/ao.png")
        
        wallMaterial = loadMaterialTexture(albedoPath: "wall/albedo.png",
                                           normalPath: "wall/normal.png",
                                           metallicPath: "wall/metallic.png",
                                           roughnessPath: "wall/roughness.png",
                                           aoPath: "wall/ao.png")
        
        let cubeTextureDescritpor = MTLTextureDescriptor.textureCubeDescriptor(pixelFormat: .rgba16Float,
                                                                           size: 512,
                                                                           mipmapped: false)
        cubeTextureDescritpor.usage = [.renderTarget, .shaderRead]
        cubeTextureDescritpor.storageMode = .private
        
        cubeTexture = device.makeTexture(descriptor: cubeTextureDescritpor)!
        
        let irradianceTextureDescriptor = MTLTextureDescriptor.textureCubeDescriptor(pixelFormat: .rgba16Float, size: 32, mipmapped: false)
        irradianceTextureDescriptor.usage = [.renderTarget, .shaderRead]
        irradianceTextureDescriptor.storageMode = .private
        
        irradianceTexture = device.makeTexture(descriptor: irradianceTextureDescriptor)!
        
        let prefilterTextureDescriptor = MTLTextureDescriptor.textureCubeDescriptor(
            pixelFormat: .rgba16Float, size: 128, mipmapped: false);
        prefilterTextureDescriptor.usage = [.renderTarget, .shaderRead];
        prefilterTextureDescriptor.storageMode = .private
        prefilterTexture = device.makeTexture(descriptor: prefilterTextureDescriptor)!
        
        let brdfTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rg16Float, width: 512, height: 512, mipmapped: false)
        brdfTextureDescriptor.usage = [.renderTarget, .shaderRead]
        brdfTextureDescriptor.storageMode = .private
        
        brdfLUTexture = device.makeTexture(descriptor: brdfTextureDescriptor)
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .lessEqual
        depthStencilDescriptor.isDepthWriteEnabled = true
        
        depthState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)!
        
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
        
        let mtlAttributesMap = [
            Int(ModelVertexAttributePosition.rawValue): MDLVertexAttributePosition,
            Int(ModelVertexAttributeTexcoord.rawValue): MDLVertexAttributeTextureCoordinate,
            Int(ModelVertexAttributeNormal.rawValue): MDLVertexAttributeNormal
        ]
        
        cubeMesh = try! MTKMesh.newBox(withVertexDescriptor: mtlVertexDescriptor,
                                  withAttributesMap: mtlAttributesMap,
                                  withDevice: device,
                                  withDimensions: vector_float3(2.0, 2.0, 2.0),
                                  segments: vector_uint3(1, 1, 1),
                                  geometryType: .triangles,
                                  inwardNormals: false)
        
        sphereMesh = try! MTKMesh.newSphere(withVertexDescriptor: mtlVertexDescriptor,
                                               withAttributesMap: mtlAttributesMap,
                                               withDevice: device,
                                               radii: 1.0,
                                               radialSegments: 60,
                                               verticalSegments: 60,
                                               geometryType: .triangles,
                                               inwardNormals: false,
                                               hemisphere: false)
        
        let library = device.makeDefaultLibrary()!
        let cubeVertexFunc = library.makeFunction(name: "cubeMapVertexShader")
        let cubeFragmentFunc = library.makeFunction(name: "cubeMapFragmentShader")
        
        let cubeRenderDescriptor = MTLRenderPipelineDescriptor()
        cubeRenderDescriptor.vertexDescriptor = mtlVertexDescriptor
        cubeRenderDescriptor.vertexFunction = cubeVertexFunc
        cubeRenderDescriptor.fragmentFunction = cubeFragmentFunc
        cubeRenderDescriptor.colorAttachments[0].pixelFormat = cubeTexture.pixelFormat
        cubeRenderDescriptor.inputPrimitiveTopology = .triangle
        
        cubeMapPipelineState = try! device.makeRenderPipelineState(descriptor: cubeRenderDescriptor)
        
        let irradianceFragmentFunc = library.makeFunction(name: "irradianceFragmentShader")
        
        let irradianceDescriptor = MTLRenderPipelineDescriptor()
        irradianceDescriptor.vertexDescriptor = mtlVertexDescriptor
        irradianceDescriptor.vertexFunction = cubeVertexFunc
        irradianceDescriptor.fragmentFunction = irradianceFragmentFunc
        irradianceDescriptor.colorAttachments[0].pixelFormat = irradianceTexture.pixelFormat
        irradianceDescriptor.inputPrimitiveTopology = .triangle
        
        irradiancePipelineState = try! device.makeRenderPipelineState(descriptor: irradianceDescriptor)
        
        let bgVertexFunc = library.makeFunction(name: "backgroundVertexShader")
        let bgFragmentFunc = library.makeFunction(name: "backgroundFragmentShader")
        
        let bgRenderDescriptor = MTLRenderPipelineDescriptor()
        bgRenderDescriptor.vertexDescriptor = mtlVertexDescriptor
        bgRenderDescriptor.vertexFunction = bgVertexFunc
        bgRenderDescriptor.fragmentFunction = bgFragmentFunc
        bgRenderDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        bgRenderDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        
        backgroundPipelineState = try! device.makeRenderPipelineState(descriptor: bgRenderDescriptor)
        
        let pbrVertexFunc = library.makeFunction(name: "pbrVertexShader")!
        let pbrFragmentFunc = library.makeFunction(name: "pbrFragmentShader")!
        
        let renderDescriptor = MTLRenderPipelineDescriptor()
        renderDescriptor.vertexDescriptor = mtlVertexDescriptor
        renderDescriptor.vertexFunction = pbrVertexFunc
        renderDescriptor.fragmentFunction = pbrFragmentFunc
        renderDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        renderDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        
        pbrRenderPipelineState = try! device.makeRenderPipelineState(descriptor: renderDescriptor)
        
        let prefilterFragmentFunc = library.makeFunction(name: "preFilterFragmentShader")
        
        let preFilterRenderDescriptor = MTLRenderPipelineDescriptor()
        preFilterRenderDescriptor.vertexDescriptor = mtlVertexDescriptor
        preFilterRenderDescriptor.vertexFunction = cubeVertexFunc;
        preFilterRenderDescriptor.fragmentFunction = prefilterFragmentFunc
        preFilterRenderDescriptor.colorAttachments[0].pixelFormat = prefilterTexture.pixelFormat
        preFilterRenderDescriptor.inputPrimitiveTopology = .triangle
        
        let prefilterPipelineState = try! device.makeRenderPipelineState(descriptor: preFilterRenderDescriptor)
        
        let brdfVertexFunc = library.makeFunction(name: "brdfVertexShader")
        let brdfFragmentFunc = library.makeFunction(name: "brdfFragmentShader")
        let brdfPipelineDescriptor = MTLRenderPipelineDescriptor()
        brdfPipelineDescriptor.vertexFunction = brdfVertexFunc
        brdfPipelineDescriptor.fragmentFunction = brdfFragmentFunc
        brdfPipelineDescriptor.colorAttachments[0].pixelFormat = brdfLUTexture.pixelFormat
        
        let brdfPipelineState = try! device.makeRenderPipelineState(descriptor: brdfPipelineDescriptor)
        
        rustedIronBuffer = createMaterialBuffer(fragmentFunc: pbrFragmentFunc,
                                                material: rustedIronMaterial)
        goldMatrialBuffer = createMaterialBuffer(fragmentFunc: pbrFragmentFunc,
                                                 material: goldMaterial)
        grassMaterialBuffer = createMaterialBuffer(fragmentFunc: pbrFragmentFunc,
                                                   material: grassMaterial)
        plasticMaterialBuffer = createMaterialBuffer(fragmentFunc: pbrFragmentFunc,
                                                     material: plasticMaterial)
        wallMaterialBuffer = createMaterialBuffer(fragmentFunc: pbrFragmentFunc,
                                                  material: wallMaterial)
        
        let pbrArgumentEncoder = pbrFragmentFunc.makeArgumentEncoder(bufferIndex: Int(FragmentInputIndexArguments.rawValue))
        argumentBuffer = device.makeBuffer(length: pbrArgumentEncoder.encodedLength,
                                           options: .storageModeShared)
        pbrArgumentEncoder.setArgumentBuffer(argumentBuffer, offset: 0)
        pbrArgumentEncoder.setTexture(irradianceTexture, index: Int(PBRArgumentIndexIrradianceMap.rawValue))
        pbrArgumentEncoder.setTexture(prefilterTexture, index: Int(PBRArgumentIndexPrefilterMap.rawValue))
        pbrArgumentEncoder.setTexture(brdfLUTexture, index: Int(PBRArgumentIndexBrdfLUT.rawValue))

        let quadVerties = [
            QuadVertex(position: vector_float2(-1.0,  1.0), texCoords: vector_float2(0.0, 0.0)),
            QuadVertex(position: vector_float2(-1.0, -1.0), texCoords: vector_float2(0.0, 1.0)),
            QuadVertex(position: vector_float2( 1.0,  1.0), texCoords: vector_float2(1.0, 0.0)),
            QuadVertex(position: vector_float2( 1.0, -1.0), texCoords: vector_float2(1.0, 1.0))
        ]
        
        material = Material(albedo: vector_float3(0.5, 0.0, 0.0), metallic: 1.0, roughness: 0.0, ao: 1.0)
        
        lights = [
            Light(position: vector_float3(-10.0, 10.0, 10.0), color: vector_float3(300.0, 300.0, 300.0)),
            Light(position: vector_float3( 10.0, 10.0, 10.0), color: vector_float3(300.0, 300.0, 300.0)),
            Light(position: vector_float3(-10.0,-10.0, 10.0), color: vector_float3(300.0, 300.0, 300.0)),
            Light(position: vector_float3( 10.0,-10.0, 10.0), color: vector_float3(300.0, 300.0, 300.0))
        ]
        
        // render to cubemap texture
        let cubemapParams = [
            CubeMapParams(viewMatrix: matrix_look_at_right_hand(vector_float3(0.0, 0.0, 0.0),
                                                               vector_float3(-1.0, 0.0, 0.0),
                                                               vector_float3(0.0, -1.0, 0.0)),
                          layerId: 0),
            CubeMapParams(viewMatrix: matrix_look_at_right_hand(vector_float3(0.0, 0.0, 0.0),
                                                               vector_float3(1.0, 0.0, 0.0),
                                                               vector_float3(0.0, -1.0, 0.0)),
                          layerId: 1),
            CubeMapParams(viewMatrix: matrix_look_at_right_hand(vector_float3(0.0, 0.0, 0.0),
                                                               vector_float3(0.0, 1.0, 0.0),
                                                               vector_float3(0.0, 0.0, 1.0)),
                          layerId: 2),
            CubeMapParams(viewMatrix: matrix_look_at_right_hand(vector_float3(0.0, 0.0, 0.0),
                                                               vector_float3(0.0, -1.0, 0.0),
                                                               vector_float3(0.0, 0.0, -1.0)),
                          layerId: 3),
            CubeMapParams(viewMatrix: matrix_look_at_right_hand(vector_float3(0.0, 0.0, 0.0),
                                                               vector_float3(0.0, 0.0, 1.0),
                                                               vector_float3(0.0, -1.0, 0.0)),
                          layerId: 4),
            CubeMapParams(viewMatrix: matrix_look_at_right_hand(vector_float3(0.0, 0.0, 0.0),
                                                               vector_float3(0.0, 0.0, -1.0),
                                                               vector_float3(0.0, -1.0, 0.0)),
                          layerId: 5),
        ]
        
        instanceParamsBuffer = device.makeBuffer(bytes: cubemapParams,
                                                 length: MemoryLayout<CubeMapParams>.stride * cubemapParams.count,
                                                 options: .storageModeShared)

        let commandBuffer = commandQueue.makeCommandBuffer()!

        let cubeMapRenderDescriptor = MTLRenderPassDescriptor()
        cubeMapRenderDescriptor.colorAttachments[0].texture = cubeTexture
        cubeMapRenderDescriptor.colorAttachments[0].loadAction = .clear
        cubeMapRenderDescriptor.colorAttachments[0].storeAction = .store
        cubeMapRenderDescriptor.renderTargetArrayLength = 6

        let cubeMapRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: cubeMapRenderDescriptor)!

        cubeMapRenderEncoder.setViewport(MTLViewport(originX: 0.0, originY: 0.0, width: 512, height: 512, znear: 0.0, zfar: 1.0))
        cubeMapRenderEncoder.setRenderPipelineState(cubeMapPipelineState)

        cubeMapRenderEncoder.setVertexMesh(cubeMesh, index: Int(CubeMapVertexIndexPosition.rawValue))

        let cubemapProjection = matrix_perspective_left_hand(Float.pi / 2.0, 1.0, 0.1, 10.0)
        withUnsafePointer(to: cubemapProjection) {
            cubeMapRenderEncoder.setVertexBytes($0,
                                                length: MemoryLayout<matrix_float4x4>.stride,
                                                index: Int(CubeMapVertexIndexProjection.rawValue))
        }

        cubeMapRenderEncoder.setVertexBuffer(instanceParamsBuffer,
                                             offset: 0,
                                             index: Int(CubeMapVertexIndexInstanceParams.rawValue))

        cubeMapRenderEncoder.setFragmentTexture(hdrTexture, index: 0)

        cubeMapRenderEncoder.drawMesh(cubeMesh, instanceCount: 6)
        cubeMapRenderEncoder.endEncoding()
        
        let irradianceRenderDescriptor = MTLRenderPassDescriptor()
        irradianceRenderDescriptor.colorAttachments[0].texture = irradianceTexture
        irradianceRenderDescriptor.colorAttachments[0].loadAction = .clear
        irradianceRenderDescriptor.colorAttachments[0].storeAction = .store
        irradianceRenderDescriptor.renderTargetArrayLength = 6
        
        let irradianceEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: irradianceRenderDescriptor)!
        irradianceEncoder.setViewport(MTLViewport(originX: 0.0, originY: 0.0, width: 32, height: 32, znear: 0.0, zfar: 1.0))
        irradianceEncoder.setRenderPipelineState(irradiancePipelineState)
        irradianceEncoder.setVertexMesh(cubeMesh, index: Int(CubeMapVertexIndexPosition.rawValue))
        withUnsafePointer(to: cubemapProjection) {
            irradianceEncoder.setVertexBytes($0,
                                                length: MemoryLayout<matrix_float4x4>.stride,
                                                index: Int(CubeMapVertexIndexProjection.rawValue))
        }
        irradianceEncoder.setVertexBuffer(instanceParamsBuffer,
                                          offset: 0,
                                          index: Int(CubeMapVertexIndexInstanceParams.rawValue))
        irradianceEncoder.setFragmentTexture(cubeTexture, index: 0)
        irradianceEncoder.drawMesh(cubeMesh, instanceCount: 6)
        irradianceEncoder.endEncoding()
        
        // prefilter
        let prefilterRenderPassDescriptor = MTLRenderPassDescriptor()
        prefilterRenderPassDescriptor.colorAttachments[0].texture = prefilterTexture
        prefilterRenderPassDescriptor.colorAttachments[0].loadAction = .clear
        prefilterRenderPassDescriptor.colorAttachments[0].storeAction = .store
        prefilterRenderPassDescriptor.renderTargetArrayLength = 6
        
        let prefilterEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: prefilterRenderPassDescriptor)!
        prefilterEncoder.setViewport(MTLViewport(originX: 0.0, originY: 0.0, width: 128, height: 128, znear: 0.0, zfar: 1.0))
        prefilterEncoder.setRenderPipelineState(prefilterPipelineState)
        prefilterEncoder.setVertexMesh(cubeMesh, index: Int(CubeMapVertexIndexPosition.rawValue))
        
        withUnsafePointer(to: cubemapProjection) {
            prefilterEncoder.setVertexBytes($0,
                                            length: MemoryLayout<matrix_float4x4>.stride,
                                            index: Int(CubeMapVertexIndexProjection.rawValue))
        }

        prefilterEncoder.setVertexBuffer(instanceParamsBuffer,
                                         offset: 0,
                                         index: Int(CubeMapVertexIndexInstanceParams.rawValue))
        prefilterEncoder.setFragmentTexture(cubeTexture, index: 0)
        
        // TODO: don't know how to render to texture's diffrenct mip level;
        let roughness: Float = 1.0
        withUnsafePointer(to: roughness) {
            prefilterEncoder.setFragmentBytes($0, length: MemoryLayout<Float>.stride, index: 1)
        }

        prefilterEncoder.drawMesh(cubeMesh, instanceCount: 6)
        prefilterEncoder.endEncoding()

        // brdf
        let brdfRenderPassDescriptor = MTLRenderPassDescriptor()
        brdfRenderPassDescriptor.colorAttachments[0].texture = brdfLUTexture
        brdfRenderPassDescriptor.colorAttachments[0].loadAction = .clear
        brdfRenderPassDescriptor.colorAttachments[0].storeAction = .store
        
        let brdfEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: brdfRenderPassDescriptor)!
        brdfEncoder.setViewport(MTLViewport(originX: 0.0, originY: 0.0, width: 512, height: 512, znear: 0.0, zfar: 1.0))
        brdfEncoder.setRenderPipelineState(brdfPipelineState)
        let quadVertexBuffer = device.makeBuffer(bytes: quadVerties,
                                                 length: MemoryLayout<QuadVertex>.stride * quadVerties.count,
                                                 options: .storageModeShared)
        brdfEncoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)
        
        brdfEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        brdfEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    
        let width = mtkView.frame.width
        let height = mtkView.frame.height
        
        let projection = matrix_perspective_left_hand(Float.pi / 4.0,
                                                      Float(width) / Float(height),
                                                      0.1,
                                                      100.0)
        
        uniform = Uniforms(modelMatrix: matrix4x4_identity(),
                           viewMatrix: camera.getViewMatrix(),
                           projectionMatrix: projection)
        
        viewPort = MTLViewport(originX: 0.0, originY: 0.0, width: Double(width), height: Double(height), znear: 0.0, zfar: 1.0)
    }
    
    func handleCameraEvent(deltaX: Float, deltaY: Float) {
        cameraController.rotateCameraAroundTarget(withDeltaPhi: deltaX * 0.2, deltaTheta: deltaY * 0.2)

        uniform.viewMatrix = camera.getViewMatrix()
    }
    
    private func loadHdrTexture(commandQueue: MTLCommandQueue? = nil) {
        let hdrUrl = Bundle.common.url(forResource: "newport_loft.hdr", withExtension: nil, subdirectory: "hdr")!
        hdrTexture = try! HDRTextureLoader.load(textureFrom: hdrUrl, device: device, commandQueue: commandQueue)
    }
    
    private func loadMaterialTexture(albedoPath: String,
                                     normalPath: String,
                                     metallicPath: String,
                                     roughnessPath: String,
                                     aoPath: String) -> MaterialTexture {
        let bundle = Bundle.common
        
        let albedoUrl = bundle.url(forResource: albedoPath, withExtension: nil)!
        let normalUrl = bundle.url(forResource: normalPath, withExtension: nil)!
        let metallicUrl = bundle.url(forResource: metallicPath, withExtension: nil)!
        let roughnessUrl = bundle.url(forResource: roughnessPath, withExtension: nil)!
        let aoUrl = bundle.url(forResource: aoPath, withExtension: nil)!
        
        let textureLoader = MTKTextureLoader(device: device)
        let albedo = try! textureLoader.newTexture(URL: albedoUrl, options: nil)
        let normal = try! textureLoader.newTexture(URL: normalUrl, options: nil)
        let metallic = try! textureLoader.newTexture(URL: metallicUrl, options: nil)
        let roughness = try! textureLoader.newTexture(URL: roughnessUrl, options: nil)
        let ao = try! textureLoader.newTexture(URL: aoUrl, options: nil)
        
        return MaterialTexture(albedoTexture: albedo,
                               normalTexture: normal,
                               metallicTexture: metallic,
                               roughnessTexture: roughness,
                               aoTexture: ao)
    }
    
    private func createMaterialBuffer(fragmentFunc: MTLFunction, material: MaterialTexture) -> MTLBuffer {
        let materialArgumentEncoder = fragmentFunc.makeArgumentEncoder(bufferIndex: Int(FragmentInputIndexMaterial.rawValue))
        let buffer = device.makeBuffer(length: materialArgumentEncoder.encodedLength,
                                       options: .storageModeShared)!
        materialArgumentEncoder.setArgumentBuffer(buffer, offset: 0)
        materialArgumentEncoder.setTexture(material.albedoTexture,
                                           index: Int(MaterialArgumentIndexAlbedo.rawValue))
        materialArgumentEncoder.setTexture(material.normalTexture,
                                           index: Int(MaterialArgumentIndexNormal.rawValue))
        materialArgumentEncoder.setTexture(material.metallicTexture,
                                           index: Int(MaterialArgumentIndexMetallic.rawValue))
        materialArgumentEncoder.setTexture(material.roughnessTexture,
                                           index: Int(MaterialArgumentIndexRoughness.rawValue))
        materialArgumentEncoder.setTexture(material.aoTexture,
                                           index: Int(MaterialArgumentIndexAO.rawValue))
        
        return buffer
    }
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewPort.width = Double(size.width)
        viewPort.height = Double(size.height)
        
        uniform.projectionMatrix = matrix_perspective_left_hand(Float.pi / 4.0,
                                                                Float(size.width) / Float(size.height),
                                                                0.1,
                                                                100.0)
    }
    
    func draw(in view: MTKView) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        let pbrRenderPassDescriptor = view.currentRenderPassDescriptor!
        
        let pbrRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: pbrRenderPassDescriptor)!
        
        pbrRenderEncoder.setViewport(viewPort)
        pbrRenderEncoder.setRenderPipelineState(pbrRenderPipelineState)
        pbrRenderEncoder.setDepthStencilState(depthState)
        pbrRenderEncoder.setVertexMesh(sphereMesh, index: Int(VertexInputIndexPosition.rawValue))
        
        pbrRenderEncoder.setFragmentBytes(lights,
                                          length: MemoryLayout<Light>.stride * lights.count,
                                          index: Int(FragmentInputIndexLights.rawValue))
        let lightsCount = lights.count
        withUnsafePointer(to: lightsCount) {
            pbrRenderEncoder.setFragmentBytes($0,
                                              length: MemoryLayout<Int>.stride,
                                              index: Int(FragmentInputIndexLightsCount.rawValue))
        }
        
        let cameraPosition = camera.cameraPosition
        withUnsafePointer(to: cameraPosition) {
            pbrRenderEncoder.setFragmentBytes($0,
                                              length: MemoryLayout<matrix_float4x4>.stride,
                                              index: Int(FragmentInputIndexCameraPostion.rawValue))
        }
        
        pbrRenderEncoder.useResource(irradianceTexture, usage: .sample)
        pbrRenderEncoder.useResource(prefilterTexture, usage: .sample)
        pbrRenderEncoder.useResource(brdfLUTexture, usage: .sample)
        pbrRenderEncoder.setFragmentBuffer(argumentBuffer,
                                           offset: 0,
                                           index: Int(FragmentInputIndexArguments.rawValue))
        
        // rusted iron
        uniform.modelMatrix = matrix4x4_translation(-5.0, 0.0, 2.0)
        withUnsafePointer(to: uniform) {
            pbrRenderEncoder.setVertexBytes($0,
                                            length: MemoryLayout<Uniforms>.stride,
                                            index: Int(VertexInputIndexUniforms.rawValue))
        }
        
        pbrRenderEncoder.useResource(rustedIronMaterial)
        
        pbrRenderEncoder.setFragmentBuffer(rustedIronBuffer,
                                           offset: 0,
                                           index: Int(FragmentInputIndexMaterial.rawValue))
        pbrRenderEncoder.drawMesh(sphereMesh)
        
        // gold
        uniform.modelMatrix = matrix4x4_translation(-3.0, 0.0, 2.0)
        withUnsafePointer(to: uniform) {
            pbrRenderEncoder.setVertexBytes($0,
                                            length: MemoryLayout<Uniforms>.stride,
                                            index: Int(VertexInputIndexUniforms.rawValue))
        }
        pbrRenderEncoder.useResource(goldMaterial)
        pbrRenderEncoder.setFragmentBuffer(goldMatrialBuffer,
                                           offset: 0,
                                           index: Int(FragmentInputIndexMaterial.rawValue))
        pbrRenderEncoder.drawMesh(sphereMesh)
        
        // grass
        uniform.modelMatrix = matrix4x4_translation(-1.0, 0.0, 2.0)
        withUnsafePointer(to: uniform) {
            pbrRenderEncoder.setVertexBytes($0,
                                            length: MemoryLayout<Uniforms>.stride,
                                            index: Int(VertexInputIndexUniforms.rawValue))
        }
        pbrRenderEncoder.useResource(grassMaterial)
        pbrRenderEncoder.setFragmentBuffer(grassMaterialBuffer,
                                           offset: 0,
                                           index: Int(FragmentInputIndexMaterial.rawValue))
        pbrRenderEncoder.drawMesh(sphereMesh)
        
        // plastic
        uniform.modelMatrix = matrix4x4_translation(1.0, 0.0, 2.0)
        withUnsafePointer(to: uniform) {
            pbrRenderEncoder.setVertexBytes($0,
                                            length: MemoryLayout<Uniforms>.stride,
                                            index: Int(VertexInputIndexUniforms.rawValue))
        }
        pbrRenderEncoder.useResource(plasticMaterial)
        pbrRenderEncoder.setFragmentBuffer(plasticMaterialBuffer,
                                           offset: 0,
                                           index: Int(FragmentInputIndexMaterial.rawValue))
        pbrRenderEncoder.drawMesh(sphereMesh)
        
        // wall
        uniform.modelMatrix = matrix4x4_translation(3.0, 0.0, 2.0)
        withUnsafePointer(to: uniform) {
            pbrRenderEncoder.setVertexBytes($0,
                                            length: MemoryLayout<Uniforms>.stride,
                                            index: Int(VertexInputIndexUniforms.rawValue))
        }
        pbrRenderEncoder.useResource(wallMaterial)
        pbrRenderEncoder.setFragmentBuffer(wallMaterialBuffer,
                                           offset: 0,
                                           index: Int(FragmentInputIndexMaterial.rawValue))
        pbrRenderEncoder.drawMesh(sphereMesh)
        
        // cubemap
        pbrRenderEncoder.setRenderPipelineState(backgroundPipelineState)
        pbrRenderEncoder.setVertexMesh(cubeMesh, index: Int(VertexInputIndexPosition.rawValue))
        withUnsafePointer(to: uniform) {
            pbrRenderEncoder.setVertexBytes($0,
                                            length: MemoryLayout<Uniforms>.stride,
                                            index: Int(VertexInputIndexUniforms.rawValue))
        }
        pbrRenderEncoder.setFragmentTexture(cubeTexture, index: 0)
        pbrRenderEncoder.drawMesh(cubeMesh)
        
        pbrRenderEncoder.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    
}

extension MTLRenderCommandEncoder {
    func useResource(_ material: MaterialTexture) {
        useResource(material.albedoTexture, usage: .sample)
        useResource(material.normalTexture, usage: .sample)
        useResource(material.metallicTexture, usage: .sample)
        useResource(material.roughnessTexture, usage: .sample)
        useResource(material.aoTexture, usage: .sample)
    }
}
