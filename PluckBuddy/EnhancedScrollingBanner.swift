//
//  EnhancedScrollingBanner.swift
//  PluckBuddy
//
//  Created by Zehui Wu on 2026/7/29.
//

import SwiftUI

/// Enhanced scrolling banner - card carousel mode (alternative option)
struct EnhancedScrollingBanner: View {
    let technique: TechniqueType
    
    @State private var currentIndex = 0
    @State private var offset: CGFloat = 0
    @State private var timer: Timer?
    
    private let switchInterval: TimeInterval = 4.0 // Switch every 4 seconds
    
    private var requirements: [String] {
        TechniqueRequirementsManager.getRequirements(for: technique)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Title bar
            HStack {
                Image(systemName: technique.icon)
                    .foregroundStyle(technique.color)
                    .font(.title3)
                
                Text("\(technique.rawValue) Key Requirements")
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Progress indicator
                Text("\(currentIndex + 1)/\(requirements.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Scrolling content area
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(requirements.indices, id: \.self) { index in
                        RequirementCard(
                            text: requirements[index],
                            color: technique.color
                        )
                        .frame(width: geometry.size.width)
                    }
                }
                .offset(x: offset)
            }
            .frame(height: 60)
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
        .onAppear {
            startAutoScroll()
        }
        .onDisappear {
            stopAutoScroll()
        }
        .onChange(of: technique) { _, _ in
            resetScroll()
        }
    }
    
    // MARK: - Auto Scroll Control
    
    private func startAutoScroll() {
        timer = Timer.scheduledTimer(withTimeInterval: switchInterval, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                scrollToNext()
            }
        }
        
        print("📋 Starting requirement carousel: \(technique.rawValue)")
    }
    
    private func stopAutoScroll() {
        timer?.invalidate()
        timer = nil
    }
    
    private func resetScroll() {
        stopAutoScroll()
        currentIndex = 0
        offset = 0
        startAutoScroll()
        
        print("🔄 Reset requirement carousel: \(technique.rawValue)")
    }
    
    private func scrollToNext() {
        currentIndex = (currentIndex + 1) % requirements.count
        offset = -CGFloat(currentIndex) * UIScreen.main.bounds.width
    }
}

// MARK: - Requirement Card

struct RequirementCard: View {
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(color)
                .font(.title2)
            
            // Text
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        EnhancedScrollingBanner(technique: .roll)
            .padding()
        
        EnhancedScrollingBanner(technique: .sweep)
            .padding()
        
        EnhancedScrollingBanner(technique: .pluck)
            .padding()
    }
    .background(Color.black)
}
