//
//  TunerView.swift
//  PluckBuddy
//
//  Created by Zehui Wu on 2026/7/15.
//

import SwiftUI

struct TunerView: View {
    @StateObject private var viewModel = TunerViewModel()
    
    var body: some View {
        VStack(spacing: 15) {
            // Top description and waveform
            VStack(spacing: 12) {
                HStack {
                    Text("Adjust each string one by one")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // ✅ Pipa sound filter toggle
                    Toggle(isOn: $viewModel.pipaFilterEnabled) {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.pipaFilterEnabled ? "waveform.path" : "waveform")
                                .font(.caption)
                            Text(viewModel.pipaFilterEnabled ? "Pipa Mode" : "General Mode")
                                .font(.caption)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(.blue)
                }
                .padding(.horizontal)
                
                // ✅ CoreML gate status: makes "detect the pipa sound first, then the pitch" visible
                HStack(spacing: 6) {
                    if viewModel.pipaFilterEnabled {
                        Image(systemName: viewModel.pipaSoundDetected ? "checkmark.circle.fill" : "antenna.radiowaves.left.and.right")
                            .foregroundStyle(viewModel.pipaSoundDetected ? Color.green : Color.gray)
                        Text(viewModel.pipaSoundDetected ? "Pipa sound detected" : (viewModel.pipaGateAvailable ? "Listening… waiting for the pipa" : "Model not loaded, running in fallback mode"))
                            .font(.caption)
                            .foregroundStyle(viewModel.pipaSoundDetected ? Color.green : (viewModel.pipaGateAvailable ? Color.secondary : Color.orange))
                    } else {
                        // A subtle hint while the filter is off, so users do not think the UI is frozen
                        Image(systemName: "waveform")
                            .foregroundStyle(.secondary)
                        Text("General mode: sound type is not distinguished")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Live waveform display
                WaveformView(amplitudes: viewModel.waveformData)
                    .frame(height: 90)
                    .padding(.horizontal)
                
                if viewModel.frequency > 0 {
                    HStack(spacing: 8) {
                        Text(String(format: "%.1f Hz", viewModel.frequency))
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(.primary)
                        
                        // Confidence indicator
                        HStack(spacing: 2) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(viewModel.confidence > Double(index) * 0.33 ? Color.green : Color.gray.opacity(0.3))
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                }
            }
            .padding(.top)
            
            Spacer()
            
            // Four strings laid out horizontally: string 1 → string 4 from left to right, pitch from high to low
            HStack(spacing: 20) {
                Spacer()
                
                ForEach(TunerViewModel.pipaStrings.indices, id: \.self) { index in
                    let string = TunerViewModel.pipaStrings[index]
                    let isActive = viewModel.detectedNote == string.name
                    // pipaStrings is already ordered as string 1 → 4, so index + 1 gives the string number
                    let stringNumber = index + 1
                    
                    StringTuner(
                        stringNumber: stringNumber,
                        note: string.name,
                        frequency: string.frequency,
                        isActive: isActive,
                        centOffset: isActive ? viewModel.centOffset : 0,
                        isTuned: isActive && viewModel.isTuned
                    )
                }
                
                Spacer()
            }
            
            Spacer()
            
            // Bottom hints
            VStack(spacing: 12) {
                Text(viewModel.tuningMessage)
                    .font(.title3)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(viewModel.isTuned ? .green : .primary)
                    .animation(.easeInOut, value: viewModel.tuningMessage)
                
                if viewModel.frequency > 0 {
                    Text(String(format: "%+.0f cents", viewModel.centOffset))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(
                            abs(viewModel.centOffset) < 5 ? .green :
                            abs(viewModel.centOffset) < 15 ? .orange : .red
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
        }
        .navigationTitle("Smart Tuner")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.startListening()
        }
        .onDisappear {
            viewModel.stopListening()
        }
        .onChange(of: viewModel.isTuned) { oldValue, newValue in
            if !oldValue && newValue {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }
}

// MARK: - Waveform View (upgraded to a spectrum analyzer)
struct WaveformView: View {
    let amplitudes: [Float]
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard !amplitudes.isEmpty else { return }
                
                let width = size.width
                let height = size.height
                
                // Draw the background gradient
                let backgroundGradient = Gradient(colors: [
                    Color.blue.opacity(0.1),
                    Color.cyan.opacity(0.05)
                ])
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        backgroundGradient,
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: 0, y: height)
                    )
                )
                
                // Draw the bar spectrum
                let barCount = amplitudes.count
                let barWidth = width / CGFloat(barCount)
                let spacing: CGFloat = 1
                
                for (index, amplitude) in amplitudes.enumerated() {
                    let x = CGFloat(index) * barWidth
                    
                    // Normalized amplitude (0-1)
                    let normalizedAmp = min(1.0, abs(amplitude))
                    let barHeight = CGFloat(normalizedAmp) * height * 0.95
                    
                    // Color derived from amplitude (green → yellow → red)
                    let color: Color
                    if normalizedAmp < 0.3 {
                        color = .green
                    } else if normalizedAmp < 0.6 {
                        color = .yellow
                    } else {
                        color = .orange
                    }
                    
                    // Draw the bar
                    let barRect = CGRect(
                        x: x,
                        y: height - barHeight,
                        width: barWidth - spacing,
                        height: barHeight
                    )
                    
                    // Gradient fill
                    let gradient = Gradient(colors: [
                        color,
                        color.opacity(0.3)
                    ])
                    context.fill(
                        Path(roundedRect: barRect, cornerRadius: 2),
                        with: .linearGradient(
                            gradient,
                            startPoint: CGPoint(x: barRect.midX, y: barRect.maxY),
                            endPoint: CGPoint(x: barRect.midX, y: barRect.minY)
                        )
                    )
                    
                    // Highlight dot on top
                    if normalizedAmp > 0.1 {
                        let dotRect = CGRect(
                            x: x + (barWidth - spacing) / 2 - 2,
                            y: height - barHeight - 3,
                            width: 4,
                            height: 4
                        )
                        context.fill(
                            Path(ellipseIn: dotRect),
                            with: .color(.white.opacity(0.8))
                        )
                    }
                }
                
                // Draw the center reference line
                let midY = height / 2
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: midY))
                        path.addLine(to: CGPoint(x: width, y: midY))
                    },
                    with: .color(.white.opacity(0.2)),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                )
            }
        }
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.8), Color.blue.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .cyan.opacity(0.2), radius: 8, y: 4)
    }
}

