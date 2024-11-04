//
//  TextBubbleView.swift
//  theravoice
//
//  Created by Aria Han on 11/4/24.
//

import SwiftUI

struct TextBubbleView: View {
    let text: String
    let isUser: Bool
    let audioFilePath: String?

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading) {
            // Display message text in a bubble
            Text(text)
                .padding()
                .foregroundColor(isUser ? .white : .white) // Changed AI text to white for visibility
                .background(isUser ? Color.blue : Color.gray.opacity(0.5)) // Made AI bubble more visible
                .cornerRadius(10)
                .frame(maxWidth: 250, alignment: isUser ? .trailing : .leading)
                .padding(isUser ? .leading : .trailing, 50)

            // Display play button if there's an audio response for AI messages
            if let audioPath = audioFilePath, !isUser {
                Button(action: {
                    if let url = URL(string: audioPath) {
                        ElevenLabs.playAudio(from: url)
                    }
                }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.white) // Changed to white for visibility
                        Text("Play Response")
                            .foregroundColor(.white) // Changed to white for visibility
                    }
                }
                .padding(.top, 5)
                .frame(maxWidth: 250, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        .padding(isUser ? .trailing : .leading, 10)
    }
}
