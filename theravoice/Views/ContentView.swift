import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TheraVoiceViewModel()
    @StateObject private var audioManager: AudioManager = AudioManager(viewModel: TheraVoiceViewModel())
    @State private var isSettingsPresented = false

    init() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        appearance.titleTextAttributes = [.foregroundColor: UIColor.black]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.black]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HeaderView()
                    MessagesScrollView(viewModel: viewModel)
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
            handleTranscription(newText: newText)
        }
        .onReceive(audioManager.$apiResponse) { response in
            handleAPIResponse(response: response)
        }
    }
    
    private var settingsButton: some View {
        Button("Settings") { isSettingsPresented.toggle() }
    }
    
    private func handleTranscription(newText: String) {
        if !newText.isEmpty && audioManager.isTranscriptionComplete {
            let message = Message(text: newText, isUser: true, audioFilePath: nil)
            viewModel.storeMessage(message)
            
            APIManager.shared.processTranscription(prompt: newText, selectedModel: audioManager.selectedModel) { response in
                if let response = response {
                    audioManager.apiResponse = response
                }
            }
        }
    }
    
    private func handleAPIResponse(response: String) {
        if !response.isEmpty {
            let message = Message(text: response, isUser: false, audioFilePath: nil)
            viewModel.storeMessage(message)
            
            if audioManager.isTTSModeEnabled {
                APIManager.shared.convertTextToSpeech(response: response) { audioPath in
                    if let audioPath = audioPath {
                        viewModel.storeMessage(Message(text: response, isUser: false, audioFilePath: audioPath))
                    }
                }
            }
        }
    }
}
