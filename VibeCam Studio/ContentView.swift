//
//  ContentView.swift
//  VibeCam Studio
//
//  Created by abdulrohim on 22/10/2025.
//

import SwiftUI
import AppKit
import AVFoundation

struct ContentView: View {
    @StateObject private var recordingVM = RecordingViewModel()
    @State private var availableCameras: [AVCaptureDevice] = []
    
    // macOS native colors
    private let accentColor = Color.accentColor
    private let backgroundColor = Color(NSColor.windowBackgroundColor)
    private let controlBackground = Color(NSColor.controlBackgroundColor)
    private let secondaryLabel = Color(NSColor.secondaryLabelColor)
    private let labelColor = Color(NSColor.labelColor)
    
    private func loadAvailableCameras() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        availableCameras = discoverySession.devices
        
        print("ContentView: Found \(availableCameras.count) cameras")
        for camera in availableCameras {
            print("  - \(camera.localizedName) (\(camera.uniqueID))")
        }
        
        // Set default to FaceTime camera if available
        if let faceTimeCamera = availableCameras.first(where: { $0.localizedName.contains("FaceTime") }) {
            recordingVM.selectedCamera = faceTimeCamera
            print("ContentView: Selected FaceTime camera: \(faceTimeCamera.localizedName)")
        } else if let firstCamera = availableCameras.first {
            recordingVM.selectedCamera = firstCamera
            print("ContentView: Selected first camera: \(firstCamera.localizedName)")
        } else {
            print("ContentView: No cameras available")
        }
    }

    private func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        } else {
            // Fallback: open System Preferences main page
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }

    var body: some View {
        ZStack {
            // Native macOS background
            backgroundColor
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        // Logo/Title
                        HStack(spacing: 12) {
                            Circle()
                                .fill(accentColor)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("VibeCam Studio")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(labelColor)
                                Text("Professional Screen Recording")
                                    .font(.system(size: 12))
                                    .foregroundColor(secondaryLabel)
                            }
                        }
                        
                        Spacer()
                        
                        // Camera Selector
                        HStack(spacing: 12) {
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(accentColor)
                            Picker("Camera", selection: $recordingVM.selectedCamera) {
                                ForEach(availableCameras, id: \.uniqueID) { camera in
                                    Text(camera.localizedName)
                                        .tag(camera as AVCaptureDevice?)
                                }
                            }
                            .frame(width: 220)
                            .pickerStyle(.menu)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(controlBackground)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)
                .padding(.bottom, 30)
                .onAppear {
                    loadAvailableCameras()
                }

                // Main Content Area
                VStack(spacing: 40) {
                    // Recording Status Card
                    VStack(spacing: 20) {
                        HStack(spacing: 16) {
                            Circle()
                                .fill(recordingVM.isRecording ? Color.red : accentColor)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                )
                                .shadow(color: recordingVM.isRecording ? Color.red.opacity(0.3) : accentColor.opacity(0.3), radius: 6)

                            Text(recordingVM.isRecording ? "Recording in Progress" : "Ready to Record")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(recordingVM.isRecording ? .red : labelColor)
                        }
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                        .background(controlBackground)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 40)

                    // Controls Grid
                    VStack(spacing: 24) {
                        // Device Control Buttons
                        HStack(spacing: 16) {
                            // Camera Button
                            ControlButton(
                                icon: recordingVM.isCameraEnabled ? "video.fill" : "video.slash.fill",
                                label: "Camera",
                                isEnabled: recordingVM.isCameraEnabled,
                                color: accentColor
                            ) {
                                recordingVM.toggleCamera()
                            }
                            
                            // Microphone Button
                            ControlButton(
                                icon: recordingVM.isMicrophoneEnabled ? "mic.fill" : "mic.slash.fill",
                                label: "Microphone",
                                isEnabled: recordingVM.isMicrophoneEnabled,
                                color: accentColor
                            ) {
                                recordingVM.toggleMicrophone()
                            }
                            
                            // Screen Preview Button
                            ControlButton(
                                icon: recordingVM.isScreenPreviewEnabled ? "rectangle.on.rectangle" : "rectangle.on.rectangle",
                                label: "Preview",
                                isEnabled: recordingVM.isScreenPreviewEnabled,
                                color: accentColor
                            ) {
                                recordingVM.isScreenPreviewEnabled.toggle()
                            }
                        }
                        .padding(.horizontal, 40)
                    
                        // Quality Selector
                        HStack(spacing: 16) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 20))
                                .foregroundColor(accentColor)
                            
                            Text("Quality:")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(secondaryLabel)
                            
                            Picker("Quality", selection: $recordingVM.recordingQuality) {
                                ForEach(RecordingQuality.allCases) { quality in
                                    Text(quality.rawValue)
                                        .tag(quality)
                                }
                            }
                            .frame(width: 200)
                            .pickerStyle(.menu)
                            .disabled(recordingVM.isRecording)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(controlBackground)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .padding(.horizontal, 40)
                        
                        // Overlay Size Selector - COMMENTED OUT FOR AUTO SIZING
                        /*
                        HStack(spacing: 16) {
                            Image(systemName: "aspectratio")
                                .font(.system(size: 20))
                                .foregroundColor(accentColor)
                            
                            Text("Camera Size:")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(secondaryLabel)
                            
                            Picker("Size", selection: $recordingVM.overlaySize) {
                                ForEach(OverlaySizeOption.allCases) { size in
                                    Text(size.rawValue)
                                        .tag(size)
                                }
                            }
                            .frame(width: 200)
                            .pickerStyle(.menu)
                            .disabled(recordingVM.isRecording)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(controlBackground)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .padding(.horizontal, 40)
                        */
                        
                        // Overlay Position Selector
                        HStack(spacing: 16) {
                            Image(systemName: "square.on.square")
                                .font(.system(size: 20))
                                .foregroundColor(accentColor)
                            
                            Text("Camera Position:")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(secondaryLabel)
                            
                            Picker("Position", selection: $recordingVM.overlayPosition) {
                                ForEach(OverlayPosition.allCases) { position in
                                    Text(position.rawValue)
                                        .tag(position)
                                }
                            }
                            .frame(width: 200)
                            .pickerStyle(.menu)
                            .disabled(recordingVM.isRecording)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(controlBackground)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .padding(.horizontal, 40)
                    
                        // Start/Stop Recording Button
                        Button(action: {
                            if recordingVM.isRecording {
                                recordingVM.stopRecording()
                            } else {
                                recordingVM.startRecording()
                            }
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: recordingVM.isRecording ? "stop.circle.fill" : "record.circle.fill")
                                    .font(.system(size: 32))
                                Text(recordingVM.isRecording ? "Stop Recording" : "Start Recording")
                                    .font(.system(size: 20, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: 400)
                            .padding(.vertical, 24)
                            .background(recordingVM.isRecording ? Color.red : accentColor)
                            .cornerRadius(12)
                            .shadow(color: (recordingVM.isRecording ? Color.red : accentColor).opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .scaleEffect(recordingVM.isRecording ? 1.0 : 1.0)
                        .animation(.spring(response: 0.3), value: recordingVM.isRecording)
                        .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 20)
                }

                // Status Messages
                if let message = recordingVM.statusMessage {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: message.contains("complete") || message.contains("saved") ? "checkmark.circle.fill" : "info.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(message.contains("complete") || message.contains("saved") ? .green : accentColor)
                            
                            Text(message)
                                .font(.system(size: 14))
                                .foregroundColor(secondaryLabel)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(controlBackground)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

                        // Show permission button if it's a permission issue
                        if message.contains("permission required") {
                            Button(action: {
                                openSystemPreferences()
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "gear")
                                        .font(.system(size: 16))
                                    Text("Open System Settings")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(accentColor)
                                .cornerRadius(8)
                                .shadow(color: accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }

                // Preview (when enabled)
                if recordingVM.isScreenPreviewEnabled {
                    VStack(spacing: 16) {
                        Text("Recording Preview")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(labelColor)
                        
                        HStack(spacing: 16) {
                            // Screen Preview
                            VStack(spacing: 8) {
                                Text("Screen")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(secondaryLabel)
                                
                                ZStack {
                                    Rectangle()
                                        .fill(Color.black.opacity(0.8))
                                        .frame(width: 320, height: 180)
                                    
                                    VStack(spacing: 8) {
                                        Image(systemName: "display")
                                            .font(.system(size: 40))
                                            .foregroundColor(accentColor.opacity(0.5))
                                        Text("Screen will be captured")
                                            .font(.system(size: 12))
                                            .foregroundColor(secondaryLabel)
                                    }
                                }
                                .cornerRadius(8)
                            }
                            
                            // Camera Preview
                            VStack(spacing: 8) {
                                Text("Camera")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(secondaryLabel)
                                
                                SimpleCameraPreview()
                                    .frame(width: 240, height: 180)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(accentColor, lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
                
                Spacer()
            }
        }
    }
}

// Custom Control Button Component
struct ControlButton: View {
    let icon: String
    let label: String
    let isEnabled: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isEnabled ? color.opacity(0.15) : Color(NSColor.separatorColor).opacity(0.3))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(isEnabled ? color : Color(NSColor.secondaryLabelColor))
                }
                
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isEnabled ? color : Color(NSColor.secondaryLabelColor))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Simple Camera Preview Component
struct SimpleCameraPreview: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        
        // Setup camera preview
        DispatchQueue.global(qos: .userInitiated).async {
            guard let camera = AVCaptureDevice.default(for: .video) else {
                print("SimpleCameraPreview: No camera available")
                return
            }
            
            let session = AVCaptureSession()
            session.sessionPreset = .medium
            
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if session.canAddInput(input) {
                    session.addInput(input)
                }
                
                let previewLayer = AVCaptureVideoPreviewLayer(session: session)
                previewLayer.videoGravity = .resizeAspectFill
                
                DispatchQueue.main.async {
                    previewLayer.frame = view.bounds
                    view.layer?.addSublayer(previewLayer)
                    
                    DispatchQueue.global(qos: .userInitiated).async {
                        session.startRunning()
                        print("SimpleCameraPreview: Camera session started")
                    }
                }
                
                // Store session in view's associated object to keep it alive
                objc_setAssociatedObject(view, "captureSession", session, .OBJC_ASSOCIATION_RETAIN)
                
            } catch {
                print("SimpleCameraPreview: Error setting up camera: \(error)")
            }
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update preview layer frame if needed
        if let previewLayer = nsView.layer?.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = nsView.bounds
        }
    }
    
    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        // Stop the session when view is removed
        if let session = objc_getAssociatedObject(nsView, "captureSession") as? AVCaptureSession {
            session.stopRunning()
            print("SimpleCameraPreview: Camera session stopped")
        }
    }
}

#Preview {
    ContentView()
}
