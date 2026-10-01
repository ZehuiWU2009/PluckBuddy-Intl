//
//  TechniqueCoachViewModel.swift
//  PluckBuddy
//
//  Created by Zehui Wu on 2026/7/29.
//

import Foundation
import SwiftUI
import AVFoundation
import Vision
import Combine
import CoreML

@MainActor
class TechniqueCoachViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether analysis is running
    @Published var isAnalyzing = false
    
    /// Detected technique type
    @Published var detectedTechnique: TechniqueType = .unknown
    
    /// Current hand pose data
    @Published var handPose: HandPoseData?
    
    /// Posture evaluation result
    @Published var currentEvaluation: PostureEvaluation?
    
    /// Status message
    @Published var statusMessage = "Ready to start"
    
    /// Camera permission status
    @Published var cameraPermissionGranted = false
    
    /// Current sound category reported by the Core ML sound classifier (ready to display)
    @Published var soundSceneLabel = "Not started"
    
    /// Probability from Core ML that the current sound is a pipa (0~1, smoothed over the last three results)
    @Published var pipaConfidence: Double = 0
    
    /// Whether the sound currently heard is a pipa sound
    @Published var isPipaSoundDetected = false
    
    /// Analysis session duration
    @Published var sessionDuration: TimeInterval = 0
    
    /// Hand skeleton overlay image (drawn on top of the video)
    @Published var skeletonOverlayImage: UIImage?
    
    // MARK: - Internal Properties
    
    /// Video capture manager (lets the View reach the preview layer)
    var videoCapture: VideoCaptureManager?
    
    // MARK: - Private Properties
    
    private var handPoseAnalyzer = HandPoseAnalyzer()
    private var motionFeatureExtractor = MotionFeatureExtractor()
    private var techniqueClassifier = TechniqueClassifier()
    
    private var rollEvaluator = RollPostureEvaluator()
    private var sweepEvaluator = SweepPostureEvaluator()
    private var pluckEvaluator = PluckPostureEvaluator()
    
    /// Core ML sound classification engine (loads PipaSoundClassifier)
    private let soundClassifier = PipaSoundClassifierEngine()
    
    /// Whether sound classification has produced a result yet — no gating before that, so the opening frames are never ruled out outright
    private var hasSoundResult = false
    
    // MARK: - Technique Debouncing
    /// The classifier flickers between frames (the same passage jumps between「Tremolo/Sweep/Unrecognized」),
    /// so handing every frame result to the UI makes the core requirement panel switch constantly.
    /// We therefore require several consecutive identical frames before accepting a technique.
    private var pendingTechnique: TechniqueType = .unknown
    private var pendingTechniqueFrames = 0
    private let techniqueStableFrames = 6   // ~0.2 s (at 30 fps)
    
    private var startTime: Date?
    private var durationTimer: Timer?
    
    // MARK: - Initialization
    
    init() {
        print("🎥 Smart fingering coach initialized")
    }
    
    // MARK: - Lifecycle
    
    /// Start video analysis
    func startAnalysis() async {
        print("🎥 Starting video analysis...")
        
        // 1. Request camera permission
        let authorized = await requestCameraPermission()
        guard authorized else {
            print("❌ Camera permission denied")
            statusMessage = "Camera permission required"
            return
        }
        
        cameraPermissionGranted = true
        print("✅ Camera permission granted")
        
        // 2. Initialize video capture
        videoCapture = VideoCaptureManager()
        
        videoCapture?.onFrameCaptured = { [weak self] pixelBuffer in
            Task { @MainActor in
                await self?.processFrame(pixelBuffer)
            }
        }
        
        // 3. Start capture
        do {
            try videoCapture?.startCapture()
            
            isAnalyzing = true
            startTime = Date()
            statusMessage = "Please start playing"
            
            // Start the duration timer
            startDurationTimer()
            
            print("✅ Video capture started")
            
            // 🧪 Temporary test code: simulated technique recognition
            // startSimulatedDetection()  // ⚠️ Simulated data disabled — waiting for the real algorithm
            
            // 4. Start Core ML sound classification to cross-check the visual channel
            await startSoundClassification()
            
        } catch {
            print("❌ Failed to start capture: \(error.localizedDescription)")
            statusMessage = "Camera failed to start"
        }
    }
    
    /// Stop video analysis
    func stopAnalysis() {
        print("⏹️ Stopping video analysis")
        
        videoCapture?.stopCapture()
        isAnalyzing = false
        
        // Stop sound classification
        soundClassifier.stop()
        hasSoundResult = false
        soundSceneLabel = "Stopped"
        
        // Stop the timer
        stopDurationTimer()
        
        if let start = startTime {
            sessionDuration = Date().timeIntervalSince(start)
            print("   - Analysis duration: \(String(format: "%.1f", sessionDuration))s")
        }
        
        // Reset state
        detectedTechnique = .unknown
        handPose = nil
        currentEvaluation = nil
        statusMessage = "Analysis stopped"
        
        // Reset the debounce counter; it accumulates again on the next start
        pendingTechnique = .unknown
        pendingTechniqueFrames = 0
    }
    
    // MARK: - Frame Processing
    
    /// Process a single video frame
    private func processFrame(_ pixelBuffer: CVPixelBuffer) async {
        // 1. Detect the hand pose
        guard let pose = await handPoseAnalyzer.analyzeHand(in: pixelBuffer) else {
            // No hand detected
            if detectedTechnique != .unknown {
                // A technique was detected before but has now been lost
                print("⚠️ Hand detection lost")
            }
            statusMessage = "No hand detected"
            skeletonOverlayImage = nil  // Clear the skeleton image
            return
        }
        
        handPose = pose
        
        // ✨ Generate the hand skeleton overlay image
        generateSkeletonOverlay(from: pose, pixelBuffer: pixelBuffer)
        
        // 2. Extract motion features
        let features = motionFeatureExtractor.extractFeatures(from: pose)
        
        // 3. Classify the technique
        let technique = techniqueClassifier.classify(features: features)
        
        // 3.5 Audio-side gating: only commit the visual verdict as a technique once Core ML confirms a pipa sound
        // Hand motions that look like playing but do not sound like a pipa (speech, other instruments, ambient noise) get no score
        if hasSoundResult, !isPipaSoundDetected {
            if detectedTechnique != .unknown {
                print("🔇 Sound classified as「\(soundSceneLabel)」, technique scoring withheld for now")
                detectedTechnique = .unknown
            }
            currentEvaluation = nil
            statusMessage = "No pipa sound detected (\(soundSceneLabel))"
            return
        }
        
        // 3.6 Technique debouncing: adopt a verdict only after several identical frames, otherwise keep the confirmed technique
        if technique == pendingTechnique {
            pendingTechniqueFrames += 1
        } else {
            pendingTechnique = technique
            pendingTechniqueFrames = 1
        }
        let isStable = pendingTechniqueFrames >= techniqueStableFrames
        let stableTechnique = isStable ? pendingTechnique : detectedTechnique
        
        // Log whenever the technique changes
        if stableTechnique != .unknown && stableTechnique != detectedTechnique {
            print("🎯 Technique detected: \(stableTechnique.rawValue)")
            detectedTechnique = stableTechnique
        } else if stableTechnique == .unknown && detectedTechnique != .unknown {
            print("⚠️ Technique recognition lost")
            detectedTechnique = .unknown
        }
        
        // 4. Evaluate posture
        if stableTechnique != .unknown {
            currentEvaluation = evaluatePosture(
                technique: stableTechnique,
                features: features
            )
            
            updateStatusMessage()
        }
    }
    
    // MARK: - Skeleton Overlay Generation
    
    /// Generate the hand skeleton overlay image
    private func generateSkeletonOverlay(from pose: HandPoseData, pixelBuffer: CVPixelBuffer) {
        // Get the image size
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let imageSize = CGSize(width: width, height: height)

        // Full hand skeleton: 21 landmarks + 5 finger bones + palm
        skeletonOverlayImage = drawFullHandSkeleton(
            pose: pose,
            imageSize: imageSize
        )
    }

    /// Draw the full hand skeleton (21 landmarks + finger bone lines + palm lines)
    /// - 5 fingertips: large colored circles (same as the old version)
    /// - Wrist: large blue circle
    /// - 15 intermediate joints (CMC/MP/IP/MCP/PIP/DIP): small white circles
    /// - 5 finger bone lines (CMC/MCP → MP/PIP → IP/DIP → Tip)
    /// - 5 palm lines (wrist → each finger MCP/CMC)
    private func drawFullHandSkeleton(pose: HandPoseData, imageSize: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(imageSize, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }

        context.setStrokeColor(UIColor.systemPink.cgColor)
        context.setLineWidth(2.5)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Look up coordinates by name in pose.keypoints (any point of the full 21-landmark set)
        func findPoint(_ name: String) -> CGPoint? {
            pose.keypoints.first(where: { $0.name == name })?.location
        }

        // 1) 5 finger bone lines (4 joints per finger form one bone)
        let fingerBones: [(String, String, String, String)] = [
            ("thumbCMC",   "thumbMP",   "thumbIP",   "thumbTip"),     // Thumb
            ("indexMCP",   "indexPIP",  "indexDIP",  "indexTip"),     // Index finger
            ("middleMCP",  "middlePIP", "middleDIP", "middleTip"),    // Middle finger
            ("ringMCP",    "ringPIP",   "ringDIP",   "ringTip"),      // Ring finger
            ("littleMCP",  "littlePIP", "littleDIP", "littleTip"),    // Little finger
        ]
        for (a, b, c, d) in fingerBones {
            let raw = [findPoint(a), findPoint(b), findPoint(c), findPoint(d)]
            var lastUI: CGPoint?
            for p in raw {
                guard let p = p else { continue }
                let ui = convertVisionPointToUIKit(p, imageSize: imageSize)
                if let last = lastUI {
                    context.move(to: last)
                    context.addLine(to: ui)
                }
                lastUI = ui
            }
        }

        // 2) Palm: lines from the wrist → each finger MCP/CMC
        if let wristRaw = findPoint("wrist") {
            let wristUI = convertVisionPointToUIKit(wristRaw, imageSize: imageSize)
            let palmRoots = ["thumbCMC", "indexMCP", "middleMCP", "ringMCP", "littleMCP"]
            for name in palmRoots {
                if let p = findPoint(name) {
                    let ui = convertVisionPointToUIKit(p, imageSize: imageSize)
                    context.move(to: wristUI)
                    context.addLine(to: ui)
                }
            }
        }
        context.strokePath()

        // 3) 5 large colored fingertip circles (same palette as the old version)
        let tipStyles: [(String, UIColor, CGFloat)] = [
            ("thumbTip",  .systemPink,   10),
            ("indexTip",  .systemGreen,  10),
            ("middleTip", .systemOrange, 10),
            ("ringTip",   .systemYellow, 10),
            ("littleTip", .systemPurple, 10),
        ]
        for (name, color, r) in tipStyles {
            if let p = findPoint(name) {
                drawCircle(at: p, context: context, imageSize: imageSize, color: color, radius: r)
            }
        }

        // 4) Blue wrist circle
        if let wristRaw = findPoint("wrist") {
            drawCircle(at: wristRaw, context: context, imageSize: imageSize, color: .systemBlue, radius: 8)
        }

        // 5) 15 small white joint circles (CMC / MP / IP / MCP / PIP / DIP)
        let jointNames = [
            "thumbCMC",  "thumbMP",  "thumbIP",
            "indexMCP",  "indexPIP", "indexDIP",
            "middleMCP", "middlePIP","middleDIP",
            "ringMCP",   "ringPIP",  "ringDIP",
            "littleMCP", "littlePIP","littleDIP",
        ]
        let jointColor = UIColor.white.withAlphaComponent(0.85)
        for name in jointNames {
            if let p = findPoint(name) {
                drawCircle(at: p, context: context, imageSize: imageSize, color: jointColor, radius: 4)
            }
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    /// Convert Vision coordinates to UIKit coordinates
    private func convertVisionPointToUIKit(_ point: CGPoint, imageSize: CGSize) -> CGPoint {
        return CGPoint(
            x: point.x * imageSize.width,
            y: (1 - point.y) * imageSize.height
        )
    }
    
    /// Draw a circle at the given position
    private func drawCircle(at point: CGPoint, context: CGContext, imageSize: CGSize, color: UIColor, radius: CGFloat) {
        let uiPoint = convertVisionPointToUIKit(point, imageSize: imageSize)
        context.setFillColor(color.cgColor)
        let rect = CGRect(
            x: uiPoint.x - radius,
            y: uiPoint.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.fillEllipse(in: rect)
    }
    
    /// Convert HandPoseData into an array of HandKeypoint
    private func convertToKeypoints(from pose: HandPoseData) -> [HandKeypoint] {
        var keypoints: [HandKeypoint] = []
        
        // Extract fingertip and wrist positions from HandPoseData
        let fingerTips: [(CGPoint?, String)] = [
            (pose.wrist, "wrist"),
            (pose.thumbTip, "thumbTip"),
            (pose.indexTip, "indexTip"),
            (pose.middleTip, "middleTip"),
            (pose.ringTip, "ringTip"),
            (pose.littleTip, "littleTip")
        ]
        
        // Collect every valid landmark
        for (location, name) in fingerTips {
            if let loc = location {
                keypoints.append(HandKeypoint(
                    name: name,
                    location: loc,
                    confidence: Double(pose.confidence)
                ))
            }
        }
        
        return keypoints
    }
    
    // MARK: - Posture Evaluation
    
    /// Evaluate posture
    private func evaluatePosture(
        technique: TechniqueType,
        features: HandMotionFeatures
    ) -> PostureEvaluation {
        switch technique {
        case .roll:
            return rollEvaluator.evaluate(features: features)
            
        case .sweep:
            return sweepEvaluator.evaluate(features: features)
            
        case .pluck:
            return pluckEvaluator.evaluate(features: features)
            
        case .unknown:
            return PostureEvaluation(
                overallScore: 0,
                aspects: [],
                suggestions: ["Please start playing"]
            )
        }
    }
    
    // MARK: - UI Updates
    
    private func updateStatusMessage() {
        guard let evaluation = currentEvaluation else {
            statusMessage = "Analyzing..."
            return
        }
        
        let score = evaluation.overallScore
        
        if score >= 90 {
            statusMessage = "🌟 Excellent posture!"
        } else if score >= 80 {
            statusMessage = "👍 Good posture!"
        } else if score >= 70 {
            statusMessage = "👌 Keep it up!"
        } else if score >= 60 {
            statusMessage = "💪 Mind your posture"
        } else {
            statusMessage = "⚠️ Posture needs work"
        }
    }
    
    // MARK: - Timer Management
    
    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let start = self.startTime else { return }
                self.sessionDuration = Date().timeIntervalSince(start)
            }
        }
    }
    
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
    
    // MARK: - Simulated Detection (temporary test feature)
    
    /// Start simulated technique detection
    /// Note: temporary test code, used to validate the UI before Vision detection was implemented
    private func startSimulatedDetection() {
        print("🧪 [Test Mode] Starting simulated technique detection")
        print("   The Tremolo technique will be simulated automatically in 2 seconds")
        
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2-second delay
            
            await MainActor.run {
                guard isAnalyzing else { return }
                
                // Simulate detecting tremolo
                detectedTechnique = .roll
                print("🧪 [Test Mode] Simulated technique detected: \(detectedTechnique.rawValue)")
                
                // Simulated evaluation result
                currentEvaluation = PostureEvaluation(
                    overallScore: 85,
                    aspects: [
                        EvaluationAspect(
                            category: .handShape,
                            score: 90,
                            description: "Natural hand shape"
                        ),
                        EvaluationAspect(
                            category: .tigerMouth,
                            score: 80,
                            description: "Natural tiger mouth"
                        ),
                        EvaluationAspect(
                            category: .rhythm,
                            score: 85,
                            description: "Steady rhythm"
                        )
                    ],
                    suggestions: ["Keep the current rhythm", "Watch finger independence"]
                )
                
                updateStatusMessage()
                print("🧪 [Test Mode] The scrolling banner should now be visible")
            }
        }
    }
    
    /// Manually set the technique (used by the test menu)
    func setTechnique(_ technique: TechniqueType) {
        print("🧪 [Test Mode] Manually switching technique: \(technique.rawValue)")
        detectedTechnique = technique
        
        if technique != .unknown {
            // Provide different simulated scores per technique
            let score: Double
            switch technique {
            case .roll:
                score = 85
            case .sweep:
                score = 78
            case .pluck:
                score = 82
            case .unknown:
                score = 0
            }
            
            currentEvaluation = PostureEvaluation(
                overallScore: score,
                aspects: [
                    EvaluationAspect(
                        category: .handShape,
                        score: score + 5,
                        description: "Hand Shape \(score > 80 ? "Excellent" : "Good")"
                    ),
                    EvaluationAspect(
                        category: .rhythm,
                        score: score,
                        description: "Rhythm \(score > 80 ? "Steady" : "Fair")"
                    )
                ],
                suggestions: ["Keep it up"]
            )
            
            updateStatusMessage()
        } else {
            currentEvaluation = nil
            statusMessage = "Please start playing"
        }
    }
    
    // MARK: - Core ML Sound Classification
    
    /// Start on-device sound classification to provide audio-side evidence for technique recognition
    private func startSoundClassification() async {
        guard soundClassifier.isAvailable else {
            print("⚠️ PipaSoundClassifier failed to load; this session uses the visual channel only")
            soundSceneLabel = "Sound model unavailable"
            return
        }
        
        let granted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission(completionHandler: { granted in
                continuation.resume(returning: granted)
            })
        }
        
        guard granted else {
            print("❌ Microphone permission denied; sound classification disabled")
            soundSceneLabel = "Microphone not authorized"
            return
        }
        
        soundClassifier.setResultHandler { [weak self] label, probability in
            Task { @MainActor in
                self?.applySoundResult(label: label, pipaProbability: probability)
            }
        }
        
        do {
            try soundClassifier.start()
            print("🎧 Sound classification started: Core ML PipaSoundClassifier, 16 kHz on-device inference")
        } catch {
            print("❌ Failed to start sound classification: \(error.localizedDescription)")
            soundSceneLabel = "Microphone failed to start"
        }
    }
    
    /// Record a sound classification result
    private func applySoundResult(label: String, pipaProbability: Double) {
        hasSoundResult = true
        soundSceneLabel = label
        pipaConfidence = pipaProbability
        isPipaSoundDetected = label == "Pipa" && pipaProbability >= 0.5
    }
    
    // MARK: - Permissions
    
    /// Request camera permission
    private func requestCameraPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

