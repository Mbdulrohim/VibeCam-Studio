# VibeCam Studio Development Plan

## Overview
VibeCam Studio is a macOS application built with SwiftUI that enables simultaneous screen and camera recording with a modern, native-feeling floating camera overlay. The app will capture screen content and webcam feed separately, then merge them into a single video output with the camera overlay positioned in a corner.

## Technologies
| Area             | What We'll Use                                |
| ---------------- | ---------------------------------------------- |
| Language         | Swift                                          |
| UI               | SwiftUI                                        |
| Screen Recording | `CGDisplayStream` or `AVCaptureScreenInput`    |
| Camera           | `AVCaptureDevice` + `AVCaptureVideoDataOutput` |
| Audio            | `AVCaptureAudioDataOutput`                     |
| Video Merge      | `AVAssetWriter` / `AVAssetExportSession`       |
| Design           | macOS blur + rounded corners                   |
| Packaging        | `.dmg` via `create-dmg` or `appdmg`            |
| Distribution     | Unsigned (for now), later Developer ID         |

## Core Features

### 1. Screen + Camera Capture
- **Screen Capture**: Use `CGDisplayStream` for efficient full-screen recording or `AVCaptureScreenInput` for more control
- **Camera Capture**: Implement `AVCaptureSession` with `AVCaptureDevice` for webcam input
- **Audio Capture**: Add `AVCaptureAudioDataOutput` for microphone input
- **Recording Control**: Single start/stop button to control all capture sessions simultaneously
- **Output**: Save screen and camera feeds to separate temporary video files

### 2. Floating Camera View
- **Preview Window**: Create a floating SwiftUI window with rounded rectangle shape (cornerRadius ~30)
- **Visual Effects**: 
  - Drop shadow for depth
  - Blurred glass background using `.ultraThinMaterial`
  - Smooth animations for position changes
- **Interactivity**: Make the overlay draggable during recording
- **Positioning**: Allow user to reposition the camera preview before/during recording

### 3. Combined Recording Output
- **Separate Recording**: Capture screen and camera to individual temporary files
- **Video Merging**: Use `AVFoundation` APIs (`AVAssetWriter`/`AVAssetExportSession`) to combine videos
- **Overlay Positioning**: Composite camera feed as picture-in-picture in corner of screen recording
- **Format**: Output as .mp4 file

### 4. UI/UX Design
- **Main Interface**: Minimal SwiftUI view with essential controls
- **Controls**:
  - 🎬 Start/Stop Recording button
  - 🎥 Camera toggle
  - 📸 Photo capture (optional)
  - ⚙️ Settings panel (resolution, audio input selection)
- **Modern Design**:
  - Rounded corners and macOS 13+ aesthetic
  - Transparent material backgrounds
  - Smooth transitions with `withAnimation`

### 5. Editing Layer (Phase 2)
- **Post-Recording Editor**: Simple interface for video adjustments
- **Features**:
  - Reposition camera overlay to different corners
  - Adjust overlay size/scaling
  - Trim video start/end points
  - Preview changes before export

## Implementation Phases

### Phase 1: Core Recording (Tonight)
1. Set up basic SwiftUI app structure
2. Implement screen recording with `CGDisplayStream`
3. Add camera capture with `AVCaptureSession`
4. Create floating camera preview window
5. Add start/stop recording functionality
6. Save separate video files

### Phase 2: Video Merging
1. Implement video composition with `AVFoundation`
2. Add picture-in-picture overlay logic
3. Export combined video as .mp4

### Phase 3: UI Polish & Features
1. Enhance floating window with drag functionality
2. Add settings panel for resolution/audio selection
3. Implement photo capture feature
4. Add smooth animations and transitions

### Phase 4: Editing Features
1. Build post-recording editor interface
2. Add overlay positioning controls
3. Implement video trimming
4. Add export functionality

## File Structure
```
VibeCam Studio/
├── Models/
│   ├── RecordingSession.swift
│   └── VideoComposition.swift
├── Views/
│   ├── ContentView.swift
│   ├── CameraPreviewView.swift
│   ├── FloatingCameraWindow.swift
│   └── SettingsView.swift
├── ViewModels/
│   ├── RecordingViewModel.swift
│   └── CameraViewModel.swift
├── Services/
│   ├── ScreenRecorder.swift
│   ├── CameraService.swift
│   └── VideoMerger.swift
└── Utilities/
    ├── PermissionsManager.swift
    └── FileManagerExtensions.swift
```

## Key Technical Considerations

### Permissions
- Screen Recording: Requires user permission via `CGRequestScreenCaptureAccess()`
- Camera: Requires `AVCaptureDevice.requestAccess(for: .video)`
- Microphone: Requires `AVCaptureDevice.requestAccess(for: .audio)`

### Performance
- Screen recording at high frame rates may impact performance
- Camera preview needs to be efficient to avoid dropped frames
- Video merging should be done asynchronously to prevent UI blocking

### Error Handling
- Handle permission denials gracefully
- Manage capture session interruptions
- Provide user feedback for recording failures

### Testing
- Test on different macOS versions (13+)
- Verify with various screen resolutions
- Test camera compatibility across different devices

## Potential Challenges
1. **Screen Recording Permissions**: macOS security restrictions may require additional setup
2. **Performance**: Balancing high-quality recording with smooth UI responsiveness
3. **Video Synchronization**: Ensuring audio/video sync during merging
4. **Window Management**: Implementing draggable floating windows in SwiftUI
5. **AVFoundation Complexity**: Learning curve with video composition APIs

## Next Steps
1. Review and finalize technical approach
2. Begin implementation with screen recording foundation
3. Build camera capture functionality
4. Create floating preview interface
5. Test basic recording workflow