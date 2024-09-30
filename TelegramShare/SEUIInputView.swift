//
//  SEUIInputView.swift
//  TelegramShare
//
//  Created by Mikhail Filimonov on 20.09.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import InputView
import ColorPalette
import SwiftSignalKit
import TelegramCore
import ObjcUtils

private let se_markdownRegexFormat = "(^|\\s|\\n)(````?)([\\s\\S]+?)(````?)([\\s\\n\\.,:?!;]|$)|(^|\\s)(`|\\*\\*|__|~~|\\|\\|)([^\\n]+?)\\7([\\s\\.,:?!;]|$)|@(\\d+)\\s*\\((.+?)\\)"
private let se_markdownRegex = try? NSRegularExpression(pattern: se_markdownRegexFormat, options: [.caseInsensitive, .anchorsMatchLines])


private extension SE_TextInputAttribute {

    
    func isSameAttribute(_ rhs: SE_TextInputAttribute) -> Bool {
        switch self {
        case .bold:
            return self.weight == rhs.weight
        case .strikethrough:
            return self.weight == rhs.weight
        case .spoiler:
            return self.weight == rhs.weight
        case .underline:
            return self.weight == rhs.weight
        case .italic:
            return self.weight == rhs.weight
        case .pre:
            return self.weight == rhs.weight
        case .code:
            return self.weight == rhs.weight
        case .quote:
            return self.weight == rhs.weight
        }
    }

    func intersectsOrAdjacent(with attribute: SE_TextInputAttribute) -> Bool {
        return self.range.upperBound >= attribute.range.lowerBound && self.range.lowerBound <= attribute.range.upperBound
    }

    // Merge two attributes into one with a combined range
    mutating func merge(with attribute: SE_TextInputAttribute) {
        let newStart = min(self.range.lowerBound, attribute.range.lowerBound)
        let newEnd = max(self.range.upperBound, attribute.range.upperBound)
        self = self.updateRange(newStart..<newEnd)
    }
    
    var range:Range<Int> {
        switch self {
        case let .bold(range), let .italic(range), let .pre(range, _), let .code(range), let .strikethrough(range), let .spoiler(range), let .underline(range):
            return range
        case let .quote(range, _):
            return range
        }
    }
    
    func updateRange(_ range: Range<Int>) -> SE_TextInputAttribute {
        switch self {
        case .bold:
            return .bold(range)
        case .italic:
            return .italic(range)
        case let .pre(_, language):
            return .pre(range, language)
        case .code:
            return .code(range)
        case .strikethrough:
            return .strikethrough(range)
        case .spoiler:
            return .spoiler(range)
        case .underline:
            return .underline(range)
        case let .quote(_, collapsed):
            return .quote(range, collapsed)
        }
    }
}


private func concatAttributes(_ attributes: [SE_TextInputAttribute]) -> [SE_TextInputAttribute] {
    guard !attributes.isEmpty else { return [] }

    let sortedAttributes = attributes.sorted { $0.weight < $1.weight }
    var mergedAttributes = [SE_TextInputAttribute]()

    var currentAttribute = sortedAttributes.first!

    for attribute in sortedAttributes.dropFirst() {
        if currentAttribute.isSameAttribute(attribute) && currentAttribute.intersectsOrAdjacent(with: attribute) {
            currentAttribute.merge(with: attribute)
        } else {
            mergedAttributes.append(currentAttribute)
            currentAttribute = attribute
        }
    }
    // Append the last merged or unmerged attribute
    mergedAttributes.append(currentAttribute)

    return mergedAttributes
}

