//
//  RunningPracticeView.swift
//  PluckBuddy
//
//  Created by Zehui Wu on 2026/7/15.
//

import SwiftUI
import Lottie  // Lottie animation support

struct RunningPracticeView: View {
    @StateObject private var viewModel = RunningViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showSettings = false  // Controls the settings sheet
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.green.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 12) {
                    // ✨ New: metronome bar (shown conditionally)
                    if viewModel.metronome.isEnabled {
                        MetronomeBar(
                            metronome: viewModel.metronome,
                            targetBPM: Int(viewModel.targetBPM)  // ✨ Passes the target speed
                        )
                            .padding(.horizontal)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // New top bar: settings button + BPM target + remaining time (simplified)
                    TopControlBar(
                        targetBPM: viewModel.targetBPM,
                        targetDuration: viewModel.targetDuration,
                        elapsedTime: viewModel.sessionDuration,
                        canEditSettings: !viewModel.isRunning,
                        onSettingsTapped: { showSettings = true }
                    )
                    .frame(height: geometry.size.height * 0.08)
                    .padding(.horizontal)
                    
                    // Running scene (expanded to 70% of the height)
                    CompactRunningSceneView(
                        score: viewModel.score,  // New: passes the score
                        trackOffset: viewModel.trackOffset,
                        runningSpeed: viewModel.runningSpeed,
                        isRunning: viewModel.isRunning,
                        isPlucking: viewModel.isPlucking,  // New: passes the playing state
                        currentBPM: viewModel.currentBPM,
                        stability: viewModel.stability,
                        sessionDuration: viewModel.sessionDuration,
                        statusMessage: viewModel.statusMessage
                    )
                    .frame(height: geometry.size.height * 0.70)
                    .padding(.horizontal)
                
                Spacer()
                    
                    // Start/Stop button
                    Button(action: togglePractice) {
                        HStack(spacing: 12) {
                            Image(systemName: viewModel.isRunning ? "stop.circle.fill" : "play.circle.fill")
                                .font(.title2)
                            Text(viewModel.isRunning ? "Stop Practice" : "Start Practice")
                                .fontWeight(.semibold)
                        }
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(viewModel.isRunning ? Color.red : Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            PracticeSettingsSheet(
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
        .navigationTitle("Pluck Run")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // ✨ Metronome toggle button
                Button(action: {
                    withAnimation(.spring()) {
                        viewModel.metronome.isEnabled.toggle()
                    }
                }) {
                    Image(systemName: viewModel.metronome.isEnabled ? "metronome.fill" : "metronome")
                        .foregroundStyle(viewModel.metronome.isEnabled ? .green : .primary)
                }
            }
        }
        .onDisappear {
            // ✨ Stops the metronome when leaving the screen
            viewModel.metronome.stop()
        }
    }
    
    // MARK: - Computed Properties
    private var stabilityColor: Color {
        if viewModel.stability > 0.8 {
            return .green
        } else if viewModel.stability > 0.5 {
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

// MARK: - Top Control Bar (top control bar - simplified)
struct TopControlBar: View {
    let targetBPM: Double  // Changed to read-only
    let targetDuration: TimeInterval
    let elapsedTime: TimeInterval
    let canEditSettings: Bool  // Whether the settings can be edited
    let onSettingsTapped: () -> Void  // Settings button callback
    
    // Computes the remaining time
    private var remainingTime: TimeInterval {
        max(0, targetDuration - elapsedTime)
    }
    
    // Formats the time display
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Settings button (shown only before the session starts)
            if canEditSettings {
                Button(action: onSettingsTapped) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            
            // BPM target (read-only, no adjustment buttons)
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .foregroundStyle(.orange)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Target Speed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 4) {
                        Text("\(Int(targetBPM))")
                            .font(.title3)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .frame(minWidth: 50, alignment: .center)
                        
                        Text("BPM")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Remaining time display
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .foregroundStyle(.blue)
                    .font(.title3)
                
                VStack(alignment: .center, spacing: 2) {
                    Text("Remaining")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formatTime(remainingTime))
                        .font(.title3)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(remainingTime < 30 ? .red : .primary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Compact Running Scene View (compact running scene)
struct CompactRunningSceneView: View {
    let score: Int  // New: score
    let trackOffset: Double
    let runningSpeed: Double
    let isRunning: Bool
    let isPlucking: Bool  // New: playing state (drives the animation)
    let currentBPM: Double
    let stability: Double
    let sessionDuration: TimeInterval
    let statusMessage: String
    
    @State private var animationPhase: Double = 0
    @State private var trackScrollOffset: CGFloat = 0
    
    private var animationDuration: Double {
        guard currentBPM > 0 else { return 1.0 }
        return 60.0 / currentBPM
    }
    
    private var stabilityColor: Color {
        if stability > 0.8 {
            return .green
        } else if stability > 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Moving track
                MovingTrackView(
                    offset: trackScrollOffset,
                    speed: currentBPM, // Uses the BPM directly
                    isActive: isPlucking  // Uses the playing state to drive the animation
                )
                
                // Lottie runner figure
                LottieRunnerView(
                    isRunning: isPlucking,  // Uses the playing state to drive the animation
                    currentBPM: currentBPM
                )
                .position(
                    x: geometry.size.width * 0.4,
                    y: geometry.size.height * 0.6
                )
                .scaleEffect(0.4) // Scaled down to 40% (it used to be 80%)
                
                // Live data overlay (right-hand side)
                VStack {
                    HStack {
                        // Top left: score display (enlarged)
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.title2)
                                .foregroundStyle(.yellow)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Score")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(score)")
                                    .font(.title)  // Enlarged number
                                    .fontWeight(.bold)
                                    .monospacedDigit()
                            }
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.leading, 12)
                        .padding(.top, 12)
                        
                        Spacer()
                        
                        // Top right: live data
                        VStack(alignment: .trailing, spacing: 8) {
                            // Speed
                            DataBadge(
                                icon: "speedometer",
                                value: "\(Int(currentBPM))",
                                unit: "BPM",
                                color: .blue
                            )
                            
                            // Stability
                            DataBadge(
                                icon: "waveform",
                                value: "\(Int(stability * 100))",
                                unit: "%",
                                color: stabilityColor
                            )
                            
                            // Duration
                            DataBadge(
                                icon: "timer",
                                value: formatDuration(sessionDuration),
                                unit: "",
                                color: .orange
                            )
                        }
                        .padding(.trailing, 12)
                        .padding(.top, 12)
                    }
                    
                    Spacer()
                    
                    // Status message (centered at the bottom)
                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(.bottom, 8)
                    }
                }
            }
        }
        .onAppear {
            startAnimation()
        }
        .onChange(of: isRunning) { _, newValue in
            if newValue {
                startAnimation()
            }
        }
    }
    
    private func startAnimation() {
        withAnimation(.linear(duration: animationDuration).repeatForever(autoreverses: false)) {
            animationPhase = 1.0
        }
        
        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
            trackScrollOffset = -100
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Moving Track View (landscape scrolling track)
struct MovingTrackView: View {
    let offset: CGFloat
    let speed: Double
    let isActive: Bool
    
    @State private var scrollOffset: CGFloat = 0
    @State private var isAnimating: Bool = false  // Animation state flag
    
    // Scroll speed derived from the BPM
    private var scrollDuration: Double {
        guard speed > 0 else { return 2.0 }
        // The higher the BPM, the shorter the duration and the faster it moves
        // 60 BPM → 3.0 s
        // 120 BPM → 1.5 s
        // 180 BPM → 1.0 s
        return max(0.5, 3.0 - (speed / 120.0) * 1.5)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Track lines (horizontal)
                ForEach(0..<15, id: \.self) { index in
                    // Dashed-style track line
                    Rectangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 80, height: 4)
                        .position(
                            x: CGFloat(index) * 100 + scrollOffset,
                            y: geometry.size.height * 0.65 // Below the scene
                        )
                }
                
                // Upper and lower boundary lines (optional)
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 2)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.55)
                
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 2)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.75)
            }
            .clipped()
            // Observes changes of the playing state
            .onChange(of: isActive) { _, newValue in
                print("🛤️ MovingTrackView.isActive: \(newValue), speed: \(String(format: "%.1f", speed))")
                
                if newValue {
                    startScrolling()
                } else {
                    stopScrolling()
                }
            }
            // Observes speed changes (restarts the animation when the speed changes mid-session)
            .onChange(of: speed) { oldValue, newValue in
                print("🏃 MovingTrackView.speed: \(String(format: "%.1f", oldValue)) → \(String(format: "%.1f", newValue)), isActive: \(isActive)")
                
                if isActive && newValue > 0 {
                    print("   → restart scrolling")
                    restartScrolling()
                }
            }
        }
    }
    
    // Start scrolling
    private func startScrolling() {
        guard !isAnimating, speed > 0 else {
            print("   ⚠️ skip scrolling: isAnimating=\(isAnimating), speed=\(String(format: "%.1f", speed))")
            return
        }
        
        isAnimating = true
        print("   ✓ ready to start scrolling, duration: \(String(format: "%.2f", scrollDuration)) s, current offset: \(String(format: "%.1f", scrollOffset))")
        
        // Stop completely first
        withAnimation(.linear(duration: 0)) {
            // Clean up the state
        }
        
        // Delayed start (critical!)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            guard self.speed > 0 else {
                print("   ⚠️ speed=0 after the delay, start cancelled")
                self.isAnimating = false
                return
            }
            
            print("   → start scrolling after the delay, speed: \(String(format: "%.1f", self.speed))")
            let duration = self.scrollDuration
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                self.scrollOffset = -100
            }
            print("   ✓ scrolling started!")
        }
    }
    
    // Stop scrolling
    private func stopScrolling() {
        print("   ✓ scrolling stopped")
        isAnimating = false
        
        // Stop the animation - remove it explicitly
        withAnimation(.linear(duration: 0)) {
            // Remove the repeatForever animation
        }
    }
    
    // Restart scrolling (when the speed changes)
    private func restartScrolling() {
        print("   🔄 ready to restart scrolling")
        
        // Stop completely first
        isAnimating = false
        withAnimation(.linear(duration: 0)) {
            // Remove the old animation
        }
        
        // Restart after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.startScrolling()
        }
    }
}

