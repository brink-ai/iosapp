//
//  Item.swift
//  vertical_ai_hackathon
//
//  Created by Andrew Blakeslee Moore on 10/20/24.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
