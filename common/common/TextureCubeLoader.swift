//
//  TextureCubeLoader.swift
//  common
//
//  Created by Jacob Su on 3/23/21.
//

import Foundation
import Metal
import AppKit

@objc
public class TextureCubeLoader: NSObject {
    
    private override init() {
    }
    
    @objc
    public class func load(withImageNames names: [String],
                           device: MTLDevice,
                           commandQueue: MTLCommandQueue) throws -> MTLTexture {
        if names.count != 6 {
            throw Errors.runtimeError("image numbers must be 6, but has \(names.count).")
        }
        
        let bundle = Bundle(for: TextureCubeLoader.self)
        let path = bundle.path(forResource: names.first!, ofType: "")!
    
        let url = URL(fileURLWithPath: path)
        
        let image = NSImage(contentsOf: url)!
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let cubeSize = cgImage.width
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * cubeSize
        let bytesPerImage = bytesPerRow * cubeSize
        
        let region = MTLRegionMake2D(0, 0, Int(cubeSize), Int(cubeSize))
        
        let textureDescritpor = MTLTextureDescriptor.textureCubeDescriptor(pixelFormat: .rgba8Unorm, size: Int(cubeSize), mipmapped: true)
        
        let texture = device.makeTexture(descriptor: textureDescritpor)!
        for slice in 0..<6 {
            let imagePath = bundle.path(forResource: names[slice], ofType: "")
            let imageUrl = URL(fileURLWithPath: imagePath!)
            let image = NSImage(contentsOf: imageUrl)!
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
            
            if cgImage.width != cubeSize ||
                cgImage.height != cubeSize {
                throw Errors.runtimeError("image \(names[slice]) width|height don't match \(cubeSize)")
            }
            
            let rawData = UnsafeMutableRawPointer.allocate(byteCount: cubeSize * cubeSize * bytesPerPixel, alignment: 1)

            ImageUtils.drawRGBA8Bitmap(to: rawData, fromImage: cgImage)
            
            texture.replace(region: region,
                            mipmapLevel: 0,
                            slice: slice,
                            withBytes: UnsafeRawPointer(rawData),
                            bytesPerRow: bytesPerRow,
                            bytesPerImage: bytesPerImage)
            
            rawData.deallocate()
        }
        
        let mipmapCommandBuffer = commandQueue.makeCommandBuffer()!
        let blitCommandEncoder = mipmapCommandBuffer.makeBlitCommandEncoder()!
        blitCommandEncoder.generateMipmaps(for: texture)
        blitCommandEncoder.endEncoding()
        mipmapCommandBuffer.commit()
        
        return texture
    }
}