// MARK: - Hand Pose Data Model

struct HandPoseData {
    let timestamp: Date
    let thumbTip: CGPoint?
    let indexTip: CGPoint?
    let middleTip: CGPoint?
    let ringTip: CGPoint?
    let littleTip: CGPoint?
    let wrist: CGPoint?
    /// All 21 landmarks detected by the Vision framework (including intermediate joints).
    /// Used to draw the complete finger skeleton on screen, not just fingertips + wrist.
    let keypoints: [HandKeypoint]
    let confidence: Float
}

// MARK: - Motion Features

struct HandMotionFeatures {
    // Position features
    var fingerTipPositions: [CGPoint]
    var wristPosition: CGPoint
    
    // Velocity features
    var fingerVelocities: [CGVector]
    var wristVelocity: CGVector
    
    // Angle features
    var tigerMouthAngle: Double   // Tiger mouth angle (degrees): angle at the wrist between the thumb direction and the index finger direction
    var wristAngle: Double
    
    // Rhythm features
    var movementFrequency: Double
    var sequencePattern: [Int]
}

// MARK: - Posture Evaluation Result

struct PostureEvaluation {
    var overallScore: Double        // 0-100 overall score
    var aspects: [EvaluationAspect] // Per-aspect scores
    var suggestions: [String]       // Improvement suggestions
}

