//
//  HeaderView.swift
//  theravoice
//
//  Created by Aria Han on 11/4/24.
//

import SwiftUI

struct HeaderView: View {
    var body: some View {
        Rectangle()
            .fill(Color.white)
            .frame(height: 1)
            .shadow(color: .gray.opacity(0.3), radius: 3, x: 0, y: 3)
    }
}
