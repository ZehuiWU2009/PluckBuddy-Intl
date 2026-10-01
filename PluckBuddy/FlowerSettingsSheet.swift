//
//  FlowerSettingsSheet.swift
//  PluckBuddy
//
//  Created on 2026/8/31.
//

import SwiftUI

struct FlowerSettingsSheet: View {
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
                    // Target speed (BPM)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Target Speed")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(targetBPM)) BPM")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                        }
                        
                        Slider(value: $targetBPM, in: 36...220, step: 1)
                            .tint(.blue)
                        
                        HStack {
                            Text("36")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("220")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
                    Text("Set your target practice speed and duration")
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
                        Text("The metronome plays at your target speed to help you keep a steady rhythm")
                    } else {
                        Text("Turn on the metronome for rhythm assistance")
                    }
                }
                
                // MARK: - About
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(
                            icon: "hand.tap.fill",
                            title: "Tremolo Count",
                            description: "Records every tremolo motion you complete"
                        )
                        
                        Divider()
                        
                        InfoRow(
                            icon: "rectangle.3.group",
                            title: "Sequence Quality",
                            description: "Evaluates how well each tremolo sequence was completed"
                        )
                        
                        Divider()
                        
                        InfoRow(
                            icon: "star.fill",
                            title: "Scoring System",
                            description: "Earn points from speed, evenness and quality"
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
                .foregroundStyle(.blue)
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
    FlowerSettingsSheet(
        targetBPM: .constant(120),
        targetDuration: .constant(300),
        metronomeEnabled: .constant(true),
        metronomeSoundType: .constant(.tick)
    )
}
