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
            Text(text)
                .padding()
                .foregroundColor(isUser ? .black : .white)
                .background(isUser ? Color.white : Color.white.opacity(0.2))
                .cornerRadius(10)
                .frame(maxWidth: 250, alignment: isUser ? .trailing : .leading)
            
            if let audioPath = audioFilePath, !isUser {
                Button(action: {
                    if let url = URL(string: audioPath) {
                        ElevenLabs.playAudio(from: url)
                    }
                }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.white)
                        Text("Play Response")
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 5)
            }
        }
    }
}
