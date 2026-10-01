//
//  MainMenuExample.swift
//  PluckBuddy
//
//  Created on 2026-09-08.
//  Main menu integration example - shows how to add the Social Hub entry point
//

import SwiftUI

// This is a sample file showing how to integrate the Social Hub module into the main menu
// Adjust it to match your actual main menu structure

struct MainMenuExample: View {
    @State private var showSocialSquare = false
    @State private var showFlowerPractice = false
    @State private var showRunningPractice = false
    @State private var showWavePractice = false
    @State private var showTuner = false
    @State private var showTechniqueCoach = false
    @State private var showMyResults = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // App title
                    headerSection
                    
                    // Feature grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        // Smart Tuner
                        MenuCard(
                            icon: "tuningfork",
                            title: "Smart Tuner",
                            color: .blue,
                            action: { showTuner = true }
                        )
                        
                        // Pluck Run
                        MenuCard(
                            icon: "figure.run",
                            title: "Pluck Run",
                            color: .green,
                            action: { showRunningPractice = true }
                        )
                        
                        // Tremolo Bloom
                        MenuCard(
                            icon: "leaf.fill",
                            title: "Tremolo Bloom",
                            color: .pink,
                            action: { showFlowerPractice = true }
                        )
                        
                        // Sweep Wave
                        MenuCard(
                            icon: "waveform.path",
                            title: "Sweep Wave",
                            color: .cyan,
                            action: { showWavePractice = true }
                        )
                        
                        // Smart Fingering Coach
                        MenuCard(
                            icon: "video.fill",
                            title: "Smart Fingering Coach",
                            color: .orange,
                            action: { showTechniqueCoach = true }
                        )
                        
                        // My Progress
                        MenuCard(
                            icon: "chart.bar.fill",
                            title: "My Progress",
                            color: .indigo,
                            action: { showMyResults = true }
                        )
                    }
                    
                    // Social Hub - featured wide card
                    socialSquareSection
                }
                .padding()
            }
            .navigationTitle("PluckBuddy")
            .background(Color(.systemGroupedBackground))
            
            // Full-screen cover
            .fullScreenCover(isPresented: $showSocialSquare) {
                SocialSquareView()
            }
            .fullScreenCover(isPresented: $showFlowerPractice) {
                FlowerPracticeView()
            }
            .fullScreenCover(isPresented: $showRunningPractice) {
                RunningPracticeView()
            }
            // ... fullScreenCover for the other views
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.system(size: 50))
                .foregroundStyle(.blue.gradient)
            
            Text("PluckBuddy")
                .font(.system(size: 32, weight: .bold))
            
            Text("Smart Pipa Practice Companion")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical)
    }
    
    private var socialSquareSection: some View {
        Button(action: { showSocialSquare = true }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                
                // Text info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Social Hub")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Text("NEW")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red))
                    }
                    
                    Text("Leaderboard · Achievements · Friend PK")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "wifi.slash")
                            .font(.caption2)
                        Text("Offline demo version")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.title3)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .purple.opacity(0.2), radius: 10, x: 0, y: 5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Menu Card Component
struct MenuCard: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.gradient)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
struct MainMenuExample_Previews: PreviewProvider {
    static var previews: some View {
        MainMenuExample()
    }
}
