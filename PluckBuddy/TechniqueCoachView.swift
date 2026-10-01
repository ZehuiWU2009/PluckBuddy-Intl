//
//  TechniqueCoachView.swift
//  PluckBuddy
//
//  Created by Zehui Wu on 2026/7/29.
//

import SwiftUI
import Combine

/// Main screen of the Smart Fingering Coach
struct TechniqueCoachView: View {
    @StateObject private var viewModel = TechniqueCoachViewModel()
    
    /// The technique pinned in the UI: updated when a new technique is recognized, keeps the previous one when recognition is lost.
    /// Binding straight to viewModel.detectedTechnique flickers between "recognized" and "not recognized",
    /// which makes the requirement strip and the evaluation panel below blink in and out as a whole.
    @State private var displayTechnique: TechniqueType = .roll
    /// The pinned evaluation result: likewise keeps the last valid value so the score digits do not flicker
    @State private var displayEvaluation: PostureEvaluation?
    
    var body: some View {
        ZStack {
            // Dark background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Camera preview area
                cameraPreviewSection
                
                // Combined detection result and evaluation panel (always on screen)
                // The core requirements are compressed into one row at the top of the panel instead of a separate card
                combinedEvaluationPanel
                
                Spacer()
                
                // Control button
                controlButton
            }
        }
        .onChange(of: viewModel.detectedTechnique) { _, newValue in
            // Switches the UI only when a definite technique is recognized; keeps the current display while nothing is recognized
            guard newValue != .unknown, newValue != displayTechnique else { return }
            displayTechnique = newValue
            displayEvaluation = nil
        }
        .onChange(of: viewModel.currentEvaluation?.overallScore) { _, _ in
            if let evaluation = viewModel.currentEvaluation {
                displayEvaluation = evaluation
            }
        }
        .navigationTitle("Smart Fingering Coach")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // Technique test
                    Section("Quick Technique Test") {
                        Button {
                            viewModel.setTechnique(.roll)
                        } label: {
                            Label("Tremolo", systemImage: "hand.tap.fill")
                        }
                        
                        Button {
                            viewModel.setTechnique(.sweep)
                        } label: {
                            Label("Sweep", systemImage: "waveform.path")
                        }
                        
                        Button {
                            viewModel.setTechnique(.pluck)
                        } label: {
                            Label("Pluck", systemImage: "hand.point.up.left.fill")
                        }
                        
                        Button {
                            viewModel.setTechnique(.unknown)
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                        }
                    }
                    
