//
//  ChatInterfaceInputContext.swift
//  TelegramMac
//
//  Created by keepcoder on 22/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

import Postbox

struct PossibleContextQueryTypes: OptionSet {
    var rawValue: Int32
    
    init() {
        self.rawValue = 0
    }
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    static let hashtag = PossibleContextQueryTypes(rawValue: (1 << 0))
    static let mention = PossibleContextQueryTypes(rawValue: (1 << 1))
    static let command = PossibleContextQueryTypes(rawValue: (1 << 2))
    static let contextRequest = PossibleContextQueryTypes(rawValue: (1 << 3))
    static let stickers = PossibleContextQueryTypes(rawValue: (1 << 4))
    static let emoji = PossibleContextQueryTypes(rawValue: (1 << 5))
    static let emojiFast = PossibleContextQueryTypes(rawValue: (1 << 6))
    static let swapEmoji = PossibleContextQueryTypes(rawValue: (1 << 7))
}

private func makeScalar(_ c: Character) -> Character {
    return c
    //return c.utf16[c.utf16.startIndex]
}

private let spaceScalar = makeScalar(" ")
private let newlineScalar = makeScalar("\n")
private let hashScalar = makeScalar("#")
private let atScalar = makeScalar("@")
private let slashScalar = makeScalar("/")
private let emojiScalar = makeScalar(":")
private let alphanumerics = CharacterSet.alphanumerics