private func chatTextAttributes(from entities:TextEntitiesMessageAttribute) -> [SE_TextInputAttribute] {
    var inputAttributes:[SE_TextInputAttribute] = []
    for entity in entities.entities {
        switch entity.type {
        case .Bold:
            inputAttributes.append(.bold(entity.range))
        case .Italic:
            inputAttributes.append(.italic(entity.range))
        case .Code:
            inputAttributes.append(.code(entity.range))
        case let .Pre(language):
            inputAttributes.append(.pre(entity.range, language))
        case .Strikethrough:
            inputAttributes.append(.strikethrough(entity.range))
        case .Spoiler:
            inputAttributes.append(.spoiler(entity.range))
        case .Underline:
            inputAttributes.append(.underline(entity.range))
        case let .BlockQuote(collapsed):
            inputAttributes.append(.quote(entity.range, collapsed))
        default:
            break
        }
    }
    return inputAttributes
}

private func chatTextAttributes(from attributedText: NSAttributedString) -> [SE_TextInputAttribute] {
    
    var parsedAttributes: [SE_TextInputAttribute] = []
    attributedText.enumerateAttributes(in: NSRange(location: 0, length: attributedText.length), options: [], using: { attributes, range, _ in
        for (key, value) in attributes {
            let range = range.location ..< (range.location + range.length)
            if key == TextInputAttributes.bold {
                parsedAttributes.append(.bold(range))
            } else if key == TextInputAttributes.italic {
                parsedAttributes.append(.italic(range))
            } else if key == TextInputAttributes.code {
                parsedAttributes.append(.pre(range, value as? String))
            } else if key == TextInputAttributes.monospace {
                parsedAttributes.append(.code(range))
            } else if key == TextInputAttributes.strikethrough {
                parsedAttributes.append(.strikethrough(range))
            } else if key == TextInputAttributes.underline {
                parsedAttributes.append(.underline(range))
            } else if key == TextInputAttributes.spoiler {
                parsedAttributes.append(.spoiler(range))
            } else if key == TextInputAttributes.quote, let value = value as? TextInputTextQuoteAttribute {
                parsedAttributes.append(.quote(range, value.collapsed))
            }
        }
    })
    return parsedAttributes
}


enum SE_TextInputAttribute : Equatable, Comparable {
    case bold(Range<Int>)
    case strikethrough(Range<Int>)
    case spoiler(Range<Int>)
    case underline(Range<Int>)
    case italic(Range<Int>)
    case pre(Range<Int>, String?)
    case code(Range<Int>)
    case quote(Range<Int>, Bool)

    var weight: Int {
        switch self {
        case .bold:
            return 0
        case .italic:
            return 1
        case .pre:
            return 2
        case .code:
            return 3
        case .strikethrough:
            return 4
        case .spoiler:
            return 7
        case .underline:
            return 8
        case .quote:
            return 11
        }
    }
    
    static func <(lhs: SE_TextInputAttribute, rhs: SE_TextInputAttribute) -> Bool {
        if lhs.weight != rhs.weight {
            return lhs.weight < rhs.weight
        }
        return lhs.range.lowerBound < rhs.range.lowerBound
    }

}


final class SE_TextInputState: Equatable {
    static func == (lhs: SE_TextInputState, rhs: SE_TextInputState) -> Bool {
        return lhs.selectionRange == rhs.selectionRange && lhs.attributes == rhs.attributes && lhs.inputText == rhs.inputText
    }

    let inputText: String
    
    
    let attributes:[SE_TextInputAttribute]
    let selectionRange: Range<Int>
    

    init() {
        self.inputText = ""
        self.selectionRange = 0 ..< 0
        self.attributes = []
    }

    init(inputText: String, selectionRange: Range<Int>, attributes:[SE_TextInputAttribute]) {
        self.inputText = inputText
        self.selectionRange = selectionRange
        self.attributes = attributes.sorted(by: <)
    }
    
    public init(attributedText: NSAttributedString, selectionRange: Range<Int>) {
        self.inputText = attributedText.string
        self.selectionRange = selectionRange
        self.attributes = chatTextAttributes(from: attributedText)
    }

    
    func removeAttribute(_ attribute: SE_TextInputAttribute) -> SE_TextInputState {
        var attrs = self.attributes
        attrs.removeAll(where: {
            $0 == attribute
        })
        return .init(inputText: self.inputText, selectionRange: self.selectionRange, attributes: attrs)
    }
    
