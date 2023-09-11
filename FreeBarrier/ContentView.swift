//
//  ContentView.swift
//  FreeBarrier
//
//  Created by Lau on 2023/08/20.
//

import SwiftUI
import ARKit
import CoreML

class RingData: ObservableObject {
    @Published var colors: [Color] = [.green, .green, .green, .green, .green, .green]
    @Published var texts: [String] = ["", "", "", "", "", ""]
    @Published var labels: [String] = ["", "", "", "", "", ""]
}

struct Ring: Shape {
    let radius: CGFloat
    let startAngle: Angle
    let endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false)
        return path
    }
}

struct ContentView: View {
    let ringRadius = UIScreen.main.bounds.width * 0.6 / 2
    let ringLineWidth: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 30 : 10
    
    @State var coldLaunch = true
    
    @ObservedObject var ringData = RingData()
    
    let textProcessor = TextProcessor()
    let imageProcessor = ImageProcessor()
    let arData = ARData()
    let ringProcessor = RingProcessor()
    let mlPredict = MLPredict()
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    let arsession = Depth(arARSession: ARSession(), arConfiguration: ARWorldTrackingConfiguration())
    
    let model = try! MobileNetV2(configuration: MLModelConfiguration())
    
    // model input: 224x224 color
    // model output: string and dictionary, we only need the string
    
    var body: some View {
        VStack {
            
            Text("盲人避障")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 50)
            Divider()
            Spacer()
            
            ZStack {
                ForEach(0..<6) { index in
                    ZStack {
                        Ring(radius: ringRadius, startAngle: .zero, endAngle: .init(radians: 3/Double.pi))
                            .stroke(ringData.colors[index], lineWidth: ringLineWidth)
                            .rotationEffect(.init(degrees: Double(index) * 60))
                        
                        Text(ringData.texts[index])
                            .foregroundColor(.black)
                            .fontWeight(.bold)
                            .position(textProcessor.getTextPosition(index: index))
                    }
                }
            }
            
            Spacer()
            
            Divider()
            
            Text("激光雷达检测中")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .padding(.bottom, 50)
                .overlay(
                    Image(systemName: "magnifyingglass.circle")
                        .font(.title)
                        .foregroundColor(.blue)
                        .padding(.leading, -40)
                        .padding(.bottom, 50),
                    alignment: .bottomLeading
                )
        }
        .onReceive(timer) { _ in
            DispatchQueue.global().async {
                // Perform long-running task here
                
                if coldLaunch {
                    // sleep for 1 second
                    sleep(1)
                    coldLaunch = false
                }
                
                let coordinates = [0, 96, 191]
                let parts = coordinates.map { arData.getMinDepthAtY(y: $0, arsession: arsession) }
                let (leftPart, middlePart, rightPart) = (parts[0], parts[1], parts[2])
                
                if leftPart < 0.5 || middlePart < 0.5 || rightPart < 0.5 {
                    playSound()
                }
                
                var newColors = ringData.colors
                
                newColors = Array([newColors[0], newColors[1], newColors[2]] + [leftPart, middlePart, rightPart].map { ringProcessor.getRingColor(depth: $0) })
                
                let pixelBuffer = arsession.getARFrame()!
                let intermediateImage = imageProcessor.pixelBufferToImage(pixelBuffer: pixelBuffer)
                
                let (leftPredictionString, middlePredictionString, rightPredictionString): (String, String, String) = mlPredict.predictMLArray(intermediateImage: intermediateImage, mlInstance: model)
                let newTexts = ["", "", "", "\(leftPart)m, \(leftPredictionString)", "\(middlePart)m, \(middlePredictionString)", "\(rightPart)m, \(rightPredictionString)"]
                
                // update ringData on the main thread
                DispatchQueue.main.async {
                    
                    ringData.texts = newTexts
                    ringData.colors = newColors
                }
            }
        }
    }
}
