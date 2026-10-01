//
//  HomeView.swift
//  PluckBuddy
//
//  Created by Zehui Wu on 2026/7/15.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Brand title pinned at the top, does not scroll with the feature list
                brandHeader
                
                Divider()
                
                // Feature list
                ScrollView {
                    VStack(spacing: 16) {
                        // Smart Tuner
                        NavigationLink {
                            TunerView()
                        } label: {
                            FeatureCard(
                                icon: "🎵",
                                title: "Smart Tuner",
                                subtitle: "Your assistant for tuning the four strings of the pipa",
                                color: .blue
                            )
                        }
                        
                        // Pluck Run
                        NavigationLink {
                            RunningPracticeView()
                        } label: {
                            FeatureCard(
                                icon: "🏃",
                                title: "Pluck Run",
                                subtitle: "Turn rhythm practice into a running game",
                                color: .green
                            )
                        }
                        
                        // Tremolo Bloom
                        NavigationLink {
                            FlowerPracticeView()
                        } label: {
                            FeatureCard(
                                icon: "🌸",
                                title: "Tremolo Bloom",
                                subtitle: "Watch flowers bloom as you practice tremolo",
                                color: .pink
                            )
                        }
                        
                        // Sweep Wave
                        NavigationLink {
                            WavePracticeView()
                        } label: {
                            FeatureCard(
                                icon: "🌊",
                                title: "Sweep Wave",
                                subtitle: "Visualize the power of your sweep",
                                color: .cyan
                            )
                        }
                        
                        // Smart Fingering Coach (new)
                        NavigationLink {
                            TechniqueCoachView()
                        } label: {
                            FeatureCard(
                                icon: "🎥",
                                title: "Smart Fingering Coach",
                                subtitle: "AI analyzes your playing posture in real time",
                                color: .purple
                            )
                        }
                        
                        // My Progress
                        NavigationLink {
                            ResultView()
                        } label: {
                            FeatureCard(
                                icon: "🏆",
                                title: "My Progress",
                                subtitle: "Review practice history and progress",
                                color: .orange
                            )
                        }
                        
                        // Social Hub (new)
                        NavigationLink {
                            SocialSquareView()
                        } label: {
                            FeatureCard(
                                icon: "👥",
                                title: "Social Hub",
                                subtitle: "Leaderboard · Achievements · Friend PK\n(Offline)",
                                color: .purple
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
            }
            .background(Color(.systemGroupedBackground))
            // The home page keeps only the seven feature modules, and the top navigation bar is hidden entirely;
            // once pushed, each child page provides its own navigationTitle, so the back button is unaffected
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    
    // MARK: - Top brand title
    
    /// Pinned above the list, does not scroll with the ScrollView
    private var brandHeader: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.55, green: 0.36, blue: 0.90), Color(red: 0.23, green: 0.51, blue: 0.96)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4, height: 26)
            
            Text("PluckBuddy")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.primary)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color(.systemBackground))
    }
}

// MARK: - Feature Card Component
struct FeatureCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Text(icon)
                .font(.system(size: 40))
                .frame(width: 60, height: 60)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    // Leading alignment is set explicitly: the text wraps when the card leaves it too little width,
                    // without locking it in place, multi-line text falls back to centered
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .font(.body.weight(.semibold))
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    HomeView()
}
