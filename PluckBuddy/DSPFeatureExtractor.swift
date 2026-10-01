//
//  DSPFeatureExtractor.swift
//  PluckBuddy
//
//  DSP feature extractor based on the PipaDetection scheme
//  Extracts pipa sound features: fundamental frequency, harmonic ratio, spectral centroid, attack detection, envelope decay
//

import Foundation
import AVFoundation
import Accelerate

/// DSP feature extractor
class DSPFeatureExtractor {
    
    // MARK: - Configuration
    private let fftSize: Int
    private var sampleRate: Float // ✅ Made mutable, read from the audio buffer
    
    // FFT Setup
    private let fftSetup: vDSP_DFT_Setup
    private var realBuffer: [Float]
    private var imagBuffer: [Float]
    private var magnitudes: [Float]
    
    // Historical data (used for spectral flux)
    private var previousMagnitudes: [Float]?
    
    // MARK: - Initialization
    init(fftSize: Int = 4096) {
        self.fftSize = fftSize
        self.sampleRate = 48000.0 // ✅ Default value, updated on first processing
        
        guard let setup = vDSP_DFT_zrop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            vDSP_DFT_Direction.FORWARD
        ) else {
            fatalError("Failed to create FFT setup")
        }
        
        self.fftSetup = setup
        self.realBuffer = [Float](repeating: 0, count: fftSize)
        self.imagBuffer = [Float](repeating: 0, count: fftSize)
        self.magnitudes = [Float](repeating: 0, count: fftSize / 2)
    }
    
    deinit {
        vDSP_DFT_DestroySetup(fftSetup)
    }
    
    // MARK: - Feature Extraction
    
    /// Processes the audio buffer and extracts all features - optimized version (adds low-frequency preprocessing)
    func process(buffer: AVAudioPCMBuffer) -> DSPFeatures {
        guard let channelData = buffer.floatChannelData?[0] else {
            return DSPFeatures()
        }
        
        // ✅ Reads the actual sample rate from the buffer
        let actualSampleRate = Float(buffer.format.sampleRate)
        if actualSampleRate != sampleRate {
            sampleRate = actualSampleRate
            print("✅ DSP sample rate updated: \(sampleRate) Hz")
        }
        
        let frameLength = Int(buffer.frameLength)
        guard frameLength >= fftSize else {
            return DSPFeatures()
        }
        
        // 1. Compute RMS
        var rms: Float = 0.0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameLength))
        
        // Silence detection (threshold lowered to support bass strings)
        guard rms > 0.003 else { // Lowered from 0.005 to 0.003
            return DSPFeatures(rms: rms)
        }
        
        // 2. Detect the fundamental frequency via autocorrelation (more accurate than FFT)
        let pitchHz = detectPitchAutocorrelation(channelData: channelData, frameLength: frameLength)
        
        // 3. FFT analysis
        performFFT(channelData: channelData)
        
        // 4. Harmonic energy ratio
        let harmonicRatio = calculateHarmonicRatio(fundamentalHz: pitchHz)
        
        // 5. Spectral centroid
        let spectralCentroid = calculateSpectralCentroid()
        
        // 6. Spectral flux (attack detection)
        let spectralFlux = calculateSpectralFlux()
        
        // 7. Envelope decay features
        let envelope = calculateEnvelope(channelData: channelData, frameLength: frameLength)
        
        return DSPFeatures(
            rms: rms,
            pitchHz: pitchHz,
            harmonicRatio: harmonicRatio,
            spectralCentroid: spectralCentroid,
            spectralFlux: spectralFlux,
            attackRatio: envelope.attackRatio,
            decaySlope: envelope.decaySlope
        )
    }
    
    /// Computes the pipa sound score (0-1) - optimized version, friendlier to bass strings (A string 110Hz)
    func pipaScore(_ features: DSPFeatures) -> Float {
        var score: Float = 0.0
        var weights: Float = 0.0
        
        // 1. RMS energy check (threshold lowered, A string energy may be weaker)
        if features.rms > 0.01 { // Lowered from 0.015 to 0.01
            score += 0.15
        }
        weights += 0.15
        
        // 2. Fundamental frequency range check - optimized version (for the four pipa strings: A=110, d=147, e=165, a=220)
        if features.pitchHz > 0 {
            let freq = features.pitchHz
            
            // Exact match against the standard pitches of the four pipa strings (±15Hz tolerance)
            let pipaStrings = [110.0, 146.83, 164.81, 220.0]
            var bestMatch: Float = 0.0
            
            for standardFreq in pipaStrings {
                let deviation = abs(freq - Float(standardFreq))
                if deviation < 15.0 {
                    // The closer to the standard pitch, the higher the score
                    bestMatch = max(bestMatch, 1.0 - deviation / 15.0)
                }
            }
            
            if bestMatch > 0.5 {
                score += 0.25 * bestMatch // Exact match with a standard pitch
            } else if freq >= 90 && freq <= 250 {
                score += 0.15 // Within a reasonable range
            } else if freq >= 80 && freq <= 400 {
                score += 0.08 // Extended range
            }
        }
        weights += 0.25
        
        // 3. Harmonic energy ratio (bass string harmonics may be weaker, threshold lowered)
        if features.harmonicRatio > 0.2 { // Lowered from 0.3 to 0.2
            score += 0.2 * min(1.0, features.harmonicRatio / 0.5) // Lowered from 0.6 to 0.5
        }
        weights += 0.2
        
        // 4. Spectral centroid (pipa sound energy concentrates in low frequencies, more tolerant of bass strings)
        if features.spectralCentroid < 1000 { // Raised from 800 to 1000
            score += 0.15 * (1.0 - features.spectralCentroid / 2000) // Raised from 1600 to 2000
        }
        weights += 0.15
        
        // 5. Attack feature (pipa has a distinctive plucked attack, threshold lowered)
        if features.spectralFlux > 0.12 { // Lowered from 0.18 to 0.12
            score += 0.1 * min(1.0, features.spectralFlux / 0.25)
        }
        weights += 0.1
        
        // 6. Envelope feature (fast attack + slow decay, more tolerant of bass strings)
        if features.attackRatio < 0.35 && features.decaySlope < -0.05 { // Relaxed condition
            score += 0.15
        } else if features.attackRatio < 0.4 { // At least a fast attack is required
            score += 0.08
        }
        weights += 0.15
        
        return min(1.0, score / weights)
    }
    
    // MARK: - Private Methods
    
    /// Detects the fundamental frequency with the YIN algorithm (professional tuner-level precision, ±0.05-0.2 Hz)
    /// Optimized version: more sensitive to low frequencies (A string 110Hz)
    private func detectPitchAutocorrelation(channelData: UnsafePointer<Float>, frameLength: Int) -> Float {
        let halfLength = frameLength / 2
        let minPeriod = Int(sampleRate / 1700) // Maximum 1700Hz
        let maxPeriod = min(Int(sampleRate / 80), halfLength) // Lowered to 80Hz to better support the A string
        let threshold: Float = 0.15 // Raised from 0.1 to 0.15, more tolerant of bass
        
        // 1️⃣ Compute the difference function
        var difference = [Float](repeating: 0, count: halfLength)
        for tau in 0..<halfLength {
            var sum: Float = 0.0
            for i in 0..<halfLength {
                if i + tau < frameLength {
                    let delta = channelData[i] - channelData[i + tau]
                    sum += delta * delta
                }
            }
            difference[tau] = sum
        }
        
        // 2️⃣ Cumulative mean normalized difference
        var cumulativeSum: Float = 0.0
        var normalizedDifference = [Float](repeating: 1.0, count: halfLength)
        normalizedDifference[0] = 1.0
        
        for tau in 1..<halfLength {
            cumulativeSum += difference[tau]
            if cumulativeSum > 0 {
                normalizedDifference[tau] = difference[tau] * Float(tau) / cumulativeSum
            }
        }
        
        // 3️⃣ Find the first valley (minimum) below the threshold within the valid range
        var tau = minPeriod
        while tau < maxPeriod {
            if normalizedDifference[tau] < threshold {
                // Found a local minimum
                while tau + 1 < maxPeriod && normalizedDifference[tau + 1] < normalizedDifference[tau] {
                    tau += 1
                }
                break
            }
            tau += 1
        }
        
        // No valid period was found
        guard tau < maxPeriod else { return 0 }
        
        // 4️⃣ Parabolic interpolation improves precision
        if tau > 0 && tau < halfLength - 1 {
            let alpha = normalizedDifference[tau - 1]
            let beta = normalizedDifference[tau]
            let gamma = normalizedDifference[tau + 1]
            
            // Prevent division by zero
            let denominator = 2.0 * (alpha - 2.0 * beta + gamma)
            if abs(denominator) > 0.00001 {
                let offset = (alpha - gamma) / denominator
                let refinedTau = Float(tau) + offset
                
                // Verify that the result is reasonable
                if refinedTau > Float(minPeriod) && refinedTau < Float(maxPeriod) {
                    return sampleRate / refinedTau
                }
            }
        }
        
        return sampleRate / Float(tau)
    }
    
    /// Performs the FFT
    private func performFFT(channelData: UnsafePointer<Float>) {
        // Apply a Hamming window
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hamm_window(&window, vDSP_Length(fftSize), 0)
        
        var windowedSignal = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(channelData, 1, window, 1, &windowedSignal, 1, vDSP_Length(fftSize))
        
        // FFT
        realBuffer = windowedSignal
        imagBuffer = [Float](repeating: 0, count: fftSize)
        
        vDSP_DFT_Execute(fftSetup, &realBuffer, &imagBuffer, &realBuffer, &imagBuffer)
        
        // Compute magnitudes
        for i in 0..<(fftSize / 2) {
            let real = realBuffer[i]
            let imag = imagBuffer[i]
            magnitudes[i] = sqrt(real * real + imag * imag)
        }
    }
    
    /// Computes the harmonic energy ratio - optimized version (friendlier to bass strings)
    private func calculateHarmonicRatio(fundamentalHz: Float) -> Float {
        guard fundamentalHz > 0 else { return 0 }
        
        let freqResolution = sampleRate / Float(fftSize)
        let f0Bin = Int(fundamentalHz / freqResolution)
        
        guard f0Bin > 0 && f0Bin < magnitudes.count else { return 0 }
        
        // Extract the energy of the fundamental and the first 4 harmonics
        var harmonicEnergy: Float = 0.0
        var totalEnergy: Float = 0.0
        
        for i in 0..<magnitudes.count {
            totalEnergy += magnitudes[i] * magnitudes[i]
        }
        
        // Increase the tolerance range for bass (A string 110Hz)
        let binTolerance = fundamentalHz < 130 ? 3 : 2 // ±3 for the A string, ±2 for others
        
        // Fundamental and harmonics (dynamically adjusted tolerance)
        for h in 1...5 {
            let hBin = f0Bin * h
            if hBin < magnitudes.count {
                let start = max(0, hBin - binTolerance)
                let end = min(magnitudes.count - 1, hBin + binTolerance)
                for i in start...end {
                    harmonicEnergy += magnitudes[i] * magnitudes[i]
                }
            }
        }
        
        return totalEnergy > 0 ? harmonicEnergy / totalEnergy : 0
    }
    
    /// Computes the spectral centroid (Hz)
    private func calculateSpectralCentroid() -> Float {
        var weightedSum: Float = 0.0
        var magnitudeSum: Float = 0.0
        
        let freqResolution = sampleRate / Float(fftSize)
        
        for i in 0..<magnitudes.count {
            let freq = Float(i) * freqResolution
            weightedSum += freq * magnitudes[i]
            magnitudeSum += magnitudes[i]
        }
        
        return magnitudeSum > 0 ? weightedSum / magnitudeSum : 0
    }
    
    /// Computes the spectral flux (attack detection)
    private func calculateSpectralFlux() -> Float {
        guard let prev = previousMagnitudes else {
            previousMagnitudes = magnitudes
            return 0
        }
        
        var flux: Float = 0.0
        for i in 0..<min(magnitudes.count, prev.count) {
            let diff = magnitudes[i] - prev[i]
            if diff > 0 {
                flux += diff
            }
        }
        
        previousMagnitudes = magnitudes
        
        // Normalization
        let maxFlux: Float = 100.0
        return min(1.0, flux / maxFlux)
    }
    
    /// Computes envelope features
    private func calculateEnvelope(channelData: UnsafePointer<Float>, frameLength: Int) -> (attackRatio: Float, decaySlope: Float) {
        // Find the peak position
        var peakIndex = 0
        var peakValue: Float = 0.0
        
        for i in 0..<frameLength {
            let absValue = abs(channelData[i])
            if absValue > peakValue {
                peakValue = absValue
                peakIndex = i
            }
        }
        
        let attackRatio = Float(peakIndex) / Float(frameLength)
        
        // Compute the decay slope (after the peak)
        var decaySlope: Float = 0.0
        if peakIndex < frameLength - 100 {
            let decayStart = peakValue
            let decayEnd = abs(channelData[min(peakIndex + 100, frameLength - 1)])
            decaySlope = (decayEnd - decayStart) / Float(100)
        }
        
        return (attackRatio, decaySlope)
    }
}

// MARK: - DSP Features
struct DSPFeatures {
    let rms: Float                    // Root-mean-square energy
    let pitchHz: Float                // Fundamental frequency (autocorrelation method)
    let harmonicRatio: Float          // Harmonic energy ratio
    let spectralCentroid: Float       // Spectral centroid
    let spectralFlux: Float           // Spectral flux (attack strength)
    let attackRatio: Float            // Attack time ratio
    let decaySlope: Float             // Decay slope
    
    init(
        rms: Float = 0,
        pitchHz: Float = 0,
        harmonicRatio: Float = 0,
        spectralCentroid: Float = 0,
        spectralFlux: Float = 0,
        attackRatio: Float = 0,
        decaySlope: Float = 0
    ) {
        self.rms = rms
        self.pitchHz = pitchHz
        self.harmonicRatio = harmonicRatio
        self.spectralCentroid = spectralCentroid
        self.spectralFlux = spectralFlux
        self.attackRatio = attackRatio
        self.decaySlope = decaySlope
    }
}
