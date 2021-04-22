//
//  Renderer.swift
//  Text
//
//  Created by Jacob Su on 4/21/21.
//

import Foundation
import MetalKit
import common

struct Glyph {
    var texture: MTLTexture
    var size: vector_float2
    var bearing: vector_float2 // offset from baseline to left/top of glyph
    var advance: Float
    var glyphCode: CGGlyph
    var fontSize: Float
}

struct CharacterKey : Hashable {
    var char: Character
    var isStroked: Bool
}

private let FONT_SIZE: Float = 100

class Renderer: NSObject {
    
    private var device: MTLDevice!
    private var glyphs: [CharacterKey: Glyph]!
    private var projectionMatrix: matrix_float4x4!
    private var renderPipelineState: MTLRenderPipelineState!
    private var commandQueue: MTLCommandQueue!
    private var viewport: MTLViewport!
    
    init(mtkView: MTKView) {
        super.init()
        
        device = mtkView.device!
        mtkView.delegate = self
        mtkView.clearColor = MTLClearColor(red: 0.2, green: 0.3, blue: 0.3, alpha: 1.0)
        
        glyphs = [:]
        
        let width = mtkView.frame.width
        let height = mtkView.frame.height
        
        projectionMatrix = matrix_ortho_left_hand(0.0, Float(width), Float(height), 0, -100.0, 100.0);
        commandQueue = device.makeCommandQueue()!
        
        let library = device.makeDefaultLibrary()!
        let vertexFunc = library.makeFunction(name: "vertexShader")!
        let fragmentFunc = library.makeFunction(name: "fragmentShader")!
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = vertexFunc
        renderPipelineDescriptor.fragmentFunction = fragmentFunc
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        
        renderPipelineState = try! device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        viewport = MTLViewport(originX: 0.0, originY: 0.0, width: Double(width), height: Double(height), znear: 0.0, zfar: 1.0)
        
    }
    
    private func loadGlyphs(_ char: Character, isStroke: Bool, fontSize: Float = FONT_SIZE) -> Glyph {
        let charKey = CharacterKey(char: char, isStroked: isStroke)
        
        if glyphs.keys.contains(charKey) &&
            glyphs[charKey]!.fontSize >= fontSize {
            return glyphs[charKey]!
        }
        
//        let font = NSFont(name: "PingFangSC-Semibold", size: CGFloat(FONT_SIZE))!
        let font = NSFont(name: "Antonio-Bold", size: CGFloat(FONT_SIZE))!
        let ctFont = CTFontCreateWithName(font.fontName as CFString, CGFloat(FONT_SIZE), nil)
        var aGlyph: CGGlyph = 0
        withUnsafePointer(to: char.utf16.first!) {
            CTFontGetGlyphsForCharacters(ctFont, $0, &aGlyph, 1)
            return
        }
        
        if aGlyph == kCGFontIndexInvalid || aGlyph == 0 {
            NSLog("can not find glyph")
        }
        
        let rect = withUnsafePointer(to: aGlyph) {
            return CTFontGetBoundingRectsForGlyphs(ctFont, .horizontal, $0, nil, 1)
        }
        
        let advance = withUnsafePointer(to: aGlyph) {
            return CTFontGetAdvancesForGlyphs(ctFont, .horizontal, $0, nil, 1)
        }
        
        let affineTransform = CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: -rect.origin.x, ty: -rect.origin.y )
        
        
        let path = withUnsafePointer(to: affineTransform) {
            return CTFontCreatePathForGlyph(ctFont, aGlyph, $0)
        }
        // TODO: wait the beizer curve impl
//        path?.apply(info: nil, function: { rawPointer, element in
//
//            switch element.pointee.type {
//            case .moveToPoint:
//                NSLog("Move to Point")
//                NSLog("\t \(element.pointee.points.pointee)")
//
//
//            case .addLineToPoint:
//                NSLog("add line to point")
//                NSLog("\t \(element.pointee.points.pointee)")
//
//
//            case .addCurveToPoint:
//                NSLog("add curve to point")
//                NSLog("\t \(element.pointee.points.pointee)")
//                NSLog("\t \(element.pointee.points.advanced(by: 1).pointee)")
//                NSLog("\t \(element.pointee.points.advanced(by: 2).pointee)")
//
//
//            case .addQuadCurveToPoint:
//                NSLog("add Quad curve to point")
//                NSLog("\t \(element.pointee.points.pointee)")
//                NSLog("\t \(element.pointee.points.advanced(by: 1).pointee)")
//
//            case .closeSubpath:
//                NSLog("close subpath")
//
//            @unknown default:
//                fatalError()
//            }
//        })
        
