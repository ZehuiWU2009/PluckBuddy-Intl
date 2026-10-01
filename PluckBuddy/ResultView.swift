//
//  ResultView.swift
//  PluckBuddy
//
//  Created by Zehui Wu on 2026/7/15.
//

import SwiftUI
import Charts
import CoreData

struct ResultView: View {
    @StateObject private var dataManager = PracticeDataManager.shared
    @State private var selectedTab: StatTab = .overview
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PracticeSession.startTime, ascending: false)],
        animation: .default
    )
    private var sessions: FetchedResults<PracticeSession>
    
    enum StatTab: String, CaseIterable {
        case overview = "Overview"
        case history = "History"
        case achievements = "Achievements"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab switcher
            Picker("Statistics", selection: $selectedTab) {
                ForEach(StatTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content area
            ScrollView {
                switch selectedTab {
                case .overview:
                    OverviewSection(dataManager: dataManager)
                case .history:
                    HistorySection(sessions: Array(sessions))
                case .achievements:
                    AchievementsSection(dataManager: dataManager)
                }
            }
        }
        .navigationTitle("My Progress")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            dataManager.updateStatistics()
        }
    }
}

// MARK: - Overview Section
struct OverviewSection: View {
    @ObservedObject var dataManager: PracticeDataManager
    
    var body: some View {
        VStack(spacing: 20) {
            // Overview cards
            HStack(spacing: 16) {
                StatCard(
                    title: "Total Sessions",
                    value: "\(dataManager.totalSessions)",
                    unit: "times",
                    icon: "list.bullet",
                    color: .blue
                )
                
                StatCard(
                    title: "Total Duration",
                    value: formatDuration(dataManager.totalDuration),
                    unit: "",
                    icon: "clock",
                    color: .green
                )
            }
            .padding(.horizontal)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Total Score",
                    value: "\(dataManager.totalScore)",
                    unit: "pts",
                    icon: "star.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "Day Streak",
                    value: "\(dataManager.currentStreak)",
                    unit: "days",
                    icon: "flame.fill",
                    color: .red
                )
            }
            .padding(.horizontal)
            
            // 7-day trend chart
            VStack(alignment: .leading, spacing: 12) {
                Text("Last 7 Days")
                    .font(.headline)
                    .padding(.horizontal)
                
                if #available(iOS 16.0, *) {
                    DailyPracticeChart(stats: dataManager.getDailyStats())
                        .frame(height: 200)
                        .padding()
                } else {
                    Text("Requires iOS 16+ to display the chart")
                        .foregroundStyle(.secondary)
                        .frame(height: 200)
                }
            }
            .padding(.vertical)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8)
            .padding(.horizontal)
        }
        .padding(.top)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h\(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - History Section
struct HistorySection: View {
    let sessions: [PracticeSession]
    
    var body: some View {
        VStack(spacing: 16) {
            if sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    Text("No practice records yet")
                        .foregroundStyle(.secondary)
                    Text("Start your first practice session!")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 100)
            } else {
                ForEach(sessions, id: \.id) { session in
                    SessionRow(session: session)
                }
                .padding(.horizontal)
            }
        }
        .padding(.top)
    }
}

// MARK: - Achievements Section
struct AchievementsSection: View {
    @ObservedObject var dataManager: PracticeDataManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Achievement list
            AchievementCard(
                title: "Beginner",
                description: "Complete your first practice session",
                icon: "🎯",
                isUnlocked: dataManager.totalSessions >= 1,
                progress: min(1.0, Double(dataManager.totalSessions))
            )
            
            AchievementCard(
                title: "Diligent Practitioner",
                description: "Practice 10 times in total",
                icon: "💪",
                isUnlocked: dataManager.totalSessions >= 10,
                progress: min(1.0, Double(dataManager.totalSessions) / 10.0)
            )
            
            AchievementCard(
                title: "Persistent",
                description: "Practice 7 days in a row",
                icon: "🔥",
                isUnlocked: dataManager.currentStreak >= 7,
                progress: min(1.0, Double(dataManager.currentStreak) / 7.0)
            )
            
            AchievementCard(
                title: "Time Master",
                description: "Practice for 1 hour in total",
                icon: "⏰",
                isUnlocked: dataManager.totalDuration >= 3600,
                progress: min(1.0, dataManager.totalDuration / 3600.0)
            )
            
            AchievementCard(
                title: "High Scorer",
                description: "Reach 1,000 total points",
                icon: "⭐",
                isUnlocked: dataManager.totalScore >= 1000,
                progress: min(1.0, Double(dataManager.totalScore) / 1000.0)
            )
            
            AchievementCard(
                title: "All-Rounder",
                description: "Try every practice mode",
                icon: "🏆",
                isUnlocked: checkAllModes(),
                progress: Double(getUniqueModes()) / 4.0
            )
        }
        .padding()
    }
    
    private func checkAllModes() -> Bool {
        return getUniqueModes() >= 4
    }
    
    private func getUniqueModes() -> Int {
        let sessions = dataManager.fetchAllSessions()
        let types = Set(sessions.map { $0.sessionType })
        return types.count
    }
}

// MARK: - Components

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title.bold())
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
}

struct SessionRow: View {
    let session: PracticeSession
    
    var body: some View {
        HStack(spacing: 12) {
            Text(session.icon)
                .font(.title)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(session.typeName)
                    .font(.headline)
                Text(session.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(session.score) pts")
                    .font(.subheadline.bold())
                    .foregroundStyle(.blue)
                Text(session.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
}

struct AchievementCard: View {
    let title: String
    let description: String
    let icon: String
    let isUnlocked: Bool
    let progress: Double
    
    var body: some View {
        HStack(spacing: 16) {
            Text(icon)
                .font(.system(size: 40))
                .grayscale(isUnlocked ? 0 : 1)
                .opacity(isUnlocked ? 1 : 0.3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(isUnlocked ? .primary : .secondary)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if !isUnlocked {
                    ProgressView(value: progress)
                        .tint(.blue)
                }
            }
            
            Spacer()
            
            if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
}

// MARK: - Daily Practice Chart
@available(iOS 16.0, *)
struct DailyPracticeChart: View {
    let stats: [DailyStats]
    
    var body: some View {
        Chart {
            ForEach(stats) { stat in
                BarMark(
                    x: .value("Date", stat.weekday),
                    y: .value("Duration", stat.totalDuration / 60)
                )
                .foregroundStyle(.blue.gradient)
                .annotation(position: .top) {
                    if stat.sessionCount > 0 {
                        Text("\(Int(stat.totalDuration / 60))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let minutes = value.as(Double.self) {
                        Text("\(Int(minutes))m")
                            .font(.caption2)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ResultView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

