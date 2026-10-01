//
//  PipaSoundGate.swift
//  PluckBuddy
//
//  Created by Wu Zehui on 2026/9/30.
//
//  The "pipa sound" gate of the smart tuner module. Reuses the PipaSoundClassifier CoreML model from the technique coach,
//  but does not take over AVAudioEngine or the audio session - microphone data is provided by AudioManager (to avoid competing for the tap with the technique coach / practice modules).
//
//  Input: AVAudioPCMBuffer from AudioManager (hardware format, usually 48 kHz)
//  Flow: hardware buffer -> mono -> software downsampling to 16 kHz -> accumulate to 15600 frames (about 0.975s) -> run model inference
//  State: the latest "is it a pipa" decision plus its probability, exposed as read-only Published
//
//  Implementation notes: all mutable state is accessed serially on inferenceQueue, Published outputs are dispatched
//  back to the main thread via DispatchQueue.main. Marked @unchecked Sendable because all shared state is protected serially by inferenceQueue.
//

import Foundation
import AVFoundation
import CoreML
import Combine

final class PipaSoundGate: ObservableObject, @unchecked Sendable {

    // MARK: - Model specifications (kept consistent with PipaSoundClassifierEngine in the technique coach)
    /// The sample rate required by the model
    private static let modelSampleRate: Double = 16000
    /// Model window length: 15600 samples = 16 kHz × 0.975 seconds
    private static let windowLength = 15600
    /// Overlapping inference step: 8000 frames ≈ 0.5 seconds (window 15600, step 8000 → 50% overlap)
    /// With overlap, the same sound segment is covered by 2~3 inferences, improving the hit rate; CPU load doubles but remains acceptable
    private static let windowStep = 8000
    /// Energy gate: a window whose RMS is below this value is treated as a quiet frame, skipping model inference and directly deciding background (so the moving average is not polluted)
    /// Measured on a real device's microphone: ambient noise RMS≈0.001~0.005, playing the pipa RMS≈0.05~0.3, speech≈0.01~0.05
    private static let energyFloor: Float = 0.01
    /// Output label (pipa is the "pipa" class among the four classes)
    private static let pipaLabel = "pipa"

    // MARK: - Model (read-only inside the inference queue)
    private let model: MLModel?
    private let inputName: String

    // MARK: - Inference scheduling
    /// Background inference queue. All mutable state is accessed only on it (protected by its serial nature).
    private let inferenceQueue = DispatchQueue(label: "com.pluckbuddy.tuner.soundgate", qos: .userInitiated)
    /// 16 kHz sample accumulation buffer (appended in inference order)
    private var pending16kSamples: [Float] = []
    /// The pipa probabilities of the last 3 inferences, used for the moving average to suppress single-frame jitter
    private var recentPipaProbs: [Double] = []
    /// Moving average window: average the pipa probabilities of the last N inferences before deciding. N=2 is stable enough without averaging away high probabilities.
    private let recentWindow = 2

    // MARK: - Published state exposed externally (updated by dispatching to the main thread)
    /// Whether the model was loaded successfully. On failure this gate degrades to "allow everything", equivalent to disabling filtering.
    @Published private(set) var isAvailable: Bool = false
    /// Whether the latest inference decided it was a pipa sound (pipa probability ≥ threshold, and still above threshold after smoothing)
    @Published private(set) var isPipa: Bool = false
    /// The pipa probability of the latest inference (after the moving average)
    @Published private(set) var pipaProb: Double = 0.0
    /// Timestamp of the latest "pipa sound" decision; the tuner uses it for "pipa present within 0.5s → only then judge pitch"
    private(set) var lastDetectedAt: Date?

    /// Minimum probability threshold for deciding "pipa sound" (0.35 is a compromise determined after on-device debugging - with four classes the real pipa probability mostly falls in the 0.3~0.7 range, so 0.5 is too strict).
    /// If the on-device console shows the smoothed pipa probability is often ≥0.6, raise it to 0.5 for strictness; if playing the pipa is still often judged ≤0.2, the model lacks discriminative power for the current microphone quality and needs retraining or replacing.
    private let threshold: Double = 0.35

    // MARK: - Lifecycle
    init() {
        if let loaded = Self.loadModel() {
            self.model = loaded.model
            self.inputName = loaded.inputName
            self.isAvailable = true
            print("✅ PipaSoundGate model loaded (input: \(loaded.inputName), window: \(Self.windowLength) frames @ \(Int(Self.modelSampleRate)) Hz)")
        } else {
            self.model = nil
            self.inputName = "audioSamples"
            self.isAvailable = false
            print("⚠️ PipaSoundGate failed to load the model, the gate degrades to allow everything")
        }
    }