// MARK: - Data Badge (data badge component)
struct DataBadge: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
            
            if !unit.isEmpty {
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.4))
        .clipShape(Capsule())
    }
}

// MARK: - Compact Runner View (compact runner figure)
struct CompactRunnerView: View {
    let animationPhase: Double
    let isRunning: Bool
    
    private var leftArmAngle: Angle {
        .degrees(sin(animationPhase * .pi * 2) * 30)
    }
    
    private var rightArmAngle: Angle {
        .degrees(-sin(animationPhase * .pi * 2) * 30)
    }
    
    private var leftLegAngle: Angle {
        .degrees(-sin(animationPhase * .pi * 2) * 40)
    }
    
    private var rightLegAngle: Angle {
        .degrees(sin(animationPhase * .pi * 2) * 40)
    }
    
    private var bodyTilt: Angle {
        .degrees(isRunning ? 5 : 0)
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Head
                Circle()
                    .fill(Color.orange.gradient)
                    .frame(width: 30, height: 30)
                    .overlay {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 4, height: 4)
                            Circle()
                                .fill(Color.black)
                                .frame(width: 4, height: 4)
                        }
                        .offset(y: -2)
                    }
                
                // Torso
                Capsule()
                    .fill(Color.blue.gradient)
                    .frame(width: 20, height: 40)
                
                // Legs
                ZStack {
                    Capsule()
                        .fill(Color.green.gradient)
                        .frame(width: 10, height: 35)
                        .offset(y: 17.5)
                        .rotationEffect(leftLegAngle, anchor: .top)
                        .offset(x: -5)
                    
                    Capsule()
                        .fill(Color.green.gradient)
                        .frame(width: 10, height: 35)
                        .offset(y: 17.5)
                        .rotationEffect(rightLegAngle, anchor: .top)
                        .offset(x: 5)
                }
                .frame(height: 35)
            }
            .overlay(alignment: .top) {
                ZStack {
                    Capsule()
                        .fill(Color.orange.gradient)
                        .frame(width: 8, height: 30)
                        .offset(y: 15)
                        .rotationEffect(leftArmAngle, anchor: .top)
                        .offset(x: -15, y: 30)
                    
                    Capsule()
                        .fill(Color.orange.gradient)
                        .frame(width: 8, height: 30)
                        .offset(y: 15)
                        .rotationEffect(rightArmAngle, anchor: .top)
                        .offset(x: 15, y: 30)
                }
            }
            .rotationEffect(bodyTilt)
            
            // Shadow
            Ellipse()
                .fill(Color.black.opacity(0.2))
                .frame(width: 50, height: 12)
                .offset(y: 65)
                .scaleEffect(x: isRunning ? 1.1 : 1.0)
        }
        .animation(.easeInOut(duration: 0.1), value: isRunning)
    }
}


