//
//  HDRTextureLoader.swift
//  common
//
//  Created by Jacob Su on 4/18/21.
//

import Foundation
import Metal
import AppKit

@objc
public class HDRTextureLoader: NSObject {
    
    private override init() {
    }
    
    @objc
    public class func load(textureFrom url: URL,
                           device: MTLDevice,
                           commandQueue: MTLCommandQueue? = nil) throws -> MTLTexture {
        let hdrImage = NSImage(contentsOf: url)!
        let hdrCGImage = hdrImage.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let hdrImageWidth = hdrCGImage.width
        let hdrImageHeight = hdrCGImage.height
        
        let bytesPerComponent = hdrCGImage.bitsPerComponent / 8
        let pixelChannelCount = 4
        var bytesPerPixel = bytesPerComponent * pixelChannelCount
        var textureFormat : MTLPixelFormat = .rgba32Float
        if bytesPerComponent == 4 {
            textureFormat = .rgba32Float
        } else if bytesPerComponent == 2 {
            textureFormat = .rgba16Float
        } else if bytesPerComponent == 1 {
            textureFormat = .rgba8Unorm
            bytesPerPixel = pixelChannelCount * 1
        } else {
            throw Errors.runtimeError("unsupported CGImage bytesPerComponet \(bytesPerComponent).")
        }
        
        let bytesPerRow = bytesPerPixel * hdrImageWidth
        let bytesPerImage = bytesPerRow * hdrImageHeight
        
        
        let region = MTLRegionMake2D(0, 0, Int(hdrImageWidth), Int(hdrImageHeight))
        
        let hdrTextureDescritpor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: textureFormat,
                                                                         width: hdrImageWidth,
                                                                         height: hdrImageHeight,
                                                                         mipmapped: commandQueue != nil)
        hdrTextureDescritpor.usage = [.shaderRead]
        
        let hdrTexture = device.makeTexture(descriptor: hdrTextureDescritpor)!
        
        let rawData = UnsafeMutableRawPointer.allocate(byteCount: bytesPerImage, alignment: 1)

        if textureFormat == .rgba8Unorm {
            ImageUtils.drawRGBA8Bitmap(to: rawData, fromImage: hdrCGImage)
        } else {
            try ImageUtils.copyBitmap(to: rawData, dstChannelCount: pixelChannelCount, fromImage: hdrCGImage)
        }
        
        hdrTexture.replace(region: region,
                           mipmapLevel: 0,
                           withBytes: UnsafeRawPointer(rawData),
                           bytesPerRow: bytesPerRow)
        
        defer {
            rawData.deallocate()
        }
        
        if let commandQueue = commandQueue {
            let mipmapCommandBuffer = commandQueue.makeCommandBuffer()!
            let blitCommandEncoder = mipmapCommandBuffer.makeBlitCommandEncoder()!
            blitCommandEncoder.generateMipmaps(for: hdrTexture)
            blitCommandEncoder.endEncoding()
            mipmapCommandBuffer.commit()
        }
        
        return hdrTexture
    }
}
