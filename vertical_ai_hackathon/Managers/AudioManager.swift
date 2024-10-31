import AVFoundation
import Speech

class AudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private let bus: Int = 0
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    @Published var inputLevel: CGFloat = 0
    @Published var isRecording = false
    @Published var transcribedText: String = ""
    @Published var apiResponse: String = ""
    
    private var apiCheckTimer: Timer?
    
    override init() {
        super.init()
        setupAudio()
        requestSpeechAuthorization()
    }
    
    private func setupAudio() {
        // Initialize audio session first
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setPreferredSampleRate(44100.0)
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
            
            print("Audio Session initialized with sample rate: \(session.sampleRate)")
            
            // Initialize audio engine after session is set up
            audioEngine = AVAudioEngine()
            inputNode = audioEngine?.inputNode
            speechRecognizer = SFSpeechRecognizer(locale: .current)
            
        } catch {
            print("Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    func startRecording() {
        guard !isRecording,
              let audioEngine = audioEngine,
              let inputNode = inputNode else {
            print("Audio engine or input node not available")
            return
        }
        
        // Reset state
        transcribedText = ""
        apiResponse = ""
        
        do {
            // Stop any existing audio
            if audioEngine.isRunning {
                audioEngine.stop()
                inputNode.removeTap(onBus: bus)
            }
            
            // Ensure audio session is properly configured
            let audioSession = AVAudioSession.sharedInstance()
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            }
            
            // Configure and start the engine
            try audioEngine.start()
            
            // Start speech recognition after engine is running
            startSpeechRecognition()
            
            isRecording = true
            print("Recording started successfully")
            
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
            stopRecording()
        }
    }
    
    func stopRecording() {
        guard let audioEngine = audioEngine,
              let inputNode = inputNode else { return }
        
        // Remove tap first
        inputNode.removeTap(onBus: bus)
        
        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Clean up recognition
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isRecording = false
        print("Recording stopped")
    }
    
    private func startSpeechRecognition() {
        guard let audioEngine = audioEngine,
              let inputNode = inputNode else { return }
        
        // Reset any existing recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Create new recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Configure recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                    
                    if result.isFinal {
                        self.processTranscription(prompt: self.transcribedText)
                        self.stopRecording()
                    }
                }
            }
            
            if let error = error {
                print("Speech recognition error: \(error)")
                self.stopRecording()
            }
        }
        
        // Get the format that matches the audio session
        let recordingFormat = inputNode.inputFormat(forBus: bus)
        print("Recording format: \(recordingFormat)")
        
            inputNode.installTap(onBus: bus,
                               bufferSize: 1024,
                               format: recordingFormat) { [weak self] buffer, _ in
                guard let self = self else { return }
                
                self.recognitionRequest?.append(buffer)
                
                let level = self.calculateLevel(buffer)
                DispatchQueue.main.async {
                    self.inputLevel = CGFloat(level)
                }
            }

    }
    
    private func calculateLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0.0 }
        let frames = buffer.frameLength
        
        var sum: Float = 0
        for i in 0..<Int(frames) {
            sum += abs(channelData[i])
        }
        
        return sum / Float(frames)
    }
    
    func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied:
                    print("Speech recognition denied")
                case .restricted:
                    print("Speech recognition restricted")
                case .notDetermined:
                    print("Speech recognition not determined")
                @unknown default:
                    print("Speech recognition unknown status")
                }
            }
        }
    }
    
    private func processTranscription(prompt: String) {
        apiCheckTimer?.invalidate()
        
        Huggingface.sendTranscriptionToAPI(prompt: prompt)
        
        apiCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            if let response = Huggingface.apiResponse {
                DispatchQueue.main.async {
                    self?.apiResponse = response
                    self?.apiCheckTimer?.invalidate()
                    self?.apiCheckTimer = nil
                    Huggingface.apiResponse = nil
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.apiCheckTimer?.invalidate()
            self?.apiCheckTimer = nil
            if self?.apiResponse.isEmpty ?? true {
                self?.apiResponse = "No response received from API"
            }
        }
    }
    
    deinit {
        stopRecording()
        apiCheckTimer?.invalidate()
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
