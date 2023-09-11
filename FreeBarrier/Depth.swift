//
//  Depth.swift
//  FreeBarrier
//
//  Created by Lau on 2023/08/21.
//

import ARKit

class Depth {
    private let arARSession:ARSession
    private var depthData:ARDepthData?
    init(arARSession:ARSession,arConfiguration:ARConfiguration) {
        self.arARSession = arARSession
        arConfiguration.frameSemantics = .sceneDepth
        arARSession.run(arConfiguration)
        depthData = arARSession.currentFrame?.sceneDepth
    }
    // get depth UIImage
    // Depth UIImage is a normalized grayscale image. Distances are encoded in brightness, the closest objects are dark, while the further ones are light.
    func getUIImage() -> UIImage {
        if let depthData = arARSession.currentFrame?.sceneDepth{
            let myCImage = CIImage(cvPixelBuffer: depthData.depthMap)
            return UIImage(ciImage: myCImage)
        }
        return UIImage()
    }
    // get detailed data
    func getDepthDistance() -> DepthData {
        let depthFloatData = DepthData()
        if let depth = arARSession.currentFrame?.sceneDepth?.depthMap{
            let depthWidth = CVPixelBufferGetWidth(depth)
            let depthHeight = CVPixelBufferGetHeight(depth)
            CVPixelBufferLockBaseAddress(depth, CVPixelBufferLockFlags(rawValue: 0))
            let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(depth), to: UnsafeMutablePointer<Float32>.self)
            for y in 0...depthHeight-1 {
                for x in 0...depthWidth-1 {
                    let distanceAtXYPoint = floatBuffer[y*depthWidth+x]
                    depthFloatData.set(x: x, y: y, floatData: distanceAtXYPoint)
                }
            }
        }
        return depthFloatData
    }
    // get ARFrame and return a CVImageBuffer
    func getARFrame() -> CVImageBuffer? {
        return arARSession.currentFrame?.capturedImage
    }
}

class DepthData {
    private var data = Array(repeating: Array(repeating: Float(-1), count: 192), count: 256)
    func set(x:Int,y:Int,floatData:Float) {
        data[x][y] = floatData
    }
    // x range 255, y range 191
    func get(x:Int, y:Int) -> Float {
        if x > 255 || y > 191 {
            print("data range error")
            return -1
        }
        return data[x][y]
    }
}
