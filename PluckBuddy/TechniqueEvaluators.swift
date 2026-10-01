//
//  TechniqueEvaluators.swift
//  PluckBuddy
//
//  Collection of technique evaluators
//  Created on 2026/8/29.
//

import Foundation
import CoreGraphics

/// Tremolo posture evaluator
class RollPostureEvaluator {
    func evaluate(features: HandMotionFeatures) -> PostureEvaluation {
        var aspects: [EvaluationAspect] = []
        
        // 1. Evaluate finger sequencing (the core of tremolo)
        let sequenceScore = evaluateSequence(pattern: features.sequencePattern)
        aspects.append(EvaluationAspect(
            category: .rhythm,
            score: sequenceScore,
            description: sequenceScore >= 80 ? "Finger sequence is clear" : "Pay attention to plucking with the fingers in order"
        ))
        
        // 2. Evaluate wrist stability
        let wristSpeed = hypot(Double(features.wristVelocity.dx), Double(features.wristVelocity.dy))
        let wristScore = wristSpeed < 0.2 ? 90 : max(50, 90 - wristSpeed * 100)
        aspects.append(EvaluationAspect(
            category: .wristPosition,
            score: wristScore,
            description: wristScore >= 80 ? "Wrist is stable" : "Wrist is swaying too much"
        ))
        
        // 3. Evaluate the tiger mouth angle (how far the thumb and index finger are spread)
        let tigerScore = evaluateTigerMouthAngle(degrees: features.tigerMouthAngle)
        aspects.append(EvaluationAspect(
            category: .tigerMouth,
            score: tigerScore,
            description: tigerScore >= 80 ? "Tiger mouth opens naturally" : "Adjust how far the tiger mouth opens"
        ))
        
        // 4. Evaluate motion smoothness
        let smoothScore = evaluateMovementSmoothness(velocities: features.fingerVelocities)
        aspects.append(EvaluationAspect(
            category: .relaxation,
            score: smoothScore,
            description: smoothScore >= 80 ? "Motion is smooth" : "Motion looks a bit stiff"
        ))
        
        // Compute the overall score
        let overallScore = aspects.map { $0.score }.reduce(0, +) / Double(aspects.count)
        
        // Generate suggestions
        var suggestions: [String] = []
        if sequenceScore < 80 {
            suggestions.append("Practice plucking with the fingers in order and keep an even rhythm")
        }
        if wristScore < 80 {
            suggestions.append("Relax the wrist and maintain a stable posture")
        }
        if tigerScore < 80 {
            suggestions.append("Adjust how far the tiger mouth opens so the thumb and index finger spread naturally")
        }
        if smoothScore < 80 {
            suggestions.append("Relax the hand muscles to make the motion smoother")
        }
        if suggestions.isEmpty {
            suggestions.append("Keep it up, your tremolo technique is very solid!")
        }
        
        return PostureEvaluation(
            overallScore: overallScore,
            aspects: aspects,
            suggestions: suggestions
        )
    }
    
    private func evaluateSequence(pattern: [Int]) -> Double {
        guard pattern.count >= 2 else { return 50 }
        
        // Check whether the sequence is consecutively increasing or decreasing
        var consecutivePairs = 0
        for i in 1..<pattern.count {
            let diff = abs(pattern[i] - pattern[i-1])
            if diff == 1 {
                consecutivePairs += 1
            }
        }
        
        let ratio = Double(consecutivePairs) / Double(pattern.count - 1)
        return min(100, 50 + ratio * 50)
    }
    
    private func evaluateTigerMouthAngle(degrees: Double) -> Double {
        // Continuous scoring of how far the tiger mouth opens (in degrees)
        // Ideal tiger mouth: an angle of about 30°-50° between the thumb and index finger (using the wrist as the reference point)
        let ideal = 40.0
        let diff = abs(degrees - ideal)

        if degrees < 1 {
            // Missing data (recognition failed / fingers not detected) - excluded from scoring
            return 70
        }
        if diff < 10 { return 100 }   // 30-50° perfect
        if diff < 20 { return 85 }    // 20-60° acceptable
        if diff < 30 { return 70 }    // 10-70° off
        return 50                     // Extreme
    }
    
    private func evaluateMovementSmoothness(velocities: [CGVector]) -> Double {
        guard velocities.count > 1 else { return 70 }
        
        // Compute the standard deviation of speed changes (smaller means smoother)
        let speeds = velocities.map { hypot(Double($0.dx), Double($0.dy)) }
        let avgSpeed = speeds.reduce(0, +) / Double(speeds.count)
        let variance = speeds.map { pow($0 - avgSpeed, 2) }.reduce(0, +) / Double(speeds.count)
        let stdDev = sqrt(variance)
        
        // The smaller the standard deviation, the higher the score
        return max(50, 100 - stdDev * 100)
    }
}

