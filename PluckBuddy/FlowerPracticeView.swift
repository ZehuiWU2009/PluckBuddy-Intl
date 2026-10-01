//
//  FlowerPracticeView.swift
//  PluckBuddy
//
//  Created by Zehui Wu on 2026/7/15.
//

import SwiftUI

struct FlowerPracticeView: View {
    @StateObject private var viewModel = FlowerViewModel()
    @State private var showSettings = false  // ✨ New: controls the settings sheet
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.pink.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {  // ✨ A ScrollView keeps the content from overflowing the screen
                VStack(spacing: 20) {  // ✨ Spacing reduced from 30 to 20
                    // ✨ Metronome bar (shown only when enabled)
                    if viewModel.metronome.isEnabled && viewModel.isRunning {
                        MetronomeBar(
                            metronome: viewModel.metronome,
                            targetBPM: Int(viewModel.targetBPM)
                        )
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Top stats bar
                    HStack(spacing: 40) {
                        FlowerStatItem(title: "Tremolo", value: "\(viewModel.rollCount)", icon: "hand.tap.fill")
                        FlowerStatItem(title: "Sequences", value: "\(viewModel.sequenceCount)", icon: "rectangle.3.group")
                        FlowerStatItem(title: "Score", value: "\(viewModel.score)", icon: "star.fill")
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
                    
                    // Duration display
                    if viewModel.isRunning {
                        HStack(spacing: 12) {
                            Image(systemName: "timer")
                                .foregroundStyle(.secondary)
                            Text(timeDisplay)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                            
                            if viewModel.targetDuration > 0 {
                                Text("/ \(targetTimeDisplay)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                    
                    //Spacer()  // ✨ No Spacer needed inside a ScrollView
                    
                    // Flower display area
                    ZStack {
                        FlowerView(
                            growth: viewModel.flowerGrowth,
                            petalCount: viewModel.petalCount,
                            brightness: viewModel.flowerBrightness,
                            symmetry: viewModel.flowerSymmetry,
                            isRolling: viewModel.isRolling,
                            pulseCounter: viewModel.pulseCounter // ✨ Passes the pulse counter down
                        )
                        .frame(width: 220, height: 220)  // ✨ Reduced from 250
                        
                        // Sequence quality indicator
                        if let quality = viewModel.lastSequenceQuality {
                            VStack {
                                Spacer()
                                HStack(spacing: 6) {
                                    Text(quality.emoji)
                                        .font(.title3)  // ✨ Reduced
                                    Text(quality.description)
                                        .font(.subheadline)  // ✨ Reduced
                                        .foregroundStyle(qualityColor(quality))
                                }
                                .padding(.horizontal, 12)  // ✨ Reduced padding
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .transition(.scale.combined(with: .opacity))
                            }
                            .frame(height: 220)  // ✨ Matches the flower size
                        }
                    }
                    .padding(.horizontal)  // ✨ Reduced padding
                    
                    // Speed and evenness indicators
                    VStack(spacing: 12) {  // ✨ Reduced spacing
                        // Speed display
                        HStack {
                            Image(systemName: "speedometer")
                                .font(.caption)  // ✨ Reduced icon
                                .foregroundStyle(.secondary)
                            Text("Speed: \(String(format: "%.1f", viewModel.currentSpeed)) /s")
                                .font(.subheadline)  // ✨ Reduced font
                            Spacer()
                            Text("Avg: \(String(format: "%.1f", viewModel.averageSpeed))")
                                .font(.caption)  // ✨ Reduced font
                                .foregroundStyle(.secondary)
                        }
                        
                        // Evenness progress bar
                        VStack(alignment: .leading, spacing: 6) {  // ✨ Reduced spacing
                            HStack {
                                Image(systemName: "waveform.path")
                                    .font(.caption)  // ✨ Reduced icon
                                    .foregroundStyle(.secondary)
                                Text("Evenness")
                                    .font(.subheadline)  // ✨ Reduced font
                                Spacer()
                                Text("\(Int(viewModel.uniformity * 100))%")
                                    .font(.caption)  // ✨ Reduced font
                                    .foregroundStyle(uniformityColor)
                            }
                            
                            ProgressView(value: viewModel.uniformity)
                                .tint(uniformityColor)
                                .scaleEffect(y: 1.5)  // ✨ Reduced height
                        }
                    }
                    .padding(.horizontal, 12)  // ✨ Reduced padding
                    .padding(.vertical, 10)  // ✨ Reduced padding
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    
                    // ✅ Pipa sound detection status row (reverted to DSP heuristics, no longer shown)
                    // Status hint
                    Text(viewModel.statusMessage)
                        .font(.body)  // ✨ Reduced font
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .frame(minHeight: 50)  // ✨ Reduced minimum height
                    
                    // Start/Stop button
                    Button(action: togglePractice) {
                        HStack {
                            Image(systemName: viewModel.isRunning ? "stop.fill" : "play.fill")
                            Text(viewModel.isRunning ? "Stop Practice" : "Start Practice")
                                .fontWeight(.semibold)
                        }
                        .font(.headline)  // ✨ Reduced font
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)  // ✨ Reduced vertical padding
                        .background(viewModel.isRunning ? Color.red : Color.pink)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)  // ✨ Keeps enough bottom margin
                }
            }  // End of ScrollView
        }
        .sheet(isPresented: $showSettings) {
            FlowerSettingsSheet(
                targetBPM: $viewModel.targetBPM,
                targetDuration: $viewModel.targetDuration,
                metronomeEnabled: Binding(
                    get: { viewModel.metronomeIsEnabled },
                    set: { viewModel.metronomeIsEnabled = $0 }
                ),
                metronomeSoundType: Binding(
                    get: { viewModel.metronomeSoundType },
                    set: { viewModel.metronomeSoundType = $0 }
                )
            )
        }
        .navigationTitle("Tremolo Bloom")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.blue)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var uniformityColor: Color {
        if viewModel.uniformity > 0.8 {
            return .green
        } else if viewModel.uniformity > 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var timeDisplay: String {
        let minutes = Int(viewModel.sessionDuration / 60)
        let seconds = Int(viewModel.sessionDuration.truncatingRemainder(dividingBy: 60))
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
    
    private var targetTimeDisplay: String {
        let minutes = Int(viewModel.targetDuration / 60)
        let seconds = Int(viewModel.targetDuration.truncatingRemainder(dividingBy: 60))
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
    
    private func qualityColor(_ quality: RollSequence.Quality) -> Color {
        switch quality {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .needsImprovement: return .red
        }
    }
    
    // MARK: - Actions
    private func togglePractice() {
        if viewModel.isRunning {
            viewModel.stopPractice()
        } else {
            viewModel.startPractice()
        }
    }
}

// MARK: - Flower View
struct FlowerView: View {
    let growth: Double // 0-1
    let petalCount: Int
    let brightness: Double // 0-1
    let symmetry: Double // 0-1
    let isRolling: Bool // Whether tremolo is currently playing
    let pulseCounter: Int // ✨ New: pulse counter parameter
    
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.green.opacity(0.1))
            
            // Petals
            ForEach(0..<8) { index in
                if index < petalCount {
                    Petal(
                        rotation: Double(index) * 45 + rotationAngle,
                        scale: growth * symmetry,
                        color: petalColor,
                        pulseCounter: pulseCounter // ✨ Passes the pulse counter down
                    )
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: growth)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: petalCount)
                }
            }
            
            // Flower center
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.yellow, Color.orange],
                        center: .center,
                        startRadius: 0,
                        endRadius: 30
                    )
                )
                .frame(width: 60, height: 60)
                .opacity(growth > 0 ? 1 : 0)
                .scaleEffect(growth)
                .scaleEffect(isRolling ? 1.1 : 1.0) // Scales up slightly while tremolo is playing
                .animation(.spring(response: 0.5), value: growth)
                .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isRolling)
        }
        .rotationEffect(.degrees(rotationAngle))
        .onChange(of: pulseCounter) { oldValue, newValue in
            // ✨ Watches the pulse counter to trigger the rotation animation
            if newValue > oldValue {
                withAnimation(.easeOut(duration: 0.3)) {
                    rotationAngle += 45 // Rotates 45 degrees each time (the angle of one petal)
                }
            }
        }
    }
    
    private var petalColor: Color {
        // Adjusts the color based on brightness
        let hue = 0.9 // Pink hue
        let saturation = 0.6 + (brightness * 0.4)
        let lightness = 0.5 + (brightness * 0.2)
        
        return Color(hue: hue, saturation: saturation, brightness: lightness)
    }
}

// MARK: - Petal Shape
struct Petal: View {
    let rotation: Double
    let scale: Double
    let color: Color
    let pulseCounter: Int // ✨ Uses a counter instead of a boolean
    
    @State private var pulseScale: Double = 1.0
    
    var body: some View {
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 50, height: 100)
            .offset(y: -60)
            .scaleEffect(pulseScale)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .onChange(of: pulseCounter) { oldValue, newValue in
                // ✨ Fix: a new pulse fires every time the counter changes
                guard newValue > oldValue else { return }
                
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                    pulseScale = 1.2
                }
                
                // Restore
                Task {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 s
                    await MainActor.run {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            pulseScale = 1.0
                        }
                    }
                }
            }
    }
}

// MARK: - Stat Item (Reuse from RunningPracticeView)
struct FlowerStatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        FlowerPracticeView()
    }
}