    func withUpdatedRange(_ range: Range<Int>) -> SE_TextInputState {
        return .init(inputText: self.inputText, selectionRange: range, attributes: attributes)
    }
    


    init(inputText: String) {
        self.inputText = inputText
        self.selectionRange = inputText.length ..< inputText.length
        self.attributes = []
    }


    func textInputState() -> Updated_ChatTextInputState {
        let result = NSMutableAttributedString(string: self.inputText)
        for attribute in self.attributes {
            let range = NSRange(location: attribute.range.lowerBound, length: attribute.range.count)
            switch attribute {
            case .bold:
                result.addAttribute(TextInputAttributes.bold, value: true as NSNumber, range: range)
            case .italic:
                result.addAttribute(TextInputAttributes.italic, value: true as NSNumber, range: range)
            case .code:
                result.addAttribute(TextInputAttributes.monospace, value: true as NSNumber, range: range)
            case let .pre(_, language):
                break
            case .strikethrough:
                result.addAttribute(TextInputAttributes.strikethrough, value: true as NSNumber, range: range)
            case .underline:
                result.addAttribute(TextInputAttributes.underline, value: true as NSNumber, range: range)
            case .spoiler:
                result.addAttribute(TextInputAttributes.spoiler, value: true as NSNumber, range: range)
            case let .quote(_, collapsed):
                result.addAttribute(TextInputAttributes.quote, value: TextInputTextQuoteAttribute(collapsed: collapsed), range: range)
            }
        }
        return .init(inputText: result, selectionRange: self.selectionRange)

    }

    func attributedString() -> NSAttributedString {
        return self.textInputState().inputText
    }
    
    func makeAttributeString(addPreAsBlock: Bool = false) -> NSAttributedString {
        let string = self.textInputState().inputText.mutableCopy() as! NSMutableAttributedString
        var pres:[(Range<Int>, String)] = []

        for attribute in attributes {
            switch attribute {
            case let .pre(range, language):
                if addPreAsBlock {
                    pres.append((range, language ?? ""))
                }
            default:
                break
            }
        }
        if addPreAsBlock {
            var offset: Int = 0
            for (pre, language) in pres.sorted(by: { $0.0.lowerBound < $1.0.lowerBound }) {
                let symbols = "```"
                
                string.insert(.initialize(string: symbols), at: pre.lowerBound + offset)
                offset += symbols.count

                if !language.isEmpty {
                    if string.string.nsstring.substring(with: NSMakeRange(pre.lowerBound + offset, 1)) == "\n" {
                        string.insert(.initialize(string: language), at: pre.lowerBound + offset)
                        offset += language.length
                    } else {
                        string.insert(.initialize(string: language + "\n"), at: pre.lowerBound + offset)
                        offset += language.length + 1
                    }
                }
                string.insert(.initialize(string: symbols), at: pre.upperBound + offset)
                offset += symbols.count
            }
        }

        return string.copy() as! NSAttributedString
    }


