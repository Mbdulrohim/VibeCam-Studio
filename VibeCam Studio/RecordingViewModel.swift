//
//  RecordingViewModel.swift
//  VibeCam Studio
//
//  Created by abdulrohim on 22/10/2025.
//

import SwiftUI
import Combine
import AVFoundation
import CoreGraphics

enum RecordingQuality: String, CaseIterable, Identifiable {
    case low = "Low (720p)"
    case medium = "Medium (1080p)"
    case high = "High (1440p)"
    case ultra = "Ultra (4K)"

    var id: String { rawValue }

    var bitrate: Int {
        switch self {
        case .low: return 3_000_000      // 3 Mbps
        case .medium: return 8_000_000   // 8 Mbps
        case .high: return 15_000_000    // 15 Mbps
        case .ultra: return 30_000_000   // 30 Mbps
        }
    }

    var exportPreset: String {
        switch self {
        case .low: return AVAssetExportPresetMediumQuality
        case .medium: return AVAssetExportPresetHighestQuality
        case .high: return AVAssetExportPresetHighestQuality
        case .ultra: return AVAssetExportPresetHighestQuality
        }
    }

    var cameraDimensions: (width: Int, height: Int) {
        switch self {
        case .low:
            return (1280, 720)
        case .medium:
            return (1920, 1080)
        case .high:
            return (2560, 1440)
        case .ultra:
            return (3840, 2160)
        }
    }

    var cameraSessionPreset: AVCaptureSession.Preset {
        switch self {
        case .low:
            return .hd1280x720
        case .medium:
            return .hd1920x1080
        case .high, .ultra:
            return .hd4K3840x2160
        }
    }
}

enum OverlayPosition: String, CaseIterable, Identifiable {
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"

    var id: String { rawValue }
}

enum OverlaySizeOption: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case square = "1:1"
    case fourThree = "4:3"
    case sixteenNine = "16:9"

    var id: String { rawValue }
}

