//
//  FreeBarrierApp.swift
//  FreeBarrier
//
//  Created by Lau on 2023/08/20.
//

import SwiftUI
import ARKit
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if !ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) ||
            !ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            // Ensure that the device supports scene depth and present
            //  an error-message view controller, if not.
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            window = UIWindow(frame: UIScreen.main.bounds)
            window?.rootViewController = storyboard.instantiateViewController(withIdentifier: "unsupportedDeviceMessage")
            window?.makeKeyAndVisible()
        }
        return true
    }
}

@main
struct FreeBarrierApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
