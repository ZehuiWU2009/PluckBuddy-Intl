//
//  RankingListView.swift
//  PluckBuddy
//
//  Created on 2026-09-08.
//  Leaderboard view
//

import SwiftUI

struct RankingListView: View {
    @State private var selectedMode: PracticeMode = .running
    
    var body: some View {
        VStack(spacing: 0) {
            // Mode picker
            modePicker
            
            // Offline notice banner
            offlineBanner
            
            // Leaderboard list
            ScrollView {
                VStack(spacing: 12) {
                    // Highlighted top three
                    topThreeSection
                    
                    // Other ranks
                    ForEach(4...10, id: \.self) { rank in
                        RankingRow(
                            rank: rank,
                            player: MockData.getPlayer(for: rank, mode: selectedMode),
                            isCurrentUser: rank == 7
                        )
                    }
                }
                .padding()
            }
        }
    }
    
    private var modePicker: some View {
        Picker("Practice Mode", selection: $selectedMode) {
            Text("Pluck Run").tag(PracticeMode.running)
            Text("Tremolo Bloom").tag(PracticeMode.flower)
            Text("Sweep Wave").tag(PracticeMode.wave)
        }
        .pickerStyle(.segmented)
        .padding()
    }
    
    private var offlineBanner: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundColor(.orange)
            Text("Offline mock data · Demo only")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
    }
    
    private var topThreeSection: some View {
        HStack(alignment: .bottom, spacing: 16) {
            // 2nd place
            TopPlayerCard(rank: 2, player: MockData.getPlayer(for: 2, mode: selectedMode))
            
            // 1st place (highlighted)
            TopPlayerCard(rank: 1, player: MockData.getPlayer(for: 1, mode: selectedMode))
                .padding(.bottom, 20)
            
            // 3rd place
            TopPlayerCard(rank: 3, player: MockData.getPlayer(for: 3, mode: selectedMode))
        }
        .padding(.vertical)
    }
}

// MARK: - Top Three Card
struct TopPlayerCard: View {
    let rank: Int
    let player: RankingPlayer
    
    var medalColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .clear
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Medal
            ZStack {
                Circle()
                    .fill(medalColor.gradient)
                    .frame(width: rank == 1 ? 60 : 50, height: rank == 1 ? 60 : 50)
                
                Image(systemName: "crown.fill")
                    .foregroundColor(.white)
                    .font(.system(size: rank == 1 ? 24 : 20))
            }
            
            // Rank number
            Text("\(rank)")
                .font(.system(size: rank == 1 ? 20 : 16, weight: .bold))
                .foregroundColor(medalColor)
            
            // Avatar
            Circle()
                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: rank == 1 ? 70 : 60, height: rank == 1 ? 70 : 60)
                .overlay(
                    Text(String(player.name.prefix(1)))
                        .font(.system(size: rank == 1 ? 28 : 24, weight: .bold))
                        .foregroundColor(.white)
                )
            
            // Name
            Text(player.name)
                .font(.system(size: rank == 1 ? 16 : 14, weight: .semibold))
                .lineLimit(1)
            
            // Score
            Text("\(player.score)")
                .font(.system(size: rank == 1 ? 24 : 20, weight: .bold))
                .foregroundColor(.blue)
            
            Text("pts")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: medalColor.opacity(0.3), radius: rank == 1 ? 10 : 5)
        )
    }
}

// MARK: - Ranking Row
struct RankingRow: View {
    let rank: Int
    let player: RankingPlayer
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            Text("\(rank)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(isCurrentUser ? .blue : .secondary)
                .frame(width: 30)
            
            // Avatar
            Circle()
                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(player.name.prefix(1)))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                )
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(player.name)
                        .font(.system(size: 16, weight: .semibold))
                    
                    if isCurrentUser {
                        Text("(Me)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Text("\(player.practiceCount) sessions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Score
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(player.score)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.blue)
                Text("pts")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrentUser ? Color.blue.opacity(0.05) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrentUser ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Preview
struct RankingListView_Previews: PreviewProvider {
    static var previews: some View {
        RankingListView()
    }
}
