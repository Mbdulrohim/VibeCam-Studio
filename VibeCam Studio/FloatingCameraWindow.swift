//
//  FloatingCameraWindow.swift
//  VibeCam Studio
//
//  Created by abdulrohim on 22/10/2025.
//

import SwiftUI
import AVFoundation

struct FloatingCameraWindow: View {
    @StateObject private var cameraPreview = CameraPreview()
    @State private var position: CGPoint = CGPoint(x: 50, y: 50)
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(cameraPreview: cameraPreview)
                .frame(width: 200, height: 150)
                .cornerRadius(30)
                .shadow(radius: 10)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(.ultraThinMaterial)
                        .shadow(radius: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .frame(width: 200, height: 150)
        .position(position)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation
                }
                .onEnded { value in
                    isDragging = false
                    position = CGPoint(
                        x: position.x + value.translation.width,
                        y: position.y + value.translation.height
                    )
                    dragOffset = .zero
                }
        )
        .offset(dragOffset)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
    }
}

struct CameraPreviewView: NSViewRepresentable {
    @ObservedObject var cameraPreview: CameraPreview
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let previewLayer = cameraPreview.previewLayer {
            previewLayer.frame = nsView.bounds
            nsView.layer?.addSublayer(previewLayer)
        }
    }
}

class CameraPreview: ObservableObject {
    var previewLayer: AVCaptureVideoPreviewLayer?
    private var captureSession: AVCaptureSession?
    
    init() {
        setupCameraPreview()
    }
    
    private func setupCameraPreview() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .medium
        
        guard let camera = AVCaptureDevice.default(for: .video) else { return }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession?.canAddInput(input) == true {
                captureSession?.addInput(input)
            }
            
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            previewLayer?.videoGravity = .resizeAspectFill
            
            captureSession?.startRunning()
            
        } catch {
            print("Error setting up camera preview: \(error)")
        }
    }
    
    deinit {
        captureSession?.stopRunning()
    }
}