    func subInputState(from range: NSRange, theme: TelegramPresentationTheme = theme) -> SE_TextInputState {
        
        var subText = attributedString().attributedSubstring(from: range).trimmed

        let localAttributes = chatTextAttributes(from: subText)


        var raw:String = subText.string
        var appliedText = subText.string
        var attributes:[SE_TextInputAttribute] = []

        var offsetRanges:[NSRange] = []
        if let regex = se_markdownRegex {

            var skipIndexes:Set<Int> = Set()
            if !localAttributes.isEmpty {
                var index: Int = 0
                let matches = regex.matches(in: subText.string, range: NSMakeRange(0, subText.string.length))
                for match in matches {
                    for attr in localAttributes {
                        let range = match.range
                        let attrRange = NSMakeRange(attr.range.lowerBound, attr.range.upperBound - attr.range.lowerBound)
                        if attrRange.intersection(range) != nil {
                            skipIndexes.insert(index)
                        }
                    }
                    index += 1
                }
            }


            var rawOffset:Int = 0
            var newText:[String] = []
            var index: Int = 0
            while let match = regex.firstMatch(in: raw, range: NSMakeRange(0, raw.length)) {
                
               
                
                let matchIndex = rawOffset + match.range.location



                newText.append(raw.nsstring.substring(with: NSMakeRange(0, match.range.location)))

                var pre = match.range(at: 3)


                if pre.location != NSNotFound {
                    if !skipIndexes.contains(index) {
                        var text = raw.nsstring.substring(with: pre)

                        var language: String = ""
                        let newLineRange = text.nsstring.range(of: "\n")
                        if newLineRange.location != 0 && newLineRange.location != NSNotFound {
                            let lang = text.nsstring.substring(with: NSMakeRange(0, newLineRange.location))
                            let test = lang.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                            if test.length == lang.length {
                                language = lang
                                offsetRanges.append(NSMakeRange(matchIndex + newLineRange.location, lang.length))
                                text = String(text.nsstring.substring(with: NSMakeRange(newLineRange.location, text.length - newLineRange.location)))
                                rawOffset -= newLineRange.location
                            }
                        }
                        
                        rawOffset -= match.range(at: 2).length + match.range(at: 4).length
                        newText.append(raw.nsstring.substring(with: match.range(at: 1)) + text + raw.nsstring.substring(with: match.range(at: 5)))
                        attributes.append(.pre(matchIndex + match.range(at: 1).length ..< matchIndex + match.range(at: 1).length + text.length, language))
                        offsetRanges.append(NSMakeRange(matchIndex + match.range(at: 1).length, 3))
                        offsetRanges.append(NSMakeRange(matchIndex + match.range(at: 1).length + text.length + 3, 3))
                    } else {
                        let text = raw.nsstring.substring(with: pre)
                        let entity = raw.nsstring.substring(with: match.range(at: 2))
                        newText.append(raw.nsstring.substring(with: match.range(at: 1)) + entity + text + entity + raw.nsstring.substring(with: match.range(at: 5)))
                    }
                }

                pre = match.range(at: 8)
                if pre.location != NSNotFound {
                    let text = raw.nsstring.substring(with: pre)
                    if !skipIndexes.contains(index) {

                        let left = match.range(at: 6)

                        let entity = raw.nsstring.substring(with: match.range(at: 7))
                        newText.append(raw.nsstring.substring(with: left) + text + raw.nsstring.substring(with: match.range(at: 9)))


                        switch entity {
                        case "`":
                            attributes.append(.code(matchIndex + left.length ..< matchIndex + left.length + text.length))
                        case "**":
                            attributes.append(.bold(matchIndex + left.length ..< matchIndex + left.length + text.length))
                        case "~~":
                            attributes.append(.strikethrough(matchIndex + left.length ..< matchIndex + left.length + text.length))
                        case "__":
                            attributes.append(.italic(matchIndex + left.length ..< matchIndex + left.length + text.length))
                        case "||":
                            attributes.append(.spoiler(matchIndex + left.length ..< matchIndex + left.length + text.length))
                        default:
                            break
                        }

                        offsetRanges.append(NSMakeRange(matchIndex + left.length, entity.length))
                        offsetRanges.append(NSMakeRange(matchIndex + left.length + text.length, entity.length))

                        rawOffset -= match.range(at: 7).length * 2
                    } else {
                        let entity = raw.nsstring.substring(with: match.range(at: 7))
                        newText.append(raw.nsstring.substring(with: match.range(at: 6)) + entity + text + entity + raw.nsstring.substring(with: match.range(at: 9)))
                    }
                }
                raw = raw.nsstring.substring(from: match.range.location + match.range(at: 0).length)
                rawOffset += match.range.location + match.range(at: 0).length

                index += 1
            }

            newText.append(raw)
            appliedText = newText.joined()
        }

        for attr in localAttributes {
            var newRange = NSMakeRange(attr.range.lowerBound, (attr.range.upperBound - attr.range.lowerBound))
            for offsetRange in offsetRanges {
                if offsetRange.location < newRange.location {
                    newRange.location -= offsetRange.length
                }
//                if newRange.intersection(offsetRange) != nil {
//                    newRange.length -= offsetRange.length
//                }
            }
            
            
            //if newRange.lowerBound >= range.location && newRange.upperBound <= range.location + range.length {
                switch attr {
                case .bold:
                    attributes.append(.bold(newRange.min ..< newRange.max))
                case .italic:
                    attributes.append(.italic(newRange.min ..< newRange.max))
                case let .pre(_, language):
                    attributes.append(.pre(newRange.min ..< newRange.max, language))
                case .code:
                    attributes.append(.code(newRange.min ..< newRange.max))
                case .strikethrough:
                    attributes.append(.strikethrough(newRange.min ..< newRange.max))
                case .underline:
                    attributes.append(.underline(newRange.min ..< newRange.max))
                case .spoiler:
                    attributes.append(.spoiler(newRange.min ..< newRange.max))
                case let .quote(_, collapsed):
                    attributes.append(.quote(newRange.min ..< newRange.max, collapsed))
                }
          //  }
        }
        
        let charset = CharacterSet.whitespacesAndNewlines
        
        while !appliedText.isEmpty, let range = appliedText.rangeOfCharacter(from: charset), range.lowerBound == appliedText.startIndex {
            
            let oldLength = appliedText.length
            appliedText.removeSubrange(range)
            let newLength = appliedText.length

            let symbolLength = oldLength - newLength
            
            for (i, attr) in attributes.enumerated() {
                let updated: SE_TextInputAttribute
                if attr.range.lowerBound == 0 {
                    updated = attr.updateRange(0 ..< max(attr.range.upperBound - symbolLength, 0))
                } else {
                    updated = attr.updateRange(attr.range.lowerBound - symbolLength ..< max(attr.range.upperBound - symbolLength, attr.range.lowerBound - symbolLength))
                }
                attributes[i] = updated
            }
        }
        
        
        
        while !appliedText.isEmpty, let range = appliedText.rangeOfCharacter(from: charset, options: [], range: appliedText.index(before: appliedText.endIndex) ..< appliedText.endIndex), range.upperBound == appliedText.endIndex {
            
            let oldLength = appliedText.length
            appliedText.removeSubrange(range)
            let newLength = appliedText.length

            let symbolLength = oldLength - newLength
            
            for (i, attr) in attributes.enumerated() {
                if attr.range.upperBound == oldLength {
                    let updated: SE_TextInputAttribute
                    updated = attr.updateRange(attr.range.lowerBound ..< max(attr.range.upperBound - symbolLength, attr.range.lowerBound))
                    attributes[i] = updated
                }
            }
        }
    
        attributes = concatAttributes(attributes).sorted(by: { $0.range.lowerBound < $1.range.lowerBound })
        
        return SE_TextInputState(inputText: appliedText, selectionRange: 0 ..< 0, attributes: attributes)

    }


