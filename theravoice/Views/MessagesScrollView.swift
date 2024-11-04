//
//  MessagesScrollView.swift
//  theravoice
//
//  Created by Aria Han on 11/4/24.
//

import SwiftUI

struct MessagesScrollView: View {
    @ObservedObject var viewModel: TheraVoiceViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.messages) { message in
                        HStack {
                            // Align user messages to the right and AI messages to the left
                            if message.isUser {
                                Spacer() // Push user messages to the right
                            }
                            
                            TextBubbleView(text: message.text, isUser: message.isUser, audioFilePath: message.audioFilePath)
                                .id(message.id)
                            
                            if !message.isUser {
                                Spacer() // Push AI messages to the left
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let lastMessage = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}