struct EvaluationAspect {
    enum Category: String {
        case handShape = "Hand Shape"
        case tigerMouth = "Tiger Mouth Angle"
        case wristPosition = "Wrist Position"
        case rhythm = "Rhythm Stability"
        case relaxation = "Relaxation"
    }
    
    let category: Category
    let score: Double       // 0-100
    let description: String
}

// MARK: - Placeholder Implementation (to be completed)

/// Hand pose analyzer
class HandPoseAnalyzer {
    private let extractor = HandPoseExtractor()
    
    func analyzeHand(in pixelBuffer: CVPixelBuffer) async -> HandPoseData? {
        // Use the Vision framework to detect hand landmarks
        guard let keypoints = try? await extractor.extractKeypoints(from: pixelBuffer),
              !keypoints.isEmpty else {
            print("⚠️ No hand landmarks detected")  // Debug log
            return nil
        }
        
        print("✅ Detected \(keypoints.count) landmarks")  // Debug log
        
        // Extract specific fingertip positions
        let thumbTip = keypoints.first(where: { $0.name.contains("thumbTip") })?.location
        let indexTip = keypoints.first(where: { $0.name.contains("indexTip") })?.location
        let middleTip = keypoints.first(where: { $0.name.contains("middleTip") })?.location
        let ringTip = keypoints.first(where: { $0.name.contains("ringTip") })?.location
        let littleTip = keypoints.first(where: { $0.name.contains("littleTip") })?.location
        let wrist = keypoints.first(where: { $0.name.contains("wrist") })?.location
        
        // Debug: print the landmarks that were found
        if thumbTip != nil { print("  ✓ Thumb found") }
        if indexTip != nil { print("  ✓ Index finger found") }
        if middleTip != nil { print("  ✓ Middle finger found") }
        if ringTip != nil { print("  ✓ Ring finger found") }
        if littleTip != nil { print("  ✓ Little finger found") }
        if wrist != nil { print("  ✓ Wrist found") }
        
        // Compute the average confidence
        let avgConfidence = Float(keypoints.map { $0.confidence }.reduce(0, +) / Double(keypoints.count))
        
        return HandPoseData(
            timestamp: Date(),
            thumbTip: thumbTip,
            indexTip: indexTip,
            middleTip: middleTip,
            ringTip: ringTip,
            littleTip: littleTip,
            wrist: wrist,
            keypoints: keypoints,
            confidence: avgConfidence
        )
    }
}