    func messageTextEntities(_ detectLinks: ParsingType = [.Hashtags]) -> [MessageTextEntity] {
        var entities:[MessageTextEntity] = []
        for attribute in attributes {
            sw: switch attribute {
            case let .bold(range):
                entities.append(.init(range: range, type: .Bold))
            case let .strikethrough(range):
                entities.append(.init(range: range, type: .Strikethrough))
            case let .spoiler(range):
                entities.append(.init(range: range, type: .Spoiler))
            case let .underline(range):
                entities.append(.init(range: range, type: .Underline))
            case let .italic(range):
                entities.append(.init(range: range, type: .Italic))
            case let .pre(range, language):
                entities.append(.init(range: range, type: .Pre(language: language)))
            case let .code(range):
                entities.append(.init(range: range, type: .Code))
            case let .quote(range, collapsed):
                entities.append(.init(range: range, type: .BlockQuote(isCollapsed: collapsed)))
            }
        }

        return entities
    }


}


extension Updated_ChatTextInputState : Equatable {
    func textInputState() -> SE_TextInputState {
        return .init(attributedText: self.inputText, selectionRange: self.selectionRange)
    }
    public static func ==(lhs: Updated_ChatTextInputState, rhs: Updated_ChatTextInputState) -> Bool {
        if lhs.inputText.string != rhs.inputText.string {
            return false
        }
        if lhs.textInputState().attributes != rhs.textInputState().attributes {
            return false
        }
        return lhs.selectionRange == rhs.selectionRange
    }
}


