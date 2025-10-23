# VibeCam Studio

A modern macOS screen recording application with floating camera overlay, built with SwiftUI and AVFoundation.

![VibeCam Studio](https://img.shields.io/badge/macOS-15.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.0+-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- 🎥 **Screen Recording**: Capture your screen with high-quality H.264 encoding
- 📹 **Floating Camera Overlay**: Add a repositionable camera feed to your recordings
- 🎨 **Rounded Camera Edges**: Modern rounded corners for the camera overlay
- 🎯 **Position Controls**: Move the camera overlay to any corner of the screen
- ⚙️ **Quality Settings**: Choose from Low (720p), Medium (1080p), High (1440p), or Ultra (4K) quality
- 🎵 **Audio Recording**: Capture system audio and microphone input
- 📁 **Organized Output**: Recordings are saved in timestamped folders with separate files for each component

## Screenshots

![VibeCam Studio Preview](Screenshot%202025-10-23%20at%2011.02.50.png)

*The main interface showing screen recording controls and camera overlay positioning options*

## Installation

### Prerequisites

- macOS 15.0 or later
- Xcode 16.0 or later

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/Mbdulrohim/VibeCam-Studio.git
cd VibeCam-Studio
```

2. Open the project in Xcode:
```bash
open "VibeCam Studio.xcodeproj"
```

3. Build and run the application:
   - Select the "VibeCam Studio" scheme
   - Choose your target device/simulator
   - Press Cmd+R to build and run

## Usage

1. **Launch the Application**: Open VibeCam Studio on your Mac
2. **Grant Permissions**: Allow screen recording and camera access when prompted
3. **Configure Settings**:
   - Toggle camera and microphone recording
   - Select video quality (Low/Medium/High/Ultra)
   - Choose camera overlay position (Top Left/Top Right/Bottom Left/Bottom Right)
4. **Start Recording**: Click the record button to begin capturing
5. **Stop Recording**: Click stop when finished - files will be saved to `~/Downloads/VibeCam/`

### Output Structure

Each recording creates a timestamped folder containing:
```
Recording_2025-10-23_14-30-00/
├── person_video.mov      # Camera feed recording
├── screen_record.mov     # Screen recording
└── merged_video.mov      # Final composed video
```

## Architecture

### Core Components

- **ContentView.swift**: Main application interface with recording controls
- **RecordingViewModel.swift**: State management and recording coordination
- **ScreenRecorder.swift**: Handles screen capture using AVFoundation
- **CameraService.swift**: Manages camera input and recording
- **VideoCompositor.swift**: Merges screen and camera videos with overlay positioning
- **FloatingCameraWindow.swift**: Optional floating camera preview window

### Technologies Used

- **SwiftUI**: Declarative UI framework for macOS
- **AVFoundation**: Core media framework for camera/screen capture and video processing
- **CoreGraphics/CoreAnimation**: Video composition and rendering
- **Combine**: Reactive programming for state management

## Permissions

The application requires the following macOS permissions:

- **Screen Recording**: To capture screen content
- **Camera Access**: To record from connected cameras
- **Microphone Access**: To record audio input
- **Downloads Folder Access**: To save recording files

## Development

### Project Structure

```
VibeCam Studio/
├── VibeCam Studio/
│   ├── ContentView.swift           # Main UI
│   ├── RecordingViewModel.swift    # State management
│   ├── ScreenRecorder.swift        # Screen recording
│   ├── CameraService.swift         # Camera recording
│   ├── VideoCompositor.swift       # Video merging
│   ├── FloatingCameraWindow.swift  # Camera preview
│   └── VibeCam_StudioApp.swift     # App entry point
├── VibeCam StudioTests/
├── VibeCam StudioUITests/
├── VibeCam Studio.xcodeproj/
└── README.md
```

### Building

```bash
# Clean build
xcodebuild clean

# Build for debugging
xcodebuild -scheme "VibeCam Studio" -configuration Debug build

# Build for release
xcodebuild -scheme "VibeCam Studio" -configuration Release build
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Guidelines

1. Follow Swift naming conventions
2. Add documentation for new functions and classes
3. Test your changes on multiple macOS versions
4. Ensure all permissions are properly handled
5. Keep the UI responsive and user-friendly

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

**Mbdulrohim**
- X (Twitter): [@mbdulrohim](https://x.com/mbdulrohim)
- GitHub: [Mbdulrohim](https://github.com/Mbdulrohim)

## Acknowledgments

- Built with SwiftUI and AVFoundation
- Inspired by modern screen recording applications
- Thanks to the macOS developer community

## Release Notes

### v1.0.0 (October 23, 2025)
- Initial release
- Screen recording with camera overlay
- Multiple quality settings
- Position controls for camera overlay
- Rounded camera corners
- Organized file output structure
- macOS 15.0+ support

---

*VibeCam Studio - Professional screen recording made simple.*