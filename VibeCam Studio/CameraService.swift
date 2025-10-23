//
//  CameraService.swift
//  VibeCam Studio
//
//  Created by abdulrohim on 22/10/2025.
//

import Foundation
import AVFoundation

class CameraService: NSObject {
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var sessionStartTime: CMTime?
    private let sessionQueue = DispatchQueue(label: "CameraServiceSessionQueue")
    
    private(set) var outputURL: URL?
    
    private func createOutputURL(sessionFolder: URL? = nil) throws -> URL {
        if let sessionFolder = sessionFolder {
            return sessionFolder.appendingPathComponent("person_video.mov")
        } else {
            let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            let vibeCamDir = downloadsURL.appendingPathComponent("VibeCam")
            
            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(at: vibeCamDir, withIntermediateDirectories: true, attributes: nil)
            
            return vibeCamDir.appendingPathComponent("camera_recording_\(Date().timeIntervalSince1970).mov")
        }
    }
    
    func startRecording(camera: AVCaptureDevice? = nil,
                        bitrate: Int = 5_000_000,
                        sessionPreset: AVCaptureSession.Preset = .hd1920x1080,
                        outputDimensions: (width: Int, height: Int)? = nil,
                        sessionFolder: URL? = nil) async throws {
        // Create output URL first
        outputURL = try createOutputURL(sessionFolder: sessionFolder)
        
        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: outputURL!.path) {
            try FileManager.default.removeItem(at: outputURL!)
        }
        