final class SE_TextView_Interactions : InterfaceObserver {
    var presentation: Updated_ChatTextInputState
    
    var max_height: CGFloat = 50
    var min_height: CGFloat = 50
    var max_input: Int = 100000
    var supports_continuity_camera: Bool = false
    var inputIsEnabled: Bool = true
    var canTransform: Bool = true
    var simpleTransform: Bool = false
    var emojiPlayPolicy: SE_LottiePlayPolicy = .loop
    
    var allowedLinkHosts: [String] = []
    
    init(presentation: Updated_ChatTextInputState = .init()) {
        self.presentation = presentation
    }
    
    func update(animated:Bool = true, _ f:(Updated_ChatTextInputState)->Updated_ChatTextInputState)->Void {
        let oldValue = self.presentation
        let presentation = f(oldValue)
        self.presentation = presentation
        if oldValue != presentation {
            self.notifyObservers(value: presentation, oldValue:oldValue, animated:animated)
        }
    }
    
    func insertText(_ text: NSAttributedString, selectedRange:Range<Int>? = nil) -> Updated_ChatTextInputState {
        
        var selectedRange = selectedRange ?? presentation.selectionRange
        let inputText = presentation.inputText.mutableCopy() as! NSMutableAttributedString
        
        if selectedRange.upperBound - selectedRange.lowerBound > 0 {
            inputText.replaceCharacters(in: NSMakeRange(selectedRange.lowerBound, selectedRange.upperBound - selectedRange.lowerBound), with: text)
            selectedRange = selectedRange.lowerBound ..< selectedRange.lowerBound
        } else {
            inputText.insert(text, at: selectedRange.lowerBound)
        }
        
        let nRange:Range<Int> = selectedRange.lowerBound + text.length ..< selectedRange.lowerBound + text.length
        return Updated_ChatTextInputState(inputText: inputText, selectionRange: nRange)
    }
    
    var inputDidUpdate:((Updated_ChatTextInputState)->Void) = { _ in }
    var processEnter:(NSEvent)->Bool = { event in return isEnterAccessObjc(event, false) }
    var processPaste:(NSPasteboard)->Bool = { _ in return false }
    var processAttriburedCopy: (NSAttributedString) -> Bool = { _ in return false }
    var responderDidUpdate:()->Void = { }
    
    var filterEvent: (NSEvent)->Bool = { _ in return true }
}


final class SE_UITextView : View, Notifable, ChatInputTextViewDelegate {
    func inputViewIsEnabled(_ event: NSEvent) -> Bool {
        return interactions.filterEvent(event) && interactions.inputIsEnabled
    }
    
    func inputViewProcessEnter(_ theEvent: NSEvent) -> Bool {
        return interactions.processEnter(theEvent)
    }
    
    func inputViewMaybeClosed() -> Bool {
        return false
    }
    func inputMaximumHeight() -> CGFloat {
        return max_height
    }
    func inputMaximumLenght() -> Int {
        return max_input_length
    }
    func inputViewSupportsContinuityCamera() -> Bool {
        return supports_continuity_camera
    }
    func inputViewProcessPastepoard(_ pboard: NSPasteboard) -> Bool {
        return self.interactions.processPaste(pboard)
    }
    func inputViewCopyAttributedString(_ attributedString: NSAttributedString) -> Bool {
        return self.interactions.processAttriburedCopy(attributedString)
    }
    
    func inputViewResponderDidUpdate() {
        self.interactions.responderDidUpdate()
    }
    
