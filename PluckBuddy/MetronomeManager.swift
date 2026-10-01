//
//  MetronomeManager.swift
//  PluckBuddy
//
//  Metronome manager - optimized version (fixes sound and performance issues)
//  Created on 2026/8/29.
//

import Foundation
import AVFoundation
import Combine

/// Metronome sound type
enum MetronomeSoundType: String, CaseIterable, Identifiable {
    case tick = "Tick"
    case woodblock = "Woodblock"
    case drum = "Drum"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .tick: return "metronome"
        case .woodblock: return "circle.fill"
        case .drum: return "drums.fill"
        }
    }
}

/// Metronome manager (optimized version)
@MainActor
class MetronomeManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var bpm: Int = 120 {
        didSet {
            print("🎵 bpm didSet triggered: \(bpm), isPlaying: \(isPlaying)")
            // ✨ Avoid an infinite loop: only modify when the value actually changes
            let clampedBPM = max(minBPM, min(maxBPM, bpm))
            if bpm != clampedBPM {
                bpm = clampedBPM
                return // This triggers didSet again, so return directly
            }
            
            // ✨ Fix: do not restart while playing, only update the timer interval
            if isPlaying {
                updateTimerInterval()
            }
            print("🎵 bpm didSet finished")
        }
    }
    
    @Published var isPlaying: Bool = false
    @Published var currentBeat: Int = 0
    @Published var soundType: MetronomeSoundType = .tick {
        didSet {
            print("🎨 soundType didSet triggered: \(soundType.rawValue), isAudioEngineReady: \(isAudioEngineReady)")
            // ✨ Only update the sound when the audio engine is ready
            if isAudioEngineReady {
                setupSoundForType(soundType)
            }
            saveSettings()
            print("🎨 soundType didSet finished")
        }
    }
    @Published var isEnabled: Bool = false
    
    // MARK: - Constants
    
    let minBPM = 36
    let maxBPM = 220
    let beatsPerMeasure = 4
    
    // MARK: - Private Properties
    
    private var timer: Timer?
    private var audioEngine: AVAudioEngine!
    private var playerNode: AVAudioPlayerNode!
    private var tickBuffer: AVAudioPCMBuffer?
    private var tockBuffer: AVAudioPCMBuffer?
    private var isAudioEngineReady = false  // ✨ Marks whether the audio engine is ready
    
    // MARK: - Initialization
    
    init() {
        // ✨ Simplified initialization, defer audio engine setup to first use
        // Avoid blocking the main thread
        print("🎵 MetronomeManager init() started")
        loadSettings()
        print("🎵 MetronomeManager init() finished")
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
        playerNode?.stop()
        audioEngine?.stop()
    }
    
    // MARK: - Public Methods
    
    func start() {
        guard !isPlaying else { return }
        
        // ✨ If the audio engine is not ready, try to initialize it first
        if !isAudioEngineReady {
            print("⚠️ Audio engine is not ready, attempting to reinitialize...")
            setupAudioEngine()
            setupSoundForType(soundType)  // ✨ Set the current sound type
            isAudioEngineReady = true
            print("✅ Audio engine initialization finished")
        }
        
        // ✨ Start the audio engine (if it is not running)
        if audioEngine?.isRunning == false {
            do {
                try audioEngine?.start()
                print("✅ Audio engine started")
            } catch {
                print("❌ Failed to start the audio engine: \(error)")
                return
            }
        }
        
        // ✨ Start the player node first so it is ready to receive buffers
        if !playerNode.isPlaying {
            playerNode.play()
            print("✅ Player node started")
        }
        
        isPlaying = true
        currentBeat = 0
        
        let interval = 60.0 / Double(bpm)
        
        // ✨ Delay slightly before playing the first beat to ensure the IO thread is ready
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            self.playBeat()
            
            // Then start the timer
            self.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.playBeat()
                }
            }
        }
        
        print("🎵 Metronome started - BPM: \(bpm)")
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        isPlaying = false
        currentBeat = 0
        playerNode?.stop()
        print("⏹️ Metronome stopped")
    }
    
    func toggle() {
        isPlaying ? stop() : start()
    }
    
    func increaseBPM() {
        if bpm < maxBPM { bpm += 1 }
    }
    
    func decreaseBPM() {
        if bpm > minBPM { bpm -= 1 }
    }
    
    func setBPM(_ newBPM: Int) {
        bpm = max(minBPM, min(maxBPM, newBPM))
    }
    
    // MARK: - Private Methods
    
    private func setupAudioEngine() {
        // ✨ No longer configure the audio session, because AudioManager already configures it as .playAndRecord
        // This avoids conflicts between the two managers
        
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        audioEngine.attach(playerNode)
        
        let mixer = audioEngine.mainMixerNode
        // ✨ Key fix: use the engine's output format (usually stereo)
        let outputFormat = mixer.outputFormat(forBus: 0)
        audioEngine.connect(playerNode, to: mixer, format: outputFormat)
        
        audioEngine.prepare()
        print("✅ Audio engine initialization finished")
        print("   Output format: \(outputFormat.channelCount) channels, sample rate \(outputFormat.sampleRate) Hz")
    }
    
    private func playBeat() {
        currentBeat = (currentBeat % beatsPerMeasure) + 1
        
        let buffer = (currentBeat == 1) ? tockBuffer : tickBuffer
        guard let buffer = buffer else { return }
        
        // ✨ Schedule the buffer directly (AVAudioPlayerNode is thread-safe internally)
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }
    
    private func restart() {
        stop()
        start()
    }
    
    /// ✨ Updates the timer interval (without restarting)
    private func updateTimerInterval() {
        guard isPlaying else { return }
        
        print("🔄 Updating timer interval - new BPM: \(bpm)")
        // Recreate the timer with the new interval
        timer?.invalidate()
        let interval = 60.0 / Double(bpm)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.playBeat()
            }
        }
        print("🔄 Metronome speed updated - new BPM: \(bpm)")
    }
    
    private func setupSoundForType(_ type: MetronomeSoundType) {
        switch type {
        case .tick:
            tickBuffer = createBeepBuffer(frequency: 1000, duration: 0.05)
            tockBuffer = createBeepBuffer(frequency: 1200, duration: 0.05)
        case .woodblock:
            tickBuffer = createBeepBuffer(frequency: 800, duration: 0.08)
            tockBuffer = createBeepBuffer(frequency: 1000, duration: 0.1)
        case .drum:
            tickBuffer = createBeepBuffer(frequency: 400, duration: 0.1)
            tockBuffer = createBeepBuffer(frequency: 300, duration: 0.12)
        }
    }
    
    private func createBeepBuffer(frequency: Float, duration: TimeInterval) -> AVAudioPCMBuffer? {
        let outputFormat = audioEngine.mainMixerNode.outputFormat(forBus: 0)
        let sampleRate = outputFormat.sampleRate
        let channelCount = outputFormat.channelCount  // ✨ Use the channel count of the output format
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        // ✨ Create the format using a channel count that matches the engine
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            print("❌ Failed to create the audio buffer")
            return nil
        }
        
        buffer.frameLength = frameCount
        
        guard let channelData = buffer.floatChannelData else {
            print("❌ Failed to get channel data")
            return nil
        }
        
        let amplitude: Float = 0.8 // ✨ Raise the volume (increased from 0.25 to 0.8)
        
        // ✨ Generate the same sine wave for all channels
        for channel in 0..<Int(channelCount) {
            let data = channelData[channel]
            
            // Generate a sine wave with fade-in and fade-out
            for frame in 0..<Int(frameCount) {
                let time = Float(frame) / Float(sampleRate)
                let value = amplitude * sin(2.0 * Float.pi * frequency * time)
                
                // Add an envelope to avoid popping
                let fadeLength = min(Int(sampleRate * 0.005), Int(frameCount) / 4)
                var envelope: Float = 1.0
                
                if frame < fadeLength {
                    envelope = Float(frame) / Float(fadeLength)
                } else if frame > Int(frameCount) - fadeLength {
                    envelope = Float(Int(frameCount) - frame) / Float(fadeLength)
                }
                
                data[frame] = value * envelope
            }
        }
        
        print("✅ Audio buffer created: \(channelCount) channels, \(frameCount) frames, frequency \(frequency) Hz")
        return buffer
    }
    
    private func loadSettings() {
        print("📖 Start loading settings")
        if let savedBPM = UserDefaults.standard.object(forKey: "metronome_bpm") as? Int {
            print("📖 Loaded saved BPM: \(savedBPM)")
            bpm = savedBPM
        }
        
        if let savedSound = UserDefaults.standard.string(forKey: "metronome_sound"),
           let soundType = MetronomeSoundType(rawValue: savedSound) {
            print("📖 Loaded saved sound type: \(savedSound)")
            self.soundType = soundType
        }
        print("📖 Settings loading finished")
    }
    
    func saveSettings() {
        print("💾 Saving settings: BPM=\(bpm), soundType=\(soundType.rawValue)")
        UserDefaults.standard.set(bpm, forKey: "metronome_bpm")
        UserDefaults.standard.set(soundType.rawValue, forKey: "metronome_sound")
        print("💾 Settings saved")
    }
}

// MARK: - Convenience methods

extension MetronomeManager {
    func setCommonBPM(_ bpm: Int) {
        self.bpm = bpm
    }
}
