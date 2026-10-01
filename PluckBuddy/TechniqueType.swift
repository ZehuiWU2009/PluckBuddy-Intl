//
//  TechniqueType.swift
//  PluckBuddy
//
//  Created by Zehui Wu on 2026/7/29.
//

import Foundation
import SwiftUI

/// Pipa technique types
enum TechniqueType: String, CaseIterable {
    case roll = "Tremolo"
    case sweep = "Sweep"
    case pluck = "Pluck"
    case unknown = "Unrecognized"
    
    /// Icon
    var icon: String {
        switch self {
        case .roll: return "hand.tap.fill"
        case .sweep: return "waveform.path"
        case .pluck: return "hand.point.up.left.fill"
        case .unknown: return "questionmark.circle"
        }
    }
    
    /// Theme color
    var color: Color {
        switch self {
        case .roll: return .pink
        case .sweep: return .blue
        case .pluck: return .green
        case .unknown: return .gray
        }
    }
    
    /// Description
    var description: String {
        switch self {
        case .roll: return "Fast consecutive finger plucking"
        case .sweep: return "Arm-driven sweeping motion"
        case .pluck: return "Basic alternating pluck technique"
        case .unknown: return "Waiting for detection..."
        }
    }
}