    var inputTheme: InputViewTheme = theme.inputTheme {
        didSet {
            let placeholder = self.placeholder
            self.placeholder = placeholder
            self.view.theme = inputTheme
            self.chatInputTextViewDidUpdateText()
        }
    }
    var placeholderFontSize: CGFloat? = nil
    var placeholder: String = "" {
        didSet {
            self.view.placeholderString = .initialize(string: placeholder, color: inputTheme.grayTextColor, font: .normal(placeholderFontSize ?? inputTheme.fontSize))
        }
    }
    
    private var revealSpoilers: Bool = false {
        didSet {
            self.updateInput(current: self.interactions.presentation, previous: self.interactions.presentation)
        }
    }
    
    private let delayDisposable = MetaDisposable()
    
    private var updatingInputState: Bool = false
    
    var isEmpty: Bool {
        return self.inputTextState.inputText.string.isEmpty
    }
    
    func chatInputTextViewDidUpdateText() {
        refreshInputView()
        
        let inputTextState = self.inputTextState
     
        self.interactions.update { _ in
            return inputTextState
        }
    }
    
    var inputTextState: Updated_ChatTextInputState {
        let selectionRange: Range<Int> = view.selectedRange.location ..< (view.selectedRange.location + view.selectedRange.length)
        return Updated_ChatTextInputState(inputText: stateAttributedStringForText(view.attributedText.copy() as! NSAttributedString), selectionRange: selectionRange)
    }

    private func refreshInputView() {
        refreshTextInputAttributes(self.view.textView, theme: inputTheme, spoilersRevealed: revealSpoilers, availableEmojis: Set())
       // refreshChatTextInputTypingAttributes(self.view.textView, theme: inputTheme)
    }
    
    func chatInputTextViewDidChangeSelection(dueToEditing: Bool) {
        if !dueToEditing && !self.updatingInputState {
            refreshInputView()
            let inputTextState = self.inputTextState
            interactions.update { _ in
                inputTextState
            }
        }

    }
    
    func chatInputTextViewDidBeginEditing() {
        
    }
    
    func chatInputTextViewDidFinishEditing() {
        
    }
    
    func chatInputTextView(shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        return true
    }
    
    func chatInputTextViewShouldCopy() -> Bool {
        return true
    }
    
    func chatInputTextViewShouldPaste() -> Bool {
        return true
    }
    
    func inputTextCanTransform() -> Bool {
        return interactions.canTransform
    }
    
    func inputTextSimpleTransform() -> Bool {
        return interactions.simpleTransform
    }
    
    func inputViewRevealSpoilers() {
        self.revealSpoilers = true
        delayDisposable.set(delaySignal(5.0).start(completed: { [weak self] in
            self?.revealSpoilers = false
        }))
    }
    
    func inputApplyTransform(_ reason: InputViewTransformReason) {
        
        if !interactions.canTransform {
            return
        }
        switch reason {
        case let .attribute(attribute):
            self.interactions.update({ current in
                return chatTextInputAddFormattingAttribute(current, attribute: attribute)
            })
        case .clear:
            self.interactions.update({ current in
                return chatTextInputClearFormattingAttributes(current)
            })
        case let .toggleQuote(quote, range):
            self.interactions.update({ current in
                return chatTextInputAddQuoteAttribute(current, selectionRange: range.min ..< range.max, collapsed: !quote.collapsed, doNotUpdateSelection: true)
            })
            if let window = self._window {
                showModalText(for: window, text: !quote.collapsed ? strings().inputQuoteCollapsed : strings().inputQuoteExpanded)
            }
        default:
            break
        }
    }
    
    func insertText(_ string: NSAttributedString, range: Range<Int>? = nil) {
        let updatedText = self.interactions.insertText(string, selectedRange: range)
        self.interactions.update { _ in
            updatedText
        }
    }
    
    func scrollToCursor() {
        self.view.scrollToCursor()
    }
    
    func string() -> String {
        return self.inputTextState.inputText.string
    }
    
