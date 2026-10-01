//
//  RollDetector.swift
//  PluckBuddy
//
//  Created by Wu Zehui on 2026/7/16.
//

import Foundation
import AVFoundation
import Accelerate

/// Tremolo detector - detects continuous fast plucking motions
class RollDetector {
    
    // MARK: - Configuration
    private let sampleRate: Double
    private let rollThreshold: Float = 0.1 // Tremolo detection threshold (low, because tremolo plucks are lighter)
    private let minRollInterval: Double = 0.05 // Minimum interval 50ms (20 times/sec)
    private let maxRollInterval: Double = 0.15 // Maximum interval 150ms (6.7 times/sec)
    private let rollSequenceMinCount = 4 // At least 4 consecutive plucks count as a tremolo
    
    // MARK: - State
    private var lastDetectionTime: Date?
    private var currentSequence: [RollNote] = [] // Current tremolo sequence
    private var rollSpeed: Double = 0 // Tremolo speed (times/sec)
    
    // MARK: - Callbacks
    var onRollDetected: ((RollEvent) -> Void)?
    var onRollSequenceComplete: ((RollSequence) -> Void)?
    
    // MARK: - Initialization
    init(sampleRate: Double = 48000.0) {
        self.sampleRate = sampleRate
    }
    
    // MARK: - Detection
    /// Detects tremolo motion
    func detectRoll(from buffer: AVAudioPCMBuffer) -> RollEvent? {
        guard let channelData = buffer.floatChannelData?[0] else {
            return nil
        }
        
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return nil }
        
        // 1️⃣ Compute the peak amplitude
        var peak: Float = 0.0
        vDSP_maxv(channelData, 1, &peak, vDSP_Length(frameLength))
        
        // 2️⃣ Check whether the threshold is exceeded
        guard peak > rollThreshold else {
            // If nothing is detected for a while, end the current sequence
            checkSequenceTimeout()
            return nil
        }
        
        // 3️⃣ Check the time interval
        let now = Date()
        var interval: Double = 0
        
        if let lastTime = lastDetectionTime {
            interval = now.timeIntervalSince(lastTime)
            
            // An interval that is too short or too long is not a valid tremolo
            guard interval >= minRollInterval && interval <= maxRollInterval else {
                if interval > maxRollInterval {
                    // The interval is too long, end the sequence
                    completeCurrentSequence()
                }
                return nil
            }
        }
        
        lastDetectionTime = now
        
        // 4️⃣ Create a tremolo note
        let note = RollNote(
            timestamp: now,
            amplitude: peak,
            interval: interval
        )
        
        // 5️⃣ Append to the current sequence
        currentSequence.append(note)
        
        // 6️⃣ Compute the tremolo speed
        if currentSequence.count >= 2 {
            let intervals = currentSequence.suffix(5).dropFirst().map { $0.interval }
            let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
            rollSpeed = avgInterval > 0 ? 1.0 / avgInterval : 0
        }
        
        // 7️⃣ Create the event
        let event = RollEvent(
            note: note,
            sequenceLength: currentSequence.count,
            currentSpeed: rollSpeed,
            isValidSequence: currentSequence.count >= rollSequenceMinCount
        )
        
        onRollDetected?(event)
        return event
    }
    
    // MARK: - Sequence Management
    
    /// Checks whether the sequence has timed out
    private func checkSequenceTimeout() {
        guard let lastTime = lastDetectionTime else { return }
        
        let timeSinceLastNote = Date().timeIntervalSince(lastTime)
        if timeSinceLastNote > maxRollInterval {
            completeCurrentSequence()
        }
    }
    
    /// Completes the current tremolo sequence
    private func completeCurrentSequence() {
        guard currentSequence.count >= rollSequenceMinCount else {
            currentSequence.removeAll()
            return
        }
        
        let sequence = RollSequence(
            notes: currentSequence,
            startTime: currentSequence.first!.timestamp,
            endTime: currentSequence.last!.timestamp,
            averageSpeed: calculateAverageSpeed(),
            uniformity: calculateUniformity()
        )
        
        onRollSequenceComplete?(sequence)
        currentSequence.removeAll()
    }
    
    /// Manually ends the sequence (called when practice ends)
    func finishSequence() {
        completeCurrentSequence()
    }
    
    // MARK: - Analysis
    
    /// Computes the average speed (times/sec)
    private func calculateAverageSpeed() -> Double {
        guard currentSequence.count >= 2 else { return 0 }
        
        let totalDuration = currentSequence.last!.timestamp.timeIntervalSince(currentSequence.first!.timestamp)
        return Double(currentSequence.count - 1) / totalDuration
    }
    
    /// Computes evenness (0-1, 1 means perfectly even)
    private func calculateUniformity() -> Double {
        guard currentSequence.count >= 3 else { return 0 }
        
        let intervals = currentSequence.dropFirst().map { $0.interval }
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        
        guard mean > 0 else { return 0 }
        
        let variance = intervals.map { pow($0 - mean, 2) }.reduce(0, +) / Double(intervals.count)
        let stdDev = sqrt(variance)
        
        // Coefficient of variation (smaller means more even)
        let cv = stdDev / mean
        
        // Convert to a 0-1 score
        return max(0, min(1, 1.0 - cv * 3))
    }
    
    /// Resets the detector
    func reset() {
        lastDetectionTime = nil
        currentSequence.removeAll()
        rollSpeed = 0
    }
}

// MARK: - RollNote
/// A single tremolo note
struct RollNote {
    let timestamp: Date
    let amplitude: Float
    let interval: Double // Interval from the previous note (seconds)
}

// MARK: - RollEvent
/// Tremolo event (raised each time a tremolo note is detected)
struct RollEvent {
    let note: RollNote
    let sequenceLength: Int // Current sequence length
    let currentSpeed: Double // Current speed (times/sec)
    let isValidSequence: Bool // Whether a valid tremolo sequence is formed
}

// MARK: - RollSequence
/// A complete tremolo sequence
struct RollSequence {
    let notes: [RollNote]
    let startTime: Date
    let endTime: Date
    let averageSpeed: Double // Average speed (times/sec)
    let uniformity: Double // Evenness (0-1)
    
    /// Sequence duration
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
    
    /// Note count
    var noteCount: Int {
        return notes.count
    }
    
    /// Quality rating
    var quality: Quality {
        if uniformity > 0.85 && averageSpeed >= 10 {
            return .excellent
        } else if uniformity > 0.7 && averageSpeed >= 8 {
            return .good
        } else if uniformity > 0.5 && averageSpeed >= 6 {
            return .fair
        } else {
            return .needsImprovement
        }
    }
    
    enum Quality {
        case excellent      // Excellent
        case good          // Good
        case fair          // Fair
        case needsImprovement // Needs Work
        
        var description: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .fair: return "Fair"
            case .needsImprovement: return "Needs Work"
            }
        }
        
        var emoji: String {
            switch self {
            case .excellent: return "🌟"
            case .good: return "👍"
            case .fair: return "👌"
            case .needsImprovement: return "💪"
            }
        }
    }
}
