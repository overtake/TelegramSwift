//
//  File.swift
//  
//
//  Created by Mike Renoir on 07.10.2023.
//

import Foundation
import TelegramCore
import TGUIKit

private extension EnginePeer {
    var compactDisplayTitle: String {
        switch self {
        case let .user(user):
            if let firstName = user.firstName, !firstName.isEmpty {
                return firstName
            } else if let lastName = user.lastName, !lastName.isEmpty {
                return lastName
            } else if let _ = user.phone {
                return ""
            } else {
                return "Deleted Account"
            }
        case let .legacyGroup(group):
            return group.title
        case let .channel(channel):
            return channel.title
        case .secretChat:
            return ""
        }
    }

}


public func chatTextInputAddFormattingAttribute(_ state: Updated_ChatTextInputState, attribute: NSAttributedString.Key) -> Updated_ChatTextInputState {
    var selectionRange = state.selectionRange
    if !selectionRange.isEmpty {
        let nsRange = NSRange(location: selectionRange.lowerBound, length: selectionRange.count)
        var addAttribute = true
        var attributesToRemove: [NSAttributedString.Key] = []
        
        state.inputText.enumerateAttributes(in: nsRange, options: []) { attributes, range, stop in
            for (key, _) in attributes {
                if key == attribute && range == nsRange {
                    addAttribute = false
                    attributesToRemove.append(key)
                }
            }
        }
        
        let result = NSMutableAttributedString(attributedString: state.inputText)
        for attribute in attributesToRemove {
            result.removeAttribute(attribute, range: nsRange)
        }
        if addAttribute {
            if attribute == TextInputAttributes.quote {
                result.addAttribute(attribute, value: TextInputTextQuoteAttribute(collapsed: false), range: nsRange)
                if nsRange.upperBound != result.length && (result.string as NSString).character(at: nsRange.upperBound) != 0x0a {
                    result.insert(NSAttributedString(string: "\n"), at: nsRange.upperBound)
                }
                if nsRange.lowerBound != 0 && (result.string as NSString).character(at: nsRange.lowerBound - 1) != 0x0a {
                    result.insert(NSAttributedString(string: "\n"), at: nsRange.lowerBound)
                    selectionRange = nsRange.lowerBound + 1 ..< nsRange.upperBound + 1

                }
            } else {
                result.addAttribute(attribute, value: true as Bool, range: nsRange)
            }
        }
        return Updated_ChatTextInputState(inputText: result, selectionRange: selectionRange)
    } else {
        return state
    }
}

public func chatTextInputClearFormattingAttributes(_ state: Updated_ChatTextInputState, targetKey: NSAttributedString.Key? = nil) -> Updated_ChatTextInputState {
    if !state.selectionRange.isEmpty {
        let nsRange = NSRange(location: state.selectionRange.lowerBound, length: state.selectionRange.count)
        var attributesToRemove: [(NSAttributedString.Key, NSRange)] = []
        
        state.inputText.enumerateAttributes(in: NSMakeRange(0, state.inputText.length), options: []) { attributes, range, stop in
            for (key, _) in attributes {
                if range.intersection(nsRange) != nil {
                    if let targetKey = targetKey {
                        if targetKey == key {
                            attributesToRemove.append((key, range))
                        }
                    } else {
                        if key != TextInputAttributes.customEmoji {
                            attributesToRemove.append((key, range))
                        }
                    }
                }
            }
        }
        
        let result = NSMutableAttributedString(attributedString: state.inputText)
        for (attribute, range) in attributesToRemove {
            result.removeAttribute(attribute, range: range)
        }
        return Updated_ChatTextInputState(inputText: result, selectionRange: state.selectionRange)
    } else {
        return state
    }
}

