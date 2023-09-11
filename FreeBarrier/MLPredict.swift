//
//  MLPredict.swift
//  FreeBarrier
//
//  Created by Lau on 2023/08/24.
//

import UIKit
import CoreML

class MLPredict {
    let imageProcessor = ImageProcessor()
    
    func predictMLArray(intermediateImage: UIImage, mlInstance: MobileNetV2) -> (leftPredictionString: String, middlePredictionString: String, rightPredictionString: String) {
        let splitImages = imageProcessor.splitImageIntoThreeParts(image: intermediateImage)
        var result: [String] = []
        for image in splitImages {
            let croppedImage = imageProcessor.cropImageTo224x224(image: image)
            let buffer = imageProcessor.bufferFromImage(from: croppedImage)!
            let prediction = try! mlInstance.prediction(image: buffer)
            result.append(prediction.classLabel.components(separatedBy: ", ")[0])
        }
        return (result[0], result[1], result[2])
    }
}