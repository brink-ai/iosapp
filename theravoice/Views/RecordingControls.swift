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
        Button(action: {
            if audioManager.isRecording {
                audioManager.stopRecording()
            } else {
                ElevenLabs.audioPlayer?.stop()
                audioManager.startRecording()
            }
        }) {
            Image(systemName: audioManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                .resizable()
                .frame(width: 64, height: 64)
                .foregroundColor(.white)
                
        }
    }
}
