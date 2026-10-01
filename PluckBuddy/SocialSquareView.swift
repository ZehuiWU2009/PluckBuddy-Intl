//
//  SocialSquareView.swift
//  PluckBuddy
//
//  Created on 2026-09-08.
//  Social Hub - offline mock version
//

import SwiftUI

struct SocialSquareView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top tab switcher
                topTabBar
                
                // Content area
                TabView(selection: $selectedTab) {
                    RankingListView()
                        .tag(0)
                    
                    AchievementView()
                        .tag(1)
                    
                    FriendPKView()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Social Hub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .imageScale(.large)
                    }
                }
            }
        }
    }
    
    private var topTabBar: some View {
        HStack(spacing: 0) {
            TabButton(title: "Leaderboard", icon: "trophy.fill", isSelected: selectedTab == 0) {
                withAnimation { selectedTab = 0 }
            }
            
            TabButton(title: "Achievements", icon: "star.fill", isSelected: selectedTab == 1) {
                withAnimation { selectedTab = 1 }
            }
            
            TabButton(title: "Friend PK", icon: "person.2.fill", isSelected: selectedTab == 2) {
                withAnimation { selectedTab = 2 }
            }
        }
        .padding(.top, 8)
        .background(Color(.systemBackground))
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundColor(isSelected ? .blue : .gray)
            .background(
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(isSelected ? Color.blue : Color.clear)
                        .frame(height: 3)
                }
            )
        }
    }
}

// MARK: - Preview
struct SocialSquareView_Previews: PreviewProvider {
    static var previews: some View {
        SocialSquareView()
    }
}
