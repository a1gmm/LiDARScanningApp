//
//  Processor.swift
//  FreeBarrier
//
//  Created by Lau on 2023/08/24.
//

import UIKit
import Accelerate
import SwiftUI

class ARData {
    func getMinDepthAtY(y: Int, arsession: Depth) -> Float {
        
        let xRange = 0...255
        var minDepth = Float.greatestFiniteMagnitude
        let depthData = arsession.getDepthDistance()
        
        for x in xRange {
            
            let depthAtxy = depthData.get(x: x, y: y)
            if depthAtxy < minDepth {
                minDepth = depthAtxy
            }
        }
        
        return Float(String(format: "%.2f", minDepth))!
    }
}

class TextProcessor {
    func getTextPosition(index: Int) -> CGPoint {
        let ringRadius = UIScreen.main.bounds.width * 0.6 / 2
        let ringLineWidth: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 30 : 10
        let angle = Double(index) * 60 + 30
        let radians = angle * Double.pi / 180
        let textRadius = ringRadius + ringLineWidth + 20
        let xoffset = UIScreen.main.bounds.width * 0.5
        let yoffset = UIScreen.main.bounds.height * 0.5 - 150
        let x = textRadius * CGFloat(cos(radians))
        let y = textRadius * CGFloat(sin(radians))
        return CGPoint(x: x+xoffset, y: y+yoffset)
    }
}

class ImageProcessor {
    func pixelBufferToImage(pixelBuffer:CVPixelBuffer) -> UIImage {
        //01
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        //02
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }
        
        //03
        let lumaBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
        //04
        let lumaWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let lumaHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let lumaRowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        var sourceLumaBuffer = vImage_Buffer(data: lumaBaseAddress, height: vImagePixelCount(lumaHeight), width: vImagePixelCount(lumaWidth), rowBytes: lumaRowBytes)
        
        let chromaBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)
        let chromaWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1)
        let chromaHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
        let chromaRowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
        var sourceChromaBuffer = vImage_Buffer(data: chromaBaseAddress, height: vImagePixelCount(chromaHeight), width: vImagePixelCount(chromaWidth), rowBytes: chromaRowBytes)
        
        //05
        var rawRGBBuffer: UnsafeMutableRawPointer = malloc(lumaWidth * lumaHeight * 4)
        var rgbBuffer: vImage_Buffer = vImage_Buffer(data: rawRGBBuffer, height: vImagePixelCount(lumaHeight), width: vImagePixelCount(lumaWidth), rowBytes: lumaWidth * 4)
        
        //06
        guard var conversionInfoYpCbCrToARGB = _conversionInfoYpCbCrToARGB else {
            return UIImage()
        }
        
        //07
        guard vImageConvert_420Yp8_CbCr8ToARGB8888(&sourceLumaBuffer, &sourceChromaBuffer, &rgbBuffer, &conversionInfoYpCbCrToARGB, nil, 255, vImage_Flags(kvImageNoFlags)) == kvImageNoError else {
            return UIImage()
        }
        
        //08
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: rgbBuffer.data, width: lumaWidth, height: lumaHeight, bitsPerComponent: 8, bytesPerRow: rgbBuffer.rowBytes, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        let imageRef = ctx!.makeImage()!
        let uiimage = UIImage(cgImage: imageRef)
        
        //09 
        rawRGBBuffer.deallocate()
        return uiimage
    }
    
    private var _conversionInfoYpCbCrToARGB: vImage_YpCbCrToARGB? = {
        var pixelRange = vImage_YpCbCrPixelRange(Yp_bias: 16, CbCr_bias: 128, YpRangeMax: 235, CbCrRangeMax: 240, YpMax: 235, YpMin: 16, CbCrMax: 240, CbCrMin: 16)
        var infoYpCbCrToARGB = vImage_YpCbCrToARGB()
        guard vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_601_4!, &pixelRange, &infoYpCbCrToARGB, kvImage422CbYpCrYp8, kvImageARGB8888, vImage_Flags(kvImageNoFlags)) == kvImageNoError else {
            return nil
        }
        return infoYpCbCrToARGB
    }()
    
    func bufferFromImage(from image: UIImage) -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.size.width), Int(image.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard (status == kCVReturnSuccess) else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context?.translateBy(x: 0, y: image.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context!)
        image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
    
    // only use the center 224 x 224 of the given image
    func cropImageTo224x224(image: UIImage) -> UIImage {
        let cgImage = image.cgImage!
        let width = cgImage.width
        let height = cgImage.height
        let x = (width - 224) / 2
        let y = (height - 224) / 2
        let rect = CGRect(x: x, y: y, width: 224, height: 224)
        let croppedCGImage = cgImage.cropping(to: rect)
        return UIImage(cgImage: croppedCGImage!)
    }
    
    func splitImageIntoThreeParts(image: UIImage) -> [UIImage] {
        let imageWidth = image.size.width
        let imageHeight = image.size.height
        
        let leftToFrame = CGRect(x: 0, y: 0, width: imageWidth / 3, height: imageHeight)
        let middleToFrame = CGRect(x: imageWidth / 3, y: 0, width: imageWidth / 3, height: imageHeight)
        let rightToFrame = CGRect(x: 2 * imageWidth / 3, y: 0, width: imageWidth / 3, height: imageHeight)
        
        let leftCGImage = image.cgImage!.cropping(to: leftToFrame)!
        let middleCGImage = image.cgImage!.cropping(to: middleToFrame)!
        let rightCGImage = image.cgImage!.cropping(to: rightToFrame)!
        
        let leftFrame = UIImage(cgImage: leftCGImage)
        let middleFrame = UIImage(cgImage: middleCGImage)
        let rightFrame = UIImage(cgImage: rightCGImage)
        
        return [leftFrame, middleFrame, rightFrame]
    }
}

class RingProcessor {
    func getRingColor(depth: Float) -> Color {
        if depth < 0.5 {
            return .red
        } else if depth < 1.0 {
            return .orange
        } else {
            return .green
        }
    }
}