/// Motion feature extractor
class MotionFeatureExtractor {
    // Pose history queue (used to compute velocity and movement patterns)
    private var poseHistory: [HandPoseData] = []
    private let maxHistorySize = 10 // Keep the most recent 10 frames
    
    func extractFeatures(from handPose: HandPoseData) -> HandMotionFeatures {
        // 1. Append to the history queue
        poseHistory.append(handPose)
        if poseHistory.count > maxHistorySize {
            poseHistory.removeFirst()
        }
        
        // 2. Extract position features
        let fingerPositions = [
            handPose.thumbTip ?? .zero,
            handPose.indexTip ?? .zero,
            handPose.middleTip ?? .zero,
            handPose.ringTip ?? .zero,
            handPose.littleTip ?? .zero
        ]
        let wristPos = handPose.wrist ?? .zero
        
        // 3. Compute velocity features
        let velocities = calculateFingerVelocities()
        let wristVel = calculateWristVelocity()
        
        // 4. Compute angle features
        let tigerAngle = calculateTigerMouthAngle(handPose: handPose)
        let wristAngle = calculateWristAngle(handPose: handPose)

        // 5. Compute rhythm features
        let frequency = calculateMovementFrequency()
        let pattern = detectSequencePattern()

        return HandMotionFeatures(
            fingerTipPositions: fingerPositions,
            wristPosition: wristPos,
            fingerVelocities: velocities,
            wristVelocity: wristVel,
            tigerMouthAngle: tigerAngle,
            wristAngle: wristAngle,
            movementFrequency: frequency,
            sequencePattern: pattern
        )
    }
    
