//
//  PitchDetector.swift
//  PluckBuddy
//
//  Created by Wu Zehui on 2026/7/15.
//

import Foundation
import AVFoundation
import Accelerate

/// FFT-based pitch detector - 100% native Apple implementation
/// Uses the Accelerate framework for the fast Fourier transform
class PitchDetector {
    
    // MARK: - Configuration
    private let sampleRate: Double
    private let bufferSize: Int
    
    // MARK: - FFT Setup
    private let fftSetup: vDSP_DFT_Setup
    private let log2n: vDSP_Length
    
    // Working buffers (reused to improve performance)
    private var realBuffer: [Float]
    private var imagBuffer: [Float]
    private var magnitudes: [Float]
    
    // Smoothing filter (reduces jitter)
    private var frequencyHistory: [Double] = []
    private let historySize = 5 // Keep the last 5 detection results
    
    // MARK: - Initialization
    init(sampleRate: Double = 44100.0, bufferSize: Int = 4096) {
        self.sampleRate = sampleRate
        self.bufferSize = bufferSize
        
        // Compute log2(bufferSize)
        self.log2n = vDSP_Length(log2(Float(bufferSize)))
        
        // Create the FFT setup (DFT for real-valued input)
        guard let setup = vDSP_DFT_zrop_CreateSetup(
            nil,
            vDSP_Length(bufferSize),
            vDSP_DFT_Direction.FORWARD
        ) else {
            fatalError("Failed to create FFT setup")
        }
        self.fftSetup = setup
        
        // Pre-allocate the buffers
        self.realBuffer = [Float](repeating: 0, count: bufferSize)
        self.imagBuffer = [Float](repeating: 0, count: bufferSize)
        self.magnitudes = [Float](repeating: 0, count: bufferSize / 2)
    }
    
    deinit {
        vDSP_DFT_DestroySetup(fftSetup)
    }
    