    // MARK: - Model loading (refer to PipaSoundClassifierEngine.loadModel in the technique coach)

    private struct LoadedModel {
        let model: MLModel
        let inputName: String
    }

    private static func loadModel() -> LoadedModel? {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all

        var modelURL = Bundle.main.url(forResource: "PipaSoundClassifier", withExtension: "mlmodelc")
        if modelURL == nil,
           let rawURL = Bundle.main.url(forResource: "PipaSoundClassifier", withExtension: "mlmodel") {
            modelURL = try? MLModel.compileModel(at: rawURL)
        }

        guard let url = modelURL,
              let model = try? MLModel(contentsOf: url, configuration: configuration) else {
            return nil
        }

        let inputs = model.modelDescription.inputDescriptionsByName
        let inputName = inputs["audioSamples"] != nil ? "audioSamples" : (inputs.keys.first ?? "audioSamples")
        return LoadedModel(model: model, inputName: inputName)
    }

    // MARK: - Feeding audio buffers (called once per frame from the AudioManager callback)
    /// Receives a hardware-format buffer from AudioManager, downsamples it and pushes it into the accumulation queue;
  /// once a full window (15600 frames @16kHz) is collected, runs one inference in the background and updates the Published state on the main thread.
    func feed(buffer: AVAudioPCMBuffer) {
        let samples = Self.monoSamples(from: buffer, targetSampleRate: Self.modelSampleRate)
        guard !samples.isEmpty else { return }

        inferenceQueue.async { [weak self] in
            guard let self else { return }
            self.append(samples)
        }
    }

    // On the inference queue: append samples, fill the window, run inference
    private func append(_ samples: [Float]) {
        guard model != nil else { return }
        pending16kSamples.append(contentsOf: samples)

        // ✅ Overlapping window inference: run inference once at least 1 window is accumulated, stepping by windowStep each time (50% overlap)
        while pending16kSamples.count >= Self.windowLength {
            let window = Array(pending16kSamples.prefix(Self.windowLength))
            pending16kSamples.removeFirst(Self.windowStep)

            // ✅ Energy gate: quiet frames are directly decided as background, without polluting the moving average
            let windowRMS = Self.rms(of: window)
            let label: String
            let pipaProb: Double
            let skipped = windowRMS < Self.energyFloor
            if skipped {
                label = "background"
                pipaProb = 0
            } else if let result = classify(window) {
                (label, pipaProb, _) = result
            } else {
                continue
            }

            // Moving average (suppresses single-frame jitter)
            recentPipaProbs.append(pipaProb)
            if recentPipaProbs.count > recentWindow {
                recentPipaProbs.removeFirst()
            }
            let smoothed = recentPipaProbs.reduce(0, +) / Double(max(recentPipaProbs.count, 1))
            let smoothedIsPipa = (label == Self.pipaLabel) && (smoothed >= threshold)

            // Diagnostic output: print the probability distribution and decision for every inference, to ease on-device debugging
            let tag = skipped ? "[silent-skip]" : ""
            print("🎵 [PipaGate]\(tag) rms=\(String(format: "%.4f", windowRMS)) label=\(label) pipa=\(String(format: "%.3f", pipaProb)) smoothed=\(String(format: "%.3f", smoothed)) -> pipa:\(smoothedIsPipa ? "✅" : "❌")")

            // Dispatch to the main thread to update Published (Combine notifies the View automatically)
            let detectedAt = Date()
            let rawIsPipa = (label == Self.pipaLabel) && (pipaProb >= threshold)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pipaProb = smoothed
                self.isPipa = smoothedIsPipa
                if rawIsPipa || smoothedIsPipa {
                    self.lastDetectedAt = detectedAt
                }
            }
        }

