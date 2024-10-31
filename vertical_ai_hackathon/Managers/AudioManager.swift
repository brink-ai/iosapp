import AVFoundation
import Speech

class AudioManager: NSObject, ObservableObject {
    @Published private(set) var inputLevel: CGFloat = 0
    @Published private(set) var isRecording = false
    @Published private(set) var transcribedText = ""
    @Published private(set) var apiResponse = ""
    
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: .init(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    override init() {
        super.init()
        configureAudioSession()
    }
    
    func startRecording() {
        checkPermissions { [weak self] authorized in
            guard authorized, let self = self else { return }
            self.setupRecording()
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
    }
    
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }
    
    private func checkPermissions(completion: @escaping (Bool) -> Void) {
        AVAudioApplication.shared().requestRecordPermissionWithCompletionHandler { granted in
            guard granted else {
                print("Microphone permission denied")
                return completion(false)
            }
            
            SFSpeechRecognizer.requestAuthorization { status in
                let authorized = status == .authorized
                if !authorized {
                    print("Speech recognition permission denied")
                }
                completion(authorized)
            }
        }
    }
    
    private func setupRecording() {
        stopRecording()  // Clean up any existing recording session
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.inputFormat(forBus: 0)
        
        inputNode.removeTap(onBus: 0)  // Remove any existing tap first
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.updateInputLevel(buffer)
        }
        
        do {
            try audioEngine.start()
            isRecording = true
            startTranscription()
        } catch {
            print("Failed to start audio engine: \(error)")
            stopRecording()
        }
    }
    
    private func startTranscription() {
        guard let request = recognitionRequest else { return }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Recognition error: \(error)")
                self.stopRecording()
                return
            }
            
            if let result = result {
                self.transcribedText = result.bestTranscription.formattedString
                
                if result.isFinal {
                    self.processTranscription()
                }
            }
            
            if result?.isFinal == true {
                self.stopRecording()
            }
        }
    }
    
    private func processTranscription() {
        Huggingface.sendTranscriptionToAPI(prompt: transcribedText) { [weak self] response in
            DispatchQueue.main.async {
                self?.apiResponse = response ?? "No response"
            }
        }
    }
    
    private func updateInputLevel(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Float(buffer.frameLength)
        let rms = sqrt(channelData.prefix(Int(frameCount)).map { $0 * $0 }.reduce(0, +) / frameCount)
        inputLevel = CGFloat(rms) * 1000
    }
}
