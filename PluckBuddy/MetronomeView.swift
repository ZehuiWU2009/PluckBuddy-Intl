//
//  MetronomeView.swift
//  PluckBuddy
//
//  Metronome visualization components
//  Created on 2026/8/29.
//

import SwiftUI

// MARK: - Main Metronome View

/// Metronome top bar (simplified version - display and control only)
struct MetronomeBar: View {
    @ObservedObject var metronome: MetronomeManager
    let targetBPM: Int  // ✨ Read-only, displays the target tempo
    
    var body: some View {
        HStack(spacing: 16) {
            // Beat lights
            BeatIndicatorView(
                currentBeat: metronome.currentBeat,
                totalBeats: metronome.beatsPerMeasure,
                isPlaying: metronome.isPlaying
            )
            .frame(width: 100)
            
            Spacer()
            
            // BPM display (read-only)
            VStack(spacing: 4) {
                Text("\(targetBPM)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                
                Text("BPM")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 80)
            
            Spacer()
            
            // Play/pause button
            Button(action: { metronome.toggle() }) {
                Image(systemName: metronome.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(metronome.isPlaying ? Color.orange : Color.green)
                    .clipShape(Circle())
                    .shadow(color: (metronome.isPlaying ? Color.orange : Color.green).opacity(0.3), radius: 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Beat Indicator

/// Beat light indicator (shows 4 lights)
struct BeatIndicatorView: View {
    let currentBeat: Int
    let totalBeats: Int
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalBeats, id: \.self) { beat in
                Circle()
                    .fill(beatColor(for: beat))
                    .frame(width: 16, height: 16)
                    .shadow(
                        color: beatColor(for: beat).opacity(0.5),
                        radius: currentBeat == beat && isPlaying ? 6 : 0
                    )
                    .scaleEffect(currentBeat == beat && isPlaying ? 1.2 : 1.0)
                    .animation(.spring(response: 0.2), value: currentBeat)
            }
        }
    }
    
    private func beatColor(for beat: Int) -> Color {
        if !isPlaying {
            return Color.gray.opacity(0.3)
        }
        
        if beat == currentBeat {
            // Highlight the current beat
            return beat == 1 ? .red : .green
        } else {
            // Dim the other beats
            return Color.gray.opacity(0.3)
        }
    }
}

// MARK: - Compact Metronome (for space-constrained layouts)

/// Compact metronome button
struct CompactMetronomeButton: View {
    @ObservedObject var metronome: MetronomeManager
    
    var body: some View {
        Button(action: { metronome.isEnabled.toggle() }) {
            HStack(spacing: 8) {
                Image(systemName: "metronome")
                    .foregroundStyle(metronome.isEnabled ? .green : .secondary)
                
                if metronome.isEnabled {
                    Text("\(metronome.bpm)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(metronome.isEnabled ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Preview

#Preview("Metronome Bar") {
    VStack {
        MetronomeBar(metronome: MetronomeManager(), targetBPM: 120)
            .padding()
        
        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}

#Preview("Compact Button") {
    CompactMetronomeButton(metronome: MetronomeManager())
        .padding()
}
