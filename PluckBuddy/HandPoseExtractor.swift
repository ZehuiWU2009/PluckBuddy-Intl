//
//  HandPoseExtractor.swift
//  PluckBuddy
//
//  Created by Zehui Wu on 2026/8/17.
//

import Vision
import AVFoundation
import CoreImage

/// Hand pose extractor
/// Extracts 21 hand keypoints using Apple's Vision framework
class HandPoseExtractor {
    
    // MARK: - Properties
    private var handPoseRequest: VNDetectHumanHandPoseRequest
    
    // Names of the 21 keypoints (in order)
    private let jointNames: [VNHumanHandPoseObservation.JointName] = [
        .wrist,
        .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
        .indexMCP, .indexPIP, .indexDIP, .indexTip,
        .middleMCP, .middlePIP, .middleDIP, .middleTip,
        .ringMCP, .ringPIP, .ringDIP, .ringTip,
        .littleMCP, .littlePIP, .littleDIP, .littleTip
    ]
    
    // MARK: - Initialization
    init() {
        handPoseRequest = VNDetectHumanHandPoseRequest()
        handPoseRequest.maximumHandCount = 2  // Detect at most 2 hands
    }
    
    // MARK: - Public Methods
    
    /// Extract hand keypoints from a video frame
    /// - Parameter buffer: The video frame buffer
    /// - Returns: An array of keypoints (each with x, y coordinates and a confidence value)
    func extractKeypoints(from buffer: CVPixelBuffer) async throws -> [HandKeypoint] {
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, options: [:])
        try handler.perform([handPoseRequest])
        
        guard let observations = handPoseRequest.results,
              !observations.isEmpty else {
            // No hand detected, return an empty array
            return []
        }
        
        // Extract the keypoints of the first hand (usually the right hand)
        let firstHand = observations.first!
        var keypoints: [HandKeypoint] = []
        
        for jointName in jointNames {
            if let point = try? firstHand.recognizedPoint(jointName) {
                // Use shorter keypoint names (for example: "wrist", "thumbTip", etc.)
                let simpleName = getSimpleName(for: jointName)
                keypoints.append(HandKeypoint(
                    name: simpleName,
                    location: point.location,
                    confidence: Double(point.confidence)
                ))
            }
        }
        
        print("✅ Detected \(keypoints.count) keypoints")  // Debug log
        return keypoints
    }
    
    /// Get the simplified name of a keypoint
    private func getSimpleName(for jointName: VNHumanHandPoseObservation.JointName) -> String {
        switch jointName {
        case .wrist: return "wrist"
        case .thumbCMC: return "thumbCMC"
        case .thumbMP: return "thumbMP"
        case .thumbIP: return "thumbIP"
        case .thumbTip: return "thumbTip"
        case .indexMCP: return "indexMCP"
        case .indexPIP: return "indexPIP"
        case .indexDIP: return "indexDIP"
        case .indexTip: return "indexTip"
        case .middleMCP: return "middleMCP"
        case .middlePIP: return "middlePIP"
        case .middleDIP: return "middleDIP"
        case .middleTip: return "middleTip"
        case .ringMCP: return "ringMCP"
        case .ringPIP: return "ringPIP"
        case .ringDIP: return "ringDIP"
        case .ringTip: return "ringTip"
        case .littleMCP: return "littleMCP"
        case .littlePIP: return "littlePIP"
        case .littleDIP: return "littleDIP"
        case .littleTip: return "littleTip"
        default: return "unknown"
        }
    }
    
    /// Build a flattened feature vector from the keypoint array (for model input)
    /// - Parameter keypoints: The keypoint array
    /// - Returns: A feature vector [x1, y1, x2, y2, ..., x21, y21]
    func extractFeatureVector(from keypoints: [HandKeypoint]) -> [Double] {
        var features: [Double] = []
        
        for keypoint in keypoints {
            features.append(Double(keypoint.location.x))
            features.append(Double(keypoint.location.y))
        }
        
        return features
    }
    
    /// Normalize keypoint coordinates (relative to the wrist)
    /// - Parameter keypoints: The raw keypoints
    /// - Returns: The normalized keypoints
    func normalizeKeypoints(_ keypoints: [HandKeypoint]) -> [HandKeypoint] {
        guard !keypoints.isEmpty else { return [] }
        
        // Use the wrist as the reference point
        let wrist = keypoints[0].location
        
        return keypoints.map { keypoint in
            HandKeypoint(
                name: keypoint.name,
                location: CGPoint(
                    x: keypoint.location.x - wrist.x,
                    y: keypoint.location.y - wrist.y
                ),
                confidence: keypoint.confidence
            )
        }
    }
}

// MARK: - Data Structures

/// Hand keypoint data structure
struct HandKeypoint {
    let name: String
    let location: CGPoint
    let confidence: Double
}

/// Hand pose data (containing the full keypoint sequence)
struct HandPose {
    let keypoints: [HandKeypoint]
    let timestamp: Date
    
    /// Whether it is valid (at least 50% of the keypoints detected)
    var isValid: Bool {
        let validCount = keypoints.filter { $0.confidence > 0.3 }.count
        return Double(validCount) / Double(keypoints.count) > 0.5
    }
}
