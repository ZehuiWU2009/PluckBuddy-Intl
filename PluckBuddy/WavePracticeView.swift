//
//  WavePracticeView.swift
//  PluckBuddy
//
//  Created by Zehui Wu on 2026/7/15.
//

import SwiftUI

struct WavePracticeView: View {
    @StateObject private var viewModel = WaveViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showSettings = false  // ✨ New: controls the settings sheet
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ✨ Custom title bar (with back and settings buttons)
                ZStack {
                    // Title (centered)
                    Text("Sweep Wave")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.cyan, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    // Back button on the left, settings button on the right
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.cyan)
                                .frame(width: 44, height: 44)
                                .background(Color.cyan.opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            showSettings = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                                .foregroundStyle(.cyan)
                                .frame(width: 44, height: 44)
                                .background(Color.cyan.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // ✨ Metronome bar (shown only when enabled)
                        if viewModel.metronome.isEnabled && viewModel.isRunning {
                            MetronomeBar(
                                metronome: viewModel.metronome,
                                targetBPM: Int(viewModel.targetBPM)
                            )
                            .padding(.horizontal)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // Top stats bar (with extra top spacing)
                        HStack(spacing: 30) {
                            WaveStatItem(title: "Total", value: "\(viewModel.sweepCount)", icon: "waveform")
                            WaveStatItem(title: "Up", value: "\(viewModel.upCount)", icon: "arrow.up")
                            WaveStatItem(title: "Down", value: "\(viewModel.downCount)", icon: "arrow.down")
                            WaveStatItem(title: "Score", value: "\(viewModel.score)", icon: "star.fill")
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal)
                        
                        // ✨ Duration display
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
                        
                        // Water surface area
                        ZStack {
                            WaterSurfaceView(
                                waves: viewModel.waves,
                                waterColor: viewModel.waterColor
                            )
                            
                            // ✨ Sweep status indicator (flash in the center)
                            if viewModel.isSweeping {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Color.white.opacity(0.8),
                                                Color.white.opacity(0.3),
                                                Color.clear
                                            ],
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: 50
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                    .scaleEffect(viewModel.isSweeping ? 1.2 : 0.8)
                                    .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: viewModel.isSweeping)
                                    .transition(.scale.combined(with: .opacity))
                            }
                            
                            // ✨ Waiting hint (shown when no sweep has happened yet)
                            if viewModel.isRunning && !viewModel.isSweeping && viewModel.sweepCount == 0 {
                                VStack(spacing: 8) {
                                    Image(systemName: "hand.raised.fill")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.secondary)
                                    Text("Start sweeping...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .transition(.opacity)
                            }
                        }
                        .frame(width: 280, height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.1), radius: 10)
                        .padding(.horizontal)
                        
                        // Strength and balance indicators
                        VStack(spacing: 12) {
                            // Strength display
                            HStack {
                                Image(systemName: "bolt.fill")
                                    .foregroundStyle(.secondary)
                                Text("Average Strength")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(Int(viewModel.averageStrength * 100))%")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(strengthColor)
                            }
                            
                            ProgressView(value: viewModel.averageStrength)
                                .tint(strengthColor)
                                .scaleEffect(y: 1.5)
                            
                            // Direction balance
                            HStack {
                                Image(systemName: "arrow.up.arrow.down")
                                    .foregroundStyle(.secondary)
                                Text("Direction Balance")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(Int(viewModel.directionBalance * 100))%")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(balanceColor)
                            }
                            
                            ProgressView(value: viewModel.directionBalance)
                                .tint(balanceColor)
                                .scaleEffect(y: 1.5)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                        
                        // ✅ Pipa sound detection status row (reverted to DSP heuristics, no longer shown)
                        // Status hint
                        Text(viewModel.statusMessage)
                            .font(.body)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .frame(minHeight: 50)
                        
                        // Start/Stop button
                        Button(action: togglePractice) {
                            HStack(spacing: 12) {
                                Image(systemName: viewModel.isRunning ? "stop.fill" : "play.fill")
                                    .font(.title3)
                                Text(viewModel.isRunning ? "Stop Practice" : "Start Practice")
                                    .fontWeight(.semibold)
                                    .font(.headline)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(viewModel.isRunning ? Color.red : Color.cyan)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: (viewModel.isRunning ? Color.red : Color.cyan).opacity(0.3), radius: 8, y: 4)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            WaveSettingsSheet(
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
        .navigationBarHidden(true)
    }
    
    // MARK: - Computed Properties
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
    
    private var strengthColor: Color {
        if viewModel.averageStrength > 0.7 {
            return .green
        } else if viewModel.averageStrength > 0.4 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var balanceColor: Color {
        if viewModel.directionBalance > 0.4 {
            return .green
        } else if viewModel.directionBalance > 0.2 {
            return .orange
        } else {
            return .red
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

// MARK: - Water Surface View
struct WaterSurfaceView: View {
    let waves: [WaveRipple]
    let waterColor: Color
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                // Water surface background
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        Gradient(colors: [
                            waterColor.opacity(0.3),
                            waterColor.opacity(0.6)
                        ]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )
                
                // Draw all the ripples
                for wave in waves {
                    drawWave(wave, in: context, size: size)
                }
            }
        }
    }
    
    private func drawWave(_ wave: WaveRipple, in context: GraphicsContext, size: CGSize) {
        let centerX = wave.center.x * size.width
        let centerY = wave.center.y * size.height
        let center = CGPoint(x: centerX, y: centerY)
        
        // ✨ Uses the live progress computed by the wave
        let progress = wave.progress
        let opacity = wave.opacity
        
        // Current radius derived from the progress
        let currentRadius = wave.maxRadius * min(size.width, size.height) * CGFloat(progress)
        
        // Draw several concentric rings (stronger ripple effect)
        for i in 0..<3 {
            let delay = Double(i) * 0.15 // Each ring is delayed by 0.15 s
            let adjustedProgress = max(0, progress - delay)
            
            guard adjustedProgress > 0 else { continue }
            
            let adjustedRadius = currentRadius * CGFloat(adjustedProgress / progress)
            let adjustedOpacity = opacity * (1.0 - Double(i) * 0.2) // Outer rings are more transparent
            
            // Draw the ring
            let path = Path { p in
                p.addEllipse(in: CGRect(
                    x: center.x - adjustedRadius,
                    y: center.y - adjustedRadius,
                    width: adjustedRadius * 2,
                    height: adjustedRadius * 2
                ))
            }
            
            context.stroke(
                path,
                with: .color(wave.color.opacity(adjustedOpacity)),
                lineWidth: 3 - CGFloat(i) * 0.5 // Outer rings use a thinner line
            )
        }
    }
}

// MARK: - Wave Stat Item
struct WaveStatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        WavePracticeView()
    }
}

