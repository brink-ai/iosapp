//
//  ContentView.swift
//  vertical_ai_hackathon
//
//  Created by Aria Han on 10/31/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TheraVoiceViewModel() // Initialize TheraVoiceViewModel
    @StateObject private var audioManager: AudioManager // Initialize AudioManager with viewModel
    @Environment(\.colorScheme) var colorScheme
    
    init() {
        let viewModel = TheraVoiceViewModel()
        _viewModel = StateObject(wrappedValue: viewModel)
        _audioManager = StateObject(wrappedValue: AudioManager(viewModel: viewModel))
    }

    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                VStack {
                    CircleView(
                        level: audioManager.inputLevel,
                        title: audioManager.isRecording ? "Listening..." : "Tap to Start"
                    )
                    
                    if !audioManager.transcribedText.isEmpty {
                        Text("Transcribed:")
                            .font(.headline)
                            .padding(.top)
                        Text(audioManager.transcribedText)
                            .padding()
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                    
                    if !audioManager.apiResponse.isEmpty {
                        Text("API Response:")
                            .font(.headline)
                            .padding(.top)
                        Text(audioManager.apiResponse)
                            .padding()
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                    
                    Button(action: {
                        if audioManager.isRecording {
                            audioManager.stopRecording()
                        } else {
                            audioManager.startRecording()
                        }
                    }) {
                        Text(audioManager.isRecording ? "Stop" : "Start")
                            .padding()
                            .frame(width: 100)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding()
                    
                    // Navigation link to TheraVoiceView
                    NavigationLink(destination: TheraVoiceView(viewModel: viewModel)) {
                        Text("Go to Biometric Data")
                            .font(.headline)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.top, 20)
                }
            }
        }
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? .black : .white
    }
}
