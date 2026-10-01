//
//  WaveSettingsSheet.swift
//  PluckBuddy
//
//  Created on 2026/8/31.
//

import SwiftUI

struct WaveSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var targetBPM: Double
    @Binding var targetDuration: TimeInterval
    @Binding var metronomeEnabled: Bool
    @Binding var metronomeSoundType: MetronomeSoundType
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Goal settings
                Section {
                    // Target speed (BPM) - sweeps are usually slower
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Target Speed")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(targetBPM)) BPM")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.cyan)
                        }
                        
                        Slider(value: $targetBPM, in: 36...220, step: 1)
                            .tint(.cyan)
                        
                        HStack {
                            Text("36")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("220")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Speed suggestion
                        HStack(spacing: 4) {
                            Image(systemName: "lightbulb.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                            Text(speedSuggestion)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                    
                    // Target duration
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Target Duration")
                                .font(.headline)
                            Spacer()
                            if targetDuration > 0 {
                                Text(durationText)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green)
                            } else {
                                Text("Unlimited")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Picker("Duration", selection: $targetDuration) {
                            Text("Unlimited").tag(TimeInterval(0))
                            Text("1 min").tag(TimeInterval(60))
                            Text("3 min").tag(TimeInterval(180))
                            Text("5 min").tag(TimeInterval(300))
                            Text("10 min").tag(TimeInterval(600))
                            Text("15 min").tag(TimeInterval(900))
                            Text("20 min").tag(TimeInterval(1200))
                            Text("30 min").tag(TimeInterval(1800))
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)
                    
                } header: {
                    Label("Practice Goal", systemImage: "target")
                } footer: {
                    Text("Set your target sweep practice speed and duration")
                }
                
                // MARK: - Metronome settings
                Section {
                    // Metronome toggle
                    Toggle(isOn: $metronomeEnabled) {
                        HStack {
                            Image(systemName: "metronome")
                                .foregroundStyle(.orange)
                            Text("Enable Metronome")
                                .font(.headline)
                        }
                    }
                    .tint(.orange)
                    
                    // Metronome sound (shown only when enabled)
                    if metronomeEnabled {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Metronome Sound")
                                .font(.headline)
                            
                            Picker("Sound", selection: $metronomeSoundType) {
                                ForEach(MetronomeSoundType.allCases) { type in
                                    HStack {
                                        Image(systemName: type.icon)
                                        Text(type.rawValue)
                                    }
                                    .tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.vertical, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                } header: {
                    Label("Metronome", systemImage: "speaker.wave.2")
                } footer: {
                    if metronomeEnabled {
                        Text("The metronome plays at your target speed to help you keep a steady sweep rhythm")
                    } else {
                        Text("Turn on the metronome for rhythm assistance")
                    }
                }
                
                // MARK: - Technique tips
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        TipRow(
                            icon: "arrow.up.arrow.down",
                            title: "Practice Both Directions",
                            description: "Practice sweeping both up and down to keep your directions balanced"
                        )
                        
                        Divider()
                        
                        TipRow(
                            icon: "bolt.fill",
                            title: "Control Your Strength",
                            description: "Keep your sweep strength steady instead of alternating hard and soft"
                        )
                        
                        Divider()
                        
                        TipRow(
                            icon: "waveform.path",
                            title: "Steady Rhythm",
                            description: "Follow the metronome and increase the speed step by step"
                        )
                    }
                } header: {
                    Label("Practice Tips", systemImage: "star.fill")
                }
                
                // MARK: - About
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(
                            icon: "waveform",
                            title: "Sweep Detection",
                            description: "Automatically recognizes upward and downward sweeps"
                        )
                        
                        Divider()
                        
                        InfoRow(
                            icon: "drop.fill",
                            title: "Ripple Effect",
                            description: "Generates ripples of different sizes based on sweep strength"
                        )
                        
                        Divider()
                        
                        InfoRow(
                            icon: "star.fill",
                            title: "Scoring System",
                            description: "Earn points from strength and direction balance"
                        )
                    }
                } header: {
                    Label("How It Works", systemImage: "info.circle")
                }
            }
            .navigationTitle("Practice Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Helper Properties
    
    private var durationText: String {
        let minutes = Int(targetDuration / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) h"
            } else {
                return "\(hours) h \(remainingMinutes) min"
            }
        }
    }
    
    private var speedSuggestion: String {
        let bpm = Int(targetBPM)
        switch bpm {
        case 0..<50:
            return "Very slow - good for beginners' basic practice"
        case 50..<70:
            return "Slow - good for stability practice"
        case 70..<90:
            return "Moderately slow - good for basic sweeps"
        case 90..<110:
            return "Moderate - good for daily practice"
        case 110..<140:
            return "Moderately fast - good for intermediate practice"
        case 140..<170:
            return "Fast - good for advanced practice"
        default:
            return "Very fast - good for professional-level practice"
        }
    }
}

// MARK: - Info Row Component

private struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.cyan)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Tip Row Component

private struct TipRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WaveSettingsSheet(
        targetBPM: .constant(60),
        targetDuration: .constant(300),
        metronomeEnabled: .constant(true),
        metronomeSoundType: .constant(.tick)
    )
}
