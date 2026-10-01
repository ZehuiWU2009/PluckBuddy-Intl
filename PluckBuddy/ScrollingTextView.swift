//
//  ScrollingTextView.swift
//  PluckBuddy
//
//  Created by Zehui Wu on 2026/7/29.
//

import SwiftUI

/// Scrolling text view - displays the key requirements of a technique
struct ScrollingTextView: View {
    let text: String
    let technique: TechniqueType
    
    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    
    // MARK: - Configuration
    private let scrollSpeed: Double = 50 // points per second
    private let padding: CGFloat = 12
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                backgroundColor
                
                // Scrolling text
                Text(text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(
                        GeometryReader { textGeometry in
                            Color.clear
                                .onAppear {
                                    textWidth = textGeometry.size.width
                                }
                                .onChange(of: text) { _, _ in
                                    // Recalculate the width when the text changes
                                    textWidth = textGeometry.size.width
                                }
                        }
                    )
                    .offset(x: offset)
                    .onAppear {
                        startScrolling(containerWidth: geometry.size.width)
                    }
                    .onChange(of: technique) { _, _ in
                        // Restart the animation when the technique changes
                        resetScrolling(containerWidth: geometry.size.width)
                    }
            }
        }
        .frame(height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
    }
    
    // MARK: - Background Color
    private var backgroundColor: some View {
        technique.color
            .opacity(0.25)
            .overlay(
                LinearGradient(
                    colors: [
                        .white.opacity(0.1),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
    
    // MARK: - Scrolling Animation
    
    /// Start the scrolling animation
    private func startScrolling(containerWidth: CGFloat) {
        // Enter from the right
        offset = containerWidth
        
        // Compute the scroll duration
        let totalDistance = containerWidth + textWidth
        let duration = totalDistance / scrollSpeed
        
        // Start an infinite loop animation
        withAnimation(
            .linear(duration: duration)
            .repeatForever(autoreverses: false)
        ) {
            offset = -textWidth
        }
        
        print("📜 Starting scrolling text: \(technique.rawValue)")
        print("   - Text width: \(Int(textWidth))pt")
        print("   - Scroll duration: \(String(format: "%.1f", duration))s")
    }
    
    /// Reset the scrolling animation (when the technique changes)
    private func resetScrolling(containerWidth: CGFloat) {
        // Stop the current animation
        withAnimation(.linear(duration: 0)) {
            offset = containerWidth
        }
        
        // Restart after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startScrolling(containerWidth: containerWidth)
        }
        
        print("🔄 Switching scrolling text: \(technique.rawValue)")
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ScrollingTextView(
            text: TechniqueRequirementsManager.getScrollingText(for: .roll),
            technique: .roll
        )
        .padding()
        
        ScrollingTextView(
            text: TechniqueRequirementsManager.getScrollingText(for: .sweep),
            technique: .sweep
        )
        .padding()
        
        ScrollingTextView(
            text: TechniqueRequirementsManager.getScrollingText(for: .pluck),
            technique: .pluck
        )
        .padding()
    }
    .background(Color.black)
}
