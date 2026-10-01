//
//  VideoRecorder.swift
//  PluckBuddy
//
//  Video recording manager
//

import AVFoundation
import UIKit
import Combine

@MainActor
class VideoRecorder: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var isAuthorized = false
    
    // MARK: - Private Properties
    private let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureMovieFileOutput?
    private var currentRecordingURL: URL?
    
    // MARK: - Public Properties
    var previewLayer: AVCaptureVideoPreviewLayer {
        AVCaptureVideoPreviewLayer(session: captureSession)
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        Task {
            await checkAuthorization()
        }
    }
    
    // MARK: - Authorization
    func checkAuthorization() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            try? setupCamera()
            
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            if isAuthorized {
                try? setupCamera()
            }
            
        default:
            isAuthorized = false
        }
    }
    
    // MARK: - Camera Setup
    private func setupCamera() throws {
        captureSession.beginConfiguration()
        
        // 1. Set the resolution
        captureSession.sessionPreset = .high
        
        // 2. Add the front camera input
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw VideoRecorderError.cameraNotAvailable
        }
        
        let videoInput = try AVCaptureDeviceInput(device: frontCamera)
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        // 3. Add the audio input (to record sound)
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            let audioInput = try? AVCaptureDeviceInput(device: audioDevice)
            if let audioInput = audioInput, captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
            }
        }
        
        // 4. Add the video output
        let output = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            videoOutput = output
        }
        
        captureSession.commitConfiguration()
        
        // 5. Start the session
        Task {
            captureSession.startRunning()
        }
    }
    
    // MARK: - Recording Control
    func startRecording() {
        guard let videoOutput = videoOutput, !isRecording else { return }
        
        // Generate a temporary file path
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("practice_\(Date().timeIntervalSince1970).mp4")
        
        currentRecordingURL = outputURL
        
        // Start recording
        videoOutput.startRecording(to: outputURL, recordingDelegate: self)
        isRecording = true
    }
    
    func stopRecording() {
        guard let videoOutput = videoOutput, isRecording else { return }
        
        videoOutput.stopRecording()
        isRecording = false
    }
    
    // MARK: - Cleanup
    func cleanup() {
        captureSession.stopRunning()
    }
    
    nonisolated deinit {
        Task { @MainActor in
            cleanup()
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension VideoRecorder: AVCaptureFileOutputRecordingDelegate {
    
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("📹 Started recording: \(fileURL)")
    }
    
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        
        if let error = error {
            print("❌ Recording failed: \(error.localizedDescription)")
            return
        }
        
        print("✅ Recording finished: \(outputFileURL)")
        
        // Save to the photo library (requires permission)
        Task { @MainActor in
            await saveToPhotoLibrary(url: outputFileURL)
        }
    }
    
    @MainActor
    private func saveToPhotoLibrary(url: URL) async {
        // TODO: Implement saving to the photo library
        // NSPhotoLibraryAddUsageDescription needs to be added to Info.plist
        print("💾 Video saved: \(url.path)")
    }
}

// MARK: - Error
enum VideoRecorderError: Error {
    case cameraNotAvailable
    case unauthorized
    case setupFailed
}