    // MARK: - Velocity Calculation
    
    private func calculateFingerVelocities() -> [CGVector] {
        guard poseHistory.count >= 2 else {
            return Array(repeating: .zero, count: 5)
        }
        
        let current = poseHistory.last!
        let previous = poseHistory[poseHistory.count - 2]
        let timeDiff = current.timestamp.timeIntervalSince(previous.timestamp)
        
        guard timeDiff > 0 else {
            return Array(repeating: .zero, count: 5)
        }
        
        let fingers = [
            (current.thumbTip, previous.thumbTip),
            (current.indexTip, previous.indexTip),
            (current.middleTip, previous.middleTip),
            (current.ringTip, previous.ringTip),
            (current.littleTip, previous.littleTip)
        ]
        
        return fingers.map { curr, prev in
            guard let curr = curr, let prev = prev else { return .zero }
            let dx = (curr.x - prev.x) / CGFloat(timeDiff)
            let dy = (curr.y - prev.y) / CGFloat(timeDiff)
            return CGVector(dx: dx, dy: dy)
        }
    }
    
    private func calculateWristVelocity() -> CGVector {
        guard poseHistory.count >= 2 else { return .zero }
        
        let current = poseHistory.last!
        let previous = poseHistory[poseHistory.count - 2]
        let timeDiff = current.timestamp.timeIntervalSince(previous.timestamp)
        
        guard timeDiff > 0,
              let currWrist = current.wrist,
              let prevWrist = previous.wrist else {
            return .zero
        }
        
        let dx = (currWrist.x - prevWrist.x) / CGFloat(timeDiff)
        let dy = (currWrist.y - prevWrist.y) / CGFloat(timeDiff)
        return CGVector(dx: dx, dy: dy)
    }
    
    // MARK: - Angle Calculation
    