    // MARK: - Pitch Detection
    /// Detects pitch from an audio buffer (Hz)
    /// - Parameter buffer: PCM audio buffer
    /// - Returns: The detected frequency (Hz), or nil if it cannot be detected
    func detectPitch(from buffer: AVAudioPCMBuffer) -> Double? {
        guard let channelData = buffer.floatChannelData?[0] else {
            return nil
        }
        
        let frameLength = Int(buffer.frameLength)
        guard frameLength >= bufferSize else { return nil }
        
        // 1️⃣ Compute RMS to check signal energy
        var rms: Float = 0.0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameLength))
        
        // Energy threshold (avoid detecting noise)
        guard rms > 0.01 else { return nil }
        
        // 2️⃣ Apply a Hamming window (reduces spectral leakage)
        var windowedSignal = [Float](repeating: 0, count: bufferSize)
        vDSP_vmul(
            channelData, 1,
            createHammingWindow(), 1,
            &windowedSignal, 1,
            vDSP_Length(bufferSize)
        )
        
        // 3️⃣ Perform the FFT
        realBuffer = windowedSignal
        imagBuffer = [Float](repeating: 0, count: bufferSize)
        
        vDSP_DFT_Execute(
            fftSetup,
            &realBuffer,
            &imagBuffer,
            &realBuffer,
            &imagBuffer
        )
        
        // 4️⃣ Compute the magnitude spectrum
        // magnitude = sqrt(real^2 + imag^2)
        for i in 0..<(bufferSize / 2) {
            let real = realBuffer[i]
            let imag = imagBuffer[i]
            magnitudes[i] = sqrt(real * real + imag * imag)
        }
        
        // 5️⃣ Find the strongest frequency peak
        guard let peakFrequency = findPeakFrequency() else {
            return nil
        }
        
        // 6️⃣ Apply moving-average filtering (reduces jitter)
        let smoothedFrequency = smoothFrequency(peakFrequency)
        
        return smoothedFrequency
    }
    
    // MARK: - Helper Methods
    
    /// Smooths the frequency (moving-average filtering)
    private func smoothFrequency(_ newFrequency: Double) -> Double {
        frequencyHistory.append(newFrequency)
        
        // Limit the history size
        if frequencyHistory.count > historySize {
            frequencyHistory.removeFirst()
        }
        
        // If fewer than 3 history entries, return the new value directly
        guard frequencyHistory.count >= 3 else {
            return newFrequency
        }
        
        // Compute the median (more robust against outliers than the mean)
        let sorted = frequencyHistory.sorted()
        let midIndex = sorted.count / 2
        
        if sorted.count % 2 == 0 {
            return (sorted[midIndex - 1] + sorted[midIndex]) / 2.0
        } else {
            return sorted[midIndex]
        }
    }
    
    /// Creates a Hamming window
    private func createHammingWindow() -> [Float] {
        var window = [Float](repeating: 0, count: bufferSize)
        vDSP_hamm_window(&window, vDSP_Length(bufferSize), 0)
        return window
    }
    
    /// Finds the peak frequency in the spectrum (optimized for better pipa string recognition accuracy)
    private func findPeakFrequency() -> Double? {
        // Standard frequencies of the four pipa strings
        let pipaFreqs = [110.0, 146.83, 164.81, 220.0]
        
        // Set a search window for each string (±20Hz, more precise)
        let searchWindows: [(Double, Double)] = pipaFreqs.map { freq in
            (freq - 20.0, freq + 20.0)
        }
        
        // Frequency resolution
        let freqResolution = sampleRate / Double(bufferSize)
        
        // Find the peak within each window
        var candidates: [(frequency: Double, magnitude: Float, windowIndex: Int)] = []
        
        for (windowIndex, window) in searchWindows.enumerated() {
            let minBin = Int(window.0 / freqResolution)
            let maxBin = min(Int(window.1 / freqResolution), bufferSize / 2 - 1)
            
            guard minBin < maxBin else { continue }
            
            // Find the maximum value within the window
            var maxMagnitude: Float = 0.0
            var maxIndex = 0
            
            for i in minBin...maxBin {
                if magnitudes[i] > maxMagnitude {
                    maxMagnitude = magnitudes[i]
                    maxIndex = i
                }
            }
            
            // Parabolic interpolation improves precision
            let refinedIndex = parabolicInterpolation(index: maxIndex, magnitudes: magnitudes)
            let frequency = refinedIndex * freqResolution
            
            candidates.append((frequency, maxMagnitude, windowIndex))
        }
        
        // Filter out candidates with too small a magnitude (threshold raised to 0.2)
        let validCandidates = candidates.filter { $0.magnitude > 0.2 }
        
        guard !validCandidates.isEmpty else { return nil }
        
        // Select the candidate with the largest magnitude
        let best = validCandidates.max(by: { $0.magnitude < $1.magnitude })!
        
        // Extra validation: check for obvious harmonic interference
        if hasHarmonicInterference(frequency: best.frequency, magnitude: best.magnitude) {
            // If harmonic interference is detected, try to find the fundamental
            if let fundamental = findFundamental(from: best.frequency) {
                return fundamental
            }
        }
        
        return best.frequency
    }
    
    /// Detects harmonic interference
    private func hasHarmonicInterference(frequency: Double, magnitude: Float) -> Bool {
        let freqResolution = sampleRate / Double(bufferSize)
        
        // Check whether a low-frequency component of similar strength exists (possibly the fundamental)
        let halfFreqBin = Int((frequency / 2.0) / freqResolution)
        
        guard halfFreqBin > 0 && halfFreqBin < magnitudes.count else {
            return false
        }
        
        // If the magnitude at half the frequency exceeds 60% of the current magnitude, it is likely a harmonic
        return magnitudes[halfFreqBin] > magnitude * 0.6
    }
    
    /// Finds the fundamental frequency from a harmonic frequency
    private func findFundamental(from harmonic: Double) -> Double? {
        let freqResolution = sampleRate / Double(bufferSize)
        let pipaFreqs = [110.0, 146.83, 164.81, 220.0]
        
        // Try dividing by 2 and 3 to find the fundamental
        for divisor in 2...3 {
            let possibleFundamental = harmonic / Double(divisor)
            
            // Check whether it is close to a standard pipa pitch
            for standardFreq in pipaFreqs {
                if abs(possibleFundamental - standardFreq) < 10.0 {
                    // Verify that this fundamental actually exists in the spectrum
                    let bin = Int(possibleFundamental / freqResolution)
                    if bin > 0 && bin < magnitudes.count && magnitudes[bin] > 0.1 {
                        return possibleFundamental
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Parabolic interpolation (improves frequency estimation precision)
    /// Fits a parabola using the peak point and its left and right neighbors
    private func parabolicInterpolation(index: Int, magnitudes: [Float]) -> Double {
        guard index > 0 && index < magnitudes.count - 1 else {
            return Double(index)
        }
        
        let alpha = magnitudes[index - 1]
        let beta = magnitudes[index]
        let gamma = magnitudes[index + 1]
        
        // Offset of the parabola vertex
        let offset = 0.5 * (alpha - gamma) / (alpha - 2.0 * beta + gamma)
        
        // Return the precise bin position (can be fractional)
        return Double(index) + Double(offset)
    }
}

// MARK: - Extension: frequency to note name conversion (for debugging)
extension PitchDetector {
    /// Converts a frequency to the closest note name (for debugging)
    static func frequencyToNote(_ frequency: Double) -> String {
        // A4 = 440Hz as reference
        let a4Frequency = 440.0
        
        // Compute the semitone difference from A4
        let semitonesFromA4 = 12.0 * log2(frequency / a4Frequency)
        let roundedSemitones = round(semitonesFromA4)
        
        // Note name array (starting from A)
        let noteNames = ["A", "A#", "B", "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#"]
        
        let noteIndex = (Int(roundedSemitones) + 12 * 10) % 12 // +120 ensures a positive number
        let octave = 4 + Int((roundedSemitones + 0.5) / 12.0)
        
        return "\(noteNames[noteIndex])\(octave)"
    }
}
