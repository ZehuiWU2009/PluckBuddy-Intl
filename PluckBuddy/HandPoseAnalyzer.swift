//
//  HandPoseAnalyzer.swift
//  PluckBuddy
//
//  Hand pose utility classes - provides hand pose smoothing, visualization, and geometry helpers
//  Note: HandPoseExtractor and HandKeypoint are defined in HandPoseExtractor.swift
//  Note: HandPoseData and HandPoseAnalyzer are defined in TechniqueCoachViewModel.swift
//  Created on 2026/8/31.
//

import Vision
import AVFoundation
import CoreImage
import UIKit
// MARK: - Hand pose smoother (Kalman filter)

/// Hand pose smoother - uses a simplified Kalman filter to reduce jitter
/// Used to smooth hand landmark positions and improve stability
class HandPoseSmoother {
    
    // MARK: - Kalman Filter State
    
    /// Kalman filter state for each landmark
    private var filterStates: [String: KalmanFilterState] = [:]
    
    /// Kalman filter state
    private struct KalmanFilterState {
        var position: CGPoint
        var velocity: CGVector
        var lastUpdate: Date
    }
    
    // MARK: - Parameters
    
    /// Process noise covariance (larger value means more trust in measurements)
    private let processNoise: CGFloat = 0.01
    
    /// Measurement noise covariance (larger value means more trust in predictions)
    private let measurementNoise: CGFloat = 0.1
    
    // MARK: - Public Methods
    
    /// Smooths hand landmark positions
    /// - Parameter keypoints: Raw landmark array
    /// - Returns: Smoothed landmark array
    func smooth(keypoints: [HandKeypoint]) -> [HandKeypoint] {
        let now = Date()
        
        return keypoints.map { keypoint in
            // Get or create the filter state
            if var state = filterStates[keypoint.name] {
                // Compute the time interval
                let dt = CGFloat(now.timeIntervalSince(state.lastUpdate))
                
                // Prediction step
                let predictedPosition = CGPoint(
                    x: state.position.x + state.velocity.dx * dt,
                    y: state.position.y + state.velocity.dy * dt
                )
                
                // Update step (simplified Kalman gain calculation)
                let kalmanGain = processNoise / (processNoise + measurementNoise)
                
                let smoothedPosition = CGPoint(
                    x: predictedPosition.x + kalmanGain * (keypoint.location.x - predictedPosition.x),
                    y: predictedPosition.y + kalmanGain * (keypoint.location.y - predictedPosition.y)
                )
                
                // Update the velocity estimate
                let newVelocity = CGVector(
                    dx: (smoothedPosition.x - state.position.x) / dt,
                    dy: (smoothedPosition.y - state.position.y) / dt
                )
                
                // Save the state
                state.position = smoothedPosition
                state.velocity = newVelocity
                state.lastUpdate = now
                filterStates[keypoint.name] = state
                
                return HandKeypoint(
                    name: keypoint.name,
                    location: smoothedPosition,
                    confidence: keypoint.confidence
                )
                
            } else {
                // First detection, initialize the state
                filterStates[keypoint.name] = KalmanFilterState(
                    position: keypoint.location,
                    velocity: .zero,
                    lastUpdate: now
                )
                return keypoint
            }
        }
    }
    
    /// Resets the filter (called when the hand leaves the frame)
    func reset() {
        filterStates.removeAll()
        print("🔄 Hand pose smoother has been reset")
    }
}

// MARK: - Hand pose visualization (debugging tool)

/// Hand pose visualization tool - for debugging and demonstration
class HandPoseVisualizer {
    
