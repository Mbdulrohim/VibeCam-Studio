//
//  VideoCompositor.swift
//  VibeCam Studio
//
//  Created by abdulrohim on 23/10/2025.
//

import Foundation
import AVFoundation
import CoreGraphics
import QuartzCore

class VideoCompositor {

    func mergeVideos(screenURL: URL,
                     cameraURL: URL,
                     overlayPosition: OverlayPosition = .bottomRight,
                     overlaySize: OverlaySizeOption = .auto,
                     exportPreset: String = AVAssetExportPresetHighestQuality,
                     sessionFolder: URL? = nil,
                     completion: @escaping (Result<URL, Error>) -> Void) {
        let composition = AVMutableComposition()

        guard let screenAsset = AVAsset(url: screenURL) as? AVURLAsset,
              let cameraAsset = AVAsset(url: cameraURL) as? AVURLAsset else {
            completion(.failure(NSError(domain: "VideoCompositor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load video assets"])))
            return
        }

        // Add screen video track
        guard let screenVideoTrack = screenAsset.tracks(withMediaType: .video).first,
              let compositionScreenTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            completion(.failure(NSError(domain: "VideoCompositor", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to add screen video track"])))
            return
        }

        // Add camera video track
        guard let cameraVideoTrack = cameraAsset.tracks(withMediaType: .video).first,
              let compositionCameraTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            completion(.failure(NSError(domain: "VideoCompositor", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to add camera video track"])))
            return
        }

        // Add audio tracks (prefer screen audio, fallback to camera audio)
        var compositionAudioTrack: AVMutableCompositionTrack?
        if let screenAudioTrack = screenAsset.tracks(withMediaType: .audio).first {
            compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            print("VideoCompositor: Using screen audio track")
        } else if let cameraAudioTrack = cameraAsset.tracks(withMediaType: .audio).first {
            compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            print("VideoCompositor: Using camera audio track")
        } else {
            print("VideoCompositor: No audio tracks found in either video")
        }

        // Determine overlapping time range for sync
        let screenTimeRange = screenVideoTrack.timeRange
        let cameraTimeRange = cameraVideoTrack.timeRange
        let screenStart = screenTimeRange.start
        let cameraStart = cameraTimeRange.start
        let screenEnd = CMTimeAdd(screenStart, screenTimeRange.duration)
        let cameraEnd = CMTimeAdd(cameraStart, cameraTimeRange.duration)

        let syncStart = CMTimeMaximum(screenStart, cameraStart)
        let syncEnd = CMTimeMinimum(screenEnd, cameraEnd)

        guard syncEnd > syncStart else {
            completion(.failure(NSError(domain: "VideoCompositor", code: -5, userInfo: [NSLocalizedDescriptionKey: "No overlapping time range between screen and camera recordings"])))
            return
        }

        let syncDuration = CMTimeSubtract(syncEnd, syncStart)

        print("VideoCompositor: Syncing using overlapping range starting at \(CMTimeGetSeconds(syncStart))s for duration \(CMTimeGetSeconds(syncDuration))s")

        do {
            let desiredRange = CMTimeRange(start: syncStart, duration: syncDuration)
            let screenIntersection = CMTimeRangeGetIntersection(desiredRange, otherRange: screenVideoTrack.timeRange)
            let cameraIntersection = CMTimeRangeGetIntersection(desiredRange, otherRange: cameraVideoTrack.timeRange)

            try compositionScreenTrack.insertTimeRange(screenIntersection,
                                                      of: screenVideoTrack,
                                                      at: CMTimeSubtract(screenIntersection.start, syncStart))
            try compositionCameraTrack.insertTimeRange(cameraIntersection,
                                                       of: cameraVideoTrack,
                                                       at: CMTimeSubtract(cameraIntersection.start, syncStart))

            // Insert audio track if available
            if let audioTrack = compositionAudioTrack {
                if let screenAudioTrack = screenAsset.tracks(withMediaType: .audio).first {
                    let audioIntersection = CMTimeRangeGetIntersection(desiredRange, otherRange: screenAudioTrack.timeRange)
                    try audioTrack.insertTimeRange(audioIntersection,
                                                   of: screenAudioTrack,
                                                   at: CMTimeSubtract(audioIntersection.start, syncStart))
                    print("VideoCompositor: Inserted screen audio track")
                } else if let cameraAudioTrack = cameraAsset.tracks(withMediaType: .audio).first {
                    let audioIntersection = CMTimeRangeGetIntersection(desiredRange, otherRange: cameraAudioTrack.timeRange)
                    try audioTrack.insertTimeRange(audioIntersection,
                                                   of: cameraAudioTrack,
                                                   at: CMTimeSubtract(audioIntersection.start, syncStart))
                    print("VideoCompositor: Inserted camera audio track")
                }
            }
        } catch {
            completion(.failure(error))
            return
        }

        // Create video composition with Core Animation
        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        // Get screen dimensions
        let screenSize = screenVideoTrack.naturalSize
        let screenWidth = screenSize.width
        let screenHeight = screenSize.height
        videoComposition.renderSize = CGSize(width: screenWidth, height: screenHeight)

        print("VideoCompositor: Screen size: \(screenWidth) x \(screenHeight)")

        // Camera PIP dimensions (25% of screen width)
        // Calculate aspect ratio from actual camera video
        let cameraSize = cameraVideoTrack.naturalSize
        let cameraAspectRatio = cameraSize.width / cameraSize.height

        let (pipWidth, pipHeight): (CGFloat, CGFloat) = {
            let baseWidth = screenWidth * 0.25
            switch overlaySize {
            case .auto:
                let height = baseWidth / cameraAspectRatio
                return (baseWidth, height)
            case .square:
                return (baseWidth, baseWidth)
            case .fourThree:
                return (baseWidth, baseWidth * (3.0 / 4.0))
            case .sixteenNine:
                return (baseWidth, baseWidth * (9.0 / 16.0))
            }
        }()

        print("VideoCompositor: overlay size option: \(overlaySize.rawValue), width: \(pipWidth), height: \(pipHeight))")
        let margin: CGFloat = 40

        print("VideoCompositor: Camera aspect ratio: \(cameraAspectRatio) (\(cameraSize.width) x \(cameraSize.height))")

        // Calculate position based on user selection (video coordinate system, origin bottom-left)
        let (pipX, pipY): (CGFloat, CGFloat) = {
            switch overlayPosition {
            case .topLeft:
                return (margin, screenHeight - pipHeight - margin)
            case .topRight:
                return (screenWidth - pipWidth - margin, screenHeight - pipHeight - margin)
            case .bottomLeft:
                return (margin, margin)
            case .bottomRight:
                return (screenWidth - pipWidth - margin, margin)
            }
        }()

        print("VideoCompositor: PIP position: \(overlayPosition.rawValue) at (\(pipX), \(pipY)), size: \(pipWidth) x \(pipHeight)")

        // Create Core Animation layers for proper PIP with rounded corners
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        let cameraOverlayLayer = CALayer()

        // IMPORTANT: Core Animation coordinate system has Y=0 at TOP
        // But we need to flip it for video composition
        parentLayer.frame = CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight)
        videoLayer.frame = CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight)

        // Flip Y coordinate for Core Animation layer (invert from bottom-origin to top-origin)
        let flippedPipY = screenHeight - pipY - pipHeight
        cameraOverlayLayer.frame = CGRect(x: pipX, y: flippedPipY, width: pipWidth, height: pipHeight)

        print("VideoCompositor: Core Animation layer Y (flipped): \(flippedPipY)")

        // Create a mask layer for rounded corners
        let maskLayer = CAShapeLayer()
        let maskPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: pipWidth, height: pipHeight),
                             cornerWidth: 16,
                             cornerHeight: 16,
                             transform: nil)
        maskLayer.path = maskPath
        cameraOverlayLayer.mask = maskLayer

