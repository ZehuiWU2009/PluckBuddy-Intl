//
//  FlowerViewModel.swift
//  PluckBuddy
//
//  Created by Zehui Wu on 2026/7/16.
//

import Foundation
import AVFoundation
import Combine
import SwiftUI

@MainActor
class FlowerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRunning = false
    @Published var rollCount: Int = 0 // Tremolo count
    @Published var sequenceCount: Int = 0 // Number of completed tremolo sequences
    @Published var currentSpeed: Double = 0 // Current speed (times/sec)
    @Published var averageSpeed: Double = 0 // Average speed
    @Published var uniformity: Double = 0 // Evenness 0-1
    @Published var score: Int = 0 // Score
    @Published var statusMessage = "Ready to start"
    @Published var sessionDuration: TimeInterval = 0 // Current practice duration (s)
    @Published var targetDuration: TimeInterval = 300 // Target duration (default 5 minutes)
    @Published var targetBPM: Double = 120 // ✨ New: target speed (BPM)

    // Flower state
    @Published var flowerGrowth: Double = 0.0 // Flower growth progress 0-1
    @Published var petalCount: Int = 0 // Current petal count
    @Published var flowerBrightness: Double = 0.5 // Flower brightness (based on speed)
    @Published var flowerSymmetry: Double = 1.0 // Flower symmetry (based on evenness)
    @Published var isRolling: Bool = false // Whether tremolo is in progress (drives the animation)
    @Published var lastSequenceQuality: RollSequence.Quality? // Quality of the most recently completed sequence
    @Published var pulseCounter: Int = 0 // ✨ New: petal pulse counter
    
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
    private var rollDetector: RollDetector?
    private var startTime: Date?
    private var durationTimer: Timer? // Used to update the elapsed time
    private var idleWorkItem: DispatchWorkItem? // Used to detect idle (no tremolo)
    private var completedSequences: [RollSequence] = []
    
    // MARK: - Constants
    private let maxPetals = 8 // At most 8 petals
    private let notesPerPetal = 5 // One petal grows every 5 notes
    private let scorePerNote: Int = 5 // Base score per note
    private let scorePerSequence: Int = 50 // Bonus score per complete sequence
    private let idleTimeout: TimeInterval = 2.0 // Idle timeout: 2 s without tremolo counts as stopped
    
    // MARK: - Lifecycle
    func startPractice() {
        Task {
            print("🌸 Starting tremolo practice...")
            
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
            
            // Initialize the tremolo detector
            rollDetector = RollDetector(sampleRate: 44100.0)
            
            rollDetector?.onRollDetected = { [weak self] event in
                Task { @MainActor in
                    self?.handleRollEvent(event)
                }
            }
            
            rollDetector?.onRollSequenceComplete = { [weak self] sequence in
                Task { @MainActor in
                    self?.handleSequenceComplete(sequence)
                }
            }
            print("✅ Tremolo detector initialized")
            
            // Reset state
            resetSession()
            
            // Start audio monitoring
            do {
                print("🎧 Starting audio monitoring...")
                try manager.startListening { [weak self] buffer, _ in
                    guard let self = self,
                          let detector = self.rollDetector else { return }
                    
                    // ✅ The DSP heuristic gate was rolled back (unstable in testing); hand the buffer straight to the tremolo detector
                    _ = detector.detectRoll(from: buffer)
                }
                
                print("✅ Audio monitoring started")
                isRunning = true
                startTime = Date()
                statusMessage = "Start your tremolo!"
                
                // ✨ Auto-start the metronome when it is enabled
                if metronome.isEnabled {
                    // Sync the metronome speed to the target BPM
                    metronome.bpm = Int(targetBPM)
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
        // Finish the current sequence
        rollDetector?.finishSequence()
        
        audioManager?.stopListening()
        isRunning = false
        isRolling = false // Reset the tremolo state
        
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
            if rollCount > 0 {
                print("💾 Saving practice record...")
                print("   - Duration: \(String(format: "%.1f", sessionDuration))s")
                print("   - Tremolo count: \(rollCount)")
                print("   - Average speed: \(String(format: "%.1f", averageSpeed)) times/sec")
                print("   - Score: \(score)")
                
                PracticeDataManager.shared.saveFlowerSession(
                    duration: sessionDuration,
                    rollCount: rollCount,
                    rollSpeed: averageSpeed,
                    score: score
                )
            }
        }
        
        updateStatusMessage()
    }
    
    // MARK: - Event Handling
    private func handleRollEvent(_ event: RollEvent) {
        guard isRunning else { return }
        
        // 🔍 Add debug logging
        print("🎵 Tremolo note detected!")
        print("   - Sequence length: \(event.sequenceLength)")
        print("   - Current speed: \(String(format: "%.1f", event.currentSpeed)) times/sec")
        print("   - Amplitude: \(String(format: "%.2f", event.note.amplitude))")
        print("   - Interval: \(String(format: "%.3f", event.note.interval))s")
        print("   - Valid sequence: \(event.isValidSequence ? "Yes" : "No")")
        
        // ✨ Fix: mark tremolo as active and increment the pulse counter
        let wasRolling = isRolling
        isRolling = true
        
        if !wasRolling {
            print("   ✓ Starting a new tremolo motion: isRolling = true")
        }
        
        // ✨ Increment the pulse counter on every detected note
        pulseCounter += 1
        print("   ✓ Triggering petal pulse #\(pulseCounter)")
        
        // Reset the idle timer
        resetIdleTimer()
        
        // Update statistics
        rollCount += 1
        let oldSpeed = currentSpeed
        currentSpeed = event.currentSpeed
        print("   ✓ Speed updated: \(String(format: "%.1f", oldSpeed)) → \(String(format: "%.1f", currentSpeed)) times/sec")
        
        // Base score
        score += scorePerNote
        
        // Update flower growth
        updateFlowerGrowth()
        
        // Update the status message
        updateStatusMessage()
    }
    
    private func handleSequenceComplete(_ sequence: RollSequence) {
        guard isRunning else { return }
        
        print("🎊 Tremolo sequence complete!")
        print("   - Note count: \(sequence.noteCount)")
        print("   - Duration: \(String(format: "%.2f", sequence.duration))s")
        print("   - Average speed: \(String(format: "%.1f", sequence.averageSpeed)) times/sec")
        print("   - Evenness: \(Int(sequence.uniformity * 100))%")
        print("   - Quality rating: \(sequence.quality.emoji) \(sequence.quality.description)")
        
        // Record the sequence
        completedSequences.append(sequence)
        sequenceCount += 1
        lastSequenceQuality = sequence.quality
        
        // Update the average speed
        averageSpeed = completedSequences.map { $0.averageSpeed }.reduce(0, +) / Double(completedSequences.count)
        
        // Update the evenness
        uniformity = completedSequences.map { $0.uniformity }.reduce(0, +) / Double(completedSequences.count)
        
        print("   - Cumulative average speed: \(String(format: "%.1f", averageSpeed)) times/sec")
        print("   - Cumulative evenness: \(Int(uniformity * 100))%")
        
        // Sequence bonus score
        var bonusScore = scorePerSequence
        
        // Quality bonus
        switch sequence.quality {
        case .excellent:
            bonusScore = Int(Double(bonusScore) * 2.0) // 2x
            print("   🌟 Excellent! Bonus: \(bonusScore) pts")
        case .good:
            bonusScore = Int(Double(bonusScore) * 1.5) // 1.5x
            print("   👍 Good! Bonus: \(bonusScore) pts")
        case .fair:
            bonusScore = Int(Double(bonusScore) * 1.0) // 1x
            print("   👌 Fair! Bonus: \(bonusScore) pts")
        case .needsImprovement:
            bonusScore = Int(Double(bonusScore) * 0.5) // 0.5x
            print("   💪 Keep going! Bonus: \(bonusScore) pts")
        }
        
        score += bonusScore
        
        // Update the flower attributes
        updateFlowerAttributes()
        
        // Special feedback
        if sequence.quality == .excellent {
            // An excellent tremolo makes the flower bloom fully
            print("   ✨ Triggering the flower bloom animation!")
            triggerFlowerBloom()
        }
    }
    
    // MARK: - Flower Animation
    private func updateFlowerGrowth() {
        // Each note adds growth progress
        let growthPerNote = 1.0 / Double(maxPetals * notesPerPetal)
        flowerGrowth = min(1.0, flowerGrowth + growthPerNote)
        
        // Compute the petal count
        petalCount = min(maxPetals, rollCount / notesPerPetal)
    }
    
    private func updateFlowerAttributes() {
        // Brightness is based on speed (the faster, the brighter)
        flowerBrightness = min(1.0, max(0.3, currentSpeed / 15.0))
        
        // Symmetry is based on evenness
        flowerSymmetry = uniformity
    }
    
    private func triggerFlowerBloom() {
        // Trigger the bloom animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            flowerGrowth = 1.0
            flowerBrightness = 1.0
        }
        
        // Reset after a short delay, ready for the next flower
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await MainActor.run {
                if isRunning {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        flowerGrowth = 0.0
                        petalCount = 0
                    }
                }
            }
        }
    }
    
    // MARK: - UI Updates
    private func updateStatusMessage() {
        if !isRunning {
            statusMessage = generateSummary()
            return
        }
        
        if rollCount == 0 {
            statusMessage = "Start your tremolo!"
            return
        }
        
        // Give feedback based on the latest sequence quality
        if let quality = lastSequenceQuality {
            switch quality {
            case .excellent:
                statusMessage = "🌟 Perfect tremolo! Keep it up!"
            case .good:
                statusMessage = "👍 Good tremolo, a bit faster would be even better!"
            case .fair:
                statusMessage = "👌 Keep practicing, mind your evenness"
            case .needsImprovement:
                statusMessage = "💪 Relax your fingers and keep an even tempo"
            }
            return
        }
        
        // Give feedback based on the current speed
        if currentSpeed >= 12 {
            statusMessage = "🚀 Very fast!"
        } else if currentSpeed >= 10 {
            statusMessage = "👍 Good speed!"
        } else if currentSpeed >= 8 {
            statusMessage = "👌 Keep it up!"
        } else if currentSpeed >= 6 {
            statusMessage = "💪 You can go a bit faster"
        } else if currentSpeed > 0 {
            statusMessage = "🎵 Try a faster tremolo"
        } else {
            statusMessage = "Waiting for tremolo..."
        }
        
        // Evenness hint
        if uniformity > 0 && uniformity < 0.5 {
            statusMessage += "\nTry keeping every note interval consistent"
        }
    }
    
    private func generateSummary() -> String {
        guard rollCount > 0 else {
            return "Ready to start"
        }
        
        let minutes = Int(sessionDuration / 60)
        let seconds = Int(sessionDuration.truncatingRemainder(dividingBy: 60))
        
        var summary = "Practice finished!\n"
        summary += "Duration: \(minutes):\(String(format: "%02d", seconds))\n"
        summary += "Tremolo: \(rollCount) times\n"
        summary += "Sequences: \(sequenceCount)\n"
        summary += "Average speed: \(String(format: "%.1f", averageSpeed)) times/sec\n"
        summary += "Score: \(score)"
        
        return summary
    }
    
    // MARK: - Reset
    private func resetSession() {
        rollCount = 0
        sequenceCount = 0
        currentSpeed = 0
        averageSpeed = 0
        uniformity = 0
        score = 0
        flowerGrowth = 0
        petalCount = 0
        flowerBrightness = 0.5
        flowerSymmetry = 1.0
        sessionDuration = 0
        isRolling = false
        lastSequenceQuality = nil
        pulseCounter = 0 // ✨ Reset the pulse counter
        completedSequences.removeAll()
        rollDetector?.reset()
    }
    
    // MARK: - Idle Timer Management
    
    /// Reset the idle timer (called on every tremolo)
    private func resetIdleTimer() {
        // Cancel the existing task
        idleWorkItem?.cancel()
        
        // Create a new task
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            print("⏸️ Idle timeout (\(self.idleTimeout)s without tremolo), stopping the animation")
            print("   - Current state: isRolling=\(self.isRolling), speed=\(self.currentSpeed)")
            
            self.isRolling = false
            self.currentSpeed = 0
            
            // ✅ Reset the tremolo detector and clear its history
            print("   - Resetting RollDetector history")
            self.rollDetector?.reset()
            
            print("   - New state: isRolling=\(self.isRolling), speed=\(self.currentSpeed)")
        }
        
        idleWorkItem = workItem
        
        // Execute after a delay on the main thread
        DispatchQueue.main.asyncAfter(deadline: .now() + idleTimeout, execute: workItem)
    }
    
    // MARK: - Timer Management
    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startTime else { return }
            Task { @MainActor in
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
    func setTargetDuration(_ duration: TimeInterval) {
        targetDuration = max(60, min(1800, duration)) // Clamped to 1-30 minutes
    }
}
