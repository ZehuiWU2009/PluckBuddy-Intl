//
//  CameraManager.swift
//  PluckBuddy
//
//  Created by Zehui Wu on 2026/8/17.
//

import AVFoundation
import UIKit
import Combine

/// Camera manager
/// Manages the camera session and video frame capture
@MainActor
class CameraManager: NSObject, ObservableObject {
    
    // MARK: - Properties
    @Published var isAuthorized = false
    @Published var setupResult: SessionSetupResult = .success
    
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let videoDataOutput = AVCaptureVideoDataOutput()
    
    /// Video frame callback
    var onFrameCapture: ((CVPixelBuffer) -> Void)?
    
    enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        checkAuthorization()
    }
    
    // MARK: - Authorization
    
    /// Check camera permission
    private func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self = self else { return }
                Task { @MainActor in
                    self.isAuthorized = granted
                    self.sessionQueue.resume()
                }
            }
            
        default:
            isAuthorized = false
            setupResult = .notAuthorized
        }
    }
    
    // MARK: - Session Management
    
    /// Configure the camera session
    func configureSession() {
        guard setupResult == .success else { return }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            // Set the session preset (high quality)
            self.session.sessionPreset = .high
            
            // Add the video input
            do {
                let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                guard let device = videoDevice else {
                    Task { @MainActor in
                        self.setupResult = .configurationFailed
                    }
                    self.session.commitConfiguration()
                    return
                }
                
                let videoDeviceInput = try AVCaptureDeviceInput(device: device)
                
                if self.session.canAddInput(videoDeviceInput) {
                    self.session.addInput(videoDeviceInput)
                    self.videoDeviceInput = videoDeviceInput
                } else {
                    Task { @MainActor in
                        self.setupResult = .configurationFailed
                    }
                    self.session.commitConfiguration()
                    return
                }
            } catch {
                Task { @MainActor in
                    self.setupResult = .configurationFailed
                }
                self.session.commitConfiguration()
                return
            }
            
            // Add the video output
            if self.session.canAddOutput(self.videoDataOutput) {
                self.session.addOutput(self.videoDataOutput)
                
                self.videoDataOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
                ]
                
                self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.data.output.queue"))
                
                // Set the video orientation. Starting with iOS 17, videoOrientation is deprecated in favor of videoRotationAngle;
                // 90° corresponds to portrait, equivalent to the old .portrait
                if let connection = self.videoDataOutput.connection(with: .video) {
                    if connection.isVideoRotationAngleSupported(90.0) {
                        connection.videoRotationAngle = 90.0
                    }
                    if connection.isVideoMirroringSupported {
                        connection.isVideoMirrored = true  // Mirror the front camera
                    }
                }
            } else {
                Task { @MainActor in
                    self.setupResult = .configurationFailed
                }
                self.session.commitConfiguration()
                return
            }
            
            self.session.commitConfiguration()
        }
    }
    
    /// Start the session
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            switch self.setupResult {
            case .success:
                self.session.startRunning()
                
            case .notAuthorized:
                print("Camera not authorized")
                
            case .configurationFailed:
                print("Camera configuration failed")
            }
        }
    }
    
    /// Stop the session
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Callback on the main thread
        Task { @MainActor in
            self.onFrameCapture?(pixelBuffer)
        }
    }
}
