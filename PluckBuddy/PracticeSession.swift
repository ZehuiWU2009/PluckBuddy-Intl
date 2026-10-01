//
//  PracticeSession.swift
//  PluckBuddy
//
//  Created by Zehui Wu on 2026/7/16.
//

import Foundation
import CoreData

/// Practice session data model
@objc(PracticeSession)
public class PracticeSession: NSManagedObject {
    
    @NSManaged public var id: UUID
    @NSManaged public var sessionType: String // "tuner", "running", "flower", "wave"
    @NSManaged public var startTime: Date
    @NSManaged public var endTime: Date
    @NSManaged public var duration: Double // seconds
    
    // Common stats
    @NSManaged public var score: Int32
    @NSManaged public var notes: String? // Notes
    
    // Tuner-specific
    @NSManaged public var tuningAccuracy: Double // Average pitch accuracy
    @NSManaged public var tuningCount: Int32 // Number of tunings
    
    // Pluck Run-specific
    @NSManaged public var pluckCount: Int32 // Number of plucks
    @NSManaged public var averageBPM: Double // Average speed
    @NSManaged public var stability: Double // Rhythm stability
    @NSManaged public var distance: Double // Running distance (meters)
    
    // Tremolo Bloom-specific
    @NSManaged public var rollCount: Int32 // Number of tremolo strokes
    @NSManaged public var rollSpeed: Double // Average speed
    
    // Sweep Wave-specific
    @NSManaged public var sweepCount: Int32 // Number of sweeps
    @NSManaged public var averageStrength: Double // Average strength
}

extension PracticeSession {
    
    /// Session type name
    var typeName: String {
        switch sessionType {
        case "tuner": return "Smart Tuner"
        case "running": return "Pluck Run"
        case "flower": return "Tremolo Bloom"
        case "wave": return "Sweep Wave"
        default: return "Unknown"
        }
    }
    
    /// Session icon
    var icon: String {
        switch sessionType {
        case "tuner": return "🎵"
        case "running": return "🏃"
        case "flower": return "🌸"
        case "wave": return "🌊"
        default: return "📝"
        }
    }
    
    /// Formatted duration
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
    
    /// Formatted date
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: startTime)
    }
}

// MARK: - Fetch Request
extension PracticeSession {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PracticeSession> {
        return NSFetchRequest<PracticeSession>(entityName: "PracticeSession")
    }
    
    /// Fetch all sessions, sorted by time descending
    static func allSessionsRequest() -> NSFetchRequest<PracticeSession> {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PracticeSession.startTime, ascending: false)]
        return request
    }
    
    /// Fetch sessions of a specific type
    static func sessionsRequest(type: String) -> NSFetchRequest<PracticeSession> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "sessionType == %@", type)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PracticeSession.startTime, ascending: false)]
        return request
    }
    
    /// Fetch sessions from the last N days
    static func recentSessionsRequest(days: Int) -> NSFetchRequest<PracticeSession> {
        let request = fetchRequest()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        request.predicate = NSPredicate(format: "startTime >= %@", startDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PracticeSession.startTime, ascending: false)]
        return request
    }
}
