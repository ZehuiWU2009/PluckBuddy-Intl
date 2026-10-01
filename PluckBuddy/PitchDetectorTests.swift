//
//  PitchDetectorTests.swift
//  PluckBuddyTests
//
//  Created by Zehui Wu on 2026/7/15.
//

import XCTest
import AVFoundation
@testable import PluckBuddy

/// Pitch detection tests
final class PitchDetectorTests: XCTestCase {
    
    /// Detect A2 (110 Hz)
    func testA2Detection() throws {
        let detector = PitchDetector(sampleRate: 44100, bufferSize: 4096)
        
        // Generate a 110 Hz sine wave
        let buffer = generateSineWave(frequency: 110.0, sampleRate: 44100, duration: 0.1)
        
        let detectedFreq = detector.detectPitch(from: buffer)
        
        // Verify the result is between 108-112 Hz (allowing a 2 Hz margin)
        XCTAssertNotNil(detectedFreq, "A frequency should be detected")
        if let freq = detectedFreq {
            XCTAssertGreaterThan(freq, 108.0, "The detected frequency should be greater than 108 Hz, actual: \(freq)")
            XCTAssertLessThan(freq, 112.0, "The detected frequency should be less than 112 Hz, actual: \(freq)")
        }
    }
    
    /// Detect d3 (146.83 Hz)
    func testD3Detection() throws {
        let detector = PitchDetector(sampleRate: 44100, bufferSize: 4096)
        
        let buffer = generateSineWave(frequency: 146.83, sampleRate: 44100, duration: 0.1)
        
        let detectedFreq = detector.detectPitch(from: buffer)
        
        XCTAssertNotNil(detectedFreq)
        if let freq = detectedFreq {
            XCTAssertGreaterThan(freq, 144.0, "The detected frequency should be greater than 144 Hz, actual: \(freq)")
            XCTAssertLessThan(freq, 149.0, "The detected frequency should be less than 149 Hz, actual: \(freq)")
        }
    }
    
    /// Detect e3 (164.81 Hz)
    func testE3Detection() throws {
        let detector = PitchDetector(sampleRate: 44100, bufferSize: 4096)
        
        let buffer = generateSineWave(frequency: 164.81, sampleRate: 44100, duration: 0.1)
        
        let detectedFreq = detector.detectPitch(from: buffer)
        
        XCTAssertNotNil(detectedFreq)
        if let freq = detectedFreq {
            XCTAssertGreaterThan(freq, 162.0, "The detected frequency should be greater than 162 Hz, actual: \(freq)")
            XCTAssertLessThan(freq, 168.0, "The detected frequency should be less than 168 Hz, actual: \(freq)")
        }
    }
    
    /// Detect a3 (220 Hz)
    func testA3Detection() throws {
        let detector = PitchDetector(sampleRate: 44100, bufferSize: 4096)
        
        let buffer = generateSineWave(frequency: 220.0, sampleRate: 44100, duration: 0.1)
        
        let detectedFreq = detector.detectPitch(from: buffer)
        
        XCTAssertNotNil(detectedFreq)
        if let freq = detectedFreq {
            XCTAssertGreaterThan(freq, 218.0, "The detected frequency should be greater than 218 Hz, actual: \(freq)")
            XCTAssertLessThan(freq, 222.0, "The detected frequency should be less than 222 Hz, actual: \(freq)")
        }
    }
    
    /// Should return nil when there is no signal
    func testNoSignal() throws {
        let detector = PitchDetector(sampleRate: 44100, bufferSize: 4096)
        
        // Generate a silent buffer
        let buffer = generateSilence(sampleRate: 44100, duration: 0.1)
        
        let detectedFreq = detector.detectPitch(from: buffer)
        
        XCTAssertNil(detectedFreq, "Silence should return nil")
    }
    
    /// Frequencies outside the valid range should return nil
    func testOutOfRange() throws {
        let detector = PitchDetector(sampleRate: 44100, bufferSize: 4096)
        
        // Generate 50 Hz (too low)
        let lowBuffer = generateSineWave(frequency: 50.0, sampleRate: 44100, duration: 0.1)
        let lowFreq = detector.detectPitch(from: lowBuffer)
        XCTAssertNil(lowFreq, "50 Hz should be filtered out")
        
        // Generate 400 Hz (too high)
        let highBuffer = generateSineWave(frequency: 400.0, sampleRate: 44100, duration: 0.1)
        let highFreq = detector.detectPitch(from: highBuffer)
        XCTAssertNil(highFreq, "400 Hz should be filtered out")
    }
    
    // MARK: - Helper Functions
    
    /// Generate a sine wave test signal
    func generateSineWave(frequency: Double, sampleRate: Double, duration: Double) -> AVAudioPCMBuffer {
        let frameCount = Int(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))!
        buffer.frameLength = buffer.frameCapacity
        
        let channelData = buffer.floatChannelData![0]
        let angularFrequency = 2.0 * Double.pi * frequency / sampleRate
        
        for i in 0..<frameCount {
            channelData[i] = Float(sin(angularFrequency * Double(i)))
        }
        
        return buffer
    }
    
    /// Generate a silent signal
    func generateSilence(sampleRate: Double, duration: Double) -> AVAudioPCMBuffer {
        let frameCount = Int(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))!
        buffer.frameLength = buffer.frameCapacity
        
        let channelData = buffer.floatChannelData![0]
        for i in 0..<frameCount {
            channelData[i] = 0.0
        }
        
        return buffer
    }
}
