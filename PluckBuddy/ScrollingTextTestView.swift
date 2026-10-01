//
//  ScrollingTextTestView.swift
//  PluckBuddy
//
//  Created by Zehui Wu on 2026/7/29.
//

import SwiftUI

/// Scrolling text test view - tests the scrolling effect in isolation
struct ScrollingTextTestView: View {
    @State private var selectedTechnique: TechniqueType = .roll
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Technique picker
                VStack(spacing: 12) {
                    Text("Select a technique to see its requirements")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Picker("Technique", selection: $selectedTechnique) {
                        Text("🎵 Tremolo").tag(TechniqueType.roll)
                        Text("🌊 Sweep").tag(TechniqueType.sweep)
                        Text("🎸 Pluck").tag(TechniqueType.pluck)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Technique icon and name
                VStack(spacing: 12) {
                    Image(systemName: selectedTechnique.icon)
                        .font(.system(size: 80))
                        .foregroundStyle(selectedTechnique.color)
                    
                    Text(selectedTechnique.rawValue)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text(selectedTechnique.description)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Scrolling text area
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                        Text("Key Requirements - Simple Scrolling Bar")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Simple scrolling bar
                    ScrollingTextView(
                        text: TechniqueRequirementsManager.getScrollingText(
                            for: selectedTechnique
                        ),
                        technique: selectedTechnique
                    )
                    .frame(height: 50)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Card carousel (alternative)
                VStack(spacing: 8) {
                    Text("Alternative - Card Carousel")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    EnhancedScrollingBanner(technique: selectedTechnique)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Explanatory text
                VStack(spacing: 8) {
                    Text("💡 Tip")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.yellow)
                    
                    Text("Switch the picker above to see the key requirements of each technique")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .padding(.top, 20)
        }
        .navigationTitle("Scrolling Text Test")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ScrollingTextTestView()
    }
}
