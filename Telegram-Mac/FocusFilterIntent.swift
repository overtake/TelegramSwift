//
//  FocusFilterIntent.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25.04.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import AppIntents
//
//@available(macOS 13, *)
//struct AppFocusFilterIntent : SetFocusFilterIntent {
//    static var title: LocalizedStringResource {
//        return "Focus Settings"
//    }
//           
//    // The description as it appears in the Settings app
//    static var description: LocalizedStringResource? = "Focus Settings" // name under Minus icon in options list
//
//    
//    // How a configured filter appears on the Focus details screen
//    var displayRepresentation: DisplayRepresentation {
//        return DisplayRepresentation(stringLiteral: "Focus Settings") // name under filter once added to Foucs
//    }
//    
//    @Parameter(title: "Show Task Bar", default: false)
//    var showDefaultTaskBar: Bool
//
//    @Parameter(title: "Start Timer")
//    var startTimer: Bool
//    
//    func perform() async throws -> some IntentResult {
//        
//        // This doesnt seem to run
//        // What can I put here?
//        // I need to write string data to a text file somewhere or communicate with the host app in some way.
//        
//        return .result()
//    }
//    
//    
//}
