//
//  VideoCaptureManager.swift
//  PluckBuddy
//
//  Created by Zehui Wu on 2026/7/29.
//

import Foundation
import AVFoundation
import UIKit

/// Video capture manager - captures camera frames using AVFoundation
class VideoCaptureManager: NSObject {
    
    // MARK: - Properties
    
    /// Capture session
    private let captureSession = AVCaptureSession()
    
    /// Video output
    private let videoOutput = AVCaptureVideoDataOutput()
    
    /// Processing queue
    private let videoQueue = DispatchQueue(label: "com.pluckbuddy.video", qos: .userInitiated)
    
    /// Preview layer
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    
    /// Frame callback
    var onFrameCaptured: ((CVPixelBuffer) -> Void)?
    
    /// Whether it is currently running
    private(set) var isRunning = false
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        print("📹 VideoCaptureManager initialized")
    }
    
    // MARK: - Setup
    
    /// Configure the capture session
    func setupCamera() throws {
        print("🎥 Configuring the camera...")
        
        // 1. Set the session quality
        captureSession.sessionPreset = .medium  // 640x480, suitable for hand detection
        
        // 2. Get the front camera
        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front  // Front camera
        ) else {
            print("❌ Unable to access the front camera")
            throw CaptureError.cameraNotAvailable
        }
        
        print("✅ Found the front camera: \(camera.localizedName)")
        
        // 3. Create the input
        let input = try AVCaptureDeviceInput(device: camera)
        
        guard captureSession.canAddInput(input) else {
            print("❌ Unable to add the camera input")
            throw CaptureError.cannotAddInput
        }
        
        captureSession.addInput(input)
        print("✅ Camera input added")
        
        // 4. Configure the output
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        
        // Drop late frames to keep things real time
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        guard captureSession.canAddOutput(videoOutput) else {
            print("❌ Unable to add the video output")
            throw CaptureError.cannotAddOutput
        }
        
        captureSession.addOutput(videoOutput)
        print("✅ Video output added")
        
        // 5. Set the video orientation
        if let connection = videoOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
            
            // Mirror the front camera
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }
        
        // 6. Create the preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        
        print("✅ Camera configuration finished")
    }
    
    // MARK: - Control
    
    /// Start capture
    func startCapture() throws {
        guard !isRunning else {
            print("⚠️ The camera is already running")
            return
        }
        
        // Configure it first if it has not been set up yet
        if captureSession.inputs.isEmpty {
            try setupCamera()
        }
        
        print("▶️ Starting camera capture...")
        
        // Start on a background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
            
            DispatchQueue.main.async {
                self?.isRunning = true
                print("✅ Camera started")
            }
        }
    }
    
    /// Stop capture
    func stopCapture() {
        guard isRunning else {
            print("⚠️ The camera is not running")
            return
        }
        
        print("⏹️ Stopping camera capture...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
            
            DispatchQueue.main.async {
                self?.isRunning = false
                print("✅ Camera stopped")
            }
        }
    }
    
    // MARK: - Errors
    
    enum CaptureError: Error, LocalizedError {
        case cameraNotAvailable
        case cannotAddInput
        case cannotAddOutput
        
        var errorDescription: String? {
            switch self {
            case .cameraNotAvailable:
                return "The camera is unavailable"
            case .cannotAddInput:
                return "Unable to add the camera input"
            case .cannotAddOutput:
                return "Unable to add the video output"
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension VideoCaptureManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Extract the pixel buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Callback on the main thread
        DispatchQueue.main.async { [weak self] in
            self?.onFrameCaptured?(pixelBuffer)
        }
    }
    
    func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Frame dropped (performance monitoring)
        // print("⚠️ A frame was dropped")
    }
}
