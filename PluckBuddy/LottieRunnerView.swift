//
//  LottieRunnerView.swift
//  PluckBuddy
//
//  Lottie running animation view
//

import SwiftUI
import Lottie

struct LottieRunnerView: View {
    let isRunning: Bool  // Whether the user is playing (controls the animation)
    let currentBPM: Double
    
    @State private var animationPhase: Double = 0
    
    // Compute the playback speed from the BPM
    private var animationSpeed: CGFloat {
        guard currentBPM > 0 else { return 1.0 }
        return CGFloat(currentBPM / 120.0)
    }
    
    var body: some View {
        ZStack {
            // Try to load the Lottie animation
            if let animation = LottieAnimation.named("running_man") {
                // Use the Lottie animation
                LottieViewWrapper(
                    animation: animation,
                    isRunning: isRunning,
                    speed: animationSpeed
                )
                .frame(width: 200, height: 200)
            } else {
                // Fallback: use an SF Symbol
                VStack(spacing: 8) {
                    Image(systemName: isRunning ? "figure.run" : "figure.stand")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(isRunning ? animationPhase * 10 : 0))
                        .offset(y: isRunning ? sin(animationPhase * .pi * 2) * 5 : 0)
                    
                    // Hint text
                    Text(isRunning ? "Running..." : "Waiting...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            print("✅ LottieRunnerView loaded")
            checkAnimation()
        }
        // Observe playing state changes
        .onChange(of: isRunning) { _, newValue in
            print("🎬 LottieRunnerView.isRunning: \(newValue), BPM: \(currentBPM)")
            
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
        // Observe speed changes
        .onChange(of: currentBPM) { oldValue, newValue in
            print("🎵 LottieRunnerView.currentBPM: \(String(format: "%.1f", oldValue)) → \(String(format: "%.1f", newValue)), isRunning: \(isRunning)")
            
            if isRunning && newValue > 0 {
                print("   → Restart the animation")
                startAnimation()
            } else if isRunning && newValue == 0 {
                print("   ⚠️ isRunning=true but BPM=0")
            }
        }
    }
    
    private func startAnimation() {
        guard currentBPM > 0 else {
            print("   ⚠️ BPM=0, skipping the animation")
            return
        }
        
        let duration = max(0.3, 60.0 / currentBPM)
        print("   ✓ Preparing to start the animation, period: \(String(format: "%.2f", duration))s, current phase: \(String(format: "%.2f", animationPhase))")
        
        // Stop any existing animation completely first
        withAnimation(.linear(duration: 0)) {
            animationPhase = 0
        }
        
        // Wait for SwiftUI to clean up the animation (critical!)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            print("   → Starting after the delay, BPM: \(String(format: "%.1f", self.currentBPM))")
            guard self.currentBPM > 0 else {
                print("   ⚠️ BPM=0 after the delay, cancelling start")
                return
            }
            
            let newDuration = max(0.3, 60.0 / self.currentBPM)
            withAnimation(.linear(duration: newDuration).repeatForever(autoreverses: false)) {
                self.animationPhase = 1.0
            }
            print("   ✓ Animation started!")
        }
    }
    
    // Stop the animation
    private func stopAnimation() {
        print("   ✓ Animation stopped")
        
        // Explicitly stop the repeatForever animation
        withAnimation(.linear(duration: 0)) {
            animationPhase = 0
        }
    }
    
    private func checkAnimation() {
        if LottieAnimation.named("running_man") == nil {
            print("⚠️ Warning: running_man.json animation file not found, using the fallback icon")
        } else {
            print("✅ Lottie animation loaded successfully")
        }
    }
}

// MARK: - Lottie View Wrapper (using UIViewRepresentable)
struct LottieViewWrapper: UIViewRepresentable {
    let animation: LottieAnimation
    let isRunning: Bool
    let speed: CGFloat
    
    // Use a Coordinator to track state changes
    class Coordinator {
        var lastIsRunning: Bool = false
        var lastSpeed: CGFloat = 0
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView(animation: animation)
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .loop
        animationView.backgroundBehavior = .pauseAndRestore
        
        // Use a transparent background (for animations with transparency)
        animationView.backgroundColor = .clear
        
        return animationView
    }
    
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        let coordinator = context.coordinator
        let wasRunning = coordinator.lastIsRunning
        let speedChanged = abs(coordinator.lastSpeed - speed) > 0.1
        
        print("      🎬 LottieViewWrapper.updateUIView - isRunning:\(wasRunning)→\(isRunning), speed:\(String(format: "%.1f", speed)), isPlaying:\(uiView.isAnimationPlaying), progress:\(String(format: "%.2f", uiView.currentProgress))")
        
        // Update the playback speed
        let newSpeed = max(0.5, min(3.0, speed))
        if abs(uiView.animationSpeed - newSpeed) > 0.01 {
            print("      → Updating speed: \(uiView.animationSpeed) → \(newSpeed)")
            uiView.animationSpeed = newSpeed
        }
        
        // Control playback based on the playing state
        if isRunning {
            // Detect the transition from stopped to running (critical!)
            if !wasRunning {
                print("      → Lottie resuming from the stopped state, forcing a full reset and play")
                // Stop completely
                uiView.stop()
                // Reset to the beginning
                uiView.currentProgress = 0
                // Play again
                uiView.play(fromProgress: 0, toProgress: 1, loopMode: .loop) { finished in
                    if !finished {
                        print("      ⚠️ Lottie playback was interrupted")
                    }
                }
                print("      ✓ Lottie play() called")
            } else if !uiView.isAnimationPlaying {
                print("      → Lottie is not playing, starting playback")
                uiView.play()
            } else if speedChanged {
                print("      → Lottie speed changed \(String(format: "%.1f", coordinator.lastSpeed)) → \(String(format: "%.1f", speed)), replaying")
                uiView.stop()
                uiView.currentProgress = 0
                uiView.play()
            } else {
                print("      → Lottie is playing normally")
            }
        } else {
            // Stop and return to the first frame
            if uiView.isAnimationPlaying || uiView.currentProgress > 0 {
                print("      → Lottie stopped and reset")
                uiView.stop()
                uiView.currentProgress = 0
            }
        }
        
        // Update the recorded state
        coordinator.lastIsRunning = isRunning
        coordinator.lastSpeed = speed
    }
}

#Preview {
    LottieRunnerView(isRunning: true, currentBPM: 120)
        .frame(width: 300, height: 300)
        .background(Color.gray.opacity(0.2))
}