// MARK: - Practice Settings Sheet (practice settings dialog)
struct PracticeSettingsSheet: View {
    @Binding var targetBPM: Double
    @Binding var targetDuration: TimeInterval
    @Binding var metronomeEnabled: Bool  // ✨ New: metronome toggle
    @Binding var metronomeSoundType: MetronomeSoundType  // ✨ New: metronome sound
    @Environment(\.dismiss) private var dismiss
    
    // Local temporary state
    @State private var localBPM: Double
    @State private var localDuration: TimeInterval
    @State private var localMetronomeEnabled: Bool  // ✨ New
    @State private var localSoundType: MetronomeSoundType  // ✨ New
    
    // Preset duration options
    private let durationPresets: [(String, TimeInterval)] = [
        ("1 min", 60),
        ("3 min", 180),
        ("5 min", 300),
        ("10 min", 600),
        ("15 min", 900),
        ("30 min", 1800)
    ]
    
    // Formats the duration display
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes == 0 {
            return "30 s"
        } else if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours) h"
            } else {
                return "\(hours) h \(mins) min"
            }
        }
    }
    
    init(targetBPM: Binding<Double>, targetDuration: Binding<TimeInterval>, metronomeEnabled: Binding<Bool>, metronomeSoundType: Binding<MetronomeSoundType>) {
        _targetBPM = targetBPM
        _targetDuration = targetDuration
        _metronomeEnabled = metronomeEnabled
        _metronomeSoundType = metronomeSoundType
        _localBPM = State(initialValue: targetBPM.wrappedValue)
        _localDuration = State(initialValue: targetDuration.wrappedValue)
        _localMetronomeEnabled = State(initialValue: metronomeEnabled.wrappedValue)
        _localSoundType = State(initialValue: metronomeSoundType.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // BPM settings
                Section {
                    VStack(spacing: 16) {
                        // BPM value display
                        HStack {
                            Spacer()
                            Text("\(Int(localBPM))")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.blue)
                            Text("BPM")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        
                        // Adjustment buttons
                        HStack(spacing: 12) {
                            Button(action: {
                                localBPM = max(36, localBPM - 10)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            Button(action: {
                                localBPM = min(220, localBPM + 10)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Slider
                        Slider(value: $localBPM, in: 36...220, step: 1)
                            .tint(.blue)
                        
                        // Hint text
                        Text("Range: 36-220 BPM")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Label("Target Speed", systemImage: "target")
                }
                
                // Duration settings
                Section {
                    // Duration value display
                    VStack(spacing: 16) {
                        HStack {
                            Spacer()
                            Text(formatDuration(localDuration))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.orange)
                            Spacer()
                        }
                        
                        // Slider
                        Slider(value: $localDuration, in: 30...3600, step: 30)
                            .tint(.orange)
                        
                        HStack {
                            Text("30 s")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("60 min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Quick selection buttons
                    VStack(spacing: 8) {
                        Text("Quick Pick")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(durationPresets, id: \.0) { name, duration in
                                Button(action: {
                                    localDuration = duration
                                }) {
                                    Text(name)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            isSelected(duration) ? Color.blue : Color(.systemGray5)
                                        )
                                        .foregroundStyle(
                                            isSelected(duration) ? .white : .primary
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } header: {
                    Label("Session Duration", systemImage: "timer")
                }
                
                // ✨ New: metronome settings section
                Section {
                    // Metronome toggle
                    Toggle(isOn: $localMetronomeEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "metronome.fill")
                                .foregroundStyle(localMetronomeEnabled ? .green : .secondary)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Enable Metronome")
                                    .font(.body)
                                if localMetronomeEnabled {
                                    Text("Plays automatically when the practice session starts")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .tint(.green)
                    
                    // Sound selection (shown only when enabled)
                    if localMetronomeEnabled {
                        Picker("Metronome Sound", selection: $localSoundType) {
                            ForEach(MetronomeSoundType.allCases) { type in
                                HStack(spacing: 8) {
                                    Image(systemName: type.icon)
                                    Text(type.rawValue)
                                }
                                .tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Label("Metronome", systemImage: "metronome")
                } footer: {
                    if localMetronomeEnabled {
                        Text("The metronome uses the same speed as the practice session (\(Int(localBPM)) BPM)")
                    } else {
                        Text("Turn on the metronome to help you keep a steady practice rhythm")
                    }
                }
            }
            .navigationTitle("Practice Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        targetBPM = localBPM
                        targetDuration = localDuration
                        metronomeEnabled = localMetronomeEnabled  // ✨ Saves the metronome toggle
                        metronomeSoundType = localSoundType  // ✨ Saves the metronome sound
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func isSelected(_ duration: TimeInterval) -> Bool {
        return abs(localDuration - duration) < 1
    }
}


#Preview {
    NavigationStack {
        RunningPracticeView()
    }
}

