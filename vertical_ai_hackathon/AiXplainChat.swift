//
//  AiXplainChat.swift
//  vertical_ai_hackathon
//
//  Created by Andrew Blakeslee Moore on 10/20/24.
//

import Foundation

import aiXplainKit

class AiXplainChat {
    
    var provider: ModelProvider
    
    init() {
        self.provider = ModelProvider()
        AiXplainKit.shared.keyManager.TEAM_API_KEY = "4bf088eec18762baa35fffd45dec7901bb4d19521e6575cc36f0aac26eed5a09"
    }
    
    func send_to_pipeline() async {
        let pipeline = try! await PipelineProvider().get("67155c1a57c705a318033b04")
        let response = try? await pipeline.run("I'm sad")
        print(response)
    }
    
}


