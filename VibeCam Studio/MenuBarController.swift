//
//  MenuBarController.swift
//  VibeCam Studio
//
//  Created by Cascade on 24/10/2025.
//

import AppKit
import Combine

final class MenuBarController {
    private let statusItem: NSStatusItem
    private weak var recordingViewModel: RecordingViewModel?
    private var cancellables = Set<AnyCancellable>()

    private let toggleRecordingItem = NSMenuItem(title: "Start Recording",
                                                 action: #selector(toggleRecording),
                                                 keyEquivalent: "r")
    private let showAppItem = NSMenuItem(title: "Show VibeCam Studio",
                                         action: #selector(showMainWindow),
                                         keyEquivalent: "o")
    private let quitItem = NSMenuItem(title: "Quit VibeCam Studio",
                                      action: #selector(quit),
                                      keyEquivalent: "q")

    init(recordingViewModel: RecordingViewModel) {
        self.recordingViewModel = recordingViewModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupMenu()
        bind(to: recordingViewModel)
        updateStatus(isRecording: recordingViewModel.isRecording,
                     duration: recordingViewModel.recordingDuration)
    }

    private func setupMenu() {
        guard let button = statusItem.button else { return }
        button.title = "VibeCam ◯"
        button.imagePosition = .imageLeading

        let menu = NSMenu()

        showAppItem.target = self
        toggleRecordingItem.target = self
        quitItem.target = self

        menu.addItem(showAppItem)
        menu.addItem(.separator())
        menu.addItem(toggleRecordingItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func bind(to viewModel: RecordingViewModel) {
        viewModel.$isRecording
            .combineLatest(viewModel.$recordingDuration)
            .receive(on: RunLoop.main)
            .sink { [weak self] isRecording, duration in
                self?.updateStatus(isRecording: isRecording, duration: duration)
            }
            .store(in: &cancellables)
    }

    private func updateStatus(isRecording: Bool, duration: TimeInterval) {
        guard let button = statusItem.button else { return }

        if isRecording {
            button.title = "⏺ " + formattedDuration(duration)
            toggleRecordingItem.title = "Stop Recording"
        } else {
            button.title = "VibeCam ◯"
            toggleRecordingItem.title = "Start Recording"
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let clampedDuration = max(0, Int(duration.rounded()))
        let minutes = clampedDuration / 60
        let seconds = clampedDuration % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    @objc private func toggleRecording() {
        guard let viewModel = recordingViewModel else { return }
        if viewModel.isRecording {
            viewModel.stopRecording()
        } else {
            viewModel.startRecording()
        }
    }

    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows
            .filter { $0.isVisible }
            .forEach { $0.makeKeyAndOrderFront(nil) }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
