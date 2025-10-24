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
    @Published var recordingDuration: TimeInterval = 0

    private var screenRecorder: ScreenRecorder?
    private var cameraService: CameraService?
    private var videoCompositor: VideoCompositor?
    private var sessionFolderURL: URL?
    private var exportedAudioURL: URL?
    private var recordingStartDate: Date?
    private var durationTimer: Timer?

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
        exportedAudioURL = nil

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
                    startDurationTimer()
                }

                // Start both recordings simultaneously to ensure sync
                if isCameraEnabled {
                    // Start both at the same time using async tasks
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        // Start screen recording
                        group.addTask {
                            try self.screenRecorder?.startRecording(bitrate: self.recordingQuality.bitrate, sessionFolder: sessionFolder)
                        }
                        
                        // Start camera recording
                        group.addTask {
                            try await self.cameraService?.startRecording(camera: self.selectedCamera,
                                                                        bitrate: self.recordingQuality.bitrate,
                                                                        sessionPreset: self.recordingQuality.cameraSessionPreset,
                                                                        outputDimensions: self.recordingQuality.cameraDimensions,
                                                                        sessionFolder: sessionFolder)
                        }
                        
                        // Wait for both to start
                        try await group.waitForAll()
                    }
                } else {
                    // Only screen recording
                    try screenRecorder?.startRecording(bitrate: recordingQuality.bitrate, sessionFolder: sessionFolder)
                }

            } catch {
                await MainActor.run {
                    isRecording = false
                    statusMessage = "Failed to start recording: \(error.localizedDescription)"
                    stopDurationTimer()
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
                var screenRecordingURL: URL?
                if let screenRecorder = screenRecorder {
                    screenRecordingURL = try await screenRecorder.stopRecording()
                }

                var cameraRecordingURL: URL?
                if isCameraEnabled, let cameraService = cameraService {
                    cameraRecordingURL = try await cameraService.stopRecording()
                }

                let sessionFolder = await MainActor.run { self.sessionFolderURL }

                await MainActor.run {
                    isRecording = false
                    stopDurationTimer()
                }

                // Wait a moment for files to finish writing
                try await Task.sleep(nanoseconds: 500_000_000)

                // Export standalone audio track if available
                var audioExportURL: URL?
                if let sessionFolder,
                   let screenURL = screenRecordingURL ?? screenRecorder?.outputURL {
                    await MainActor.run {
                        statusMessage = "Exporting audio track..."
                    }

                    do {
                        audioExportURL = try await exportAudioTrack(from: screenURL, sessionFolder: sessionFolder)
                    } catch {
                        print("RecordingViewModel: Audio export failed with error: \(error.localizedDescription)")
                        await MainActor.run {
                            statusMessage = "Audio export failed: \(error.localizedDescription). Continuing with video processing."
                        }
                    }
                }

                await MainActor.run {
                    self.exportedAudioURL = audioExportURL
                }

                // Merge videos if camera was enabled
                if isCameraEnabled,
                   let screenURL = screenRecordingURL ?? screenRecorder?.outputURL,
                   let cameraURL = cameraRecordingURL ?? cameraService?.outputURL,
                   let sessionFolder = sessionFolder {

                    await MainActor.run {
                        statusMessage = "Merging screen and camera videos..."
                    }

                    await mergeVideos(screenURL: screenURL, cameraURL: cameraURL, sessionFolder: sessionFolder)
                } else {
                    await MainActor.run {
                        statusMessage = "Recording saved to Downloads/VibeCam folder"
                        if let audioFileName = self.exportedAudioURL?.lastPathComponent {
                            statusMessage = "Recording saved to Downloads/VibeCam folder (Audio: \(audioFileName))"
                        }
                        self.sessionFolderURL = nil
                        self.exportedAudioURL = nil
                    }
                }

            } catch {
                await MainActor.run {
                    isRecording = false
                    statusMessage = "Error stopping recording: \(error.localizedDescription)"
                    self.exportedAudioURL = nil
                    stopDurationTimer()
                }
            }
        }
    }

    private func mergeVideos(screenURL: URL, cameraURL: URL, sessionFolder: URL) async {
        await withCheckedContinuation { continuation in
            // Get wall-clock start times for synchronization
            let screenStartTime = screenRecorder?.wallClockStartTime
            let cameraStartTime = cameraService?.wallClockStartTime
            
            videoCompositor?.mergeVideos(screenURL: screenURL, 
                                        cameraURL: cameraURL, 
                                        screenStartTime: screenStartTime,
                                        cameraStartTime: cameraStartTime,
                                        overlayPosition: overlayPosition, 
                                        overlaySize: overlaySize, 
                                        exportPreset: recordingQuality.exportPreset, 
                                        sessionFolder: sessionFolder) { result in
                Task { @MainActor in
                    switch result {
                    case .success(let mergedURL):
                        let folderName = mergedURL.deletingLastPathComponent().lastPathComponent
                        var message = "Recording complete! Saved to: \(folderName)/"
                        if let audioFileName = self.exportedAudioURL?.lastPathComponent {
                            message += " (Audio: \(audioFileName))"
                        }
                        self.statusMessage = message
                    case .failure(let error):
                        var message = "Merge failed: \(error.localizedDescription). Individual files saved."
                        if let audioFileName = self.exportedAudioURL?.lastPathComponent {
                            message += " Audio track saved as \(audioFileName)."
                        }
                        self.statusMessage = message
                    }
                    self.sessionFolderURL = nil
                    self.exportedAudioURL = nil
                    continuation.resume()
                }
            }
        }
    }

    private func exportAudioTrack(from screenURL: URL, sessionFolder: URL) async throws -> URL? {
        let asset = AVURLAsset(url: screenURL)
        guard !asset.tracks(withMediaType: .audio).isEmpty else {
            print("RecordingViewModel: No audio track found in screen recording - skipping audio export")
            return nil
        }

        let audioOutputURL = sessionFolder.appendingPathComponent("session_audio.m4a")

        if FileManager.default.fileExists(atPath: audioOutputURL.path) {
            try FileManager.default.removeItem(at: audioOutputURL)
        }

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "RecordingViewModel", code: -20, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio export session"])
        }

        exportSession.outputURL = audioOutputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = CMTimeRange(start: .zero, duration: asset.duration)

        return try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    print("RecordingViewModel: Audio track exported to \(audioOutputURL.path)")
                    continuation.resume(returning: audioOutputURL)
                case .failed, .cancelled:
                    let error = exportSession.error ?? NSError(domain: "RecordingViewModel", code: -21, userInfo: [NSLocalizedDescriptionKey: "Audio export failed"])
                    continuation.resume(throwing: error)
                default:
                    let error = exportSession.error ?? NSError(domain: "RecordingViewModel", code: -22, userInfo: [NSLocalizedDescriptionKey: "Unexpected audio export status"])
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    deinit {
        durationTimer?.invalidate()
    }

    @MainActor
    private func startDurationTimer() {
        recordingStartDate = Date()
        recordingDuration = 0
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let startDate = self.recordingStartDate else { return }
            self.recordingDuration = Date().timeIntervalSince(startDate)
        }
        if let durationTimer {
            RunLoop.main.add(durationTimer, forMode: .common)
        }
    }

    @MainActor
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
        recordingStartDate = nil
        recordingDuration = 0
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
