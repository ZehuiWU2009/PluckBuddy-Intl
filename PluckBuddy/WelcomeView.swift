//
//  WelcomeView.swift
//  PluckBuddy
//
//  Created by Zehui Wu on 2026/9/29.
//
//  Launch screen. Shows the PluckBuddy brand mark and the daily practice prompt,
//  then automatically enters the main screen after a 3-second countdown; the "Skip 3" button in the top-right corner enters immediately.
//

import SwiftUI

/// Launch screen: centers logo-English, the practice prompt, the feature subtitle and the developer info at the bottom,
/// then automatically enters the main screen after a 3-second countdown; the "Skip 3" button in the top-right corner enters immediately.
///
/// logo-English.png ships with a cream background (RGB 254/253/241) and is fully opaque, so the page uses the same color value,
/// letting the image edges blend seamlessly into the page. Entering and leaving animates opacity only, avoiding visible color-block borders.
struct WelcomeView: View {
    /// Cream white matching the logo background color
    static let brandBackground = Color(red: 254.0 / 255.0, green: 253.0 / 255.0, blue: 241.0 / 255.0)
    /// Brand dark purple, used for the prompt text and the skip button
    private static let brandPurple = Color(red: 0.30, green: 0.24, blue: 0.55)
    
    /// Called when "Skip" is tapped or the countdown ends, to enter the main screen
    let onEnter: () -> Void
    
    @State private var appeared = false
    /// Whether the exit animation is running, so the countdown and "Skip" cannot both trigger the exit
    @State private var isDismissing = false
    /// Countdown in the top-right corner, decrements every second
    @State private var remaining = 3
    
    var body: some View {
        // No alignment on the ZStack: the content stays centered as a whole.
        // Using .topTrailing previously pushed the not-full-width VStack to the right, shifting the logo off center.
        ZStack {
            Self.brandBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                
                // Brand mark
                Image("LogoEnglish")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 320)
                    .padding(.horizontal, 24)
                
                // Practice prompt
                Text("Let's practice for 5 minutes today!")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Self.brandPurple)
                    .padding(.top, 4)
                
                // Feature subtitle
                Text("Pipa practice partner · AI fingering analysis · Smart Tuner")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Self.brandPurple.opacity(0.6))
                    .padding(.top, 6)
                
                Spacer(minLength: 0)
                
                // Developer info
                VStack(spacing: 3) {
                    Text("Developer: Zehui Wu")
                    Text("School: Cogdel Cranleigh High School Wuhan")
                }
                .font(.system(size: 12))
                .foregroundStyle(Self.brandPurple.opacity(0.55))
                .padding(.bottom, 40)
            }
            // Fills the full width; the inner text centers itself and is not affected by the ZStack alignment
            .frame(maxWidth: .infinity)
            .scaleEffect(appeared ? 1 : 0.94)
            .opacity(appeared ? 1 : 0)
        }
        .overlay(alignment: .topTrailing) {
            skipButton
                .padding(.top, 8)
                .padding(.trailing, 20)
                .opacity(appeared ? 1 : 0)
        }
        .task {
            withAnimation(.easeOut(duration: 0.7)) {
                appeared = true
            }
            // Counts down second by second, fades out and enters the main screen at zero; the task is cancelled when the view disappears, so it never fires twice
            while remaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                remaining -= 1
            }
            beginDismiss()
        }
    }
    
    /// Exits the welcome page: fades this page out first (opacity + slight scale), then asks the parent view to remove it once the animation ends.
    /// The onEnter closure is copied for the async call to avoid capturing the view struct itself.
    private func beginDismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        let enter = onEnter
        withAnimation(.easeInOut(duration: 0.5)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            enter()
        }
    }

    /// The "Skip 3" capsule button in the top-right corner; tapping it enters the main screen immediately
    private var skipButton: some View {
        Button(action: beginDismiss) {
            HStack(spacing: 4) {
                Text("Skip")
                Text("\(remaining)")
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: remaining)
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Self.brandPurple)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.white.opacity(0.9)))
            .overlay(
                Capsule()
                    .stroke(Self.brandPurple.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WelcomeView { }
}