    func highlight(for range: NSRange, whole: Bool) -> NSRect {
        return self.view.highlight(for: range, whole: whole)
    }
    
    var inputView:NSTextView {
        return self.view.inputView
    }
    
    var selectedRange: NSRange {
        return self.view.selectedRange
    }
    var scrollView: NSScrollView {
        return self.view
    }
    
    var max_height: CGFloat {
        return interactions.max_height
    }
    var max_input_length: Int {
        return interactions.max_input
    }
    var min_height: CGFloat {
        return interactions.min_height
    }
    var supports_continuity_camera: Bool {
        return interactions.supports_continuity_camera
    }
    
    let view: ChatInputTextView
    
    var interactions: SE_TextView_Interactions {
        didSet {
            oldValue.remove(observer: self)
            interactions.add(observer: self)
        }
    }
    
    var context: AccountContext?
    
    required init(frame frameRect: NSRect, interactions: SE_TextView_Interactions) {
        self.view = ChatInputTextView(frame: frameRect.size.bounds)
        self.interactions = interactions
        super.init(frame: frameRect)
        self.interactions.add(observer: self)
        addSubview(view)
        view.delegate = self
        
    }
    
    override func layout() {
        super.layout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required convenience init(frame frameRect: NSRect) {
        self.init(frame: frameRect, interactions: .init())
    }
    
    func isEqual(to other: Notifable) -> Bool {
        if let other = other as? SE_UITextView {
            return other === self
        }
        return false
    }
        
    
    func set(_ input: SE_TextInputState) {
        let inputState = input.textInputState()
        if self.interactions.presentation != inputState {
            self.interactions.update { _ in
                return inputState
            }
        }
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? Updated_ChatTextInputState, let oldValue = oldValue as? Updated_ChatTextInputState {
            self.updateInput(current: value, previous: oldValue)
        }
    }
    
    private func updateInput(current: Updated_ChatTextInputState, previous: Updated_ChatTextInputState) {
        
        self.updatingInputState = true
        

        
        let attributedText = textAttributedStringForStateText(current.inputText, fontSize: inputTheme.fontSize, textColor: inputTheme.textColor, accentTextColor: inputTheme.accentColor, writingDirection: nil, spoilersRevealed: revealSpoilers, availableEmojis: Set())
        
        
        let textViewAttributed = textAttributedStringForStateText(view.attributedText.copy() as! NSAttributedString, fontSize: inputTheme.fontSize, textColor: inputTheme.textColor, accentTextColor: inputTheme.accentColor, writingDirection: nil, spoilersRevealed: revealSpoilers, availableEmojis: Set())


        
        let selectionRange = NSMakeRange(current.selectionRange.lowerBound, current.selectionRange.count)

        if attributedText.string != textViewAttributed.string || chatTextAttributes(from: attributedText) != chatTextAttributes(from: textViewAttributed) {
            let undoItem = InputViewUndoItem(was: textViewAttributed, be: attributedText, wasRange: self.view.selectedRange, beRange: selectionRange)
            self.view.addUndoItem(undoItem)
        }
        
        refreshInputView()

        
        if previous != current {
            self.interactions.inputDidUpdate(current)
        }
        self.updatingInputState = false

    }
    
    func updateLayout(size: NSSize, textHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: self.view, frame: size.bounds)
        self.view.updateLayout(size: size, textHeight: textHeight, transition: transition)
    }
    
    func height(for width: CGFloat) -> CGFloat {
        return self.view.textHeightForWidth(width)
    }
    
    func setToEnd() {
        self.interactions.update({ current in
            var current = current
            current.selectionRange = current.inputText.length ..< current.inputText.length
            return current
        })
    }
    
    func selectAll() {
        self.interactions.update({ current in
            var current = current
            current.selectionRange = 0 ..< current.inputText.length
            return current
        })
    }
    
    func makeFirstResponder() {
        self.window?.makeFirstResponder(self.inputView)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        self.inputTheme = theme.inputTheme
    }
    
    deinit {
        delayDisposable.dispose()
    }
}
