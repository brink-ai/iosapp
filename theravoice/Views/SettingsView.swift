//
//  SettingsView.swift
//  theravoice
//
//  Created by Aria Han on 11/4/24.
//

import SwiftUI

struct SettingsView: View {
    @Binding var isTTSModeEnabled: Bool
    @Binding var selectedModel: String
    
    var body: some View {
        Form {
            Section(header: Text("AI Model").foregroundColor(.white)) {
                Picker("Select AI Model", selection: $selectedModel) {
                    Text("Huggingface").tag("Huggingface")
                    Text("Groq").tag("Groq")
                }
                .pickerStyle(SegmentedPickerStyle())
                .tint(.white)
            }
            
            Section(header: Text("Text-to-Speech").foregroundColor(.white)) {
                Toggle(isOn: $isTTSModeEnabled) {
                    Text("Enable TTS")
                        .foregroundColor(.black)
                }
                .tint(.gray)
            }
        }
        .navigationTitle("Settings")
        .background(Color.black)
        .scrollContentBackground(.hidden)
    }
}
