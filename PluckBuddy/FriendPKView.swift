//
//  FriendPKView.swift
//  PluckBuddy
//
//  Created on 2026-09-08.
//  Friend PK view
//

import SwiftUI
import AVKit

struct FriendPKView: View {
    @State private var friends = MockData.friends
    @State private var selectedFriend: Friend?
    @State private var showVideoDetail = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Info banner
                infoBanner
                
                // Friend list
                ForEach(friends) { friend in
                    FriendPKCard(friend: friend) {
                        selectedFriend = friend
                        showVideoDetail = true
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showVideoDetail) {
            if let friend = selectedFriend {
                FriendVideoDetailView(friend: friend)
            }
        }
    }
    
    private var infoBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("How Friend PK Works")
                    .font(.headline)
            }
            
            Text("Friends can upload practice videos and compete with you on technique. Tap a card to watch a friend's practice video and compare stats.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
        )
    }
}

// MARK: - Friend PK Card
struct FriendPKCard: View {
    let friend: Friend
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Header info
                HStack(spacing: 12) {
                    // Friend avatar
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(String(friend.name.prefix(1)))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(friend.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "video.fill")
                                .font(.caption)
                            Text(friend.videoTitle)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                
                Divider()
                
                // Data comparison
                HStack(spacing: 0) {
                    statColumn(title: "Score", value: "\(friend.score)", color: .blue)
                    
                    Divider()
                        .frame(height: 50)
                    
                    statColumn(title: "Speed", value: "\(friend.speed) BPM", color: .orange)
                    
                    Divider()
                        .frame(height: 50)
                    
                    statColumn(title: "Stability", value: "\(friend.stability)%", color: .green)
                }
                .padding(.vertical, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 5)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func statColumn(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Friend Video Detail View
struct FriendVideoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let friend: Friend
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Video placeholder (a real project would play an actual video here)
                    videoPlaceholder
                    
                    // Friend info
                    friendInfoSection
                    
                    // Data comparison
                    comparisonSection
                    
                    // Comment section placeholder
                    commentSection
                }
                .padding()
            }
            .navigationTitle("Friend Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var videoPlaceholder: some View {
        ZStack {
            Rectangle()
                .fill(Color.black)
                .aspectRatio(16/9, contentMode: .fit)
                .cornerRadius(12)
            
            VStack(spacing: 12) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                
                Text("Tap to play video")
                    .font(.caption)
                    .foregroundColor(.white)
                
                Text("(Not supported in offline mode)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    private var friendInfoSection: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(friend.name.prefix(1)))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.name)
                    .font(.headline)
                
                Text(friend.videoTitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Uploaded 3 days ago")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Comparison")
                .font(.headline)
            
            VStack(spacing: 12) {
                comparisonRow(title: "Score", myValue: "1850", friendValue: "\(friend.score)", unit: "pts")
                comparisonRow(title: "Speed", myValue: "115", friendValue: "\(friend.speed)", unit: "BPM")
                comparisonRow(title: "Stability", myValue: "82", friendValue: "\(friend.stability)", unit: "%")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
    }
    
    private func comparisonRow(title: String, myValue: String, friendValue: String, unit: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Me")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(myValue) \(unit)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            Text("vs")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(friendValue) \(unit)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.purple)
            }
        }
    }
    
    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comments")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(0..<3) { index in
                    commentRow(username: "User \(index + 1)", comment: "Beautiful playing! I can learn from you 🎵")
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            
            Text("Comments are available in the online version")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
    
    private func commentRow(username: String, comment: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 30, height: 30)
                .overlay(
                    Text(String(username.prefix(1)))
                        .font(.caption)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(username)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text(comment)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview
struct FriendPKView_Previews: PreviewProvider {
    static var previews: some View {
        FriendPKView()
    }
}
