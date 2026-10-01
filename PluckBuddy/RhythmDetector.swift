//
//  RhythmDetector.swift
//  PluckBuddy
//
//  Created by Wu Zehui on 2026/7/16.
//

import Foundation
import AVFoundation
import Accelerate

/// Rhythm detector - detects plucking motions and rhythm
class RhythmDetector {
    
    // MARK: - Configuration
    private let sampleRate: Double
    private let amplitudeThreshold: Float = 0.015 // Amplitude threshold (raised to reduce noise)
    private let rmsThreshold: Float = 0.008 // RMS threshold (raised to reduce noise)
    private let minIntervalMs: Double = 200 // Minimum interval 200ms (prevents noise and duplicate detection)
    private let maxReasonableBPM: Double = 240 // Maximum reasonable BPM (filters out abnormally fast intervals)
    private let minReasonableBPM: Double = 40 // Minimum reasonable BPM (filters out abnormally slow intervals)
    
    // MARK: - State
    private var lastDetectionTime: Date?
    private var intervals: [Double] = [] // Records recent time intervals
    private let maxIntervalHistory = 10
    
    // 🔍 Debug: volume monitoring
    private var lastLogTime: Date?
    private let logInterval: Double = 1.0 // Print once every second (made more frequent)
    private var detectionCount = 0
    
    // MARK: - Callbacks
    var onPluckDetected: ((PluckEvent) -> Void)?
    
    // MARK: - Initialization
    init(sampleRate: Double = 48000.0) {
        self.sampleRate = sampleRate
        print("🎧 RhythmDetector initialized (noise-resistant version)")
        print("   - Peak threshold: \(amplitudeThreshold)")
        print("   - RMS threshold: \(rmsThreshold)")
        print("   - Minimum interval: \(Int(minIntervalMs))ms")
        print("   - BPM range: \(Int(minReasonableBPM))-\(Int(maxReasonableBPM))")
    }
    
    // MARK: - Detection
    /// Detects plucking motion
    func detectPluck(from buffer: AVAudioPCMBuffer) -> PluckEvent? {
        guard let channelData = buffer.floatChannelData?[0] else {
            return nil
        }
        
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return nil }
        
        // 1️⃣ Compute RMS (root mean square) - represents signal energy
        var rms: Float = 0.0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameLength))
        
        // 2️⃣ Compute the peak amplitude
        var peak: Float = 0.0
        vDSP_maxv(channelData, 1, &peak, vDSP_Length(frameLength))
        
        // 🔍 Print volume in real time (more frequently, to help debugging)
        let now = Date()
        if lastLogTime == nil || now.timeIntervalSince(lastLogTime!) >= logInterval {
            if peak > 0.005 { // Lower the print threshold
                let isAboveThreshold = peak > amplitudeThreshold || rms > rmsThreshold
                let marker = isAboveThreshold ? "✅" : "⚪️"
                print("\(marker) Volume monitor - peak: \(String(format: "%.3f", peak)) (threshold:\(amplitudeThreshold)), RMS: \(String(format: "%.3f", rms)) (threshold:\(rmsThreshold))")
            }
            lastLogTime = now
        }
        
        // 3️⃣ Check whether the threshold is exceeded (OR logic, either peak or RMS qualifies)
        guard peak > amplitudeThreshold || rms > rmsThreshold else {
            return nil
        }
        
        // 4️⃣ Check the time interval (debouncing)
        if let lastTime = lastDetectionTime {
            let intervalMs = now.timeIntervalSince(lastTime) * 1000
            guard intervalMs >= minIntervalMs else {
                return nil // Too fast, ignore
            }
        }
        
        // 5️⃣ Record the time interval
        var interval: Double = 0
        if let lastTime = lastDetectionTime {
            interval = now.timeIntervalSince(lastTime)
            
            // 🔍 Filter out unreasonable intervals (too fast or too slow)
            let instantBPM = 60.0 / interval
            if instantBPM > maxReasonableBPM {
                print("⚠️ Interval too short (\(String(format: "%.3f", interval))s, BPM:\(String(format: "%.0f", instantBPM))) - likely noise, ignored")
                return nil // Too fast, likely noise
            }
            if instantBPM < minReasonableBPM {
                print("⚠️ Interval too long (\(String(format: "%.3f", interval))s, BPM:\(String(format: "%.0f", instantBPM))) - likely a pause, ignored")
                return nil // Too slow, likely a pause
            }
            
            intervals.append(interval)
            
            // Limit the history size
            if intervals.count > maxIntervalHistory {
                intervals.removeFirst()
            }
        }
        
        lastDetectionTime = now
        detectionCount += 1
        
        // 6️⃣ Create the event
        let event = PluckEvent(
            timestamp: now,
            amplitude: peak,
            rms: rms,
            interval: interval,
            bpm: calculateBPM()
        )
        
        // 🔍 Detailed log
        print("🎸 [\(detectionCount)] Pluck detected! Peak:\(String(format: "%.3f", peak)) RMS:\(String(format: "%.3f", rms))")
        
        onPluckDetected?(event)
        return event
    }
    
    // MARK: - Analysis
    /// Computes the current BPM (beats per minute)
    func calculateBPM() -> Double {
        guard intervals.count >= 3 else { return 0 }
        
        // Compute the average interval
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        
        // Convert to BPM
        guard avgInterval > 0 else { return 0 }
        return 60.0 / avgInterval
    }
    
    /// Computes rhythm stability (0-1, 1 means perfectly stable)
    func calculateStability() -> Double {
        guard intervals.count >= 2 else { return 0 } // Lowered to at least 2 plucks
        
        // Compute the standard deviation
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        
        // Avoid division by 0
        guard mean > 0 else { return 0 }
        
        let variance = intervals.map { pow($0 - mean, 2) }.reduce(0, +) / Double(intervals.count)
        let stdDev = sqrt(variance)
        
        // Coefficient of variation (CV) = standard deviation / mean
        let cv = stdDev / mean
        
        // Convert to a stability score (smaller CV means more stable)
        // CV < 0.05 → stability 100%
        // CV < 0.1  → stability 90%
        // CV < 0.2  → stability 80%
        // CV < 0.3  → stability 70%
        let stability = max(0, min(1, 1.0 - cv * 3)) // Adjusted coefficient down from 5 to 3
        
        print("📊 Stability calculation: intervals=\(intervals.count), mean=\(String(format: "%.3f", mean)), stdDev=\(String(format: "%.3f", stdDev)), CV=\(String(format: "%.3f", cv)), stability=\(String(format: "%.1f", stability * 100))%")
        
        return stability
    }
    
    /// Resets the detection state
    func reset() {
        lastDetectionTime = nil
        intervals.removeAll()
    }
}

// MARK: - PluckEvent
/// Pluck event
struct PluckEvent {
    let timestamp: Date
    let amplitude: Float // Peak amplitude (0-1)
    let rms: Float // Root-mean-square energy
    let interval: Double // Interval since the previous pluck (seconds)
    let bpm: Double // Current speed (BPM)
    
    /// Strength level (weak, medium, strong)
    var strength: Strength {
        if amplitude < 0.3 {
            return .weak
        } else if amplitude < 0.6 {
            return .medium
        } else {
            return .strong
        }
    }
    
    enum Strength {
        case weak
        case medium
        case strong
        
        var description: String {
            switch self {
            case .weak: return "Weak"
            case .medium: return "Medium"
            case .strong: return "Strong"
            }
        }
    }
}