    private func calculateTigerMouthAngle(handPose: HandPoseData) -> Double {
        // Tiger mouth angle: at the wrist, thumb direction vs index finger direction (degrees)
        // Three endpoints: wrist (reference), thumbTip (thumb end), indexTip (index end)
        // The angle formed by the thumb + index finger + wrist joints reflects how open the tiger mouth is
        guard let wrist = handPose.wrist,
              let thumbTip = handPose.thumbTip,
              let indexTip = handPose.indexTip else {
            return 0
        }

        // Two vectors: wrist -> thumbTip, wrist -> indexTip
        let v1x = Double(thumbTip.x - wrist.x)
        let v1y = Double(thumbTip.y - wrist.y)
        let v2x = Double(indexTip.x - wrist.x)
        let v2y = Double(indexTip.y - wrist.y)

        let len1 = sqrt(v1x * v1x + v1y * v1y)
        let len2 = sqrt(v2x * v2x + v2y * v2y)

        // Return 0 if either vector is too short (recognition failed / points coincide)
        guard len1 > 0.001, len2 > 0.001 else { return 0 }

        let dot = v1x * v2x + v1y * v2y
        let cosTheta = dot / (len1 * len2)
        let clamped = max(-1.0, min(1.0, cosTheta))
        return acos(clamped) * 180.0 / .pi
    }
    
    private func calculateWristAngle(handPose: HandPoseData) -> Double {
        // Compute the wrist angle relative to the horizontal line
        guard let wrist = handPose.wrist,
              let middleTip = handPose.middleTip else {
            return 0
        }
        
        let dx = middleTip.x - wrist.x
        let dy = middleTip.y - wrist.y
        return atan2(Double(dy), Double(dx))
    }
    
    // MARK: - Rhythm Analysis
    
    private func calculateMovementFrequency() -> Double {
        guard poseHistory.count >= 5 else { return 0 }
        
        // Compute the average movement speed over the last 5 frames
        var totalSpeed: Double = 0
        for i in 1..<min(5, poseHistory.count) {
            let curr = poseHistory[poseHistory.count - i]
            let prev = poseHistory[poseHistory.count - i - 1]
            
            if let currIndex = curr.indexTip, let prevIndex = prev.indexTip {
                let distance = hypot(Double(currIndex.x - prevIndex.x), Double(currIndex.y - prevIndex.y))
                totalSpeed += distance
            }
        }
        
        return totalSpeed / Double(min(4, poseHistory.count - 1))
    }
    
    private func detectSequencePattern() -> [Int] {
        // Detect the finger movement order (0=thumb, 1=index, 2=middle, 3=ring, 4=little)
        guard poseHistory.count >= 3 else { return [] }
        
        var pattern: [Int] = []
        
        // Compare recent frames to find which finger moved the fastest
        for i in 1..<min(3, poseHistory.count) {
            let curr = poseHistory[poseHistory.count - i]
            let prev = poseHistory[poseHistory.count - i - 1]
            
            let fingers = [
                (curr.thumbTip, prev.thumbTip, 0),
                (curr.indexTip, prev.indexTip, 1),
                (curr.middleTip, prev.middleTip, 2),
                (curr.ringTip, prev.ringTip, 3),
                (curr.littleTip, prev.littleTip, 4)
            ]
            
            var maxMovement: Double = 0
            var movingFinger = -1
            
            for (currTip, prevTip, index) in fingers {
                guard let curr = currTip, let prev = prevTip else { continue }
                let distance = hypot(Double(curr.x - prev.x), Double(curr.y - prev.y))
                if distance > maxMovement && distance > 0.01 { // Threshold: 1% of the screen
                    maxMovement = distance
                    movingFinger = index
                }
            }
            
            if movingFinger >= 0 {
                pattern.append(movingFinger)
            }
        }
        
        return pattern
    }
    
    /// Reset the history data
    func reset() {
        poseHistory.removeAll()
    }
}

/// Technique classifier
class TechniqueClassifier {
    private var classificationHistory: [TechniqueType] = []
    private let historySize = 5 // Smooth over the 5 most recent classification results
    
    func classify(features: HandMotionFeatures) -> TechniqueType {
        let technique = classifyBasedOnRules(features: features)
        
        // Append to history and smooth
        classificationHistory.append(technique)
        if classificationHistory.count > historySize {
            classificationHistory.removeFirst()
        }
        
        // Return the most common classification (prevents flicker)
        return mostFrequentTechnique() ?? technique
    }
    
    // MARK: - Rule-based Classification
    
