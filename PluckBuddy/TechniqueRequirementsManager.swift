//
//  TechniqueRequirementsManager.swift
//  PluckBuddy
//
//  Created by Wu Zehui on 2026/7/29.
//

import Foundation

/// Technique requirements manager - provides the core requirement content for each technique
class TechniqueRequirementsManager {
    
    // MARK: - Core requirement content library
    
    /// Gets the core requirement list for the specified technique
    static func getRequirements(for technique: TechniqueType) -> [String] {
        switch technique {
        case .roll:
            return [
                "✅ Keep the wrist relaxed, do not lift it too much",
                "✅ The four fingers (index, middle, ring, little) pluck out quickly in order",
                "✅ Each finger moves independently, avoid dragging the others along",
                "✅ A string contact angle of 45-60 degrees is ideal",
                "✅ Keep a constant speed, a stable rhythm matters most",
                "✅ Let the fingers curve naturally, do not stiffen them",
                "✅ Practice step by step, from slow to fast",
                "✅ Keep the volume balanced, avoid any finger being too light or too heavy"
            ]
            
        case .sweep:
            return [
                "✅ Let the arm lead and generate power as a whole, not just the wrist",
                "✅ Keep the motion smooth and continuous, done in one fluid gesture",
                "✅ The sweep path should be an arc, not a stiff straight line",
                "✅ Keep the string contact depth moderate, neither too deep nor too shallow",
                "✅ Keep the strength consistent on both up and down strokes",
                "✅ Relax the shoulders, avoid shrugging",
                "✅ Coordinate your breathing with the motion for a natural rhythm",
                "✅ Multiple fingers touch the strings at the same time for a full sound"
            ]
            
        case .pluck:
            return [
                "✅ The first finger joint actively generates the power",
                "✅ Leave the string quickly after contact, the motion should be clean and crisp",
                "✅ Keep a constant rhythm when alternating between pluck and pick",
                "✅ Let the wrist swing naturally in coordination, the range should not be too large",
                "✅ Thumb pluck: pluck outward, the power comes from the first joint",
                "✅ Index finger pick: hook the string inward, the power point is at the fingertip",
                "✅ Keep the shoulder, arm and wrist relaxed, concentrate the power at the fingertip",
                "✅ Aim for a clear, bright tone and avoid muffled sound"
            ]
            
        case .unknown:
            return [
                "💡 Please start playing, the system will automatically recognize your practice technique",
                "💡 Make sure the lighting is sufficient and your hand is clearly visible",
                "💡 It is recommended to place the camera at a 45° angle to the front-side"
            ]
        }
    }
    
    /// Gets the complete scrolling text (for the scrolling marquee)
    /// - Parameter technique: Technique type
    /// - Returns: The complete concatenated text (with separators)
    static func getScrollingText(for technique: TechniqueType) -> String {
        let requirements = getRequirements(for: technique)
        let separator = "  •  "
        
        // Concatenate all requirements and append a separator at the end to enable looping
        return requirements.joined(separator: separator) + separator
    }
    
    /// Gets the requirement at the specified index (for carousel mode)
    /// - Parameters:
    ///   - index: Requirement index
    ///   - technique: Technique type
    /// - Returns: A single requirement text
    static func getRequirement(at index: Int, for technique: TechniqueType) -> String? {
        let requirements = getRequirements(for: technique)
        guard index >= 0 && index < requirements.count else {
            return nil
        }
        return requirements[index]
    }
    
    /// Gets the total number of requirements
    static func getRequirementsCount(for technique: TechniqueType) -> Int {
        return getRequirements(for: technique).count
    }
}

// MARK: - Extension: smart recommendations (optional)

extension TechniqueRequirementsManager {
    
    /// Sorts the requirements intelligently based on evaluation results (to be implemented)
    /// Prioritizes the aspects the user needs to improve
    static func getPrioritizedRequirements(
        for technique: TechniqueType,
        weakAspects: [String] = []
    ) -> [String] {
        // TODO: Adjust the order based on weak aspects
        // Currently returns the default order
        return getRequirements(for: technique)
    }
}
