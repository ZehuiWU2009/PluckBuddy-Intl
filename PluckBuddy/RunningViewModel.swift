//
//  RunningViewModel.swift
//  PluckBuddy
//
//  Created by Zehui Wu on 2026/7/16.
//

import Foundation
import AVFoundation
import Combine
import SwiftUI

@MainActor
class RunningViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRunning = false
    @Published var distance: Double = 0.0 // Running distance (m)
    @Published var pluckCount: Int = 0 // Pluck count
    @Published var currentBPM: Double = 0 // Current speed
    @Published var stability: Double = 0 // Stability 0-1
    @Published var score: Int = 0 // Score
    @Published var statusMessage = "Ready to start"
    @Published var targetBPM: Double = 120 // Target speed
    @Published var sessionDuration: TimeInterval = 0 // Current practice duration (s)
    @Published var targetDuration: TimeInterval = 300 // Target duration (default 5 minutes)

    // Character animation state
    @Published var characterPosition: Double = 0.0 // Character position (0-1) - deprecated, the track moves instead
    @Published var isCharacterRunning = false
    @Published var isPlucking: Bool = false // Whether the user is playing (drives the animation)
    
    // Track animation state
    @Published var trackOffset: Double = 0.0 // Track offset (for the scrolling effect)
    @Published var runningSpeed: Double = 0.0 // Running speed (pixels/sec)
    
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
    private var rhythmDetector: RhythmDetector?
    private var startTime: Date?
    private var durationTimer: Timer? // Used to update the elapsed time
    private var idleWorkItem: DispatchWorkItem? // Used to detect idle (no playing)
    private var cancellables = Set<AnyCancellable>() // ✨ Combine subscriptions
    
    // MARK: - Constants
    private let distancePerPluck: Double = 1.0 // Move 1 m forward per pluck
    private let scorePerPluck: Int = 10 // Score per pluck
    private let bonusThreshold: Double = 0.8 // Stability bonus threshold
    private let idleTimeout: TimeInterval = 2.0 // Idle timeout: 2 s without playing counts as stopped
    
    // MARK: - Initialization
    init() {
        print("🏃 RunningViewModel init() start")
        // ✨ Set the initial metronome speed (synchronous, since it is only an assignment)
        metronome.bpm = Int(targetBPM)
        print("🏃 RunningViewModel - metronome speed set")
        
        // ✨ Defer setting up subscriptions so they do not block init
        DispatchQueue.main.async {
            print("🏃 RunningViewModel - setting up BPM sync")
            self.setupBPMSync()
        }
        print("🏃 RunningViewModel init() done")
    }
    
    // ✨ Set up BPM sync (deferred call)
    private func setupBPMSync() {
        // Observe targetBPM changes and sync the metronome automatically
        $targetBPM
            .dropFirst() // Skip the initial value to avoid setting it twice
            .sink { [weak self] newBPM in
                self?.metronome.bpm = Int(newBPM)
                print("🎯 Target speed changed to \(Int(newBPM)) BPM, metronome synced")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Lifecycle
    func startPractice() {
        Task { [weak self] in
            guard let self = self else { return }
            print("🎵 Starting practice...")
            
            // Request microphone permission
            audioManager = AudioManager.shared
            guard let manager = audioManager else {
                print("❌ AudioManager failed to initialize")
                return
            }
            
            print("🎤 Requesting microphone permission...")
            let hasPermission = await manager.requestMicrophonePermission()
            guard hasPermission else {
                print("❌ Microphone permission denied")
                statusMessage = "Microphone permission required"
                return
            }
            print("✅ Microphone permission granted")
            
            // Initialize the rhythm detector
            rhythmDetector = RhythmDetector(sampleRate: 48000.0)
            rhythmDetector?.onPluckDetected = { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handlePluckEvent(event)
                }
            }
            print("✅ Rhythm detector initialized")
            
            // Reset state
            resetSession()
            
            // Start audio monitoring
            do {
                print("🎧 Starting audio monitoring...")
                try manager.startListening { [weak self] buffer, _ in
                    guard let self = self,
                          let detector = self.rhythmDetector else { return }
                    
                    // ✅ The DSP heuristic gate was rolled back (unstable in testing); hand the buffer straight to the rhythm detector
                    _ = detector.detectPluck(from: buffer)
                }
                
                print("✅ Audio monitoring started")
                isRunning = true
                startTime = Date()
                statusMessage = "Start playing!"
                
                // ✨ Auto-start the metronome when it is enabled
                if metronome.isEnabled {
                    metronome.start()
                    print("🎵 Metronome started automatically")
                }
                
                // Start the duration timer
                startDurationTimer()
                
            } catch {
                print("❌ Failed to start audio: \(error.localizedDescription)")
                statusMessage = "Audio failed to start"
            }
        }
    }
    
    func stopPractice() {
        audioManager?.stopListening()
        isRunning = false
        isCharacterRunning = false
        isPlucking = false // Reset the playing state
        
        // ✨ Stop the metronome
        metronome.stop()
        
        // Stop the duration timer
        stopDurationTimer()
        
        // Cancel the idle task
        idleWorkItem?.cancel()
        idleWorkItem = nil
        
        if let start = startTime {
            sessionDuration = Date().timeIntervalSince(start)
            
            // Save the practice record
            if pluckCount > 0 {
                PracticeDataManager.shared.saveRunningSession(
                    duration: sessionDuration,
                    pluckCount: pluckCount,
                    averageBPM: currentBPM,
                    stability: stability,
                    distance: distance,
                    score: score
                )
            }
        }
        
        updateStatusMessage()
    }
    
    // MARK: - Event Handling
    private func handlePluckEvent(_ event: PluckEvent) {
        guard isRunning else { return }
        // 🔍 Add debug logging
        print("🎸 Playing detected!")
        print("   - BPM: \(String(format: "%.1f", event.bpm))")
        print("   - Strength: \(String(format: "%.2f", event.amplitude))")
        print("   - RMS: \(String(format: "%.2f", event.rms))")
        print("   - Interval: \(String(format: "%.3f", event.interval))s")
        print("   - Pluck count: \(pluckCount + 1)")
        print("   - Current state: isPlucking=\(isPlucking), currentBPM=\(String(format: "%.1f", currentBPM))")
        
        // Mark as currently playing
        isPlucking = true
        print("   ✓ Setting isPlucking = true")
        
        // Reset the idle timer
        resetIdleTimer()
        
        // Update statistics
        pluckCount += 1
        distance += distancePerPluck
        
        // Update speed and stability
        let oldBPM = currentBPM
        currentBPM = event.bpm
        print("   ✓ currentBPM updated: \(String(format: "%.1f", oldBPM)) → \(String(format: "%.1f", currentBPM))")
        
        stability = rhythmDetector?.calculateStability() ?? 0
        
        print("   - Current stability: \(Int(stability * 100))%")
        
        // Compute the score
        var points = scorePerPluck
        
        // Stability bonus
        if stability > bonusThreshold {
            points += Int(Double(scorePerPluck) * 0.5) // +50% bonus
        }
        
        // Speed match bonus
        let bpmDiff = abs(currentBPM - targetBPM)
        if bpmDiff < 5 {
            points += Int(Double(scorePerPluck) * 0.3) // +30% bonus
        }
        
        score += points
        
        // Update the character animation
        triggerCharacterStep()
        
        // Update the status message
        updateStatusMessage()
    }
    
    // MARK: - Idle Timer Management
    
    /// Reset the idle timer (called on every pluck)
    private func resetIdleTimer() {
        // Cancel the existing task
        idleWorkItem?.cancel()
        
        // Create a new task
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            print("⏸️ Idle timeout (\(self.idleTimeout)s without playing), stopping the animation")
            print("   - Current state: isPlucking=\(self.isPlucking), BPM=\(self.currentBPM)")
            
            self.isPlucking = false
            self.currentBPM = 0
            
            // ✅ Reset the rhythm detector and clear its history
            print("   - Resetting RhythmDetector history")
            self.rhythmDetector?.reset()
            
            print("   - New state: isPlucking=\(self.isPlucking), BPM=\(self.currentBPM)")
        }
        
        idleWorkItem = workItem
        
        // Execute after a delay on the main thread
        DispatchQueue.main.asyncAfter(deadline: .now() + idleTimeout, execute: workItem)
    }
    
    // MARK: - Animation
    private func triggerCharacterStep() {
        isCharacterRunning = true
        
        // Compute the running speed (based on BPM)
        // BPM 60 -> 50 pixels/sec
        // BPM 180 -> 300 pixels/sec
        let speedMultiplier = currentBPM / 60.0
        runningSpeed = 50.0 * speedMultiplier
        
        // Stop the running animation after a short delay (the limb swing keeps going)
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            await MainActor.run {
                isCharacterRunning = false
            }
        }
    }
    
    // MARK: - UI Updates
    private func updateStatusMessage() {
        if !isRunning {
            statusMessage = generateSummary()
            return
        }
        
        if pluckCount == 0 {
            statusMessage = "Start playing!"
            return
        }
        
        // Give feedback based on stability
        if stability > 0.9 {
            statusMessage = "🎉 Very steady rhythm!"
        } else if stability > 0.7 {
            statusMessage = "👍 Good rhythm, keep it up!"
        } else if stability > 0.5 {
            statusMessage = "💪 Keep practicing, try to be steadier"
        } else {
            statusMessage = "🎵 Try playing at a steady tempo"
        }
        
        // Speed hint
        let bpmDiff = currentBPM - targetBPM
        if abs(bpmDiff) > 20 {
            if bpmDiff > 0 {
                statusMessage += " (a little slower)"
            } else {
                statusMessage += " (you can go faster)"
            }
        }
    }
    
    private func generateSummary() -> String {
        guard pluckCount > 0 else {
            return "Ready to start"
        }
        
        let minutes = Int(sessionDuration / 60)
        let seconds = Int(sessionDuration.truncatingRemainder(dividingBy: 60))
        
        var summary = "Practice finished!\n"
        summary += "Duration: \(minutes):\(String(format: "%02d", seconds))\n"
        summary += "Plucks: \(pluckCount) times\n"
        summary += "Distance: \(Int(distance)) m\n"
        summary += "Score: \(score)"
        
        return summary
    }
    
    // MARK: - Reset
    private func resetSession() {
        distance = 0
        pluckCount = 0
        currentBPM = 0
        stability = 0
        score = 0
        characterPosition = 0
        trackOffset = 0
        runningSpeed = 0
        sessionDuration = 0
        rhythmDetector?.reset()
    }
    
    // MARK: - Timer Management
    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let start = self.startTime else { return }
                self.sessionDuration = Date().timeIntervalSince(start)
                
                // Check whether the target duration has been reached
                if self.sessionDuration >= self.targetDuration {
                    print("⏰ Time is up! Stopping automatically")
                    self.stopPractice()
                }
            }
        }
    }
    
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
    
    // MARK: - Settings
    func setTargetBPM(_ bpm: Double) {
        targetBPM = max(60, min(200, bpm)) // Clamped to 60-200 BPM
    }
}