    private func classifyBasedOnRules(features: HandMotionFeatures) -> TechniqueType {
        // Check whether there is enough data
        guard !features.fingerVelocities.isEmpty,
              !features.sequencePattern.isEmpty else {
            return .unknown
        }
        
        // Compute the average finger speed
        let avgSpeed = features.fingerVelocities.map { hypot(Double($0.dx), Double($0.dy)) }
            .reduce(0, +) / Double(features.fingerVelocities.count)
        
        // Compute the wrist movement speed
        let wristSpeed = hypot(Double(features.wristVelocity.dx), Double(features.wristVelocity.dy))
        
        // 1️⃣ Detect "Sweep"
        // Features: all fingers move quickly at once + the wrist is moving too
        let fastFingers = features.fingerVelocities.filter { 
            hypot(Double($0.dx), Double($0.dy)) > 0.5 
        }.count
        if fastFingers >= 4 && wristSpeed > 0.3 {
            print("🎸 Rule match: Sweep (fast fingers:\(fastFingers), wrist speed:\(String(format: "%.2f", wristSpeed)))")
            return .sweep
        }
        
        // 2️⃣ Detect "Tremolo" (Roll)
        // Features: fingers move one after another (a clear sequential pattern)
        if isSequentialPattern(features.sequencePattern) && avgSpeed > 0.2 {
            print("🔄 Rule match: Tremolo (sequence:\(features.sequencePattern), average speed:\(String(format: "%.2f", avgSpeed)))")
            return .roll
        }
        
        // 3️⃣ Detect "Pluck"
        // Features: a single finger moves quickly while the others stay relatively still
        let movingFingers = features.fingerVelocities.enumerated().filter { index, velocity in
            hypot(Double(velocity.dx), Double(velocity.dy)) > 0.4
        }
        
        if movingFingers.count == 1 || movingFingers.count == 2 {
            print("👆 Rule match: Pluck (active fingers:\(movingFingers.count))")
            return .pluck
        }
        
        // 4️⃣ Moderate movement that matches none of the patterns above
        if avgSpeed > 0.15 {
            // Default to tremolo (the most common)
            print("🤔 Fuzzy match: defaulting to Tremolo (average speed:\(String(format: "%.2f", avgSpeed)))")
            return .roll
        }
        
        // 5️⃣ No obvious movement
        return .unknown
    }
    
    // MARK: - Helper Methods
    
    /// Whether the pattern is sequential (e.g. [1,2,3] or [4,3,2,1])
    private func isSequentialPattern(_ pattern: [Int]) -> Bool {
        guard pattern.count >= 2 else { return false }
        
        // Check for an ascending sequence
        let isAscending = pattern.enumerated().dropFirst().allSatisfy { index, value in
            value > pattern[index - 1]
        }
        
        // Check for a descending sequence
        let isDescending = pattern.enumerated().dropFirst().allSatisfy { index, value in
            value < pattern[index - 1]
        }
        
        return isAscending || isDescending
    }
    
    /// Return the most frequent technique in the history (smoothing)
    private func mostFrequentTechnique() -> TechniqueType? {
        guard !classificationHistory.isEmpty else { return nil }
        
        // Count how often each technique occurs
        var counts: [TechniqueType: Int] = [:]
        for technique in classificationHistory {
            counts[technique, default: 0] += 1
        }
        
        // Find the one that occurs most often
        let sorted = counts.sorted { $0.value > $1.value }
        let mostCommon = sorted.first?.key
        
        // If the most common is unknown, fall back to the second most common
        if mostCommon == .unknown, sorted.count > 1 {
            return sorted[1].key
        }
        
        return mostCommon
    }
    
    /// Reset the classification history
    func reset() {
        classificationHistory.removeAll()
    }
}

// MARK: - Core ML Sound Classification Engine

/// Loads the custom Create ML sound classification model PipaSoundClassifier,
/// captures 16 kHz audio with AVAudioEngine, and runs four-class inference on device (pipa / other instrument / speech / ambient noise).
/// Nothing is uploaded, written to disk, or sent over the network: audio only slides through memory and inference happens on device.
final class PipaSoundClassifierEngine: @unchecked Sendable {
    
    /// Input sample rate required by the model
    static let sampleRate: Double = 16000
    
    /// Whether the model loaded successfully — callers should degrade to vision-only recognition when it fails
    private(set) var isAvailable: Bool = false
    
    private let model: MLModel?
    private let inputName: String
    private let inputShape: [NSNumber]
    private let windowLength: Int
    private let hopLength: Int
    
    private let queue = DispatchQueue(label: "com.pluckbuddy.soundclassifier", qos: .userInitiated)
    private var resultHandler: (@Sendable (String, Double) -> Void)?
    private var engine: AVAudioEngine?
    private var pendingSamples: [Float] = []
    private var recentProbabilities: [Double] = []
    private var isRunning = false
    private var didActivateSession = false
    