    /// Draws the hand skeleton on an image
    /// - Parameters:
    ///   - keypoints: Hand landmarks
    ///   - imageSize: Image size
    /// - Returns: Image annotated with the skeleton
    static func drawSkeleton(
        keypoints: [HandKeypoint],
        imageSize: CGSize
    ) -> UIImage? {
        // Create the drawing context
        UIGraphicsBeginImageContextWithOptions(imageSize, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        
        // Set drawing attributes
        context.setStrokeColor(UIColor.systemPink.cgColor)
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        
        // Define the hand skeleton connections
        let connections: [(String, String)] = [
            // Wrist to the base of each finger
            ("wrist", "thumbCMC"),
            ("wrist", "indexMCP"),
            ("wrist", "middleMCP"),
            ("wrist", "ringMCP"),
            ("wrist", "littleMCP"),
            
            // Thumb
            ("thumbCMC", "thumbMP"),
            ("thumbMP", "thumbIP"),
            ("thumbIP", "thumbTip"),
            
            // Index finger
            ("indexMCP", "indexPIP"),
            ("indexPIP", "indexDIP"),
            ("indexDIP", "indexTip"),
            
            // Middle finger
            ("middleMCP", "middlePIP"),
            ("middlePIP", "middleDIP"),
            ("middleDIP", "middleTip"),
            
            // Ring finger
            ("ringMCP", "ringPIP"),
            ("ringPIP", "ringDIP"),
            ("ringDIP", "ringTip"),
            
            // Little finger
            ("littleMCP", "littlePIP"),
            ("littlePIP", "littleDIP"),
            ("littleDIP", "littleTip")
        ]
        
        // Build a lookup dictionary for landmarks
        let keypointDict = Dictionary(
            uniqueKeysWithValues: keypoints.map { ($0.name, $0.location) }
        )
        
        // Draw the connecting lines
        for (start, end) in connections {
            guard let startLoc = keypointDict[start],
                  let endLoc = keypointDict[end] else {
                continue
            }
            
            // Convert from Vision coordinates to UIKit coordinates
            let startPoint = CGPoint(
                x: startLoc.x * imageSize.width,
                y: (1 - startLoc.y) * imageSize.height
            )
            let endPoint = CGPoint(
                x: endLoc.x * imageSize.width,
                y: (1 - endLoc.y) * imageSize.height
            )
            
            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.strokePath()
        }
        
        // Draw the landmarks
        context.setFillColor(UIColor.systemBlue.cgColor)
        for keypoint in keypoints {
            let point = CGPoint(
                x: keypoint.location.x * imageSize.width,
                y: (1 - keypoint.location.y) * imageSize.height
            )
            
            // Adjust the point size based on confidence
            let radius = CGFloat(4 + keypoint.confidence * 3)
            let rect = CGRect(
                x: point.x - radius,
                y: point.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            
            context.fillEllipse(in: rect)
        }
        
        // Get the resulting image
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
}

// MARK: - Hand feature calculation utilities

/// Hand feature calculation utilities - provides common geometric calculations
enum HandGeometry {
    
    /// Computes the Euclidean distance between two points
    static func distance(from point1: CGPoint, to point2: CGPoint) -> Double {
        let dx = Double(point2.x - point1.x)
        let dy = Double(point2.y - point1.y)
        return hypot(dx, dy)
    }
    
    /// Computes the angle of a vector (in radians)
    static func angle(from point1: CGPoint, to point2: CGPoint) -> Double {
        let dx = Double(point2.x - point1.x)
        let dy = Double(point2.y - point1.y)
        return atan2(dy, dx)
    }
    
    /// Computes the angle between three points (in radians)
    /// - Parameters:
    ///   - point1: First point
    ///   - vertex: Vertex
    ///   - point2: Second point
    /// - Returns: The angle (0 to π)
    static func angle(point1: CGPoint, vertex: CGPoint, point2: CGPoint) -> Double {
        let vector1 = CGVector(
            dx: point1.x - vertex.x,
            dy: point1.y - vertex.y
        )
        let vector2 = CGVector(
            dx: point2.x - vertex.x,
            dy: point2.y - vertex.y
        )
        
        let dotProduct = Double(vector1.dx * vector2.dx + vector1.dy * vector2.dy)
        let magnitude1 = hypot(Double(vector1.dx), Double(vector1.dy))
        let magnitude2 = hypot(Double(vector2.dx), Double(vector2.dy))
        
        guard magnitude1 > 0, magnitude2 > 0 else { return 0 }
        
        let cosAngle = dotProduct / (magnitude1 * magnitude2)
        return acos(max(-1, min(1, cosAngle)))
    }
    
    /// Determines whether a finger is bent
    /// - Parameters:
    ///   - mcp: Metacarpophalangeal joint
    ///   - pip: Proximal interphalangeal joint
    ///   - dip: Distal interphalangeal joint
    ///   - tip: Fingertip
    /// - Returns: Whether the finger is bent
    static func isFingerBent(mcp: CGPoint, pip: CGPoint, dip: CGPoint, tip: CGPoint) -> Bool {
        // Compute the angles of the three joints
        let angle1 = angle(point1: mcp, vertex: pip, point2: dip)
        let angle2 = angle(point1: pip, vertex: dip, point2: tip)
        
        // If the angle is less than 150 degrees (2.618 radians), the finger is considered bent
        return angle1 < 2.618 || angle2 < 2.618
    }
}