func textInputStateContextQueryRangeAndType(_ inputState: ChatTextInputState, includeContext: Bool = true) -> (Range<String.Index>, PossibleContextQueryTypes, Range<String.Index>?)? {
    let inputText = inputState.inputText
    if !inputText.isEmpty {
        if inputText.hasPrefix("@") && inputText != "@" {
            let startIndex = inputText.index(after: inputText.startIndex)
            var index = startIndex
            var contextAddressRange: Range<String.Index>?
            
            while true {
                if index == inputText.endIndex {
                    break
                }
                let c = inputText[index]
                
                if c == " " {
                    if index != startIndex {
                        contextAddressRange = startIndex ..< index
                        index = inputText.index(after: index)
                    }
                    break
                } else {
                    if !((c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || (c >= "0" && c <= "9") || c == "_") {
                        break
                    }
                }
                
                if index == inputText.endIndex {
                    break
                } else {
                    index = inputText.index(after: index)
                }
            }
            
            if let contextAddressRange = contextAddressRange, includeContext {
                return (contextAddressRange, [.contextRequest], index ..< inputText.endIndex)
            }
        }
        
        
        let maxUtfIndex = inputText.utf16.index(inputText.utf16.startIndex, offsetBy: min(inputState.selectionRange.lowerBound, inputText.utf16.count))
        guard let maxIndex = maxUtfIndex.samePosition(in: inputText) else {
            return nil
        }
        if maxIndex == inputText.startIndex {
            return nil
        }
        var index = inputText.index(before: maxIndex)
        
//        if inputText.length <= 7, inputText.isSingleEmoji {
//            var inputText = inputText
//            if inputText.canHaveSkinToneModifier {
//                inputText = inputText.emojiUnmodified
//            }
//            return (inputText.startIndex ..< maxIndex, [.stickers], nil)
//        }
        
       
        
        var possibleQueryRange: Range<String.Index>?
        
        var possibleTypes = PossibleContextQueryTypes([.command, .mention, .emoji, .hashtag, .emojiFast])
        //var possibleTypes = PossibleContextQueryTypes([.command, .mention])


        
        func check() {
            if inputText.startIndex != inputText.index(before: index) {
                let prev = inputText.index(before: inputText.index(before: index))
                let scalars:CharacterSet = CharacterSet.alphanumerics
                if let scalar = inputText[prev].unicodeScalars.first, scalars.contains(scalar) && inputText[prev] != newlineScalar {
                    possibleTypes = []
                }
                switch possibleTypes {
                case .emoji:
                    if index != inputText.endIndex {
                        if let scalar = inputText[index].unicodeScalars.first {
                            if !scalars.contains(scalar) {
                                possibleTypes = []
                            }
                        } else {
                            possibleTypes = []
                        }
                    } else {
                        // possibleTypes = []
                    }
                    
                default:
                    break
                }
            } else if maxIndex < inputText.endIndex {
                let char = inputText[maxIndex]
                if !char.isWhitespace {
                    possibleTypes = []
                }
            }
        }
        
        var definedType = false
        
        var characterSet = CharacterSet.alphanumerics
        characterSet.insert(hashScalar.unicodeScalars.first!)
        characterSet.insert(atScalar.unicodeScalars.first!)
        characterSet.insert(slashScalar.unicodeScalars.first!)
        characterSet.insert(emojiScalar.unicodeScalars.first!)
        
        let lowerUtfIndex = inputText.utf16.index(inputText.utf16.startIndex, offsetBy: inputState.selectionRange.lowerBound)
        let upperUtfIndex = inputText.utf16.index(inputText.utf16.startIndex, offsetBy: inputState.selectionRange.upperBound)

        let lowerIndex = lowerUtfIndex.samePosition(in: inputText)
        let upperIndex = upperUtfIndex.samePosition(in: inputText)

        
        
        if let lowerIndex = lowerIndex, let upperIndex = upperIndex {
            let text = String(inputText[lowerIndex ..< upperIndex])
            if text.isSingleEmoji {
                return (lowerIndex ..< upperIndex, [.swapEmoji], nil)
            }
        }
        
        for _ in 0 ..< 20 {
            let c = inputText[index]
                    
            let f = inputText[index ..< maxIndex]
            
            if String(f).containsOnlyEmoji {
                if index == inputText.startIndex {
                    possibleTypes = [.swapEmoji, .stickers]
                } else {
                    possibleTypes = [.swapEmoji]
                }
                definedType = true
                possibleQueryRange = index ..< maxIndex

                break
            } else if !characterSet.contains(c.unicodeScalars.first!) {
                possibleTypes = []
            } else if c == hashScalar {
                possibleTypes = possibleTypes.intersection([.hashtag])
                definedType = true
                index = inputText.index(after: index)
                possibleQueryRange = index ..< maxIndex
                
                check()
                
                break
            } else if c == atScalar {
                possibleTypes = possibleTypes.intersection([.mention])
                definedType = true
                index = inputText.index(after: index)
                possibleQueryRange = index ..< maxIndex
                
                check()
                
                break
            } else if c == slashScalar, inputText.startIndex == index {
                possibleTypes = possibleTypes.intersection([.command])
                definedType = true
                index = inputText.index(after: index)
                possibleQueryRange = index ..< maxIndex
                
                check()
                
                break
            } else if c == emojiScalar {
                possibleTypes = possibleTypes.intersection([.emoji])
                definedType = true
                index = inputText.index(after: index)
                possibleQueryRange = index ..< maxIndex
                
                check()
                
                break
            }
            if index == inputText.startIndex {
                break
            } else {
                index = inputText.index(before: index)
                possibleQueryRange = index ..< maxIndex
            }
        }
        
        if inputText.trimmingCharacters(in: CharacterSet.letters).isEmpty, !inputText.isEmpty  {
            possibleTypes = possibleTypes.intersection([.emojiFast])
            definedType = true
            possibleQueryRange = index ..< maxIndex
        }
        
        
        if let possibleQueryRange = possibleQueryRange, definedType && !possibleTypes.isEmpty {
            return (possibleQueryRange, possibleTypes, nil)
        }
    }
    return nil
}

func inputContextQueryForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, includeContext: Bool) -> ChatPresentationInputQuery {
    let inputState = chatPresentationInterfaceState.effectiveInput
    if let (possibleQueryRange, possibleTypes, additionalStringRange) = textInputStateContextQueryRangeAndType(inputState, includeContext: includeContext) {
        
        if chatPresentationInterfaceState.state == .editing && (possibleTypes != [.contextRequest] && possibleTypes != [.mention] && possibleTypes != [.emoji]) {
            return .none
        }
        
        var possibleQueryRange = possibleQueryRange

        if chatPresentationInterfaceState.botMenu?.revealed == true {
            return .command("")
        }
        
        let value = inputState.inputText[possibleQueryRange]
        
        let range = NSRange(string: inputState.inputText, range: possibleQueryRange)
        

        let query = String(value) 
        if possibleTypes == [.hashtag] {
            return .hashtag(query)
        } else if possibleTypes == [.mention] {
            return .mention(query: query, includeRecent: inputState.inputText.startIndex == inputState.inputText.index(before: possibleQueryRange.lowerBound) && chatPresentationInterfaceState.state == .normal)
        } else if possibleTypes == [.command] {
            return .command(query)
        } else if possibleTypes == [.contextRequest], let additionalStringRange = additionalStringRange {
            let additionalString = String(inputState.inputText[additionalStringRange])
            return .contextRequest(addressName: query, query: additionalString)
        } else if possibleTypes.contains(.stickers) {
            if !inputState.isFirstAnimatedEmoji(query) {
                return .stickers(query.emojiUnmodified)
            } else {
                return .none
            }
        } else if possibleTypes == [.emoji] {
            return .emoji(query, firstWord: !query.trimmingCharacters(in: CharacterSet.letters).isEmpty)
        } else if possibleTypes == [.emojiFast] {
            return .emoji(query, firstWord: true)
        }
        return .none

    } else {
        if chatPresentationInterfaceState.botMenu?.revealed == true {
            return .command("")
        } else {
            return .none
        }
    }
}
