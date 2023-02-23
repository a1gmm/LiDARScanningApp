import SwiftUI

@main
struct LiDARScanningAppApp: App {
    var body: some Scene {
        WindowGroup {
          ContentView(coordinator: Coordinator())
        }
    }
}