        // Prevent backlog: drop old data once more than 4 windows have accumulated
        if pending16kSamples.count > Self.windowLength * 4 {
            pending16kSamples.removeFirst(pending16kSamples.count - Self.windowLength)
        }
    }

    // Called on the inference queue: a single inference, returning (raw English label, pipa probability, full probability dictionary)
    private func classify(_ window: [Float]) -> (String, Double, [String: Double])? {
        guard let model, window.count == Self.windowLength else { return nil }
        let shape = [NSNumber(value: Self.windowLength)]
        guard let array = try? MLMultiArray(shape: shape, dataType: .float32) else { return nil }
        for index in 0..<Self.windowLength {
            array[index] = NSNumber(value: window[index])
        }
        let value = MLFeatureValue(multiArray: array)
        let provider: MLFeatureProvider
        do {
            provider = try MLDictionaryFeatureProvider(dictionary: [inputName: value])
        } catch {
            return nil
        }
        guard let output = try? model.prediction(from: provider) else { return nil }
        let rawLabel = output.featureValue(for: "target")?.stringValue ?? "background"
        let probDict = output.featureValue(for: "targetProbability")?.dictionaryValue ?? [:]
        // The keys of dictionaryValue are AnyHashable and need to be converted back to String
        var probs: [String: Double] = [:]
        for (k, v) in probDict {
            let key = (k.base as? String) ?? String(describing: k)
            if let n = v as? NSNumber { probs[key] = n.doubleValue }
        }
        let pipaProb = probs[Self.pipaLabel] ?? 0
        return (rawLabel, pipaProb, probs)
    }

    // MARK: - Public decision API (for the tuner main thread to check quickly inside the audio callback)

    /// "Whether the latest decision falls inside the valid 'pipa sound' window". Defaults to 0.5 seconds, called when the tuner judges pitch.
    /// - Parameter window: Length of the decision window, default 0.5 seconds
    /// - Returns: Returns true when the model fails to load (degrades to allow everything), otherwise decided from isPipa + lastDetectedAt
    func isPipaRecent(within window: TimeInterval = 0.5) -> Bool {
        guard isAvailable else { return true } // Model unavailable → allow everything
        guard let t = lastDetectedAt else { return false }
        return isPipa && Date().timeIntervalSince(t) <= window
    }

    /// Resets internal state (called when practice stops, to avoid leaving the previous "latest decision" before the next session)
    func reset() {
        inferenceQueue.async { [weak self] in
            guard let self else { return }
            self.pending16kSamples.removeAll()
            self.recentPipaProbs.removeAll()
            DispatchQueue.main.async {
                self.isPipa = false
                self.pipaProb = 0
                self.lastDetectedAt = nil
            }
        }
    }

    // MARK: - Utilities: mono downmix + software downsampling (refer to the method of the same name in the technique coach)

    /// Computes the RMS (root-mean-square energy) of a sample array. Used by the energy gate to decide whether the window contains significant sound.
    /// Silent frames usually have RMS < 0.005, playing the pipa ≈0.05~0.3, speech ≈0.01~0.05.
    private static func rms(of samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sumSq: Float = 0
        for s in samples {
            sumSq += s * s
        }
        return (sumSq / Float(samples.count)).squareRoot()
    }

    /// Mixes any PCM buffer down to mono and resamples it to the target sample rate (linear interpolation, avoiding the high-frequency distortion caused by direct decimation)
    private static func monoSamples(from buffer: AVAudioPCMBuffer, targetSampleRate: Double) -> [Float] {
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return [] }

        let channelCount = max(Int(buffer.format.channelCount), 1)
        var mono = [Float](repeating: 0, count: frameCount)

        switch buffer.format.commonFormat {
        case .pcmFormatFloat32:
            guard let data = buffer.floatChannelData else { return [] }
            for channel in 0..<channelCount {
                let source = data[channel]
                for i in 0..<frameCount { mono[i] += source[i] }
            }
        case .pcmFormatInt16:
            guard let data = buffer.int16ChannelData else { return [] }
            for channel in 0..<channelCount {
                let source = data[channel]
                for i in 0..<frameCount { mono[i] += Float(source[i]) / 32768 }
            }
        case .pcmFormatInt32:
            guard let data = buffer.int32ChannelData else { return [] }
            for channel in 0..<channelCount {
                let source = data[channel]
                for i in 0..<frameCount { mono[i] += Float(source[i]) / 2147483648 }
            }
        default:
            return []
        }

        if channelCount > 1 {
            let scale = 1 / Float(channelCount)
            for i in 0..<frameCount { mono[i] *= scale }
        }

        let sourceRate = buffer.format.sampleRate
        guard sourceRate > 0, abs(sourceRate - targetSampleRate) > 1 else { return mono }

        // 48 kHz → 16 kHz software downsampling: linear interpolation
        let step = sourceRate / targetSampleRate
        let targetCount = max(Int((Double(frameCount) - 1) / step), 1)
        var resampled = [Float](repeating: 0, count: targetCount)
        for i in 0..<targetCount {
            let position = Double(i) * step
            let index = min(Int(position), frameCount - 1)
            let next = min(index + 1, frameCount - 1)
            let fraction = Float(position - Double(index))
            resampled[i] = mono[index] + (mono[next] - mono[index]) * fraction
        }
        return resampled
    }
}