    init() {
        let loaded = Self.loadModel()
        model = loaded?.model
        inputName = loaded?.inputName ?? "audioSamples"
        inputShape = loaded?.shape ?? [NSNumber(value: 15600)]
        windowLength = loaded?.length ?? 15600
        hopLength = max((loaded?.length ?? 15600) / 2, 1)
        isAvailable = loaded != nil
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Model Loading
    
    private struct LoadedModel {
        let model: MLModel
        let inputName: String
        let shape: [NSNumber]
        let length: Int
    }
    
    private static func loadModel() -> LoadedModel? {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        
        // Xcode compiles .mlmodel into .mlmodelc inside the bundle; compile it on the fly as a fallback
        var modelURL = Bundle.main.url(forResource: "PipaSoundClassifier", withExtension: "mlmodelc")
        if modelURL == nil,
           let rawURL = Bundle.main.url(forResource: "PipaSoundClassifier", withExtension: "mlmodel") {
            modelURL = try? MLModel.compileModel(at: rawURL)
        }
        
        guard let url = modelURL,
              let model = try? MLModel(contentsOf: url, configuration: configuration) else {
            print("❌ Failed to load PipaSoundClassifier: no usable model found in the bundle")
            return nil
        }
        
        let inputs = model.modelDescription.inputDescriptionsByName
        let inputName = inputs["audioSamples"] != nil ? "audioSamples" : (inputs.keys.first ?? "audioSamples")
        let shape = inputs[inputName]?.multiArrayConstraint?.shape ?? [NSNumber(value: 15600)]
        let length = shape.reduce(1) { $0 * $1.intValue }
        
        print("✅ PipaSoundClassifier loaded")
        print("   Input: \(inputName) \(shape.map { $0.intValue }) → \(length) samples")
        print("   Output: \(model.modelDescription.outputDescriptionsByName.keys.sorted())")
        
        return LoadedModel(model: model, inputName: inputName, shape: shape, length: length)
    }
    
    // MARK: - Capture Control
    
    /// Set the inference result callback (category label + pipa probability)
    func setResultHandler(_ handler: @escaping @Sendable (String, Double) -> Void) {
        queue.sync { resultHandler = handler }
    }
    
    func start() throws {
        var failure: Error?
        
        queue.sync {
            guard !isRunning, model != nil else { return }
            
            let session = AVAudioSession.sharedInstance()
            do {
                // Use the same session configuration as the tuner AudioManager: record and play back (metronome / demo tones),
                // and allow mixing with other audio, so switching to record-only never interrupts sounds already playing
                try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker])
                try session.setActive(true)
                didActivateSession = true
            } catch {
                failure = error
                return
            }
            
            let audioEngine = AVAudioEngine()
            let input = audioEngine.inputNode
            // Key point: the tap must use the input node's own output format (48 kHz as measured on device).
            // Specifying the 16 kHz the model needs here makes AVAudioEngine throw
            // "Failed to create tap due to format mismatch" and terminate the process.
            // So we capture in the hardware format and downsample to 16 kHz in software inside the callback.
            let inputFormat = input.outputFormat(forBus: 0)
            print("🎤 Sound classification capture format: \(inputFormat.sampleRate) Hz / \(inputFormat.channelCount) ch")
            
            input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
                guard let self else { return }
                let samples = Self.monoSamples(from: buffer, targetSampleRate: Self.sampleRate)
                self.queue.async { self.append(samples) }
            }
            
            do {
                try audioEngine.start()
            } catch {
                input.removeTap(onBus: 0)
                failure = error
                return
            }
            
            engine = audioEngine
            pendingSamples.removeAll()
            recentProbabilities.removeAll()
            isRunning = true
        }
        
        if let failure {
            throw failure
        }
    }
    
    func stop() {
        queue.sync {
            guard isRunning else { return }
            engine?.inputNode.removeTap(onBus: 0)
            engine?.stop()
            engine = nil
            pendingSamples.removeAll()
            recentProbabilities.removeAll()
            isRunning = false
            // Only deactivate the session if this capture actually activated it, so we never disturb the session the tuner is still using
            if didActivateSession {
                try? AVAudioSession.sharedInstance().setActive(false)
                didActivateSession = false
            }
        }
    }
    
    // MARK: - Inference
    
    /// Run inference once a full window has accumulated, keeping 50% overlap between windows
    private func append(_ samples: [Float]) {
        guard !samples.isEmpty else { return }
        pendingSamples.append(contentsOf: samples)
        
        while pendingSamples.count >= windowLength {
            let window = Array(pendingSamples.prefix(windowLength))
            pendingSamples.removeFirst(min(hopLength, pendingSamples.count))
            classify(window)
        }
        
        // Drop the backlog when inference cannot keep up with capture, to avoid unbounded memory growth
        if pendingSamples.count > windowLength * 4 {
            pendingSamples.removeFirst(pendingSamples.count - windowLength)
        }
    }
    
    private func classify(_ window: [Float]) {
        guard let model, window.count == windowLength else { return }
        guard let array = try? MLMultiArray(shape: inputShape, dataType: .float32) else { return }
        for index in 0..<windowLength {
            array[index] = NSNumber(value: window[index])
        }
        let value = MLFeatureValue(multiArray: array)
        
        let provider: MLFeatureProvider
        do {
            provider = try MLDictionaryFeatureProvider(dictionary: [inputName: value])
        } catch {
            return
        }
        
        guard let output = try? model.prediction(from: provider) else { return }
        
        let rawLabel = output.featureValue(for: "target")?.stringValue ?? "background"
        let probability = (output.featureValue(for: "targetProbability")?.dictionaryValue["pipa"] as? NSNumber)?.doubleValue ?? 0
        
        // Average the last three results to suppress single-frame jitter
        recentProbabilities.append(probability)
        if recentProbabilities.count > 3 {
            recentProbabilities.removeFirst()
        }
        let smoothed = recentProbabilities.reduce(0, +) / Double(recentProbabilities.count)
        
        resultHandler?(Self.chineseLabel(for: rawLabel), smoothed)
    }
    
    // MARK: - Audio Processing
    
    /// Mix a PCM buffer of any format down to mono and resample it to the model sample rate
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
        
        // Software resampling from 48 kHz → 16 kHz: linear interpolation, since plain decimation adds high-frequency distortion and hurts classification confidence
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
    
    private static func chineseLabel(for raw: String) -> String {
        switch raw {
        case "pipa": return "Pipa"
        case "other_instrument": return "Other Instrument"
        case "speech": return "Speech"
        case "background": return "Background Noise"
        default: return raw
        }
    }
}

// MARK: - Note:
// RollPostureEvaluator, SweepPostureEvaluator, PluckPostureEvaluator
// These classes are now defined in TechniqueEvaluators.swift
