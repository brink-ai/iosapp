//
//  AudioManager.swift
//  vertical_ai_hackathon
//
//  Created by Andrew Blakeslee Moore on 10/20/24.
//

import Foundation
import AVFoundation

class AudioManager: ObservableObject {
    private var audioEngine: AVAudioEngine
    private var inputNode: AVAudioInputNode
    private var bus: AVAudioNodeBus
    private var audioFile: AVAudioFile?  // Store the audio file for saving input

    @Published var inputLevel: CGFloat = 0
    @Published var isRecording = false  // Track whether recording is in progress
    
    init() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode
        bus = 0  // For stereo, 0 is left channel and 1 is right channel
        
        setupAudioSession()
        setupAudioMonitoring()
        handleAudioRouteChangeNotifications()
    }
    
    func startAudioEngine() {
        do {
            // Prepare audio file for saving
            try prepareAudioFile()
            
            try audioEngine.start()
            isRecording = true
            print("Audio engine started.")
        } catch {
            print("Audio Engine couldn't start: \(error)")
        }
    }
    
    func stopAudioEngine() {
        audioEngine.stop()
        isRecording = false
        print("Audio engine stopped.")
        
        // Call function to send the file to a Python script
        sendAudioToPythonScript()
    }
    
    private func prepareAudioFile() throws {
        let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioFileURL = documentDir.appendingPathComponent("recordedAudio.caf")  // Save as Core Audio Format (CAF)
        
        // Create audio file with same format as input node
        let format = inputNode.outputFormat(forBus: bus)
        audioFile = try AVAudioFile(forWriting: audioFileURL, settings: format.settings)
    }
    
    private func setupAudioSession() {
        DispatchQueue.main.async {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                
                // Configure the session for both playback and recording
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                
                // Make the session active
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                
                print("Audio session is active.")
                
            } catch {
                print("Error setting up AVAudioSession: \(error)")
            }
        }
    }
    
    private func setupAudioMonitoring() {
        // Get the microphone's hardware format (the format it is currently using)
        let hardwareFormat = inputNode.inputFormat(forBus: bus)
        print("Input Node Format (Hardware): \(hardwareFormat)")  // Log format for debugging
        
        // Tap the input node with the correct format (hardware format)
        inputNode.installTap(onBus: bus, bufferSize: 1024, format: hardwareFormat) { buffer, _ in
            DispatchQueue.main.async {
                self.inputLevel = self.calculateRMSLevel(buffer: buffer)
                self.saveAudioBuffer(buffer: buffer)
                print("Input Level: \(self.inputLevel)")  // Log the input level to track its changes
            }
        }
        
        startAudioEngine()
    }
    
    private func saveAudioBuffer(buffer: AVAudioPCMBuffer) {
        do {
            try audioFile?.write(from: buffer)
        } catch {
            print("Error writing audio buffer to file: \(error)")
        }
    }
    
    private func handleAudioRouteChangeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt else { return }
        if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
            // Reactivate the session if an audio device (like Bluetooth) changes
            print("Audio route changed. Reactivating session...")
            setupAudioSession()
        }
    }
    
    private func calculateRMSLevel(buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))
        let rms = sqrt(channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        return CGFloat(rms) * 1000  // Amplify the RMS value further for more visible changes
    }
    
    // Function to send the saved audio file to a Python script
    private func sendAudioToPythonScript() {
        let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioFileURL = documentDir.appendingPathComponent("recordedAudio.caf")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/python3")  // Path to Python 3 executable
        task.arguments = ["/path/to/your/script.py", audioFileURL.path]  // Your Python script path and audio file path
        
        do {
            try task.run()
            task.waitUntilExit()
            print("Audio sent to Python script.")
        } catch {
            print("Error sending audio to Python script: \(error)")
        }
    }
}