public func chatTextInputAddLinkAttribute(_ state: Updated_ChatTextInputState, selectionRange: Range<Int>, url: String, text: String) -> Updated_ChatTextInputState {
    if !selectionRange.isEmpty {
        let nsRange = NSRange(location: selectionRange.lowerBound, length: selectionRange.count)
        var linkRange = nsRange
        var attributesToRemove: [(NSAttributedString.Key, NSRange)] = []
        state.inputText.enumerateAttributes(in: nsRange, options: .longestEffectiveRangeNotRequired) { attributes, range, stop in
            for (key, _) in attributes {
                if key == TextInputAttributes.textUrl {
                    attributesToRemove.append((key, range))
                    linkRange = linkRange.union(range)
                } else {
                    attributesToRemove.append((key, nsRange))
                }
            }
        }
        
        let result = NSMutableAttributedString(attributedString: state.inputText)
        for (attribute, range) in attributesToRemove {
            result.removeAttribute(attribute, range: range)
        }
        result.replaceCharacters(in:nsRange, with: text)
        let length: Int
        if nsRange.length > text.length {
            length = min(nsRange.length, text.length)
        } else {
            length = max(nsRange.length, text.length)
        }
        let updatedRange = NSMakeRange(nsRange.location, length)
        result.addAttribute(TextInputAttributes.textUrl, value: TextInputTextUrlAttribute(url: url), range: updatedRange)
        return Updated_ChatTextInputState(inputText: result, selectionRange: updatedRange.lowerBound ..< updatedRange.upperBound)
    } else {
        return state
    }
}

public func chatTextInputAddMentionAttribute(_ state: Updated_ChatTextInputState, peer: EnginePeer) -> Updated_ChatTextInputState {
    let inputText = NSMutableAttributedString(attributedString: state.inputText)
    
    let range = NSMakeRange(state.selectionRange.startIndex, state.selectionRange.endIndex - state.selectionRange.startIndex)
    
    if let addressName = peer.addressName, !addressName.isEmpty {
        let replacementText = "@\(addressName) "
        
        inputText.replaceCharacters(in: range, with: replacementText)
        
        let selectionPosition = range.lowerBound + (replacementText as NSString).length
        
        return Updated_ChatTextInputState(inputText: inputText, selectionRange: selectionPosition ..< selectionPosition)
    } else if !peer.compactDisplayTitle.isEmpty {
        let replacementText = NSMutableAttributedString()
        replacementText.append(NSAttributedString(string: peer.compactDisplayTitle, attributes: [TextInputAttributes.textMention: ChatTextInputTextMentionAttribute(peerId: peer.id)]))
        replacementText.append(NSAttributedString(string: " "))
        
        let updatedRange = NSRange(location: range.location , length: range.length)
        
        inputText.replaceCharacters(in: updatedRange, with: replacementText)
        
        let selectionPosition = updatedRange.lowerBound + replacementText.length
        
        return Updated_ChatTextInputState(inputText: inputText, selectionRange: selectionPosition ..< selectionPosition)
    } else {
        return state
    }
}

public func chatTextInputAddQuoteAttribute(_ state: Updated_ChatTextInputState, selectionRange: Range<Int>, collapsed: Bool = false, doNotUpdateSelection: Bool = false) -> Updated_ChatTextInputState {
    if selectionRange.isEmpty {
        return state
    }
    let nsRange = NSRange(location: selectionRange.lowerBound, length: selectionRange.count)
    var quoteRange = nsRange
    var attributesToRemove: [(NSAttributedString.Key, NSRange)] = []
    state.inputText.enumerateAttributes(in: nsRange, options: .longestEffectiveRangeNotRequired) { attributes, range, stop in
        for (key, _) in attributes {
            if key == TextInputAttributes.quote {
                attributesToRemove.append((key, range))
                quoteRange = quoteRange.union(range)
            }
        }
    }
    
    let result = NSMutableAttributedString(attributedString: state.inputText)
    for (attribute, range) in attributesToRemove {
        result.removeAttribute(attribute, range: range)
    }
    result.addAttribute(TextInputAttributes.quote, value: TextInputTextQuoteAttribute(collapsed: collapsed), range: nsRange)
    return Updated_ChatTextInputState(inputText: result, selectionRange: doNotUpdateSelection ? state.selectionRange : selectionRange)
}

