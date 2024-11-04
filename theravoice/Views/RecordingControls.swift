//
//  RecordingControls.swift
//  theravoice
//
//  Created by Aria Han on 11/4/24.
//

import SwiftUI

struct RecordingControls: View {
    @ObservedObject var audioManager: AudioManager
    
    var body: some View {
        ZStack {
            if audioManager.isRecording {
                CircleView(level: audioManager.inputLevel * 5, title: "Listening...")
                    .onTapGesture {
                        audioManager.stopRecording()
                    }
            } else {
                Button(action: audioManager.startRecording) {
                    Image(systemName: "mic.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.white)
                }
            }
        }
    }
}