                    // Scrolling caption test
                    Section {
                        NavigationLink {
                            ScrollingTextTestView()
                        } label: {
                            Label("Scrolling Caption Test", systemImage: "text.badge.checkmark")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Camera preview area
    
    private var cameraPreviewSection: some View {
        ZStack {
            if viewModel.isAnalyzing, let previewLayer = viewModel.videoCapture?.previewLayer {
                // Live camera preview
                CameraPreviewView(previewLayer: previewLayer)
                    .frame(height: 470)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                
                // ✨ Hand skeleton overlay
                if let skeletonImage = viewModel.skeletonOverlayImage {
                    Image(uiImage: skeletonImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 470)
                        .allowsHitTesting(false)  // Does not intercept touch events
                }
            } else {
                // Placeholder view
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 470)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.white.opacity(0.5))
                            
                            if !viewModel.isAnalyzing {
                                Text("Tap the Start Analysis button to enable the camera")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.85))
                            } else if viewModel.handPose == nil {
                                Text("Waiting for hand detection...")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.85))
                            } else {
                                Text("✅ Hand detected")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.green)
                            }
                        }
                    )
            }
        }
        .padding(.horizontal)
    }
    
    private var combinedEvaluationPanel: some View {
        VStack(spacing: 0) {
            // Top: single-line carousel of technique requirements (32 pt, replaces the former standalone card)
            RequirementStripView(technique: displayTechnique)
            
            // Divider
            Divider()
            
            // Upper half: detection info (left) + suggestions (right)
            HStack(spacing: 0) {
                // Left: detection info
                HStack(spacing: 12) {
                    // Technique icon
                    Image(systemName: displayTechnique.icon)
                        .font(.system(size: 26))
                        .foregroundStyle(displayTechnique.color)
                        .frame(width: 40, height: 40)
                        .background(displayTechnique.color.opacity(0.2))
                        .clipShape(Circle())
                    
                    // Three lines of detection info: technique name / score / status
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text("Detected:")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                            Text(displayTechnique.rawValue)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(displayTechnique.color)
                        }
                        
                        if let evaluation = displayEvaluation {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                                Text("\(Int(evaluation.overallScore))/100")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(scoreColor(evaluation.overallScore))
                            }
                        }
                        
                        Text(viewModel.statusMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
                
                // Divider
                Divider()
                    .padding(.vertical, 8)
                
                // Right: improvement suggestions (scrollable, two visible)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                        Text("Suggestions")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    
                    if let evaluation = displayEvaluation {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(evaluation.suggestions.prefix(5), id: \.self) { suggestion in
                                    Text("• \(suggestion)")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white.opacity(0.82))
                                        .lineLimit(2)
                                }
                            }
                        }
                        .frame(height: 36)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 12)
            }
            .frame(height: 78)
            
            // Divider
            Divider()
            
            // Lower half: the 4 fixed evaluation aspects (2×2)
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(0..<2, id: \.self) { index in
                        if let aspect = getStandardAspect(at: index) {
                            FixedAspectView(aspect: aspect)
                        } else {
                            PlaceholderAspectView()
                        }
                    }
                }
                
                HStack(spacing: 6) {
                    ForEach(2..<4, id: \.self) { index in
                        if let aspect = getStandardAspect(at: index) {
                            FixedAspectView(aspect: aspect)
                        } else {
                            PlaceholderAspectView()
                        }
                    }
                }
            }
            .padding(10)
            .frame(height: 106)
        }
        .frame(height: 218)  // 32(requirements) + 1 + 78(upper) + 1 + 106(lower)
        .modifier(CoachPanelBackground())
        .padding(.horizontal)
    }
    
    // MARK: - Standard evaluation aspects
    
    /// Returns the 4 common fixed evaluation aspects
    private func getStandardAspect(at index: Int) -> EvaluationAspect? {
        guard let evaluation = displayEvaluation else {
            return nil
        }
        
        // Defines the 4 common fixed aspects
        let standardCategories: [EvaluationAspect.Category] = [
            .handShape,      // Hand Shape
            .tigerMouth,     // Tiger Mouth Angle
            .rhythm,         // Rhythm Stability
            .wristPosition   // Wrist Position
        ]
        
        guard index < standardCategories.count else {
            return nil
        }
        
        let category = standardCategories[index]
        
        // Looks up the matching aspect in the evaluation result
        if let aspect = evaluation.aspects.first(where: { $0.category == category }) {
            return aspect
        }
        
        // Falls back to a default value when nothing is found
        return EvaluationAspect(
            category: category,
            score: 0,
            description: "No data yet"
        )
    }
    
    // MARK: - Detection result card
    
    private var detectionResultCard: some View {
        HStack(spacing: 16) {
            // Technique icon - slightly smaller
            Image(systemName: viewModel.detectedTechnique.icon)
                .font(.system(size: 32))
                .foregroundStyle(viewModel.detectedTechnique.color)
                .frame(width: 50, height: 50)
                .background(viewModel.detectedTechnique.color.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                // Detected technique
                HStack(spacing: 4) {
                    Text("Detected:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text(viewModel.detectedTechnique.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(viewModel.detectedTechnique.color)
                }
                
                // Score
                if let evaluation = viewModel.currentEvaluation {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                        
                        Text("\(Int(evaluation.overallScore))/100")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(scoreColor(evaluation.overallScore))
                    }
                }
                
                // Status message
                Text(viewModel.statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    // MARK: - Detailed evaluation panel
    
    private func evaluationDetailSection(evaluation: PostureEvaluation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.blue)
                    .font(.caption)
                Text("Detailed Evaluation")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            // Aspect scores - compressed into 2 rows of 2
            if !evaluation.aspects.isEmpty {
                VStack(spacing: 6) {
                    // Splits the score items into two rows
                    let aspectPairs = stride(from: 0, to: evaluation.aspects.count, by: 2).map { index -> [EvaluationAspect] in
                        let endIndex = min(index + 2, evaluation.aspects.count)
                        return Array(evaluation.aspects[index..<endIndex])
                    }
                    
                    ForEach(aspectPairs.indices, id: \.self) { pairIndex in
                        HStack(spacing: 8) {
                            ForEach(aspectPairs[pairIndex].indices, id: \.self) { index in
                                CompactAspectView(aspect: aspectPairs[pairIndex][index])
                            }
                        }
                    }
                }
            }
            
            // Improvement suggestions - more compact
            if !evaluation.suggestions.isEmpty {
                Divider()
                    .padding(.vertical, 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption2)
                        Text("Suggestions")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    // Only the first 2 suggestions are shown, to keep it short
                    ForEach(evaluation.suggestions.prefix(2), id: \.self) { suggestion in
                        Text("• \(suggestion)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Control button
    
    private var controlButton: some View {
        Button(action: toggleAnalysis) {
            HStack(spacing: 12) {
                Image(systemName: viewModel.isAnalyzing ? "stop.fill" : "play.fill")
                    .font(.title3)
                
                Text(viewModel.isAnalyzing ? "Stop Analysis" : "Start Analysis")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                viewModel.isAnalyzing
                    ? Color.red
                    : Color.blue
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    // MARK: - Actions
    
    private func toggleAnalysis() {
        if viewModel.isAnalyzing {
            viewModel.stopAnalysis()
        } else {
            Task {
                await viewModel.startAnalysis()
            }
        }
    }
    
    // MARK: - Helper
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 90 {
            return .green
        } else if score >= 80 {
            return .blue
        } else if score >= 70 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Fixed evaluation aspect view

struct FixedAspectView: View {
    let aspect: EvaluationAspect
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Category name and score
            HStack(spacing: 4) {
                Text(aspect.category.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                
                Spacer()
                
                Text("\(Int(aspect.score))")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(scoreColor)
            }
            
            // Compact progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(scoreColor)
                        .frame(
                            width: geometry.size.width * (aspect.score / 100),
                            height: 4
                        )
                }
            }
            .frame(height: 4)
        }
        .padding(8)
        .frame(height: 40)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private var scoreColor: Color {
        if aspect.score >= 80 {
            return .green
        } else if aspect.score >= 60 {
            return .orange
        } else if aspect.score > 0 {
            return .red
        } else {
            return .gray
        }
    }
}

// MARK: - Placeholder evaluation aspect view

struct PlaceholderAspectView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("---")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text("--")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.white.opacity(0.12))
                .frame(height: 4)
        }
        .padding(8)
        .frame(height: 40)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Evaluation aspect row

struct AspectRow: View {
    let aspect: EvaluationAspect
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(aspect.category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(aspect.score))/100")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(scoreColor)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 2)
                        .fill(scoreColor)
                        .frame(
                            width: geometry.size.width * (aspect.score / 100),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
            
            // Description
            Text(aspect.description)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    private var scoreColor: Color {
        if aspect.score >= 80 {
            return .green
        } else if aspect.score >= 60 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Compact score view

struct CompactAspectView: View {
    let aspect: EvaluationAspect
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Category and score
            HStack(spacing: 4) {
                Text(aspect.category.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(aspect.score))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(scoreColor)
            }
            
            // Compact progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(scoreColor)
                        .frame(
                            width: geometry.size.width * (aspect.score / 100),
                            height: 4
                        )
                }
            }
            .frame(height: 4)
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var scoreColor: Color {
        if aspect.score >= 80 {
            return .green
        } else if aspect.score >= 60 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Core requirement carousel view

/// Single-line carousel of the technique requirements.
/// It used to be a horizontal marquee (text scrolled in from outside the right edge at 50 pt/s, showing up only after seven or eight seconds, and it reset on every technique switch),
/// then became a standalone card with fade-in switching that still took 86 pt of height. Here it is compressed into a 32 pt single-line strip merged into the top of the panel below.
struct RequirementStripView: View {
    let technique: TechniqueType
    
    @State private var index = 0
    @State private var tick = Timer.publish(every: 4.0, on: .main, in: .common).autoconnect()
    
    private var items: [String] {
        TechniqueRequirementsManager.getRequirements(for: technique)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 11))
                .foregroundStyle(.yellow)
            
            Text(items.isEmpty ? "No requirements yet" : items[safeIndex])
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(safeIndex)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: safeIndex)
            
            if items.count > 1 {
                Text("\(safeIndex + 1)/\(items.count)")
                    .font(.system(size: 11))
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .onReceive(tick) { _ in
            guard items.count > 1 else { return }
            index = (index + 1) % items.count
        }
        .onChange(of: technique) { _, _ in
            index = 0
        }
    }
    
    /// Prevents an out-of-range index when the item count changes after the technique switches
    private var safeIndex: Int {
        guard !items.isEmpty else { return 0 }
        return min(index, items.count - 1)
    }
}

// MARK: - Panel background style

/// Semi-transparent black background with a thin stroke: keeps the text readable even when the camera feed is bright
struct CoachPanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.black.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TechniqueCoachView()
    }
}