        // Add border using a separate shape layer (so it appears on top)
        let borderLayer = CAShapeLayer()
        borderLayer.path = maskPath
        borderLayer.fillColor = nil
        borderLayer.strokeColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1.0)
        borderLayer.lineWidth = 4
        borderLayer.frame = CGRect(x: 0, y: 0, width: pipWidth, height: pipHeight)

        // Add a subtle delay before showing border to avoid white box on empty layer
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = 0.3
        animation.beginTime = CACurrentMediaTime() + 0.1
        animation.fillMode = .backwards
        borderLayer.add(animation, forKey: "fadeIn")

        cameraOverlayLayer.addSublayer(borderLayer)

        // Add layers to parent
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(cameraOverlayLayer)

        print("VideoCompositor: Created layers - video: \(videoLayer.frame), camera: \(cameraOverlayLayer.frame)")

        // Create layer instructions
        let screenInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionScreenTrack)
        screenInstruction.setTransform(CGAffineTransform.identity, at: .zero)

        let cameraInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionCameraTrack)

        // Calculate camera transform to fit in PIP frame
        print("VideoCompositor: Camera natural size: \(cameraSize.width) x \(cameraSize.height)")

        let scaleX = pipWidth / cameraSize.width
        let scaleY = pipHeight / cameraSize.height
        let scale: CGFloat
        if overlaySize == .auto {
            scale = min(scaleX, scaleY)
        } else {
            scale = max(scaleX, scaleY) // fill and crop when forced aspect ratio
        }

        let scaledWidth = cameraSize.width * scale
        let scaledHeight = cameraSize.height * scale
        let offsetX = (pipWidth - scaledWidth) / 2.0
        let offsetY = (pipHeight - scaledHeight) / 2.0

        // Transform camera to fit in overlay position with centering
        var cameraTransform = CGAffineTransform(scaleX: scale, y: scale)
        cameraTransform = cameraTransform.translatedBy(x: (pipX + offsetX) / scale,
                                                       y: (pipY + offsetY) / scale)

        cameraInstruction.setTransform(cameraTransform, at: .zero)

        print("VideoCompositor: Camera scale: \(scale), position: (\(pipX), \(pipY))")

        // Create main instruction
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRange(start: .zero, duration: syncDuration)
        mainInstruction.layerInstructions = [cameraInstruction, screenInstruction]

        videoComposition.instructions = [mainInstruction]

        // Use Core Animation tool to apply rounded corners
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        print("VideoCompositor: Video composition configured with rounded corners")

        // Export
        let outputURL = createOutputURL(sessionFolder: sessionFolder)

        // Remove existing file if present
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: exportPreset) else {
            completion(.failure(NSError(domain: "VideoCompositor", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])))
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.videoComposition = videoComposition

        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                print("VideoCompositor: Merged video saved to: \(outputURL.path)")
                completion(.success(outputURL))
            case .failed:
                let error = exportSession.error ?? NSError(domain: "VideoCompositor", code: -5, userInfo: [NSLocalizedDescriptionKey: "Export failed"])
                print("VideoCompositor: Export failed: \(error.localizedDescription)")
                completion(.failure(error))
            case .cancelled:
                completion(.failure(NSError(domain: "VideoCompositor", code: -6, userInfo: [NSLocalizedDescriptionKey: "Export cancelled"])))
            default:
                completion(.failure(NSError(domain: "VideoCompositor", code: -7, userInfo: [NSLocalizedDescriptionKey: "Unknown export status"])))
            }
        }
    }

    private func createOutputURL(sessionFolder: URL? = nil) -> URL {
        if let sessionFolder = sessionFolder {
            return sessionFolder.appendingPathComponent("merged_video.mov")
        } else {
            let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            let vibeCamDir = downloadsURL.appendingPathComponent("VibeCam")

            // Create directory if it doesn't exist
            try? FileManager.default.createDirectory(at: vibeCamDir, withIntermediateDirectories: true, attributes: nil)

            return vibeCamDir.appendingPathComponent("merged_recording_\(Date().timeIntervalSince1970).mov")
        }
    }
}