        let width = Int(rect.width + 1)
        let height = Int(rect.height + 1)
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)

        let rawData = UnsafeMutableRawPointer.allocate(byteCount: width * height * 4, alignment: 1)
        
        let context = CGContext(data: rawData,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: width,
                                space: colorSpace,
                                bitmapInfo: bitmapInfo.rawValue)!
        context.setAllowsAntialiasing(false)
        context.setFillColor(CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0))
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))

        context.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        context.setStrokeColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        context.setLineWidth(1.0)
        
        if path != nil {
            context.addPath(path!)
            if isStroke {
                context.strokePath()
            } else {
                context.fillPath()
            }
        }
        
        // handle rawData here
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm,
                                                                         width: width,
                                                                         height: height,
                                                                         mipmapped: false)
        textureDescriptor.usage = .shaderRead
        textureDescriptor.storageMode = .managed
        
        let texture = device.makeTexture(descriptor: textureDescriptor)!
        
        
        texture.replace(region: MTLRegionMake2D(0, 0, width, height),
                         mipmapLevel: 0,
                         withBytes: rawData,
                         bytesPerRow: width)
        
        defer {
            rawData.deallocate()
        }
        
        
        let character = Glyph(texture: texture,
                             size: vector_float2(Float(rect.width), Float(rect.height)),
                             bearing: vector_float2(Float(rect.minX), Float(rect.maxY)),
                             advance: Float(advance),
                             glyphCode: aGlyph,
                             fontSize: fontSize)
        
        glyphs[charKey] = character
        
        return character
    }
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewport.width = Double(size.width)
        viewport.height = Double(size.height)
        
        projectionMatrix = matrix_ortho_left_hand(0.0, Float(size.width), Float(size.height), 0.0, -100.0, 100.0)
    }
    
    func draw(in view: MTKView) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        let renderPassDescriptor = view.currentRenderPassDescriptor!
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        renderEncoder.setViewport(viewport)
        renderEncoder.setRenderPipelineState(renderPipelineState)
        
        renderEncoder.setVertexBytes(&projectionMatrix,
                                     length: MemoryLayout<matrix_float4x4>.stride,
                                     index: 1)
    
        var origin = vector_float2(50.0, 250.0)
        renderText("This is sample text", renderEncoder: renderEncoder, origin: &origin, isStrok: false)
        origin = vector_float2(400.0, 600.0)
        renderText("(C) ", renderEncoder: renderEncoder, origin: &origin, isStrok: true)
        renderText("LearnOpenGL", renderEncoder: renderEncoder, origin: &origin, isStrok: false)
        renderText(".com", renderEncoder: renderEncoder, origin: &origin, isStrok: true)
        
        renderEncoder.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    private func renderText(_ text: String, renderEncoder: MTLRenderCommandEncoder, origin: inout vector_float2, isStrok: Bool) {
        
        for a in text {
            let glyph = loadGlyphs(a, isStroke: isStrok)
            
            if glyph.glyphCode == 0 {
                origin.x += glyph.advance
                continue
            }
            
            let lt = vector_float2(origin.x + glyph.bearing.x, origin.y - glyph.bearing.y)
            let rt = lt + vector_float2(glyph.size.x, 0.0);
            let lb = lt + vector_float2(0.0, glyph.size.y);
            let rb = lt + vector_float2(glyph.size.x, glyph.size.y);
            
            let verties = [
                Vertex(position: lt, texCoords: vector_float2(0.0, 0.0)),
                Vertex(position: rt, texCoords: vector_float2(1.0, 0.0)),
                Vertex(position: lb, texCoords: vector_float2(0.0, 1.0)),
                Vertex(position: rb, texCoords: vector_float2(1.0, 1.0))
            ]
            
            renderEncoder.setVertexBytes(verties, length: MemoryLayout<Vertex>.stride * verties.count, index: 0)
            
            renderEncoder.setFragmentTexture(glyph.texture, index: 0)
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            
            origin.x += glyph.advance
        }
    }
    
}

