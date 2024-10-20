//
//  ContentView.swift
//  vertical_ai_hackathon
//
//  Created by Andrew Blakeslee Moore on 10/20/24.
//

import SwiftUI
import Foundation

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
                } else {
                    SpeakingCircleView(level: audioManager.inputLevel)
                }
                
                Button(action: {
                    audioManager.stopAudioEngine()  // Stop recording and send to Python
                }) {
                    Text("Send to Python")
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
                .stroke(strokeColor, lineWidth: 10 + (level))  // Adjust line width more drastically
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
