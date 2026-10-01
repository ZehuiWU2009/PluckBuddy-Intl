//
//  SocialModels.swift
//  PluckBuddy
//
//  Created on 2026-09-08.
//  Social module data models
//

import SwiftUI

// MARK: - Practice Mode
enum PracticeMode {
    case running  // Pluck Run
    case flower   // Tremolo Bloom
    case wave     // Sweep Wave
    
    var name: String {
        switch self {
        case .running: return "Pluck Run"
        case .flower: return "Tremolo Bloom"
        case .wave: return "Sweep Wave"
        }
    }
}

// MARK: - Leaderboard Player
struct RankingPlayer: Identifiable {
    let id = UUID()
    let name: String
    let score: Int
    let practiceCount: Int
    let mode: PracticeMode
}

// MARK: - Achievement Category
enum AchievementCategory: CaseIterable, Hashable {
    case beginner    // Beginner
    case practice    // Practice
    case skill       // Skill
    case persistence // Persistence
    
    var title: String {
        switch self {
        case .beginner: return "Getting Started"
        case .practice: return "Diligent Practice"
        case .skill: return "Mastered Skills"
        case .persistence: return "Persistence"
        }
    }
    
    var icon: String {
        switch self {
        case .beginner: return "star.fill"
        case .practice: return "flame.fill"
        case .skill: return "crown.fill"
        case .persistence: return "calendar.badge.clock"
        }
    }
    
    var color: Color {
        switch self {
        case .beginner: return .green
        case .practice: return .orange
        case .skill: return .purple
        case .persistence: return .blue
        }
    }
}

// MARK: - Achievement
struct Achievement: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let category: AchievementCategory
    let unlocked: Bool
    let progress: Double  // 0.0 - 1.0
}

// MARK: - Friend
struct Friend: Identifiable {
    let id = UUID()
    let name: String
    let videoTitle: String
    let score: Int
    let speed: Int
    let stability: Int
    let thumbnailName: String?  // Reserved video thumbnail
}

// MARK: - Mock Data
struct MockData {
    // Player name pool
    private static let names = [
        "Pipa Master", "Music Star", "Rhythm Ace", "Practice Pro", "Plucking Pro",
        "Tremolo King", "King of Speed", "Steady Master", "Busy Little Bee", "Young Prodigy"
    ]
    
    // Generate player data from rank and mode
    static func getPlayer(for rank: Int, mode: PracticeMode) -> RankingPlayer {
        let baseScore: Int
        switch mode {
        case .running:
            baseScore = 5000 - (rank - 1) * 300
        case .flower:
            baseScore = 4500 - (rank - 1) * 280
        case .wave:
            baseScore = 4000 - (rank - 1) * 250
        }
        
        let name = rank <= names.count ? names[rank - 1] : "Player \(rank)"
        let practiceCount = 100 - (rank - 1) * 5
        
        return RankingPlayer(
            name: name,
            score: baseScore,
            practiceCount: practiceCount,
            mode: mode
        )
    }
    
    // Achievement data
    static let achievements: [Achievement] = [
        // Getting Started
        Achievement(
            title: "First Attempt",
            description: "Complete your first practice session",
            icon: "hand.wave.fill",
            category: .beginner,
            unlocked: true,
            progress: 1.0
        ),
        Achievement(
            title: "Getting the Hang of It",
            description: "Complete 10 practice sessions",
            icon: "star.circle.fill",
            category: .beginner,
            unlocked: true,
            progress: 1.0
        ),
        Achievement(
            title: "Practice Makes Perfect",
            description: "Complete 50 practice sessions",
            icon: "sparkles",
            category: .beginner,
            unlocked: false,
            progress: 0.6
        ),
        Achievement(
            title: "Forged Through Practice",
            description: "Complete 100 practice sessions",
            icon: "flame.circle.fill",
            category: .beginner,
            unlocked: false,
            progress: 0.3
        ),
        
        // Diligent Practice
        Achievement(
            title: "Star of Diligence",
            description: "Practice 7 days in a row",
            icon: "calendar.badge.plus",
            category: .practice,
            unlocked: true,
            progress: 1.0
        ),
        Achievement(
            title: "Never Give Up",
            description: "Practice 30 days in a row",
            icon: "calendar.badge.checkmark",
            category: .practice,
            unlocked: false,
            progress: 0.4
        ),
        Achievement(
            title: "Marathon Player",
            description: "Practice for 30 minutes in one session",
            icon: "figure.run",
            category: .practice,
            unlocked: false,
            progress: 0.7
        ),
        Achievement(
            title: "Time Management Master",
            description: "Practice for 10 hours in total",
            icon: "clock.badge.checkmark",
            category: .practice,
            unlocked: false,
            progress: 0.45
        ),
        
        // Mastered Skills
        Achievement(
            title: "Steady Expert",
            description: "Reach 90% stability",
            icon: "waveform.path.ecg",
            category: .skill,
            unlocked: true,
            progress: 1.0
        ),
        Achievement(
            title: "King of Speed",
            description: "Reach 150 BPM",
            icon: "gauge.badge.plus",
            category: .skill,
            unlocked: false,
            progress: 0.8
        ),
        Achievement(
            title: "Perfect Tremolo",
            description: "Reach 95% tremolo evenness",
            icon: "circle.grid.cross.fill",
            category: .skill,
            unlocked: false,
            progress: 0.55
        ),
        Achievement(
            title: "Outstanding Skill",
            description: "Score over 3000 in one session",
            icon: "trophy.circle.fill",
            category: .skill,
            unlocked: false,
            progress: 0.65
        ),
        
        // Persistence
        Achievement(
            title: "Early Bird",
            description: "Practice before 6 a.m.",
            icon: "sunrise.fill",
            category: .persistence,
            unlocked: true,
            progress: 1.0
        ),
        Achievement(
            title: "Night Owl",
            description: "Practice after 10 p.m.",
            icon: "moon.stars.fill",
            category: .persistence,
            unlocked: true,
            progress: 1.0
        ),
        Achievement(
            title: "All-Rounder",
            description: "Practice all three modes",
            icon: "square.grid.3x3.fill",
            category: .persistence,
            unlocked: false,
            progress: 0.67
        ),
        Achievement(
            title: "Social Butterfly",
            description: "Add 5 friends",
            icon: "person.3.fill",
            category: .persistence,
            unlocked: false,
            progress: 0.4
        ),
    ]
    
    // Friend data
    static let friends: [Friend] = [
        Friend(
            name: "Xiaoming Li",
            videoTitle: "Tremolo Practice - 100 BPM Challenge",
            score: 2350,
            speed: 105,
            stability: 88,
            thumbnailName: nil
        ),
        Friend(
            name: "Xiaofang Wang",
            videoTitle: "Pluck Speed Training Log",
            score: 2150,
            speed: 120,
            stability: 85,
            thumbnailName: nil
        ),
        Friend(
            name: "Wei Zhang",
            videoTitle: "Sweep Wave - Beginner to Intermediate",
            score: 1950,
            speed: 95,
            stability: 90,
            thumbnailName: nil
        ),
        Friend(
            name: "Siyu Liu",
            videoTitle: "Tremolo Bloom - Improving Stability",
            score: 2280,
            speed: 110,
            stability: 92,
            thumbnailName: nil
        ),
        Friend(
            name: "Haoran Chen",
            videoTitle: "Pluck Run - Speed Breakthrough",
            score: 2420,
            speed: 125,
            stability: 87,
            thumbnailName: nil
        )
    ]
}
