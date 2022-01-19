//
//  SimpleRecorderApp.swift
//  SimpleRecorder
//
//  Created by Xiao Quan on 1/18/22.
//

import SwiftUI
import AVFoundation


class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
		let session = AVAudioSession.sharedInstance()
		do {
			try session.setCategory(.playAndRecord, options: [.allowBluetooth])
			try session.setActive(true)
		} catch {
			print("Error setting AVAudioSession Category", error.localizedDescription)
		}
        
		print("Simulator Directory: \(NSHomeDirectory())")
		
        return true
    }
}

@main
struct LearningAVFoundationApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	
    var body: some Scene {
        WindowGroup {
            RecorderView()
        }
    }
}
