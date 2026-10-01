//
//  WaveViewModel.swift
//  PluckBuddy
//
//  Created by Zehui Wu on 2026/7/16.
//

import Foundation
import AVFoundation
import Combine
import SwiftUI

@MainActor
class WaveViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRunning = false
    @Published var sweepCount: Int = 0 // Sweep count
    @Published var upCount: Int = 0 // Upward sweep count
    @Published var downCount: Int = 0 // Downward sweep count
    @Published var averageStrength: Double = 0 // Average strength
    @Published var directionBalance: Double = 0.5 // Direction balance
    @Published var score: Int = 0 // Score
    @Published var statusMessage = "Ready to start"
    @Published var sessionDuration: TimeInterval = 0 // Current practice duration (s)
    @Published var targetDuration: TimeInterval = 300 // Target duration (default 5 minutes)
    @Published var targetBPM: Double = 60 // ✨ New: target speed (BPM, sweeps are usually slower)

    // Ripple state
    @Published var waves: [WaveRipple] = [] // Ripples currently on screen
    @Published var waterColor: Color = .blue // Water surface color
    @Published var isSweeping: Bool = false // ✨ New: whether a sweep is in progress (drives the animation)
    
    // ✨ New: metronome
    let metronome = MetronomeManager()
    
    // ✨ Computed properties: binding interface for the metronome settings
    var metronomeIsEnabled: Bool {
        get { metronome.isEnabled }
        set { metronome.isEnabled = newValue }
    }
    
    var metronomeSoundType: MetronomeSoundType {
        get { metronome.soundType }
        set { metronome.soundType = newValue }
    }
    
    // MARK: - Private Properties
    private var audioManager: AudioManager?
    private var sweepDetector: SweepDetector?
    private var startTime: Date?
    private var durationTimer: Timer? // Used to update the elapsed time
    private var waveIdCounter: Int = 0
    private var idleWorkItem: DispatchWorkItem? // ✨ Used to detect idle (no sweep)
    
    // MARK: - Constants
    private let idleTimeout: TimeInterval = 2.0 // ✨ Idle timeout: 2 s without a sweep counts as stopped
    private let scorePerSweep: Int = 10 // Score per sweep
    private let maxWaves = 5 // Maximum number of ripples shown on screen at the same time
    
    // MARK: - Lifecycle
    func startPractice() {
        Task { [weak self] in
            guard let self = self else { return }
            // Request microphone permission
            audioManager = AudioManager.shared
            guard let manager = audioManager else { return }
            
            let hasPermission = await manager.requestMicrophonePermission()
            guard hasPermission else {
                statusMessage = "Microphone permission required"
                return
            }
            
            // Initialize the sweep detector
            sweepDetector = SweepDetector(sampleRate: 48000.0)
            
            sweepDetector?.onSweepDetected = { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleSweepEvent(event)
                }
            }
            
            // Reset state
            resetSession()
            
            // ✨ Start the metronome (if it is enabled)
            if metronome.isEnabled {
                metronome.bpm = Int(targetBPM)
                metronome.start()
            }
            
            // Start audio monitoring
            do {
                try manager.startListening { [weak self] buffer, _ in
                    guard let self = self,
                          let detector = self.sweepDetector else { return }
                    
                    // ✅ The DSP heuristic gate was rolled back (unstable in testing); hand the buffer straight to the sweep detector
                    _ = detector.detectSweep(from: buffer)
                }
                
                isRunning = true
                startTime = Date()
                statusMessage = "Start your sweep!"
                
                // ✨ Start the duration timer
                startDurationTimer()
                
            } catch {
                statusMessage = "Audio failed to start"
                print("Audio error: \(error.localizedDescription)")
            }
        }
    }
    
    func stopPractice() {
        audioManager?.stopListening()
        isRunning = false
        isSweeping = false // ✨ Reset the sweep state
        
        // ✨ Stop the metronome
        if metronome.isPlaying {
            metronome.stop()
        }
        
        // ✨ Stop the duration timer
        durationTimer?.invalidate()
        durationTimer = nil
        
        // ✨ Cancel the idle task
        idleWorkItem?.cancel()
        idleWorkItem = nil
        
        if let start = startTime {
            sessionDuration = Date().timeIntervalSince(start)
            
            // Save the practice record
            if sweepCount > 0 {
                print("💾 Saving sweep practice record...")
                print("   - Duration: \(String(format: "%.1f", sessionDuration))s")
                print("   - Sweep count: \(sweepCount)")
                print("   - Average strength: \(String(format: "%.1f", averageStrength * 100))%")
                print("   - Score: \(score)")
                
                PracticeDataManager.shared.saveWaveSession(
                    duration: sessionDuration,
                    sweepCount: sweepCount,
                    averageStrength: averageStrength,
                    score: score
                )
            }
        }
        
        updateStatusMessage()
    }
    
    // MARK: - Event Handling
    private func handleSweepEvent(_ event: SweepEvent) {
        guard isRunning else { return }
        
        // 🔍 Add debug logging
        print("🌊 Sweep detected!")
        print("   - Direction: \(event.direction.description) \(event.direction.arrow)")
        print("   - Strength: \(event.strength.description)")
        print("   - Amplitude: \(String(format: "%.2f", event.amplitude))")
        print("   - RMS: \(String(format: "%.2f", event.rms))")
        
        // ✨ Mark a sweep as in progress
        let wasSweeping = isSweeping
        isSweeping = true
        
        if !wasSweeping {
            print("   ✓ Starting a new sweep motion: isSweeping = true")
        }
        
        // ✨ Reset the idle timer
        resetIdleTimer()
        
        // Update statistics
        sweepCount += 1
        
        switch event.direction {
        case .up:
            upCount += 1
        case .down:
            downCount += 1
        }
        
        // Update the average strength
        if let detector = sweepDetector {
            let stats = detector.getStatistics()
            averageStrength = stats.averageStrength
            directionBalance = stats.directionBalance
            
            print("   - Cumulative average strength: \(String(format: "%.1f", averageStrength * 100))%")
            print("   - Direction balance: \(String(format: "%.1f", directionBalance * 100))%")
        }
        
        // Compute the score
        var points = scorePerSweep
        
        // Strength bonus
        switch event.strength {
        case .veryStrong:
            points += 10 // +100%
            print("   💪 Very strong! Bonus: +10 pts")
        case .strong:
            points += 5 // +50%
            print("   👍 Strong! Bonus: +5 pts")
        case .medium:
            points += 2 // +20%
            print("   👌 Medium! Bonus: +2 pts")
        case .weak:
            points += 0
            print("   💪 Light, keep going!")
        }
        
        // Direction balance bonus (practice both directions)
        if directionBalance > 0.4 {
            points += 5
            print("   ⚖️ Direction balanced! Bonus: +5 pts")
        }
        
        score += points
        print("   ✓ Score for this one: \(points), total: \(score)")
        
        // Create a ripple
        createWave(from: event)
        
        // Update the water color (based on the average strength)
        updateWaterColor()
        
        // Update the status message
        updateStatusMessage()
    }
    
    // MARK: - Wave Animation
    private func createWave(from event: SweepEvent) {
        // Cap the number of ripples
        if waves.count >= maxWaves {
            waves.removeFirst()
        }
        
        waveIdCounter += 1
        
        let wave = WaveRipple(
            id: waveIdCounter,
            center: CGPoint(x: 0.5, y: 0.5), // Center position
            maxRadius: CGFloat(event.normalizedStrength * 0.8 + 0.2), // 0.2 - 1.0
            color: event.direction == .up ? Color.blue : Color.cyan,
            strength: event.normalizedStrength,
            direction: event.direction
        )
        
        waves.append(wave)
        
        // Remove the ripple automatically once it has expanded
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await MainActor.run {
                if let index = waves.firstIndex(where: { $0.id == wave.id }) {
                    waves.remove(at: index)
                }
            }
        }
    }
    
    private func updateWaterColor() {
        // Adjust the water color based on the average strength
        let hue = 0.55 // Blue base tone
        let saturation = 0.5 + (averageStrength * 0.5)
        let brightness = 0.6 + (averageStrength * 0.4)
        
        withAnimation(.easeInOut(duration: 0.5)) {
            waterColor = Color(hue: hue, saturation: saturation, brightness: brightness)
        }
    }
    
    // MARK: - UI Updates
    private func updateStatusMessage() {
        if !isRunning {
            statusMessage = generateSummary()
            return
        }
        
        if sweepCount == 0 {
            statusMessage = "Start your sweep!"
            return
        }
        
        // Give feedback based on strength
        if averageStrength > 0.7 {
            statusMessage = "💪 Great strength!"
        } else if averageStrength > 0.5 {
            statusMessage = "👍 Good strength!"
        } else if averageStrength > 0.3 {
            statusMessage = "👌 You can put in a bit more strength"
        } else {
            statusMessage = "🎵 Try increasing your strength"
        }
        
        // Direction balance hint
        if sweepCount >= 5 {
            if directionBalance < 0.2 {
                statusMessage += "\nTry practicing both directions"
            } else if directionBalance > 0.4 {
                statusMessage += "\nDirection balance is great!"
            }
        }
    }
    
    private func generateSummary() -> String {
        guard sweepCount > 0 else {
            return "Ready to start"
        }
        
        let minutes = Int(sessionDuration / 60)
        let seconds = Int(sessionDuration.truncatingRemainder(dividingBy: 60))
        
        var summary = "Practice finished!\n"
        summary += "Duration: \(minutes):\(String(format: "%02d", seconds))\n"
        summary += "Sweeps: \(sweepCount) times\n"
        summary += "Up: \(upCount) times | Down: \(downCount) times\n"
        summary += "Average strength: \(String(format: "%.1f", averageStrength * 100))%\n"
        summary += "Score: \(score)"
        
        return summary
    }
    
    // MARK: - Reset
    private func resetSession() {
        sweepCount = 0
        upCount = 0
        downCount = 0
        averageStrength = 0
        directionBalance = 0.5
        score = 0
        waves.removeAll()
        waterColor = .blue
        sessionDuration = 0
        waveIdCounter = 0
        isSweeping = false // ✨ Reset the sweep state
        sweepDetector?.reset()
    }
    
    // MARK: - Idle Timer Management
    
    /// ✨ Reset the idle timer (called on every sweep)
    private func resetIdleTimer() {
        // Cancel the existing task
        idleWorkItem?.cancel()
        
        // Create a new task
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            print("⏸️ Idle timeout (\(self.idleTimeout)s without a sweep), stopping the animation")
            print("   - Current state: isSweeping=\(self.isSweeping)")
            
            self.isSweeping = false
            
            // ✅ Reset the sweep detector and clear its history
            print("   - Resetting SweepDetector history")
            self.sweepDetector?.reset()
            
            print("   - New state: isSweeping=\(self.isSweeping)")
        }
        
        idleWorkItem = workItem
        
        // Execute after a delay on the main thread
        DispatchQueue.main.asyncAfter(deadline: .now() + idleTimeout, execute: workItem)
    }
    
    // MARK: - Timer
    private func startDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let start = self.startTime else { return }
                self.sessionDuration = Date().timeIntervalSince(start)
                
                // ✨ Check whether the target duration has been reached
                if self.targetDuration > 0 && self.sessionDuration >= self.targetDuration {
                    self.stopPractice()
                    self.statusMessage = "🎉 Target duration reached!"
                }
            }
        }
    }
}

// MARK: - WaveRipple
/// Water ripple data model
class WaveRipple: Identifiable, ObservableObject {
    let id: Int
    let center: CGPoint // Normalized coordinates (0-1)
    let maxRadius: CGFloat // Maximum radius (normalized)
    let color: Color
    let strength: Double
    let direction: SweepDirection
    let createdAt: Date // ✨ New: creation time
    
    /// ✨ Current expansion progress (0-1), computed from time
    var progress: Double {
        let elapsed = Date().timeIntervalSince(createdAt)
        let duration = 2.0 // Expansion completes in 2 seconds
        return min(1.0, elapsed / duration)
    }
    
    /// ✨ Opacity (decreases as progress increases)
    var opacity: Double {
        return max(0, 1.0 - progress)
    }
    
    init(id: Int, center: CGPoint, maxRadius: CGFloat, color: Color, strength: Double, direction: SweepDirection) {
        self.id = id
        self.center = center
        self.maxRadius = maxRadius
        self.color = color
        self.strength = strength
        self.direction = direction
        self.createdAt = Date()
    }
}
