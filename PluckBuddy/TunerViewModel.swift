//
//  TunerViewModel.swift
//  PluckBuddy
//
//  Created by Zehui Wu on 2026/7/15.
//

import Foundation
import AVFoundation
import Combine

@MainActor
class TunerViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var detectedNote: String = "—"
    @Published var frequency: Double = 0.0
    @Published var centOffset: Double = 0.0
    @Published var isTuned: Bool = false
    @Published var tuningMessage: String = "Please pluck a string"
    @Published var confidence: Double = 0.0 // Detection confidence
    @Published var waveformData: [Float] = Array(repeating: 0, count: 100) // Waveform data
    @Published var amplitudeLevel: Float = 0.0 // Current amplitude level (for visualization)
    @Published var pipaFilterEnabled: Bool = true // ✅ Pipa sound filter switch (on by default; uses the on-device CoreML PipaSoundClassifier four-class model to gate pitch detection)
    @Published var pipaSoundDetected: Bool = false // ✅ Latest CoreML gate output (whether the most recent inference said pipa), for UI feedback
    @Published var pipaScoreValue: Double = 0.0 // ✅ Latest CoreML gate output (smoothed pipa probability), for UI feedback
    @Published var pipaGateAvailable: Bool = false // ✅ Whether the CoreML gate is available; when it is not, the UI tells the user it has fallen back to the generic mode
    
    // Stability control
    private var stableCount: Int = 0
    private let stableThreshold = 2 // Lowered to 2 to improve responsiveness
    
    // Frequency display persistence
    private var lastValidFrequency: Double = 0.0
    private var lastDetectionTime: Date?
    private let displayTimeout: TimeInterval = 3.0 // The display is only cleared after 3 s
    
    // ✅ Relay the published values of pipaGate onto the ViewModel so the View need not observe pipaGate directly
    private var pipaGateCancellables = Set<AnyCancellable>()
    
    // MARK: - Pipa Standard Tuning
    struct PipaString {
        let name: String
        let frequency: Double
    }
    
    /// Ordered by string number 1 → 4: string 1 (zi) is the thinnest and highest pitched, string 4 (chan) the thickest and lowest.
    /// The UI renders them left to right, so this order must match「string 1, string 2, string 3, string 4」.
    static let pipaStrings: [PipaString] = [
        PipaString(name: "a", frequency: 220.0),  // String 1, zi, a3
        PipaString(name: "e", frequency: 164.81), // String 2, zhong, e3
        PipaString(name: "d", frequency: 146.83), // String 3, lao, d3
        PipaString(name: "A", frequency: 110.0)   // String 4, chan, A2
    ]
    
    // MARK: - Audio Components
    private var audioManager: AudioManager?
    private var pitchDetector: PitchDetector?
    private var dspExtractor: DSPFeatureExtractor? // Keep the DSP extractor (waveform only; it does not take part in gating)
    private let pipaGate = PipaSoundGate() // ✅ CoreML pipa sound gate (on-device inference; shares the microphone source with AudioManager instead of starting another AVAudioEngine)
    
    // MARK: - Init
    init() {
        pipaGateAvailable = pipaGate.isAvailable
        // Relay the gate state to the published values of the ViewModel (so the View only has to observe the view model)
        pipaGate.$isPipa
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detected in self?.pipaSoundDetected = detected }
            .store(in: &pipaGateCancellables)
        pipaGate.$pipaProb
            .receive(on: DispatchQueue.main)
            .sink { [weak self] prob in self?.pipaScoreValue = prob }
            .store(in: &pipaGateCancellables)
    }
    
    // MARK: - Lifecycle
    func startListening() {
        Task {
            // Request microphone permission
            audioManager = AudioManager.shared
            guard let manager = audioManager else { return }
            
            let hasPermission = await manager.requestMicrophonePermission()
            guard hasPermission else {
                tuningMessage = "Microphone permission is required to detect pitch"
                return
            }
            
            // Initialize the pitch detector
            pitchDetector = PitchDetector(sampleRate: 44100.0, bufferSize: 4096)
            
            // ✅ Initialize the dedicated pipa sound detector
            dspExtractor = DSPFeatureExtractor(fftSize: 4096)
            
            // Start audio input
            do {
                try manager.startListening { [weak self] buffer, _ in
                    guard let self = self,
                          let detector = self.pitchDetector else { return }
                    
                    // Update the waveform data
                    Task { @MainActor in
                        self.updateWaveform(from: buffer)
                    }
                    
                    // ✅ Also feed the buffer to the CoreML gate (async: downsampling, accumulation and inference all run on a background queue and never block the audio callback)
                    self.pipaGate.feed(buffer: buffer)
                    
                    // Compute spectral features (used for pitch detection only)
                    guard let dsp = self.dspExtractor else { return }
                    let features = dsp.process(buffer: buffer)
                    
                    // ✅ Gating: with「pipa mode」on, CoreML must have reported「pipa」within the last 0.5 s;
                    //           with「pipa mode」off or the model failing to load → everything passes (same as the previous behavior).
                    let gatePassed = self.pipaFilterEnabled ? self.pipaGate.isPipaRecent(within: 0.5) : true
                    
                    // RMS energy + pitch range filtering removes obvious noise
                    let shouldProcess = gatePassed && features.rms > 0.008 && features.pitchHz > 80
                    
                    // Feedback: filtering is on but the current frame falls outside the「pipa within the last 0.5 s」window → show a waiting hint
                    if self.pipaFilterEnabled && !self.pipaGate.isPipaRecent(within: 0.5) && features.rms > 0.008 {
                        Task { @MainActor in
                            self.tuningMessage = "Listening… please play the pipa"
                        }
                    }
                    
                    guard shouldProcess else {
                        Task { @MainActor in
                            self.checkDisplayTimeout()
                        }
                        return
                    }
                    
                    // Prefer the fundamental frequency detected by DSP (more accurate)
                    let frequency = features.pitchHz > 0 ? Double(features.pitchHz) : nil
                    
                    if let freq = frequency {
                        Task { @MainActor in
                            self.processPitch(freq)
                        }
                    } else {
                        // DSP found nothing, fall back to the FFT method
                        if let freq = detector.detectPitch(from: buffer) {
                            Task { @MainActor in
                                self.processPitch(freq)
                            }
                        } else {
                            Task { @MainActor in
                                self.checkDisplayTimeout()
                            }
                        }
                    }
                }
            } catch {
                tuningMessage = "Audio engine failed to start"
                print("Audio error: \(error.localizedDescription)")
            }
        }
    }
    
    func stopListening() {
        audioManager?.stopListening()
        pipaGate.reset() // ✅ Clear the CoreML gate accumulation and the「recent verdict」flag
        resetDisplay()
    }
    
    // MARK: - Pitch Processing
    private func processPitch(_ detectedFreq: Double) {
        guard detectedFreq > 0 else {
            return
        }
        
        // Update the detection time
        lastDetectionTime = Date()
        lastValidFrequency = detectedFreq
        
        frequency = detectedFreq
        
        // Find the closest pipa string
        guard let closestString = findClosestString(for: detectedFreq) else {
            return
        }
        
        detectedNote = closestString.name
        
        // Compute the deviation in cents
        // cents = 1200 * log2(detectedFreq / targetFreq)
        centOffset = 1200 * log2(detectedFreq / closestString.frequency)
        
        // Decide whether it is in tune (within ±10 cents counts as in tune)
        isTuned = abs(centOffset) < 10
        
        // Update the message
        updateTuningMessage()
    }
    
    /// Check the display timeout (clears only after a long stretch without any detected sound)
    private func checkDisplayTimeout() {
        guard let lastTime = lastDetectionTime else { return }
        
        let timeSinceLastDetection = Date().timeIntervalSince(lastTime)
        if timeSinceLastDetection > displayTimeout {
            resetDisplay()
        }
    }
    
    private func findClosestString(for freq: Double) -> PipaString? {
        // Only search within a reasonable range (±100 Hz)
        let candidates = Self.pipaStrings.filter { abs($0.frequency - freq) < 100 }
        return candidates.min(by: { abs($0.frequency - freq) < abs($1.frequency - freq) })
    }
    
    private func updateTuningMessage() {
        if isTuned {
            tuningMessage = "✓ Right in tune, great!"
        } else if centOffset > 10 {
            tuningMessage = "Tune a little lower ↓"
        } else if centOffset < -10 {
            tuningMessage = "Tune a little higher ↑"
        } else {
            tuningMessage = "Please pluck a string"
        }
    }
    
    private func resetDisplay() {
        detectedNote = "—"
        frequency = 0.0
        centOffset = 0.0
        isTuned = false
        confidence = 0.0
        tuningMessage = "Please pluck a string"
    }
    
    // MARK: - Waveform Update
    
    /// Update the waveform data (optimized version, reacts to pipa sound only)
    private func updateWaveform(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        // Compute the RMS amplitude level
        var sum: Float = 0.0
        for i in 0..<frameLength {
            sum += channelData[i] * channelData[i]
        }
        amplitudeLevel = sqrt(sum / Float(frameLength))
        
        // Pipa sound detection threshold (filters out faint sounds and noise)
        guard amplitudeLevel > 0.02 else {
            // Energy too low: fade the waveform out gradually instead of zeroing it abruptly
            waveformData = waveformData.map { $0 * 0.8 }
            return
        }
        
        // Compute the peak factor (a characteristic of pipa sound)
        var peak: Float = 0.0
        for i in 0..<frameLength {
            let abs = abs(channelData[i])
            if abs > peak {
                peak = abs
            }
        }
        let peakFactor = peak / (amplitudeLevel + 0.0001)
        
        // Peak factor check: pipa sound usually falls between 3 and 10
        guard peakFactor > 2.5 && peakFactor < 15.0 else {
            // Not a pipa sound, fade out gradually
            waveformData = waveformData.map { $0 * 0.85 }
            return
        }
        
        // Downsample to 100 points (for the waveform display)
        let step = max(1, frameLength / 100)
        var newWaveform: [Float] = []
        
        // Find the maximum amplitude for normalization
        var maxAmp: Float = 0.0001 // Avoid division by zero
        for i in stride(from: 0, to: frameLength, by: step) {
            if i < frameLength {
                let amp = abs(channelData[i])
                if amp > maxAmp {
                    maxAmp = amp
                }
            }
        }
        
        // Normalize and sample (lower amplification to reduce flicker)
        for i in stride(from: 0, to: frameLength, by: step) {
            if i < frameLength {
                // Normalize into the -1.0 to 1.0 range and amplify 1.5x (previously 2.0)
                let normalized = (channelData[i] / maxAmp) * 1.5
                newWaveform.append(min(1.0, max(-1.0, normalized)))
            }
        }
        
        // Make sure there are exactly 100 points
        while newWaveform.count < 100 {
            newWaveform.append(0)
        }
        if newWaveform.count > 100 {
            newWaveform = Array(newWaveform.prefix(100))
        }
        
        // Smoothing: blend with the previous waveform (reduces flicker)
        if waveformData.count == newWaveform.count {
            for i in 0..<waveformData.count {
                waveformData[i] = waveformData[i] * 0.6 + newWaveform[i] * 0.4
            }
        } else {
            waveformData = newWaveform
        }
    }
    
    // MARK: - Pipa Sound Detection
    
    /// Decide whether this is pipa sound (core recognition algorithm)
    private func isPipaSound(_ buffer: AVAudioPCMBuffer) -> Bool {
        guard let channelData = buffer.floatChannelData?[0] else { return false }
        let frameLength = Int(buffer.frameLength)
        
        // 1️⃣ Compute the RMS energy
        var sum: Float = 0.0
        for i in 0..<frameLength {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrt(sum / Float(frameLength))
        
        // Energy threshold: filter out sounds that are too faint
        guard rms > 0.015 else { return false }
        
        // 2️⃣ Compute the crest factor
        var peak: Float = 0.0
        for i in 0..<frameLength {
            let absValue = abs(channelData[i])
            if absValue > peak {
                peak = absValue
            }
        }
        let crestFactor = peak / (rms + 0.0001) // Avoid division by zero
        
        // Crest factor signature of pipa sound: 3-12
        // - Speech: < 3 (energy evenly distributed)
        // - Pipa: 3-12 (clear attack peak)
        // - Noise / plosives: > 15 (instantaneous peak too large)
        guard crestFactor >= 2.8 && crestFactor <= 15.0 else {
            return false
        }
        
        // 3️⃣ Zero-crossing rate check
        // The zero-crossing rate of pipa sound is relatively stable
        var zeroCrossings = 0
        for i in 1..<frameLength {
            if (channelData[i] >= 0 && channelData[i-1] < 0) ||
               (channelData[i] < 0 && channelData[i-1] >= 0) {
                zeroCrossings += 1
            }
        }
        let zcr = Float(zeroCrossings) / Float(frameLength)
        
        // Zero-crossing rate range: 0.05-0.3 (pipa tones are low, so the rate never gets too high)
        // - Speech: 0.1-0.5 (varies a lot)
        // - Pipa: 0.05-0.25 (relatively stable)
        // - Noise: > 0.4 (crosses zero frequently)
        guard zcr >= 0.03 && zcr <= 0.35 else {
            return false
        }
        
        // 4️⃣ Spectral concentration check
        // Pipa sound energy concentrates in the low band (100-300 Hz)
        // Compare band energies with a simple approach
        
        // Compute energy per band (low / mid / high)
        let segment = frameLength / 3
        
        var lowEnergy: Float = 0.0
        for i in 0..<segment {
            lowEnergy += channelData[i] * channelData[i]
        }
        
        var midEnergy: Float = 0.0
        for i in segment..<(segment * 2) {
            midEnergy += channelData[i] * channelData[i]
        }
        
        var highEnergy: Float = 0.0
        for i in (segment * 2)..<frameLength {
            highEnergy += channelData[i] * channelData[i]
        }
        
        let totalEnergy = lowEnergy + midEnergy + highEnergy + 0.0001
        let lowRatio = lowEnergy / totalEnergy
        
        // Pipa signature: low-band energy share > 25%
        // Speech and noise usually have a smaller low-band share
        guard lowRatio > 0.2 else {
            return false
        }
        
        // 5️⃣ Attack-decay characteristic check
        // Pipa sound has a clear fast attack and slow decay
        
        // Find the position of the maximum amplitude
        var peakIndex = 0
        var peakValue: Float = 0.0
        for i in 0..<frameLength {
            let absValue = abs(channelData[i])
            if absValue > peakValue {
                peakValue = absValue
                peakIndex = i
            }
        }
        
        // Compute the attack time share (from the start to the peak)
        let attackRatio = Float(peakIndex) / Float(frameLength)
        
        // Pipa signature: a very short attack phase (< 30%), followed by a long decay
        // Speech: the attack is distributed more evenly
        guard attackRatio < 0.4 else {
            return false
        }
        
        // ✅ Passed every check, classified as pipa sound
        return true
    }
}