        // Check camera permission (don't request here, should be done in ViewModel)
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        guard authorizationStatus == .authorized else {
            throw NSError(domain: "CameraService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Camera access not authorized"])
        }
        
        // Get camera device - use provided camera or default
        let selectedCamera: AVCaptureDevice
        if let providedCamera = camera {
            // Re-acquire by uniqueID to make sure we have a fresh, connected instance
            if let freshCamera = AVCaptureDevice(uniqueID: providedCamera.uniqueID) {
                selectedCamera = freshCamera
                print("CameraService: Using selected camera: \(freshCamera.localizedName) (\(freshCamera.uniqueID))")
            } else {
                print("CameraService: Warning - could not reacquire camera with ID \(providedCamera.uniqueID). Falling back to provided instance.")
                selectedCamera = providedCamera
            }
        } else {
            guard let defaultCamera = AVCaptureDevice.default(for: .video) else {
                throw NSError(domain: "CameraService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No camera available"])
            }
            selectedCamera = defaultCamera
            print("CameraService: Using default camera: \(defaultCamera.localizedName) (\(defaultCamera.uniqueID))")
        }
        
        // Create capture session
        captureSession = AVCaptureSession()
        guard let captureSession else {
            throw NSError(domain: "CameraService", code: -10, userInfo: [NSLocalizedDescriptionKey: "Failed to create capture session"])
        }
        
        var activePreset = sessionPreset
        if captureSession.canSetSessionPreset(sessionPreset) {
            captureSession.sessionPreset = sessionPreset
        } else if captureSession.canSetSessionPreset(.hd1920x1080) {
            activePreset = .hd1920x1080
            captureSession.sessionPreset = activePreset
            print("CameraService: Warning - preset \(sessionPreset.rawValue) unsupported, downgraded to HD 1080p")
        } else if captureSession.canSetSessionPreset(.hd1280x720) {
            activePreset = .hd1280x720
            captureSession.sessionPreset = activePreset
            print("CameraService: Warning - preset \(sessionPreset.rawValue) unsupported, downgraded to HD 720p")
        } else {
            activePreset = .high
            captureSession.sessionPreset = activePreset
            print("CameraService: Warning - preset \(sessionPreset.rawValue) unsupported, using .high")
        }
        
        // Add camera input
        let cameraInput = try AVCaptureDeviceInput(device: selectedCamera)
        if captureSession.canAddInput(cameraInput) {
            captureSession.addInput(cameraInput)
        } else {
            var fallbackPreset: AVCaptureSession.Preset?
            if activePreset != .hd1920x1080, captureSession.canSetSessionPreset(.hd1920x1080) {
                fallbackPreset = .hd1920x1080
            } else if activePreset != .hd1280x720, captureSession.canSetSessionPreset(.hd1280x720) {
                fallbackPreset = .hd1280x720
            } else if activePreset != .high, captureSession.canSetSessionPreset(.high) {
                fallbackPreset = .high
            }
            if let fallbackPreset {
                captureSession.beginConfiguration()
                captureSession.sessionPreset = fallbackPreset
                captureSession.commitConfiguration()
                activePreset = fallbackPreset
                if captureSession.canAddInput(cameraInput) {
                    captureSession.addInput(cameraInput)
                    print("CameraService: Adjusted preset to \(fallbackPreset.rawValue) to accommodate camera input")
                } else {
                    throw NSError(domain: "CameraService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Cannot add camera input even after preset fallback"])
                }
            } else {
                throw NSError(domain: "CameraService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Cannot add camera input"])
            }
        }
        
        // Add microphone audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if captureSession.canAddInput(audioInput) {
                    captureSession.addInput(audioInput)
                    print("CameraService: Added microphone audio input")
                }
            } catch {
                print("CameraService: Failed to add audio input: \(error.localizedDescription)")
            }
        }
        
        // Create video output
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput?.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput?.alwaysDiscardsLateVideoFrames = false
        
        let queue = DispatchQueue(label: "CameraQueue")
        videoOutput?.setSampleBufferDelegate(self, queue: queue)
        
        guard captureSession.canAddOutput(videoOutput!) else {
            throw NSError(domain: "CameraService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Cannot add video output"])
        }
        captureSession.addOutput(videoOutput!)
        
        // Create audio output
        audioOutput = AVCaptureAudioDataOutput()
        let audioQueue = DispatchQueue(label: "CameraAudioQueue")
        audioOutput?.setSampleBufferDelegate(self, queue: audioQueue)
        
        if captureSession.canAddOutput(audioOutput!) {
            captureSession.addOutput(audioOutput!)
            print("CameraService: Added audio output")
        }
        
        // Create asset writer
        assetWriter = try AVAssetWriter(outputURL: outputURL!, fileType: .mov)
        
        // Video input settings
        func dimensions(for preset: AVCaptureSession.Preset) -> (Int, Int) {
            switch preset {
            case .hd4K3840x2160: return (3840, 2160)
            case .hd1920x1080: return (1920, 1080)
            case .hd1280x720: return (1280, 720)
            default: return (1280, 720)
            }
        }
        let targetDimensions = outputDimensions ?? dimensions(for: activePreset)
        print("CameraService: Using output dimensions: \(targetDimensions.width) x \(targetDimensions.height)")
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: targetDimensions.width,
            AVVideoHeightKey: targetDimensions.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoMaxKeyFrameIntervalKey: 30
            ]
        ]
        
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true
        
        // Pixel buffer adaptor
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: targetDimensions.width,
            kCVPixelBufferHeightKey as String: targetDimensions.height
        ]
        
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput!,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )
        
        guard assetWriter!.canAdd(videoInput!) else {
            throw NSError(domain: "CameraService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Cannot add video input"])
        }
        
        assetWriter!.add(videoInput!)
        
        // Audio input settings
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000
        ]
        
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput?.expectsMediaDataInRealTime = true
        
        if assetWriter!.canAdd(audioInput!) {
            assetWriter!.add(audioInput!)
            print("CameraService: Added audio input to asset writer")
        }
        
        sessionStartTime = nil

        // Start writing
        guard assetWriter!.startWriting() else {
            let error = assetWriter!.error
            print("AVAssetWriter failed to start writing: \(error?.localizedDescription ?? "Unknown error")")
            throw NSError(domain: "CameraService", code: -6, userInfo: [NSLocalizedDescriptionKey: "Failed to start writing: \(error?.localizedDescription ?? "Unknown error")"])
        }
        
        // Start capture session
        captureSession.startRunning()
        print("CameraService: Capture session started")
    }
    
    func stopRecording() throws {
        captureSession?.stopRunning()
        captureSession = nil
        sessionStartTime = nil
        
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        assetWriter?.finishWriting {
            if let url = self.outputURL {
                print("Camera recording saved to: \(url.path)")
            }
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {
        
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        // Start session on first sample (video or audio) - thread-safe
        sessionQueue.sync {
            if sessionStartTime == nil {
                sessionStartTime = presentationTime
                assetWriter?.startSession(atSourceTime: presentationTime)
                print("CameraService: Started session at time: \(CMTimeGetSeconds(presentationTime))")
            }
        }
        
        // Handle video samples
        if output is AVCaptureVideoDataOutput {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                print("CameraService: No pixel buffer in sample buffer")
                return
            }

            if videoInput?.isReadyForMoreMediaData == true {
                pixelBufferAdaptor?.append(pixelBuffer, withPresentationTime: presentationTime)
            } else {
                print("CameraService: Video input not ready for more media data")
            }
        }
        // Handle audio samples
        else if output is AVCaptureAudioDataOutput {
            if audioInput?.isReadyForMoreMediaData == true {
                audioInput?.append(sampleBuffer)
            } else {
                print("CameraService: Audio input not ready for more media data")
            }
        }
    }
}