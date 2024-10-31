//
//  CircleView.swift
//  vertical_ai_hackathon
//
//  Created by Aria Han on 10/31/24.
//

import SwiftUI

struct CircleView: View {
    var level: CGFloat
    var title: String
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(strokeColor, lineWidth: 10 + level)
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
