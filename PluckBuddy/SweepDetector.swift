//
//  SweepDetector.swift
//  PluckBuddy
//
//  Created by Wu Zehui on 2026/7/16.
//

import Foundation
import AVFoundation
import Accelerate

/// Sweep detector - detects the strength and direction of sweep motions
class SweepDetector {
    
    // MARK: - Configuration
    private let sampleRate: Double
    private let sweepThreshold: Float = 0.2 // Sweep detection threshold (high, because sweeps are forceful)
    private let minSweepInterval: Double = 0.3 // Minimum interval 300ms (prevents duplicate detection)
    
    // MARK: - State
    private var lastDetectionTime: Date?
    private var lastAmplitude: Float = 0
    private var sweepHistory: [SweepEvent] = []
    
    // MARK: - Callbacks
    var onSweepDetected: ((SweepEvent) -> Void)?
    
    // MARK: - Initialization
    init(sampleRate: Double = 48000.0) {
        self.sampleRate = sampleRate
    }
    
    // MARK: - Detection
    /// Detects sweep motion
    func detectSweep(from buffer: AVAudioPCMBuffer) -> SweepEvent? {
        guard let channelData = buffer.floatChannelData?[0] else {
            return nil
        }
        
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return nil }
        
        // 1️⃣ Compute RMS (root-mean-square energy)
        var rms: Float = 0.0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameLength))
        
        // 2️⃣ Compute the peak amplitude
        var peak: Float = 0.0
        vDSP_maxv(channelData, 1, &peak, vDSP_Length(frameLength))
        
        // 3️⃣ Check whether the threshold is exceeded
        guard peak > sweepThreshold else {
            lastAmplitude = peak
            return nil
        }
        
        // 4️⃣ Check the time interval (debouncing)
        let now = Date()
        if let lastTime = lastDetectionTime {
            let interval = now.timeIntervalSince(lastTime)
            guard interval >= minSweepInterval else {
                return nil
            }
        }
        
        lastDetectionTime = now
        
        // 5️⃣ Detect direction (based on the amplitude trend)
        let direction: SweepDirection
        if peak > lastAmplitude * 1.2 {
            // Amplitude increased significantly, likely a downward sweep
            direction = .down
        } else if peak < lastAmplitude * 0.8 {
            // Amplitude decreased significantly, likely an upward sweep
            direction = .up
        } else {
            // Amplitude barely changed, infer from history
            direction = inferDirection()
        }
        
        lastAmplitude = peak
        
        // 6️⃣ Compute the strength level (based on the peak)
        let strength = calculateStrength(peak: peak, rms: rms)
        
        // 7️⃣ Create the sweep event
        let event = SweepEvent(
            timestamp: now,
            amplitude: peak,
            rms: rms,
            direction: direction,
            strength: strength
        )
        
        // Record history
        sweepHistory.append(event)
        if sweepHistory.count > 10 {
            sweepHistory.removeFirst()
        }
        
        onSweepDetected?(event)
        return event
    }
    
    // MARK: - Analysis
    
    /// Infers direction from history
    private func inferDirection() -> SweepDirection {
        guard sweepHistory.count >= 2 else {
            return .down // Default to downward
        }
        
        // Count the distribution of recent directions
        // 取最近若干次记录用于方向判定
        let recentDirections = sweepHistory.suffix(5)
        
        // Tend to alternate direction
        let lastDirection = recentDirections.last?.direction ?? .down
        return lastDirection == .down ? .up : .down
    }
    
    /// Computes the strength level
    private func calculateStrength(peak: Float, rms: Float) -> StrengthLevel {
        // Consider peak and RMS together
        let combinedStrength = (peak * 0.7 + rms * 0.3)
        
        if combinedStrength > 0.7 {
            return .veryStrong
        } else if combinedStrength > 0.5 {
            return .strong
        } else if combinedStrength > 0.3 {
            return .medium
        } else {
            return .weak
        }
    }
    
    /// Gets the average strength
    func getAverageStrength() -> Double {
        guard !sweepHistory.isEmpty else { return 0 }
        
        let totalStrength = sweepHistory.reduce(0.0) { $0 + Double($1.amplitude) }
        return totalStrength / Double(sweepHistory.count)
    }
    
    /// Gets sweep statistics
    func getStatistics() -> SweepStatistics {
        let upCount = sweepHistory.filter { $0.direction == .up }.count
        let downCount = sweepHistory.filter { $0.direction == .down }.count
        let avgStrength = getAverageStrength()
        
        return SweepStatistics(
            totalCount: sweepHistory.count,
            upCount: upCount,
            downCount: downCount,
            averageStrength: avgStrength
        )
    }
    
    /// Resets the detector
    func reset() {
        lastDetectionTime = nil
        lastAmplitude = 0
        sweepHistory.removeAll()
    }
}

// MARK: - SweepDirection
/// Sweep direction
enum SweepDirection {
    case up     // Sweep upward
    case down   // Sweep downward
    
    var description: String {
        switch self {
        case .up: return "Upward"
        case .down: return "Downward"
        }
    }
    
    var arrow: String {
        switch self {
        case .up: return "↑"
        case .down: return "↓"
        }
    }
}

// MARK: - StrengthLevel
/// Strength level
enum StrengthLevel {
    case weak
    case medium
    case strong
    case veryStrong
    
    var description: String {
        switch self {
        case .weak: return "Light"
        case .medium: return "Medium"
        case .strong: return "Heavy"
        case .veryStrong: return "Very Heavy"
        }
    }
    
    var value: Double {
        switch self {
        case .weak: return 0.25
        case .medium: return 0.5
        case .strong: return 0.75
        case .veryStrong: return 1.0
        }
    }
}

// MARK: - SweepEvent
/// Sweep event
struct SweepEvent {
    let timestamp: Date
    let amplitude: Float
    let rms: Float
    let direction: SweepDirection
    let strength: StrengthLevel
    
    /// Normalized strength value (0-1)
    var normalizedStrength: Double {
        return Double(amplitude)
    }
}

// MARK: - SweepStatistics
/// Sweep statistics
struct SweepStatistics {
    let totalCount: Int
    let upCount: Int
    let downCount: Int
    let averageStrength: Double
    
    /// Direction balance (closer to 0.5 means more balanced)
    var directionBalance: Double {
        guard totalCount > 0 else { return 0.5 }
        return Double(min(upCount, downCount)) / Double(totalCount)
    }
}