class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isCameraEnabled = true
    @Published var isMicrophoneEnabled = true
    @Published var isScreenPreviewEnabled = false
    @Published var statusMessage: String?
    @Published var recordingQuality: RecordingQuality = .medium
    @Published var overlayPosition: OverlayPosition = .bottomRight
    @Published var overlaySize: OverlaySizeOption = .auto
    @Published var selectedCamera: AVCaptureDevice?

    private var screenRecorder: ScreenRecorder?
    private var cameraService: CameraService?
    private var videoCompositor: VideoCompositor?
    private var sessionFolderURL: URL?

    init() {
        setupServices()
    }

    private func setupServices() {
        screenRecorder = ScreenRecorder()
        cameraService = CameraService()
        videoCompositor = VideoCompositor()
    }

    private func createSessionFolder() throws -> URL {
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let vibeCamDir = downloadsURL.appendingPathComponent("VibeCam")

        // Create VibeCam directory if it doesn't exist
        try FileManager.default.createDirectory(at: vibeCamDir, withIntermediateDirectories: true, attributes: nil)

        // Create timestamped session folder
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let sessionFolderName = "Recording_\(timestamp)"
        let sessionFolder = vibeCamDir.appendingPathComponent(sessionFolderName)

        // Create session folder
        try FileManager.default.createDirectory(at: sessionFolder, withIntermediateDirectories: true, attributes: nil)

        return sessionFolder
    }

    func startRecording() {
        guard !isRecording else { return }

        statusMessage = "Starting recording..."

        // Request permissions and start recording
        Task {
            do {
                // Check permissions
                let screenPermission = await requestScreenRecordingPermission()
                let cameraPermission = await requestCameraPermission()
                let microphonePermission = await requestMicrophonePermission()

                if !screenPermission {
                    await MainActor.run {
                        statusMessage = "Screen recording permission required"
                    }
                    return
                }

                if !cameraPermission && isCameraEnabled {
                    await MainActor.run {
                        statusMessage = "Camera permission required"
                    }
                    return
                }

                if !microphonePermission && isMicrophoneEnabled {
                    await MainActor.run {
                        statusMessage = "Microphone permission required"
                    }
                    return
                }

                // Create session folder
                let sessionFolder = try createSessionFolder()
                await MainActor.run {
                    self.sessionFolderURL = sessionFolder
                }

                // Start recording
                await MainActor.run {
                    isRecording = true
                    statusMessage = "Recording screen and camera..."
                }

                // Start screen recording with quality settings
                try screenRecorder?.startRecording(bitrate: recordingQuality.bitrate, sessionFolder: sessionFolder)

                // Start camera recording if enabled
                if isCameraEnabled {
                    do {
                        try await cameraService?.startRecording(camera: selectedCamera,
                                                              bitrate: recordingQuality.bitrate,
                                                              sessionPreset: recordingQuality.cameraSessionPreset,
                                                              outputDimensions: recordingQuality.cameraDimensions,
                                                              sessionFolder: sessionFolder)
                    } catch {
                        await MainActor.run {
                            isRecording = false
                            statusMessage = "Failed to start camera recording: \(error.localizedDescription)"
                        }
                        return
                    }
                }

            } catch {
                await MainActor.run {
                    isRecording = false
                    statusMessage = "Failed to start recording: \(error.localizedDescription)"
                }
            }
        }
    }

    func toggleCamera() {
        if isCameraEnabled {
            // If turning off, just set to false
            isCameraEnabled = false
        } else {
            // If turning on, request permission first
            statusMessage = "Requesting camera permission..."
            Task {
                let granted = await requestCameraPermission()
                await MainActor.run {
                    isCameraEnabled = granted
                    if granted {
                        statusMessage = "Camera permission granted"
                    } else {
                        statusMessage = "Camera permission denied. Please enable in System Settings > Privacy & Security > Camera and add 'VibeCam Studio'."
                    }
                }
            }
        }
    }

    func toggleMicrophone() {
        if isMicrophoneEnabled {
            // If turning off, just set to false
            isMicrophoneEnabled = false
        } else {
            // If turning on, request permission first
            statusMessage = "Requesting microphone permission..."
            Task {
                let granted = await requestMicrophonePermission()
                await MainActor.run {
                    isMicrophoneEnabled = granted
                    if granted {
                        statusMessage = "Microphone permission granted"
                    } else {
                        statusMessage = "Microphone permission denied. Please enable in System Settings > Privacy & Security > Microphone and add 'VibeCam Studio'."
                    }
                }
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        statusMessage = "Stopping recording..."

        Task {
            do {
                // Stop recordings
                try screenRecorder?.stopRecording()
                if isCameraEnabled {
                    try cameraService?.stopRecording()
                }

                await MainActor.run {
                    isRecording = false
                    self.sessionFolderURL = nil
                }

                // Wait a moment for files to finish writing
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                // Merge videos if camera was enabled
                if isCameraEnabled,
                   let screenURL = screenRecorder?.outputURL,
                   let cameraURL = cameraService?.outputURL,
                   let sessionFolder = self.sessionFolderURL {

                    await MainActor.run {
                        statusMessage = "Merging screen and camera videos..."
                    }

                    await mergeVideos(screenURL: screenURL, cameraURL: cameraURL, sessionFolder: sessionFolder)
                } else {
                    await MainActor.run {
                        statusMessage = "Recording saved to Downloads/VibeCam folder"
                    }
                }

            } catch {
                await MainActor.run {
                    isRecording = false
                    statusMessage = "Error stopping recording: \(error.localizedDescription)"
                }
            }
        }
    }

    private func mergeVideos(screenURL: URL, cameraURL: URL, sessionFolder: URL) async {
        await withCheckedContinuation { continuation in
            videoCompositor?.mergeVideos(screenURL: screenURL, cameraURL: cameraURL, overlayPosition: overlayPosition, overlaySize: overlaySize, exportPreset: recordingQuality.exportPreset, sessionFolder: sessionFolder) { result in
                Task { @MainActor in
                    switch result {
                    case .success(let mergedURL):
                        self.statusMessage = "Recording complete! Saved to: \(mergedURL.deletingLastPathComponent().lastPathComponent)/"
                    case .failure(let error):
                        self.statusMessage = "Merge failed: \(error.localizedDescription). Individual files saved."
                    }
                    continuation.resume()
                }
            }
        }
    }

    private func requestScreenRecordingPermission() async -> Bool {
        // For macOS, we need to request screen recording permission
        if #available(macOS 10.15, *) {
            let status = CGRequestScreenCaptureAccess()
            return status
        }
        return true // Older macOS versions don't require explicit permission
    }

    private func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            // Double-check that camera is actually available
            return AVCaptureDevice.default(for: .video) != nil
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted && (AVCaptureDevice.default(for: .video) != nil)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}
