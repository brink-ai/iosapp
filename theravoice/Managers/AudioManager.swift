import AVFoundation
import Speech

class AudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private let bus = 0
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var viewModel: TheraVoiceViewModel
    private var recognitionQueue: DispatchQueue?
    
    @Published var inputLevel: CGFloat = 0
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var apiResponse = ""
    @Published var isTTSModeEnabled = false
    @Published var selectedModel = "Groq"
    @Published var isTranscriptionComplete = false
    
    private var transcriptionBuffer = ""
    private var lastSpeechTime = Date()
    private var apiCheckTimer: Timer?
    private var silenceTimer: Timer?
    private let silenceThreshold: Float = -50.0
    private let silenceDuration: TimeInterval = 2.0
    private let speechTimeout: TimeInterval = 2.0
    private var shouldStopRecording = false
    private var isProcessingAPI = false
    
    init(viewModel: TheraVoiceViewModel) {
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
            
            audioEngine = AVAudioEngine()
            inputNode = audioEngine?.inputNode
            
            // Configure speech recognizer with specific locale and options
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            speechRecognizer?.defaultTaskHint = .dictation
            
            // Add queue for speech recognition
            recognitionQueue = DispatchQueue(label: "com.app.speechrecognition")
            
        } catch {
            print("Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    func startRecording() {
        guard !isRecording, let audioEngine = audioEngine, let inputNode = inputNode else {
            return
        }
        
        shouldStopRecording = false
        transcribedText = ""
        apiResponse = ""
        isTranscriptionComplete = false
        transcriptionBuffer = ""
        isProcessingAPI = false
        
        do {
            if audioEngine.isRunning {
                audioEngine.stop()
                inputNode.removeTap(onBus: bus)
            }
            
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            try audioEngine.start()
            isRecording = true
            startSpeechRecognition()
            
        } catch {
            stopRecording()
            print("Error starting recording: \(error)")
        }
    }
    
    func stopRecording() {
        shouldStopRecording = true
        recognitionRequest?.endAudio()
        performStopRecording()
    }
    
    private func performStopRecording() {
        guard let audioEngine = audioEngine, let inputNode = inputNode else { return }
        
        // Ensure we process any final transcription
        if !transcriptionBuffer.isEmpty && !isProcessingAPI {
            DispatchQueue.main.async {
                self.transcribedText = self.transcriptionBuffer
                self.isTranscriptionComplete = true
                if !self.transcribedText.isEmpty {
                    self.processTranscription(prompt: self.transcribedText)
                }
            }
        }
        
        inputNode.removeTap(onBus: bus)
        audioEngine.stop()
        
        recognitionTask?.finish()
        recognitionRequest = nil
        recognitionTask = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    private func startSpeechRecognition() {
        guard let inputNode = inputNode else { return }
        
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
        
        // Create new recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request")
            return
        }
        
        // Configure request
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation
        recognitionRequest.contextualStrings = ["hello", "hi", "hey"]
        
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }
        
        // Create recognition task with error handling and retry logic
        var retryCount = 0
        let maxRetries = 3
        
        func createRecognitionTask() {
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                
                if let error = error as NSError? {
                    // Handle specific error cases
                    switch error.domain {
                    case "kAFAssistantErrorDomain":
                        if error.code == 1101 {
                            // Local speech recognition error - retry
                            if retryCount < maxRetries {
                                retryCount += 1
                                print("Retrying speech recognition... Attempt \(retryCount)")
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    createRecognitionTask()
                                }
                            } else {
                                print("Max retries reached for speech recognition")
                                self.handleSpeechError()
                            }
                        } else if error.code == 1110 {
                            // No speech detected - normal case
                            print("No speech detected")
                            if !self.transcriptionBuffer.isEmpty {
                                self.stopRecording()
                            }
                        }
                    default:
                        print("Speech recognition error: \(error)")
                        self.handleSpeechError()
                    }
                    return
                }
                
                if let result = result {
                    let currentText = result.bestTranscription.formattedString
                    self.lastSpeechTime = Date()
                    
                    DispatchQueue.main.async {
                        if !currentText.isEmpty {
                            self.transcriptionBuffer = currentText
                            
                            if result.isFinal {
                                if !self.isProcessingAPI {
                                    self.transcribedText = self.transcriptionBuffer
                                    self.isTranscriptionComplete = true
                                    self.stopRecording()
                                }
                            }
                        }
                    }
                }
            }
        }
        
        createRecognitionTask()
        
        // Configure audio session
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            if let strongSelf = self {
                let level = strongSelf.calculateLevel(buffer)
                DispatchQueue.main.async {
                    strongSelf.inputLevel = CGFloat(level)
                    strongSelf.checkForSilence(level: level)
                }
            }
        }
    }
    
    private func handleSpeechError() {
        DispatchQueue.main.async {
            self.stopRecording()
        }
    }
    
    private func calculateLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0.0 }
        let frames = buffer.frameLength
        return (0..<Int(frames)).reduce(0) { $0 + abs(channelData[$1]) } / Float(frames)
    }
    
    private func checkForSilence(level: Float) {
        if level < silenceThreshold {
            if Date().timeIntervalSince(lastSpeechTime) >= speechTimeout {
                if !isProcessingAPI && !transcriptionBuffer.isEmpty {
                    stopRecording()
                }
            }
        } else {
            lastSpeechTime = Date()
            silenceTimer?.invalidate()
        }
    }
    
    private func processTranscription(prompt: String) {
        guard !prompt.isEmpty && !isProcessingAPI else { return }
        
        isProcessingAPI = true
        apiCheckTimer?.invalidate()
        
        let combinedRequest = viewModel.getCombinedDataString(withTranscription: prompt)
        
        if selectedModel == "Groq" {
            Groq.sendTranscriptionToAPI(prompt: combinedRequest) { [weak self] response in
                self?.handleAPIResponse(response, combinedRequest: combinedRequest)
            }
        } else {
            Huggingface.sendTranscriptionToAPI(prompt: combinedRequest) { [weak self] response in
                self?.handleAPIResponse(response, combinedRequest: combinedRequest)
            }
        }
    }
    
    private func handleAPIResponse(_ response: String?, combinedRequest: String) {
        DispatchQueue.main.async {
            if let response = response, !response.isEmpty {
                self.apiResponse = response
                
                // If TTS is enabled, automatically play the response
                if self.isTTSModeEnabled {
                    self.convertAndPlayResponse(response)
                }
            } else {
                self.apiResponse = "Empty response received from API"
            }
            self.isProcessingAPI = false
        }
    }
    
    private func convertAndPlayResponse(_ response: String) {
        ElevenLabs.textToSpeech(text: response) { [weak self] filePath in
            if let filePath = filePath {
                ElevenLabs.playAudio(from: filePath)
            }
        }
    }
    
    func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
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
    
    deinit {
        stopRecording()
        apiCheckTimer?.invalidate()
        silenceTimer?.invalidate()
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
