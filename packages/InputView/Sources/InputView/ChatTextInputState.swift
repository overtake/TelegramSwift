//
//  File.swift
//  
//
//  Created by Mike Renoir on 07.10.2023.
//

import Foundation

public struct Updated_ChatTextInputState: Equatable {
    public var inputText: NSAttributedString
    public var selectionRange: Range<Int>
    
    public static func ==(lhs: Updated_ChatTextInputState, rhs: Updated_ChatTextInputState) -> Bool {
        return lhs.inputText.isEqual(to: rhs.inputText) && lhs.selectionRange == rhs.selectionRange
    }
    
    public init() {
        self.inputText = NSAttributedString()
        self.selectionRange = 0 ..< 0
    }
    
    public init(inputText: NSAttributedString, selectionRange: Range<Int>) {
        self.inputText = inputText
        self.selectionRange = selectionRange
    }
    
    public init(inputText: NSAttributedString) {
        self.inputText = inputText
        let length = inputText.length
        self.selectionRange = length ..< length
    }
}
