//
//  AudioManager.swift
//  PluckBuddy
//
//  Created by Zehui Wu on 2026/7/15.
//

import Foundation
import AVFoundation
import Combine

/// Manages the audio session and microphone permission
@MainActor
class AudioManager: NSObject, ObservableObject {
    static let shared = AudioManager()
    
    @Published var hasPermission = false
    @Published var isListening = false
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    
    // MARK: - Initialization
    private override init() {
        super.init()
    }
    
    // MARK: - Permission
    func requestMicrophonePermission() async -> Bool {
        // On iOS 17+, AVAudioApplication provides a more modern API
        #if canImport(AVFAudio)
        if #available(iOS 17.0, *) {
            let status = AVAudioApplication.shared.recordPermission
            
            switch status {
            case .granted:
                hasPermission = true
                return true
            case .denied, .undetermined:
                // Request permission
                let granted = await AVAudioApplication.requestRecordPermission()
                hasPermission = granted
                return granted
            @unknown default:
                return false
            }
        } else {
            // iOS 16 and below use the legacy API
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    Task { @MainActor in
                        self.hasPermission = granted
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
        #else
        // Fallback for non-iOS platforms
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                Task { @MainActor in
                    self.hasPermission = granted
                    continuation.resume(returning: granted)
                }
            }
        }
        #endif
    }
    
    // MARK: - Audio Session Setup
    func setupAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        // ✨ Use .playAndRecord so the metronome can play while recording
        // ✨ Add .mixWithOthers to mix with other audio
        // ✨ Add .defaultToSpeaker to route audio to the speaker
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker])
        // ✨ Set the preferred sample rate to 48000 Hz (unified sample rate)
        try session.setPreferredSampleRate(48000.0)
        try session.setActive(true)
        print("✅ Audio session configured for playback + recording")
        print("   Sample rate: \(session.sampleRate) Hz")
    }
    
    // MARK: - Start Listening
    func startListening(onBufferReceived: @escaping (AVAudioPCMBuffer, AVAudioTime) -> Void) throws {
        guard hasPermission else {
            throw AudioError.noPermission
        }
        
        try setupAudioSession()
        
        // Initialize the audio engine
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else {
            throw AudioError.engineInitFailed
        }
        
        inputNode = engine.inputNode
        guard let input = inputNode else {
            throw AudioError.noInputNode
        }
        
        // ✅ Get the actual input format and sample rate
        let inputFormat = input.outputFormat(forBus: 0)
        let actualSampleRate = inputFormat.sampleRate
        
        // ✅ Print the actual sample rate for debugging
        print("🎤 Actual sample rate: \(actualSampleRate) Hz")
        
        // Install a tap (4096 samples per callback)
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, time in
            onBufferReceived(buffer, time)
        }
        
        // Start the engine
        try engine.start()
        isListening = true
    }
    
    // MARK: - Stop Listening
    func stopListening() {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        isListening = false
        
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    // MARK: - Error Types
    enum AudioError: LocalizedError {
        case noPermission
        case engineInitFailed
        case noInputNode
        
        var errorDescription: String? {
            switch self {
            case .noPermission:
                return "Microphone permission is required for pitch detection"
            case .engineInitFailed:
                return "Failed to initialize the audio engine"
            case .noInputNode:
                return "Unable to access the audio input node"
            }
        }
    }
}
