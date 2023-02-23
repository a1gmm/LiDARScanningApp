import SwiftUI
import MetalKit

struct ContentView: View {
  @ObservedObject var coordinator: Coordinator
    var body: some View {
      ZStack {
        ZStack {
          ARDisplayView(coordinator: coordinator)
        }
        .ignoresSafeArea(.all)
      }
      .sheet(isPresented: $coordinator.isSharePresented, content: {
        if let file: Data = {
          let temp = coordinator.fileToExport
          coordinator.fileToExport = nil
          return temp
        }() {
          ActivityViewController(fileToExport: file)
        }
      })
    }
}

struct ARDisplayView: View {
  @ObservedObject var coordinator: Coordinator
  
  var body: some View {
    let bounds = UIScreen.main.bounds
    
    MetalView(coordinator: coordinator)
      .disabled(false)
      .frame(width: bounds.height, height: bounds.width)
      .rotationEffect(.degrees(90))
      .position(x: bounds.width * 0.5, y: bounds.height * 0.5)
  }
}

struct MetalView: UIViewRepresentable {
  @ObservedObject var coordinator: Coordinator
  
  func makeCoordinator() -> Coordinator {
    coordinator
  }
  
  func makeUIView(context: Context) -> MTKView {
    context.coordinator.view
  }
  
  func updateUIView(_ uiView: MTKView, context: Context) {}
}

