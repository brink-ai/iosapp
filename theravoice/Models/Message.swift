//
//  Message.swift
//  theravoice
//
//  Created by Aria Han on 11/4/24.
//

import Foundation

struct Message: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let audioFilePath: String?
}
