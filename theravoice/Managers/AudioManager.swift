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
    private var shouldStopRecording = false
    
    override init() {
        super.init()
        setupAudio()
        requestSpeechAuthorization()
    }
    
    private func setupAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setPreferredSampleRate(44100.0)
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
            
            print("Audio Session initialized with sample rate: \(session.sampleRate)")
            
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
        
        shouldStopRecording = false
        transcribedText = ""
        apiResponse = ""
        
        do {
            if audioEngine.isRunning {
                audioEngine.stop()
                inputNode.removeTap(onBus: bus)
            }
            
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            try audioEngine.start()
            isRecording = true
            print("Recording started successfully")
            
            startSpeechRecognition()
            
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
            stopRecording()
        }
    }
    
    func stopRecording() {
        shouldStopRecording = true
        
        // Only stop immediately if we're not in the middle of processing
        if recognitionTask?.state != .running {
            performStopRecording()
        } else {
            // If we're still running, let the recognition task finish
            recognitionRequest?.endAudio()
        }
    }
    
    private func performStopRecording() {
        guard let audioEngine = audioEngine,
              let inputNode = inputNode else { return }
        
        inputNode.removeTap(onBus: bus)
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
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
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                isFinal = result.isFinal
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                    
                    if isFinal {
                        print("Final transcription: \(self.transcribedText)")
                        self.processTranscription(prompt: self.transcribedText)
                        if self.shouldStopRecording {
                            self.performStopRecording()
                        }
                    }
                }
            }
            
            if let error = error {
                print("Speech recognition error: \(error.localizedDescription)")
                if self.shouldStopRecording {
                    self.performStopRecording()
                }
            }
        }
        
        let recordingFormat = inputNode.inputFormat(forBus: bus)
        print("Recording format: \(recordingFormat)")
        
        inputNode.installTap(onBus: bus,
                           bufferSize: 1024,
                           format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            
            if let strongSelf = self {
                let level = strongSelf.calculateLevel(buffer)
                DispatchQueue.main.async {
                    strongSelf.inputLevel = CGFloat(level)
                }
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
        guard !prompt.isEmpty else { return }
        
        print("Processing transcription: \(prompt)")
        apiCheckTimer?.invalidate()
        
        // Send the transcription to the API
        Huggingface.sendTranscriptionToAPI(prompt: prompt)
        
        // Start polling for the response
        apiCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            if let response = Huggingface.apiResponse {
                DispatchQueue.main.async {
                    if !response.isEmpty {
                        self?.apiResponse = response
                        print("Received API response: \(response)")
                    } else {
                        self?.apiResponse = "Empty response received from API"
                    }
                    self?.apiCheckTimer?.invalidate()
                    self?.apiCheckTimer = nil
                    Huggingface.apiResponse = nil
                }
            }
        }
        
        // Set a timeout for the API response
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self else { return }
            
            self.apiCheckTimer?.invalidate()
            self.apiCheckTimer = nil
            
            if self.apiResponse.isEmpty {
                self.apiResponse = "No response received from API"
                print("API response timeout")
            }
        }
    }
    
    deinit {
        stopRecording()
        apiCheckTimer?.invalidate()
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