// MARK: - String Tuner (tuning indicator for a single string)
struct StringTuner: View {
    let stringNumber: Int
    let note: String
    let frequency: Double
    let isActive: Bool
    let centOffset: Double
    let isTuned: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // String number label
            Text("String \(stringNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Note name
            Text(note)
                .font(.title.weight(.bold))
                .foregroundStyle(isActive ? (isTuned ? .green : .primary) : .secondary)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(isActive ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                        .overlay(
                            Circle()
                                .stroke(isActive ? (isTuned ? Color.green : Color.blue) : Color.gray.opacity(0.3), lineWidth: 2)
                        )
                )
                .scaleEffect(isActive ? 1.1 : 1.0)
                .animation(.spring(response: 0.3), value: isActive)
            
            // Vertical pitch indicator (stretched, with tick marks)
            HStack(spacing: 8) {
                // Left-hand tick labels
                VStack(spacing: 0) {
                    Text("+50")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("+25")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("0")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    
                    Spacer()
                    
                    Text("-25")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("-50")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 250)
                
                // Center indicator
                VStack(spacing: 0) {
                    // Sharp region
                    Rectangle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 50, height: 125)
                        .overlay(alignment: .top) {
                            Text("High")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                        .overlay {
                            // Tick lines
                            VStack(spacing: 0) {
                                ForEach(0..<5) { i in
                                    Divider()
                                        .background(Color.gray.opacity(0.3))
                                    if i < 4 {
                                        Spacer()
                                    }
                                }
                            }
                        }
                    
                    // In-tune region
                    Rectangle()
                        .fill(Color.green.opacity(0.25))
                        .frame(width: 50, height: 50)
                        .overlay {
                            Text("✓")
                                .font(.title2)
                                .foregroundStyle(.green)
                        }
                    
                    // Flat region
                    Rectangle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 50, height: 125)
                        .overlay(alignment: .bottom) {
                            Text("Low")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 4)
                        }
                        .overlay {
                            // Tick lines
                            VStack(spacing: 0) {
                                ForEach(0..<5) { i in
                                    Divider()
                                        .background(Color.gray.opacity(0.3))
                                    if i < 4 {
                                        Spacer()
                                    }
                                }
                            }
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .center) {
                    // Pointer arrow
                    if isActive {
                        HStack(spacing: 4) {
                            Image(systemName: "arrowtriangle.right.fill")
                                .foregroundStyle(isTuned ? .green : .red)
                                .font(.system(size: 16))
                                .shadow(color: .black.opacity(0.4), radius: 3)
                        }
                        .offset(y: calculateArrowOffset(cents: centOffset))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: centOffset)
                    }
                }
            }
            
            // Frequency label
            Text(String(format: "%.1f Hz", frequency))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    /// Computes the arrow offset
    /// cents range: -50 to +50
    /// Offset range: -125 to +125 (pixels)
    private func calculateArrowOffset(cents: Double) -> CGFloat {
        let clampedCents = max(-50, min(50, cents))
        // Negative means flat (arrow down), positive means sharp (arrow up)
        // 125 pixels (half height) / 50 cents = 2.5 pixels/cent
        return CGFloat(-clampedCents) * 2.5
    }
}

#Preview {
    NavigationStack {
        TunerView()
    }
}

