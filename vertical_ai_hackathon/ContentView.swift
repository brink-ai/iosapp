//
//  ContentView.swift
//  vertical_ai_hackathon
//
//  Created by Andrew Blakeslee Moore on 10/20/24.
//

import SwiftUI
import AVFoundation
import Speech


class AudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    private var audioEngine: AVAudioEngine
    private var inputNode: AVAudioInputNode
    private var bus: AVAudioNodeBus
    private var audioFile: AVAudioFile?  // Store the audio file for saving input
    private var sessionID: String?

    private var speechRecognizer: SFSpeechRecognizer?  // Speech recognizer for converting audio to text
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?  // Request for recognizing speech
    private var recognitionTask: SFSpeechRecognitionTask?  // Task handling the recognition process

    @Published var inputLevel: CGFloat = 0
    @Published var isRecording = false  // Track whether recording is in progress
    @Published var isPlayingOutput = false  // Track whether output is being played
    @Published var transcribedText: String = ""  // Store the transcribed text

    private var audioPlayer: AVAudioPlayer?

    override init() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode
        bus = 0  // For stereo, 0 is left channel and 1 is right channel

        speechRecognizer = SFSpeechRecognizer()

        super.init()

        setupAudioSession()
        requestSpeechAuthorization()
        setupAudioMonitoring()
    }

    func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            switch authStatus {
            case .authorized:
                print("Speech recognition authorized.")
            case .denied, .restricted, .notDetermined:
                print("Speech recognition not available.")
            @unknown default:
                print("Unknown speech recognition status.")
            }
        }
    }

    func startAudioEngine() {
        if audioEngine.isRunning {
            print("Audio engine is already running.")
            return
        }

        do {
            reinstallAudioTap()
            try audioEngine.start()
            isRecording = true
            print("Audio engine started.")
            startSpeechRecognition()
        } catch {
            print("Audio Engine couldn't start: \(error)")
        }
    }

    func stopAudioEngine() {
        inputNode.removeTap(onBus: bus)  // Remove the tap before stopping the engine
        audioEngine.stop()
        isRecording = false
        recognitionTask?.cancel()
        recognitionTask = nil
        print("Audio engine stopped.")
    }
    
    func startSpeechRecognition() {
        // Ensure audio engine is running
        guard audioEngine.isRunning else {
            print("Audio engine is not running.")
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request.")
            return
        }

        recognitionRequest.shouldReportPartialResults = true  // Allow partial results

        // Start speech recognition
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                // Update transcribed text with the most recent transcription
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                    print("Transcribed Text: \(self.transcribedText)")
                }

                if result.isFinal {
                    // Send the final transcription to the server
                    self.sendTranscriptionToServer(text: self.transcribedText)
                }
            }

            if error != nil || result?.isFinal == true {
                self.audioEngine.stop()
                self.inputNode.removeTap(onBus: self.bus)
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }

    }
    
    
    func sendTranscriptionToServer(text: String) {
        guard let url = URL(string: "http://192.168.234.1:5001/run_agent") else {
            print("Invalid server URL")
            return
        }
        
        print(url)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        print(request)

        // Create the JSON body
        var bodyDict: [String: Any] = [
            "user_query": text,
            "audio": true
        ]

        // Include session_id if available
        if let sessionID = self.sessionID {
            bodyDict["session_id"] = sessionID
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: bodyDict, options: [])
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } catch {
            print("Error serializing JSON: \(error)")
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending request: \(error)")
                return
            }

            guard let data = data else {
                print("No data received from server")
                return
            }

            print(data)
            // Handle the received data
            self.handleServerResponse(data)
        }

        task.resume()
    }
    
    private func handleServerResponse(_ data: Data) {
        do {
            // Parse the JSON response
            if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                // Extract session_id if available
                if let newSessionID = jsonResponse["session_id"] as? String {
                    self.sessionID = newSessionID
                    print("Received session ID: \(self.sessionID!)")
                }

                // Handle the audio data if 'audio_data' key is present
                if let audioBase64String = jsonResponse["audio_data"] as? String {
                    // Decode the base64 string to Data
                    if let audioData = Data(base64Encoded: audioBase64String) {
                        self.handleReceivedAudioData(audioData)
                    } else {
                        print("Error decoding audio data")
                    }
                } else {
                    print("No audio data received")
                }
            } else {
                print("Invalid JSON response")
            }
        } catch {
            print("Error parsing server response: \(error)")
        }
    }
    
    
    private func handleReceivedAudioData(_ data: Data) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFileURL = documentsPath.appendingPathComponent("responseAudio.m4a")

        do {
            try data.write(to: audioFileURL)
            print("Audio file saved to \(audioFileURL)")

            // Play the saved audio file
            playAudioFile(url: audioFileURL)
        } catch {
            print("Error saving audio file: \(error)")
        }
    }
    
    private func playAudioFile(url: URL) {
        DispatchQueue.main.async {
            do {
                self.audioPlayer = try AVAudioPlayer(contentsOf: url)
                self.audioPlayer?.delegate = self
                self.audioPlayer?.prepareToPlay()
                self.audioPlayer?.play()
                self.isPlayingOutput = true
                print("Playing audio...")
            } catch {
                print("Error playing audio: \(error)")
            }
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.isPlayingOutput = false
        print("Finished playing audio.")
    }

    func setupAudioMonitoring() {
        do {
            try prepareAudioFile()
        } catch {
            print("Error preparing audio file: \(error)")
        }

        reinstallAudioTap()
    }

    private func prepareAudioFile() throws {
        let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioFileURL = documentDir.appendingPathComponent("recordedAudio.caf")  // Save as Core Audio Format (CAF)

        // Create audio file with same format as input node
        let format = inputNode.outputFormat(forBus: bus)
        audioFile = try AVAudioFile(forWriting: audioFileURL, settings: format.settings)
    }

    private func setupAudioSession() {
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

    func reinstallAudioTap() {
        // Retrieve the hardware format dynamically
        let hardwareFormat = inputNode.inputFormat(forBus: bus)
        print("Input Node Format (Hardware): \(hardwareFormat)")  // Log format for debugging

        // Remove any existing tap to avoid conflicts
        inputNode.removeTap(onBus: bus)

        // Install the tap on the input node with the correct hardware format
        inputNode.installTap(onBus: bus, bufferSize: 1024, format: hardwareFormat) { buffer, _ in
            // Update input level on the main thread
            DispatchQueue.main.async {
                self.inputLevel = self.calculateRMSLevel(buffer: buffer)
            }

            // Save audio buffer if needed
            self.saveAudioBuffer(buffer: buffer)

            // Append buffer to recognition request if available
            if let recognitionRequest = self.recognitionRequest {
                recognitionRequest.append(buffer)
            }
        }
    }
    
    
    private func saveAudioBuffer(buffer: AVAudioPCMBuffer) {
        do {
            try audioFile?.write(from: buffer)
        } catch {
            print("Error writing audio buffer to file: \(error)")
        }
    }

    private func calculateRMSLevel(buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))
        let rms = sqrt(channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        return CGFloat(rms) * 1000  // Amplify the RMS value further for more visible changes
    }
}

