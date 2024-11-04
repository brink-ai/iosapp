import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var viewModel = TheraVoiceViewModel()
    @StateObject private var audioManager: AudioManager
    @State private var isSettingsPresented = false
    @State private var currentUserMessage = ""
    @State private var showingLiveTranscription = false // Start as false
    @State private var currentlyPlayingAudio: AVAudioPlayer?

    init() {
        let vm = TheraVoiceViewModel()
        _viewModel = StateObject(wrappedValue: vm)
        _audioManager = StateObject(wrappedValue: AudioManager(viewModel: vm))
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(named: "Background")
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("Background")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HeaderView()
                    
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            // Show stored messages
                            ForEach(viewModel.messages) { message in
                                MessageBubble(
                                    message: message,
                                    currentlyPlayingAudio: $currentlyPlayingAudio
                                )
                                .padding(.horizontal)
                            }
                            
                            // Show live transcription
                            if showingLiveTranscription {
                                MessageBubble(
                                    message: Message(text: currentUserMessage, isUser: true, audioFilePath: nil),
                                    currentlyPlayingAudio: $currentlyPlayingAudio
                                )
                                .padding(.horizontal)
                                .transition(.opacity)
                            }
                        }
                        .padding(.top)
                    }
                    
                    Spacer()
                    RecordingControls(audioManager: audioManager)
                        .frame(height: 240)
                        .padding(.bottom)
                }
            }
            .navigationBarTitle("TheraVoice", displayMode: .inline)
            .navigationBarItems(trailing: settingsButton)
            .sheet(isPresented: $isSettingsPresented) {
                SettingsView(isTTSModeEnabled: $audioManager.isTTSModeEnabled, selectedModel: $audioManager.selectedModel)
            }
        }
        .onReceive(audioManager.$transcribedText) { newText in
            withAnimation {
                currentUserMessage = newText
                showingLiveTranscription = !newText.isEmpty
            }
        }
        .onReceive(audioManager.$isRecording) { isRecording in
            withAnimation {
                if isRecording {
                    // Starting new recording
                    currentUserMessage = ""
                    showingLiveTranscription = true
                    ElevenLabs.audioPlayer?.stop()
                } else {
                    // Stopping recording
                    if !currentUserMessage.isEmpty {
                        viewModel.storeMessage(Message(text: currentUserMessage, isUser: true, audioFilePath: nil))
                        currentUserMessage = ""
                        showingLiveTranscription = false
                    }
                }
            }
        }
        .onReceive(audioManager.$apiResponse) { response in
            handleAPIResponse(response: response)
        }
    }
    
    private var settingsButton: some View {
        Button("Settings") {
            isSettingsPresented.toggle()
        }
        .foregroundColor(.white)
    }
    
    private func handleAPIResponse(response: String) {
        if !response.isEmpty {
            let message = Message(text: response, isUser: false, audioFilePath: nil)
            viewModel.storeMessage(message)
            
            if audioManager.isTTSModeEnabled {
                APIManager.shared.convertTextToSpeech(response: response) { audioPath in
                    if let audioPath = audioPath,
                       let index = viewModel.messages.lastIndex(where: { !$0.isUser }) {
                        viewModel.updateMessageAudioPath(at: index, with: audioPath)
                    }
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: Message
    @Binding var currentlyPlayingAudio: AVAudioPlayer?
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading) {
                Text(message.text)
                    .padding()
                    .foregroundColor(.white)
                    .background(message.isUser ? Color.gray.opacity(0.7) : Color.gray.opacity(0.5))
                    .cornerRadius(10)
                    .frame(maxWidth: 250, alignment: message.isUser ? .trailing : .leading)
                
                if let audioPath = message.audioFilePath, !message.isUser {
                    Button(action: {
                        if let url = URL(string: audioPath) {
                            ElevenLabs.playAudio(from: url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.white)
                            Text("Play Response")
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.top, 5)
                }
            }
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