/// Sweep posture evaluator
class SweepPostureEvaluator {
    func evaluate(features: HandMotionFeatures) -> PostureEvaluation {
        var aspects: [EvaluationAspect] = []
        
        // 1. Evaluate unity (all fingers move together)
        let speeds = features.fingerVelocities.map { hypot(Double($0.dx), Double($0.dy)) }
        let avgSpeed = speeds.reduce(0, +) / Double(speeds.count)
        let fastFingers = speeds.filter { $0 > avgSpeed * 0.7 }.count
        let unityScore = Double(fastFingers) / Double(speeds.count) * 100
        aspects.append(EvaluationAspect(
            category: .handShape,
            score: unityScore,
            description: unityScore >= 80 ? "Fingers are well coordinated" : "Pay attention to plucking with all fingers at the same time"
        ))
        
        // 2. Evaluate whether the arm leads the motion
        let wristSpeed = hypot(Double(features.wristVelocity.dx), Double(features.wristVelocity.dy))
        let armScore = wristSpeed > 0.3 ? min(100, wristSpeed * 200) : 50
        aspects.append(EvaluationAspect(
            category: .wristPosition,
            score: armScore,
            description: armScore >= 70 ? "The arm leads the motion well" : "The arm should lead, not the fingers alone"
        ))
        
        // 3. Evaluate strength evenness
        let speedVariance = calculateVariance(speeds)
        let uniformityScore = max(50, 100 - speedVariance * 200)
        aspects.append(EvaluationAspect(
            category: .rhythm,
            score: uniformityScore,
            description: uniformityScore >= 80 ? "Strength is even" : "Pay attention to keeping the strength consistent"
        ))
        
        // Compute the overall score
        let overallScore = aspects.map { $0.score }.reduce(0, +) / Double(aspects.count)
        
        // Generate suggestions
        var suggestions: [String] = []
        if unityScore < 80 {
            suggestions.append("Let all fingers touch the strings at the same time")
        }
        if armScore < 70 {
            suggestions.append("Drive the sweep with your arm instead of relying on the fingers alone")
        }
        if uniformityScore < 80 {
            suggestions.append("Keep the sweep strength even")
        }
        if suggestions.isEmpty {
            suggestions.append("Your sweep technique is very solid, keep it up!")
        }
        
        return PostureEvaluation(
            overallScore: overallScore,
            aspects: aspects,
            suggestions: suggestions
        )
    }
    
    private func calculateVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let avg = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - avg, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
}

/// Pluck posture evaluator
class PluckPostureEvaluator {
    func evaluate(features: HandMotionFeatures) -> PostureEvaluation {
        var aspects: [EvaluationAspect] = []
        
        // 1. Evaluate finger independence (only 1-2 fingers should be active)
        let speeds = features.fingerVelocities.map { hypot(Double($0.dx), Double($0.dy)) }
        let activeFingers = speeds.filter { $0 > 0.3 }.count
        let independenceScore = activeFingers <= 2 ? 95 : max(50, 95 - Double(activeFingers - 2) * 15)
        aspects.append(EvaluationAspect(
            category: .handShape,
            score: independenceScore,
            description: independenceScore >= 80 ? "Finger independence is good" : "Pay attention to plucking only with the designated finger"
        ))
        
        // 2. Evaluate plucking strength (speed of the active finger)
        let maxSpeed = speeds.max() ?? 0
        let strengthScore = min(100, maxSpeed * 150)
        aspects.append(EvaluationAspect(
            category: .handShape,
            score: strengthScore,
            description: strengthScore >= 70 ? "Plucking strength is moderate" : strengthScore >= 50 ? "Strength is a bit weak" : "Strength is too weak"
        ))
        
        // 3. Evaluate wrist stability
        let wristSpeed = hypot(Double(features.wristVelocity.dx), Double(features.wristVelocity.dy))
        let stabilityScore = wristSpeed < 0.15 ? 95 : max(50, 95 - wristSpeed * 200)
        aspects.append(EvaluationAspect(
            category: .wristPosition,
            score: stabilityScore,
            description: stabilityScore >= 80 ? "Wrist is stable" : "The wrist is swaying, it should stay stable"
        ))
        
        // 4. Evaluate rhythm stability
        let rhythmScore = evaluateRhythm(frequency: features.movementFrequency)
        aspects.append(EvaluationAspect(
            category: .rhythm,
            score: rhythmScore,
            description: rhythmScore >= 80 ? "Rhythm is stable" : "Pay attention to keeping the rhythm even"
        ))
        
        // Compute the overall score
        let overallScore = aspects.map { $0.score }.reduce(0, +) / Double(aspects.count)
        
        // Generate suggestions
        var suggestions: [String] = []
        if independenceScore < 80 {
            suggestions.append("Focus on using a single finger and keep the other fingers out of it")
        }
        if strengthScore < 70 {
            suggestions.append("Increase the plucking strength, but do not overdo it")
        }
        if stabilityScore < 80 {
            suggestions.append("Keep the wrist stable, the motion should come mainly from the fingers")
        }
        if rhythmScore < 80 {
            suggestions.append("Pluck at a steady speed and keep the sense of rhythm")
        }
        if suggestions.isEmpty {
            suggestions.append("Your pluck technique is very solid, keep it up!")
        }
        
        return PostureEvaluation(
            overallScore: overallScore,
            aspects: aspects,
            suggestions: suggestions
        )
    }
    
    private func evaluateRhythm(frequency: Double) -> Double {
        // Ideal frequency: 2-4 plucks per second
        let idealRange = (0.2...0.4)
        if idealRange.contains(frequency) {
            return 90
        } else if frequency < 0.1 {
            return 60 // Too slow
        } else if frequency > 0.5 {
            return 70 // Too fast
        } else {
            return 80
        }
    }
}
