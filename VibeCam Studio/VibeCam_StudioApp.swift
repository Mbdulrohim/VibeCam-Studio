//
//  VibeCam_StudioApp.swift
//  VibeCam Studio
//
//  Created by abdulrohim on 22/10/2025.
//

import SwiftUI

@main
struct VibeCam_StudioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        
        WindowGroup(id: "floating-camera") {
            FloatingCameraWindow()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
    }
}
