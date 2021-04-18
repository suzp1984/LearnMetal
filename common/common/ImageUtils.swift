//
//  ImageUtils.swift
//  common
//
//  Created by Jacob Su on 4/18/21.
//

import Foundation

@objc
public class ImageUtils: NSObject {
    
    private override init() {
    }
    
    public class func drawRGBA8Bitmap(to rawData: UnsafeMutableRawPointer,
                                      fromImage image: CGImage) -> Void {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGImageByteOrderInfo.order32Big.rawValue)
        
        let context = CGContext(data: rawData,
                                width: width,
                                height: height,
                                bitsPerComponent: bitsPerComponent,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: bitmapInfo.rawValue)!
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return
    }
    
    public class func copyBitmap(to dstData: UnsafeMutableRawPointer,
                                    dstChannelCount: Int,
                                    fromImage image: CGImage) throws -> Void {
        let width = image.width
        let height = image.height
        let pixelCount = width * height
        
        let srcChannelCount = image.bitsPerPixel / image.bitsPerComponent
        let bytesPerComponent = image.bitsPerComponent / 8
        let shouldFillLastChannelComponent = dstChannelCount == srcChannelCount + 1
        
        let alpha16Fill = float16_from_float32(1.0);
        let alpha8Fill: uint8 = 1
        let alpha32Fill: Float = 1.0
        
        let srcData = UnsafeRawPointer(CFDataGetBytePtr(image.dataProvider!.data)!)
        for texIdx in 0..<pixelCount {
            let currSrc = srcData.advanced(by: texIdx * srcChannelCount * bytesPerComponent)
            let currDst = dstData.advanced(by: texIdx * dstChannelCount * bytesPerComponent)
            currDst.copyMemory(from: currSrc, byteCount: srcChannelCount * bytesPerComponent)
            if (shouldFillLastChannelComponent) {
                switch bytesPerComponent {
                case 4:
                    withUnsafePointer(to: alpha32Fill) {
                        currDst.advanced(by: srcChannelCount * bytesPerComponent).copyMemory(from: $0, byteCount: bytesPerComponent)
                    }
                case 2:
                    withUnsafePointer(to: alpha16Fill) {
                        currDst.advanced(by: srcChannelCount * bytesPerComponent).copyMemory(from: $0, byteCount: bytesPerComponent)
                    }
                case 1:
                    withUnsafePointer(to: alpha8Fill) {
                        currDst.advanced(by: srcChannelCount * bytesPerComponent).copyMemory(from: $0, byteCount: bytesPerComponent)
                    }
                default:
                    throw Errors.runtimeError("unsupported bytesPerComponent \(bytesPerComponent)")
                }
            }
            
        }
        
        return
    }
}
