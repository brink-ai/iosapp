import AVFoundation
import Speech

class AudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private let bus = 0
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var viewModel: TheraVoiceViewModel // Reference to the ViewModel

    @Published var inputLevel: CGFloat = 0
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var apiResponse = ""

    private var apiCheckTimer: Timer?
    private var shouldStopRecording = false

    init(viewModel: TheraVoiceViewModel) { // Initialize with the ViewModel
        self.viewModel = viewModel
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
        guard !isRecording, let audioEngine = audioEngine, let inputNode = inputNode else {
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
        recognitionRequest?.endAudio()
        performStopRecording()
    }

    private func performStopRecording() {
        guard let audioEngine = audioEngine, let inputNode = inputNode else { return }
        
        inputNode.removeTap(onBus: bus)
        audioEngine.stop()
        
        recognitionTask?.finish()  // Finish recognition to process any remaining transcription
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        print("Recording stopped")
    }

    private func startSpeechRecognition() {
        guard let inputNode = inputNode else { return }
        
        recognitionTask?.cancel()
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                    if result.isFinal {
                        print("Final transcription: \(self.transcribedText)")
                        self.processTranscription(prompt: self.transcribedText)
                        if self.shouldStopRecording {
                            self.performStopRecording()
                        }
                    }
                }
            }
            
            if let error = error as NSError? {
                // Check if the error is specific to the local speech recognition service
                if error.domain == "kAFAssistantErrorDomain" && error.code == 1101 {
                    print("Non-critical error with local speech recognition service: \(error.localizedDescription)")
                } else {
                    print("Speech recognition error: \(error.localizedDescription)")
                    if self.shouldStopRecording {
                        self.performStopRecording()
                    }
                }
            }
        }

        
        let recordingFormat = inputNode.inputFormat(forBus: bus)
        print("Recording format: \(recordingFormat)")
        
        inputNode.installTap(onBus: bus, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
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
        return (0..<Int(frames)).reduce(0) { $0 + abs(channelData[$1]) } / Float(frames)
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
        
        // Combine transcription and health data from the last 7 days
        let combinedRequest = viewModel.getCombinedDataString(withTranscription: prompt)
        
        // Send the combined string to the API
        Huggingface.sendTranscriptionToAPI(prompt: combinedRequest) { [weak self] response in
            DispatchQueue.main.async {
                if let response = response, !response.isEmpty {
                    self?.apiResponse = response
                    print("Sent request to API: \(combinedRequest)")
                    print("Received API response: \(response)")
                } else {
                    self?.apiResponse = "Empty response received from API"
                }
            }
        }
        
        // Set a fallback timeout in case no response arrives within 25 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in
            guard let self = self else { return }
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
