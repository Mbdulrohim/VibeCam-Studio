//
//  ScreenRecorder.swift
//  VibeCam Studio
//
//  Created by abdulrohim on 22/10/2025.
//

import Foundation
import AVFoundation

class ScreenRecorder: NSObject {
    private var captureSession: AVCaptureSession?
    private var screenInput: AVCaptureScreenInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var sessionStartTime: CMTime?
    private let sessionQueue = DispatchQueue(label: "ScreenRecorderSessionQueue")
    private(set) var wallClockStartTime: Date?

    private(set) var outputURL: URL?

    private func createOutputURL(sessionFolder: URL? = nil) throws -> URL {
        if let sessionFolder = sessionFolder {
            return sessionFolder.appendingPathComponent("screen_record.mov")
        } else {
            let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            let vibeCamDir = downloadsURL.appendingPathComponent("VibeCam")

            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(at: vibeCamDir, withIntermediateDirectories: true, attributes: nil)

            return vibeCamDir.appendingPathComponent("screen_recording_\(Date().timeIntervalSince1970).mov")
        }
    }

    func startRecording(bitrate: Int = 10_000_000, sessionFolder: URL? = nil) throws {
        // Create output URL first
        outputURL = try createOutputURL(sessionFolder: sessionFolder)

        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: outputURL!.path) {
            try FileManager.default.removeItem(at: outputURL!)
        }

        // Create capture session
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .high

        // Create screen input
        screenInput = AVCaptureScreenInput(displayID: CGMainDisplayID())
        screenInput?.minFrameDuration = CMTimeMake(value: 1, timescale: 30) // 30 FPS
        screenInput?.capturesMouseClicks = true

        print("Screen input created for display ID: \(CGMainDisplayID())")
        print("Display bounds: \(CGDisplayBounds(CGMainDisplayID()))")

        guard captureSession?.canAddInput(screenInput!) == true else {
            throw NSError(domain: "ScreenRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot add screen input"])
        }
        captureSession?.addInput(screenInput!)

        // Add microphone audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if captureSession?.canAddInput(audioInput) == true {
                    captureSession?.addInput(audioInput)
                    print("ScreenRecorder: Added microphone audio input")
                }
            } catch {
                print("ScreenRecorder: Failed to add audio input: \(error.localizedDescription)")
            }
        }

        // Create video output
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput?.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput?.alwaysDiscardsLateVideoFrames = false

        let queue = DispatchQueue(label: "ScreenRecorderQueue")
        videoOutput?.setSampleBufferDelegate(self, queue: queue)

        guard captureSession?.canAddOutput(videoOutput!) == true else {
            throw NSError(domain: "ScreenRecorder", code: -4, userInfo: [NSLocalizedDescriptionKey: "Cannot add video output"])
        }
        captureSession?.addOutput(videoOutput!)

        // Create audio output
        audioOutput = AVCaptureAudioDataOutput()
        let audioQueue = DispatchQueue(label: "ScreenRecorderAudioQueue")
        audioOutput?.setSampleBufferDelegate(self, queue: audioQueue)

        if captureSession?.canAddOutput(audioOutput!) == true {
            captureSession?.addOutput(audioOutput!)
            print("ScreenRecorder: Added audio output")
        }

        // Create asset writer
        assetWriter = try AVAssetWriter(outputURL: outputURL!, fileType: .mov)

        // Video input settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: CGDisplayPixelsWide(CGMainDisplayID()),
            AVVideoHeightKey: CGDisplayPixelsHigh(CGMainDisplayID()),
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
            kCVPixelBufferWidthKey as String: CGDisplayPixelsWide(CGMainDisplayID()),
            kCVPixelBufferHeightKey as String: CGDisplayPixelsHigh(CGMainDisplayID())
        ]

        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput!,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )

        guard assetWriter!.canAdd(videoInput!) else {
            throw NSError(domain: "ScreenRecorder", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot add video input"])
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
            print("ScreenRecorder: Added audio input to asset writer")
        }

        sessionStartTime = nil
        wallClockStartTime = nil

        // Start writing
        guard assetWriter!.startWriting() else {
            let error = assetWriter!.error
            print("AVAssetWriter failed to start writing: \(error?.localizedDescription ?? "Unknown error")")
            throw NSError(domain: "ScreenRecorder", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to start writing: \(error?.localizedDescription ?? "Unknown error")"])
        }

        // Start capture session
        captureSession?.startRunning()
        print("ScreenRecorder: Capture session started")
    }

    func stopRecording() async throws -> URL? {
        captureSession?.stopRunning()
        captureSession = nil
        sessionStartTime = nil

        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        guard let assetWriter else {
            let url = outputURL
            cleanupWriterResources()
            return url
        }

        return try await withCheckedThrowingContinuation { continuation in
            assetWriter.finishWriting {
                defer { self.cleanupWriterResources() }

                if let error = assetWriter.error {
                    continuation.resume(throwing: error)
                    return
                }

                if let url = self.outputURL {
                    print("Screen recording saved to: \(url.path)")
                }

                continuation.resume(returning: self.outputURL)
            }
        }
    }

    private func cleanupWriterResources() {
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        pixelBufferAdaptor = nil
    }
}

extension ScreenRecorder: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Start session on first sample (video or audio) - thread-safe
        sessionQueue.sync {
            if sessionStartTime == nil {
                sessionStartTime = presentationTime
                wallClockStartTime = Date()
                assetWriter?.startSession(atSourceTime: presentationTime)
                print("ScreenRecorder: Started session at time: \(CMTimeGetSeconds(presentationTime)), wall clock: \(wallClockStartTime!)")
            }
        }

        // Handle video samples
        if output is AVCaptureVideoDataOutput {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                print("ScreenRecorder: No pixel buffer in sample buffer")
                return
            }

            if videoInput?.isReadyForMoreMediaData == true {
                pixelBufferAdaptor?.append(pixelBuffer, withPresentationTime: presentationTime)
            } else {
                print("ScreenRecorder: Video input not ready for more media data")
            }
        }
        // Handle audio samples
        else if output is AVCaptureAudioDataOutput {
            if audioInput?.isReadyForMoreMediaData == true {
                audioInput?.append(sampleBuffer)
            } else {
                print("ScreenRecorder: Audio input not ready for more media data")
            }
        }
    }
}