struct ContentView: View {
    @ObservedObject var audioManager = AudioManager()
    @Environment(\.colorScheme) var colorScheme
    @State var listening: Bool = true  // Default to listening for now

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            VStack {
                if listening {
                    ListeningCircleView(level: audioManager.inputLevel)
                } else if audioManager.isPlayingOutput {
                    SpeakingCircleView(level: audioManager.inputLevel)
                } else {
                    Text("Processing...")
                        .font(.title)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }

                Button(action: {
                    if listening {
                        audioManager.stopAudioEngine()  // Stop recording and process audio
                    } else {
                        audioManager.reinstallAudioTap()  // Restart the audio tap
                        audioManager.startAudioEngine()  // Restart the audio engine for listening
                    }
                    listening.toggle()
                }) {
                    Text(listening ? "Stop Listening and Process" : "Start Listening")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }
        }
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? .black : .white
    }
}

struct ListeningCircleView: View {
    var level: CGFloat
    var body: some View {
        ZStack {
            CircleView(level: level, title: "Listening...")
        }
    }
}

struct SpeakingCircleView: View {
    var level: CGFloat
    var body: some View {
        CircleView(level: level, title: "Speaking...")
    }
}

struct CircleView: View {
    var level: CGFloat
    var title: String

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .stroke(strokeColor, lineWidth: 10 + (level))  // Adjust line width based on audio level
                .frame(width: 200, height: 200)
                .padding(20)

            Text(title)
                .foregroundColor(strokeColor)
                .font(.title)
        }
        .animation(.easeInOut(duration: 0.1), value: level)
    }

    private var strokeColor: Color {
        colorScheme == .dark ? .white : .black
    }
}
