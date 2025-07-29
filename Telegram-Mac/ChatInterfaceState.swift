//
//  ChatInterfaceState.swift
//  Telegram-Mac
//
//  Created by keepcoder on 01/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import SwiftSignalKit
import TelegramCore
import TGModernGrowingTextView
import InputView

private func concatAttributes(_ attributes: [ChatTextInputAttribute]) -> [ChatTextInputAttribute] {
    guard !attributes.isEmpty else { return [] }

    let sortedAttributes = attributes.sorted { $0.weight < $1.weight }
    var mergedAttributes = [ChatTextInputAttribute]()

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

private let markdownRegexFormat = "(^|\\s|\\n)(````?)([\\s\\S]+?)(````?)([\\s\\n\\.,:?!;]|$)|(^|\\s)(`|\\*\\*|__|~~|\\|\\|)([^\\n]+?)\\7([\\s\\.,:?!;]|$)|@(\\d+)\\s*\\((.+?)\\)"
private let markdownRegex = try? NSRegularExpression(pattern: markdownRegexFormat, options: [.caseInsensitive, .anchorsMatchLines])



struct ChatInterfaceSelectionState: Equatable {
    let selectedIds: Set<MessageId>
    let lastSelectedId: MessageId?

    init(selectedIds: Set<MessageId>, lastSelectedId: MessageId?) {
        self.selectedIds = selectedIds
        self.lastSelectedId = lastSelectedId
    }
    func withUpdatedSelectedIds(_ ids: Set<MessageId>) -> ChatInterfaceSelectionState {
        return ChatInterfaceSelectionState(selectedIds: ids, lastSelectedId: self.lastSelectedId)
    }
    func withUpdatedLastSelected(_ lastSelectedId: MessageId?) -> ChatInterfaceSelectionState {
        return ChatInterfaceSelectionState(selectedIds: self.selectedIds, lastSelectedId: lastSelectedId)
    }
}

struct ChatInterfaceMessageEffect : Equatable, Codable {
    var effect: AvailableMessageEffects.MessageEffect
    var fromRect: NSRect?
}

enum ChatTextInputAttribute : Equatable, Comparable, Codable {
    case bold(Range<Int>)
    case strikethrough(Range<Int>)
    case spoiler(Range<Int>)
    case underline(Range<Int>)
    case italic(Range<Int>)
    case pre(Range<Int>, String?)
    case code(Range<Int>)
    case uid(Range<Int>, Int64)
    case url(Range<Int>, String)
    case animated(Range<Int>, String, Int64, TelegramMediaFile?, ItemCollectionId?)
    case quote(Range<Int>, Bool)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        let lowerBound = Int(try container.decode(Int32.self, forKey: "start"))
        let upperBound = Int(try container.decode(Int32.self, forKey: "end"))
        let range = lowerBound ..< upperBound

        let type: Int32 = try container.decode(Int32.self, forKey: "_rawValue")
        switch type {
        case 0:
            self = .bold(range)
        case 1:
            self = .italic(range)
        case 2:
            self = .pre(range, try container.decodeIfPresent(String.self, forKey: "language"))
        case 3:
            self = .uid(range, try container.decode(Int64.self, forKey: "uid"))
        case 4:
            self = .code(range)
        case 5:
            self = .url(range, try container.decode(String.self, forKey: "url"))
        case 6:
            self = .strikethrough(range)
        case 7:
            self = .spoiler(range)
        case 8:
            self = .underline(range)
        case 9:
            self = .animated(range, try container.decode(String.self, forKey: "id"), try container.decode(Int64.self, forKey: "fileId"), try container.decodeIfPresent(TelegramMediaFile.self, forKey: "file"), try container.decodeIfPresent(ItemCollectionId.self, forKey: "info"))
        case 10:
            self = .quote(range, try container.decodeIfPresent(Bool.self, forKey: "collapsed") ?? false)
        default:
            self = .bold(range)
            //fatalError("input attribute not supported")
        }
    }
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
        case .uid:
            return 5
        case .url:
            return 6
        case .spoiler:
            return 7
        case .underline:
            return 8
        case .animated:
            return 9
        case .quote:
            return 11
        }
    }
    
    static func <(lhs: ChatTextInputAttribute, rhs: ChatTextInputAttribute) -> Bool {
        if lhs.weight != rhs.weight {
            return lhs.weight < rhs.weight
        }
        return lhs.range.lowerBound < rhs.range.lowerBound
    }

    func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode(Int32(self.range.lowerBound), forKey: "start")
        try container.encode(Int32(self.range.upperBound), forKey: "end")
        switch self {
        case .bold:
            try container.encode(Int32(0), forKey: "_rawValue")
        case .italic:
            try container.encode(Int32(1), forKey: "_rawValue")
        case let .pre(_, language):
            try container.encode(Int32(2), forKey: "_rawValue")
            try container.encodeIfPresent(language, forKey: "language")
        case .code:
            try container.encode(Int32(4), forKey: "_rawValue")
        case .strikethrough:
            try container.encode(Int32(6), forKey: "_rawValue")
        case .spoiler:
            try container.encode(Int32(7), forKey: "_rawValue")
        case .underline:
            try container.encode(Int32(8), forKey: "_rawValue")
        case let .uid(_, uid):
            try container.encode(Int32(3), forKey: "_rawValue")
            try container.encode(uid, forKey: "uid")
        case let .url(_, url):
            try container.encode(Int32(5), forKey: "_rawValue")
            try container.encode(url, forKey: "url")
        case let .animated(_, id, fileId, file, info):
            try container.encode(Int32(9), forKey: "_rawValue")
            try container.encode(id, forKey: "id")
            try container.encode(fileId, forKey: "fileId")
            if let file = file {
                try container.encode(file, forKey: "file")
            }
            if let info = info {
                try container.encode(info, forKey: "info")
            }
        case let .quote(_, collapsed):
            try container.encode(Int32(10), forKey: "_rawValue")
            try container.encode(collapsed, forKey: "collapsed")
        }
    }

}

extension ChatTextInputAttribute {

    
    func isSameAttribute(_ rhs: ChatTextInputAttribute) -> Bool {
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
        case let .uid(_, id):
            switch rhs {
            case .uid(_, id):
                return true
            default:
                return false
            }
        case let .url(_, string):
            switch rhs {
            case .url(_, string):
                return true
            default:
                return false
            }
        case .animated:
            return false
        }
    }

    func intersectsOrAdjacent(with attribute: ChatTextInputAttribute) -> Bool {
        return self.range.upperBound >= attribute.range.lowerBound && self.range.lowerBound <= attribute.range.upperBound
    }

    // Merge two attributes into one with a combined range
    mutating func merge(with attribute: ChatTextInputAttribute) {
        let newStart = min(self.range.lowerBound, attribute.range.lowerBound)
        let newEnd = max(self.range.upperBound, attribute.range.upperBound)
        self = self.updateRange(newStart..<newEnd)
    }
    
    var range:Range<Int> {
        switch self {
        case let .bold(range), let .italic(range), let .pre(range, _), let .code(range), let .strikethrough(range), let .spoiler(range), let .underline(range):
            return range
        case let .uid(range, _):
            return range
        case let .url(range, _):
            return range
        case let .animated(range, _, _, _, _):
            return range
        case let .quote(range, _):
            return range
        }
    }
    
    func updateRange(_ range: Range<Int>) -> ChatTextInputAttribute {
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
        case let .uid(_, uid):
            return .uid(range, uid)
        case let .url(_, url):
            return .url(range, url)
        case let .animated(_, id, fileId, file, info):
            return .animated(range, id, fileId, file, info)
        case let .quote(_, collapsed):
            return .quote(range, collapsed)
        }
    }
}


func chatTextAttributes(from entities:TextEntitiesMessageAttribute, associatedMedia:[MediaId : Media] = [:]) -> [ChatTextInputAttribute] {
    var inputAttributes:[ChatTextInputAttribute] = []
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
        case let .TextMention(peerId: peerId):
            inputAttributes.append(.uid(entity.range, peerId.id._internalGetInt64Value()))
        case let .TextUrl(url):
            inputAttributes.append(.url(entity.range, url))
        case .Strikethrough:
            inputAttributes.append(.strikethrough(entity.range))
        case .Spoiler:
            inputAttributes.append(.spoiler(entity.range))
        case .Underline:
            inputAttributes.append(.underline(entity.range))
        case let .CustomEmoji(_, fileId):
            inputAttributes.append(.animated(entity.range, "\(arc4random())", fileId, nil, nil))
        case let .BlockQuote(collapsed):
            inputAttributes.append(.quote(entity.range, collapsed))
        default:
            break
        }
    }
    return inputAttributes
}

func chatTextAttributes(from attributedText: NSAttributedString) -> [ChatTextInputAttribute] {
    
    var parsedAttributes: [ChatTextInputAttribute] = []
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
            } else if key == TextInputAttributes.textMention, let value = value as? ChatTextInputTextMentionAttribute {
                parsedAttributes.append(.uid(range, value.peerId.toInt64()))

            } else if key == TextInputAttributes.textUrl, let value = value as? TextInputTextUrlAttribute {
                parsedAttributes.append(.url(range, value.url))
            } else if key == TextInputAttributes.customEmoji, let value = value as? TextInputTextCustomEmojiAttribute {
                parsedAttributes.append(.animated(range, value.emoji, value.fileId, value.file, value.collectionId))
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

final class ChatTextInputState: Codable, Equatable {
    static func == (lhs: ChatTextInputState, rhs: ChatTextInputState) -> Bool {
        return lhs.selectionRange == rhs.selectionRange && lhs.attributes == rhs.attributes && lhs.inputText == rhs.inputText
    }

    let inputText: String
    
    
    let attributes:[ChatTextInputAttribute]
    let selectionRange: Range<Int>
    

    init() {
        self.inputText = ""
        self.selectionRange = 0 ..< 0
        self.attributes = []
    }

    init(inputText: String, selectionRange: Range<Int>, attributes:[ChatTextInputAttribute]) {
        self.inputText = inputText
        self.selectionRange = selectionRange
        self.attributes = attributes.sorted(by: <)
    }
    
    public init(attributedText: NSAttributedString, selectionRange: Range<Int>) {
        self.inputText = attributedText.string
        self.selectionRange = selectionRange
        self.attributes = chatTextAttributes(from: attributedText)
    }

    
    
    var inlineMedia: [MediaId : Media] {
        var media:[MediaId : Media] = [:]
        for attribute in attributes {
            switch attribute {
            case .animated(_, _, let fileId, let file, _):
                if let file = file {
                    media[MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)] = file
                }
            default:
                break
            }
        }
        return media
    }
    
    var upstairCollections: [ItemCollectionId] {
        var media:[ItemCollectionId] = []
        for attribute in attributes {
            switch attribute {
            case let .animated(_, _, _, _, info):
                if let info = info {
                    if !media.contains(info) {
                        media.append(info)
                    }
                }
            default:
                break
            }
        }
        return media
    }
    
    var withoutAnimatedEmoji: ChatTextInputState {
        let attrs = self.attributes.filter { attr in
            switch attr {
            case .animated:
                return false
            default:
                return true
            }
        }
        return .init(inputText: self.inputText, selectionRange: self.selectionRange, attributes: attrs)
    }
    
    
    func removeAttribute(_ attribute: ChatTextInputAttribute) -> ChatTextInputState {
        var attrs = self.attributes
        attrs.removeAll(where: {
            $0 == attribute
        })
        return .init(inputText: self.inputText, selectionRange: self.selectionRange, attributes: attrs)
    }
    
    func withUpdatedRange(_ range: Range<Int>) -> ChatTextInputState {
        return .init(inputText: self.inputText, selectionRange: range, attributes: attributes)
    }
    
    func isFirstAnimatedEmoji(_ string: String) -> Bool {
        for attribute in attributes {
            switch attribute {
            case let .animated(range, _, _, _, _):
                if range == 0 ..< string.length {
                    return true
                }
            default:
                break
            }
        }
        return false
    }
    func isAnimatedEmoji(at r: NSRange) -> Bool {
        for attribute in attributes {
            switch attribute {
            case let .animated(range, _, _, _, _):
                if range.lowerBound == r.lowerBound && range.upperBound == range.upperBound {
                    return true
                }
            default:
                break
            }
        }
        return false
    }

    init(inputText: String) {
        self.inputText = inputText
        self.selectionRange = inputText.length ..< inputText.length
        self.attributes = []
    }

    init(from decoder: Decoder) throws {
        
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.inputText = try container.decode(String.self, forKey: "t")
        let lowerBound = try container.decode(Int32.self, forKey: "s0")
        let upperBound = try container.decode(Int32.self, forKey: "s1")

        self.selectionRange = Int(lowerBound) ..< Int(upperBound)
        self.attributes = try container.decode([ChatTextInputAttribute].self, forKey: "t.a")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.inputText, forKey: "t")
        try container.encode(Int32(self.selectionRange.lowerBound), forKey: "s0")
        try container.encode(Int32(self.selectionRange.upperBound), forKey: "s1")
        try container.encode(self.attributes, forKey: "t.a")
    }
    
    func unique(isPremium: Bool) -> ChatTextInputState {
        let attributes:[ChatTextInputAttribute] = self.attributes.compactMap { attr in
            switch attr {
            case let .animated(range, _, fileId, file, info):
                if !isPremium && file?.isPremiumEmoji == true {
                    return nil
                }
                return .animated(range, "\(arc4random64())", fileId, file, info)
            default:
                return attr
            }
        }
        return .init(inputText: self.inputText, selectionRange: self.selectionRange, attributes: attributes)
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
            case let .uid(_, id):
                result.addAttribute(TextInputAttributes.textMention, value: ChatTextInputTextMentionAttribute(peerId: PeerId(id)), range: range)
            case let .url(_, url):
                result.addAttribute(TextInputAttributes.textUrl, value: TextInputTextUrlAttribute(url: url), range: range)
            case let .animated(_, emoji, fileId, file, collectionId):
                result.addAttribute(TextInputAttributes.customEmoji, value: TextInputTextCustomEmojiAttribute(collectionId: collectionId, fileId: fileId, file: file, emoji: emoji), range: range)
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


    func subInputState(from range: NSRange, theme: TelegramPresentationTheme = theme) -> ChatTextInputState {
//        let subText = convertMarkdownToAttributes(attributedString().attributedSubstring(from: range)).trimmed
//        let attributes = chatTextAttributes(from: subText)
        
        
        
        var subText = attributedString().attributedSubstring(from: range).trimmed

        let localAttributes = chatTextAttributes(from: subText)


        var raw:String = subText.string
        var appliedText = subText.string
        var attributes:[ChatTextInputAttribute] = []

        var offsetRanges:[NSRange] = []
        if let regex = markdownRegex {

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
                case let .uid(_, uid):
                    attributes.append(.uid(newRange.min ..< newRange.max, uid))
                case let .url(_, url):
                    attributes.append(.url(newRange.min ..< newRange.max, url))
                case let .quote(_, collapsed):
                    attributes.append(.quote(newRange.min ..< newRange.max, collapsed))
                case let .animated(_, id, fileId, file, itemId):
                    attributes.append(.animated(newRange.min ..< newRange.max, id, fileId, file, itemId))
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
                let updated: ChatTextInputAttribute
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
                    let updated: ChatTextInputAttribute
                    updated = attr.updateRange(attr.range.lowerBound ..< max(attr.range.upperBound - symbolLength, attr.range.lowerBound))
                    attributes[i] = updated
                }
            }
        }
    
        attributes = concatAttributes(attributes).sorted(by: { $0.range.lowerBound < $1.range.lowerBound })
        
        return ChatTextInputState(inputText: appliedText, selectionRange: 0 ..< 0, attributes: attributes)

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
            case let .uid(range, uid):
                entities.append(.init(range: range, type: .TextMention(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(uid)))))
            case let .url(range, url):
                entities.append(.init(range: range, type: .TextUrl(url: url)))
            case let .animated(range, _, fileId, _, _):
                entities.append(.init(range: range, type: .CustomEmoji(stickerPack: nil, fileId: fileId)))
            case let .quote(range, collapsed):
                entities.append(.init(range: range, type: .BlockQuote(isCollapsed: collapsed)))
            }
        }

        let attr = NSMutableAttributedString(string: inputText)
        attr.detectLinks(type: detectLinks)

        attr.enumerateAttribute(NSAttributedString.Key.link, in: attr.range, options: NSAttributedString.EnumerationOptions(rawValue: 0), using: { (value, range, stop) in
            if let value = value as? inAppLink {
                switch value {
                case let .external(link, _):
                    if link.hasPrefix("#") {
                        entities.append(MessageTextEntity(range: range.lowerBound ..< range.upperBound, type: .Hashtag))
                    } else if detectLinks.contains(.Links) {
                        entities.append(MessageTextEntity(range: range.lowerBound ..< range.upperBound, type: .Url))
                    }
                default:
                    break
                }
            }
        })

        return entities
    }


}


struct ChatInterfaceMessageActionsState: Codable, Equatable {
    let closedButtonKeyboardMessageId: MessageId?
    let processedSetupReplyMessageId: MessageId?

    var isEmpty: Bool {
        return self.closedButtonKeyboardMessageId == nil && self.processedSetupReplyMessageId == nil
    }

    init() {
        self.closedButtonKeyboardMessageId = nil
        self.processedSetupReplyMessageId = nil
    }

    init(closedButtonKeyboardMessageId: MessageId?, processedSetupReplyMessageId: MessageId?) {
        self.closedButtonKeyboardMessageId = closedButtonKeyboardMessageId
        self.processedSetupReplyMessageId = processedSetupReplyMessageId
    }

    init(from decoder: Decoder) throws {
        
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        if let closedMessageIdPeerId = (try? container.decodeIfPresent(Int64.self, forKey: "cb.p")), let closedMessageIdNamespace = (try? container.decodeIfPresent(Int32.self, forKey: "cb.n")), let closedMessageIdId = (try? container.decodeIfPresent(Int32.self, forKey: "cb.i")) {
            self.closedButtonKeyboardMessageId = MessageId(peerId: PeerId(closedMessageIdPeerId), namespace: closedMessageIdNamespace, id: closedMessageIdId)
        } else {
            self.closedButtonKeyboardMessageId = nil
        }

        if let processedMessageIdPeerId = (try? container.decodeIfPresent(Int64.self, forKey: "pb.p")), let processedMessageIdNamespace = (try? container.decodeIfPresent(Int32.self, forKey: "pb.n")), let processedMessageIdId = (try? container.decodeIfPresent(Int32.self, forKey: "pb.i")) {
            self.processedSetupReplyMessageId = MessageId(peerId: PeerId(processedMessageIdPeerId), namespace: processedMessageIdNamespace, id: processedMessageIdId)
        } else {
            self.processedSetupReplyMessageId = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        
        
        if let id = self.closedButtonKeyboardMessageId {
            try container.encode(id.peerId.toInt64(), forKey: "cb.p")
            try container.encode(id.namespace, forKey: "cb.n")
            try container.encode(id.id, forKey: "cb.i")
        } else {
            try container.encodeNil(forKey: "cb.p")
            try container.encodeNil(forKey: "cb.n")
            try container.encodeNil(forKey: "cb.i")
        }

        if let processedSetupReplyMessageId = self.processedSetupReplyMessageId {
            try container.encode(processedSetupReplyMessageId.peerId.toInt64(), forKey: "pb.p")
            try container.encode(processedSetupReplyMessageId.namespace, forKey: "pb.n")
            try container.encode(processedSetupReplyMessageId.id, forKey: "pb.i")
        } else {
            try container.encodeNil(forKey: "pb.p")
            try container.encodeNil(forKey: "pb.n")
            try container.encodeNil(forKey: "pb.i")
        }
    }


    func withUpdatedClosedButtonKeyboardMessageId(_ closedButtonKeyboardMessageId: MessageId?) -> ChatInterfaceMessageActionsState {
        return ChatInterfaceMessageActionsState(closedButtonKeyboardMessageId: closedButtonKeyboardMessageId, processedSetupReplyMessageId: self.processedSetupReplyMessageId)
    }

    func withUpdatedProcessedSetupReplyMessageId(_ processedSetupReplyMessageId: MessageId?) -> ChatInterfaceMessageActionsState {
        return ChatInterfaceMessageActionsState(closedButtonKeyboardMessageId: self.closedButtonKeyboardMessageId, processedSetupReplyMessageId: processedSetupReplyMessageId)
    }
}


final class ChatEmbeddedInterfaceState {
    let timestamp: Int32
    let text: String

    init(timestamp: Int32, text: String) {
        self.timestamp = timestamp
        self.text = text
    }

    init(decoder: PostboxDecoder) {
        self.timestamp = decoder.decodeInt32ForKey("d", orElse: 0)
        self.text = decoder.decodeStringForKey("t", orElse: "")
    }

    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.timestamp, forKey: "d")
        encoder.encodeString(self.text, forKey: "t")
    }

    public func isEqual(to: ChatEmbeddedInterfaceState) -> Bool {
        return self.timestamp == to.timestamp && self.text == to.text
    }
}

struct ChatInterfaceHistoryScrollState: Codable, Equatable {
    let messageIndex: MessageIndex
    let relativeOffset: Double

    init(messageIndex: MessageIndex, relativeOffset: Double) {
        self.messageIndex = messageIndex
        self.relativeOffset = relativeOffset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        let peerId = PeerId(try container.decode(Int64.self, forKey: "m.p"))
        let namespace = try container.decode(Int32.self, forKey: "m.n")
        let id = try container.decode(Int32.self, forKey: "m.i")
        let messageId = MessageId(peerId: peerId, namespace: namespace, id: id)
        let timestamp = try container.decode(Int32.self, forKey: "m.t")
        
        self.messageIndex = MessageIndex(id: messageId, timestamp: timestamp)
        self.relativeOffset = try container.decode(Double.self, forKey: "ro")
    }

    func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: StringCodingKey.self)

        
        try container.encode(self.messageIndex.timestamp, forKey: "m.t")
        try container.encode(self.messageIndex.id.peerId.toInt64(), forKey: "m.p")
        try container.encode(self.messageIndex.id.namespace, forKey: "m.n")
        try container.encode(self.messageIndex.id.id, forKey: "m.i")
        try container.encode(self.relativeOffset, forKey: "ro")
    }

    static func ==(lhs: ChatInterfaceHistoryScrollState, rhs: ChatInterfaceHistoryScrollState) -> Bool {
        if lhs.messageIndex != rhs.messageIndex {
            return false
        }
        if !lhs.relativeOffset.isEqual(to: rhs.relativeOffset) {
            return false
        }
        return true
    }
}

enum EditStateLoading : Equatable {
    case none
    case loading
    case progress(Float)
}

final class ChatEditState : Equatable {
    let inputState:ChatTextInputState
    let originalMedia: Media?
    let message:Message
    let editMedia: RequestEditMessageMedia
    let loadingState: EditStateLoading
    let editedData: EditedImageData?
    let invertMedia: Bool
    let addedMedia: Bool

    init(message:Message, originalMedia: Media? = nil, state:ChatTextInputState? = nil, loadingState: EditStateLoading = .none, editMedia: RequestEditMessageMedia = .keep, editedData: EditedImageData? = nil, invertMedia: Bool? = nil, addedMedia: Bool = false) {
        self.message = message
        if originalMedia == nil {
            self.originalMedia = message.anyMedia
        } else {
            self.originalMedia = originalMedia
        }
        if let state = state {
            self.inputState = state
        } else {
            var attribute:TextEntitiesMessageAttribute?
            for attr in message.attributes {
                if let attr = attr as? TextEntitiesMessageAttribute {
                    attribute = attr
                }
            }
            var attributes:[ChatTextInputAttribute] = []
            if let attribute = attribute {
                attributes = chatTextAttributes(from: attribute)
            }
            
            let newText = ChatTextInputState(inputText:message.text, selectionRange: message.text.length ..< message.text.length, attributes: attributes).makeAttributeString(addPreAsBlock: true)

            self.inputState = .init(inputText: newText.string, selectionRange: newText.length ..< newText.length, attributes: chatTextAttributes(from: newText))

        }
        if let invertMedia {
            self.invertMedia = invertMedia
        } else {
            self.invertMedia = message.invertMedia
        }
        self.loadingState = loadingState
        self.editMedia = editMedia
        self.editedData = editedData
        self.addedMedia = addedMedia
    }

    var canEditMedia: Bool {
        return !message.media.isEmpty && (message.media[0] is TelegramMediaImage || message.media[0] is TelegramMediaFile) && message.pendingProcessingAttribute == nil
    }
    func withUpdatedMedia(_ media: Media) -> ChatEditState {
        return ChatEditState(message: self.message.withUpdatedMedia([media]).withUpdatedStableVersion(stableVersion: self.message.stableVersion + 1), originalMedia: self.originalMedia ?? self.message.anyMedia, state: self.inputState, loadingState: loadingState, editMedia: .update(AnyMediaReference.standalone(media: media)), editedData: self.editedData, invertMedia: self.invertMedia, addedMedia: self.message.media.isEmpty || self.addedMedia)
    }
    func withUpdatedLoadingState(_ loadingState: EditStateLoading) -> ChatEditState {
        return ChatEditState(message: self.message, originalMedia: self.originalMedia, state: self.inputState, loadingState: loadingState, editMedia: self.editMedia, editedData: self.editedData, invertMedia: self.invertMedia, addedMedia: self.addedMedia)
    }
    func withUpdated(state:ChatTextInputState) -> ChatEditState {
        return ChatEditState(message: self.message, originalMedia: self.originalMedia, state: state, loadingState: loadingState, editMedia: self.editMedia, editedData: self.editedData, invertMedia: self.invertMedia, addedMedia: self.addedMedia)
    }

    func withUpdatedEditedData(_ editedData: EditedImageData?) -> ChatEditState {
        return ChatEditState(message: self.message, originalMedia: self.originalMedia, state: self.inputState, loadingState: self.loadingState, editMedia: self.editMedia, editedData: editedData, invertMedia: self.invertMedia, addedMedia: self.addedMedia)
    }
    func withUpdatedInvertMedia(_ invertMedia: Bool) -> ChatEditState {
        return ChatEditState(message: self.message, originalMedia: self.originalMedia, state: self.inputState, loadingState: self.loadingState, editMedia: self.editMedia, editedData: self.editedData, invertMedia: invertMedia, addedMedia: self.addedMedia)
    }

    static func ==(lhs:ChatEditState, rhs:ChatEditState) -> Bool {
        return lhs.message.id == rhs.message.id && lhs.message.stableId == rhs.message.stableId && lhs.inputState == rhs.inputState && lhs.loadingState == rhs.loadingState && lhs.editMedia == rhs.editMedia && lhs.editedData == rhs.editedData && lhs.invertMedia == rhs.invertMedia && lhs.addedMedia == rhs.addedMedia
    }

}


struct ChatInterfaceTempState: Equatable {
    let editState: ChatEditState?
}


struct ChatInterfaceState: Codable, Equatable {
    
    struct ChannelSuggestPost: Equatable {
        
        enum Mode : Equatable {
            case new
            case suggest(MessageId)
            case edit(MessageId)
        }
        
        var amount: CurrencyAmount?
        var date: Int32?
        var mode: Mode
        
        var attribute: SuggestedPostMessageAttribute {
            return SuggestedPostMessageAttribute(amount: amount, timestamp: date, state: nil)
        }
    }
    
    
    static func == (lhs: ChatInterfaceState, rhs: ChatInterfaceState) -> Bool {
        return lhs.associatedMessageIds == rhs.associatedMessageIds && lhs.historyScrollMessageIndex == rhs.historyScrollMessageIndex && lhs.historyScrollState == rhs.historyScrollState && lhs.editState == rhs.editState && lhs.timestamp == rhs.timestamp && lhs.inputState == rhs.inputState && lhs.replyMessageId == rhs.replyMessageId && lhs.forwardMessageIds == rhs.forwardMessageIds && lhs.dismissedPinnedMessageId == rhs.dismissedPinnedMessageId && lhs.composeDisableUrlPreview == rhs.composeDisableUrlPreview && lhs.dismissedForceReplyId == rhs.dismissedForceReplyId && lhs.messageActionsState == rhs.messageActionsState && isEqualMessageList(lhs: lhs.forwardMessages, rhs: rhs.forwardMessages) && lhs.hideSendersName == rhs.hideSendersName && lhs.themeEditing == rhs.themeEditing && lhs.hideCaptions == rhs.hideCaptions && lhs.revealedSpoilers == rhs.revealedSpoilers && lhs.tempSenderName == rhs.tempSenderName && lhs.linkBelowMessage == rhs.linkBelowMessage && lhs.largeMedia == rhs.largeMedia && lhs.messageEffect == rhs.messageEffect && lhs.suggestPost == rhs.suggestPost
    }

    var associatedMessageIds: [MessageId] {
        return []
    }



    var historyScrollMessageIndex: MessageIndex? {
        return self.historyScrollState?.messageIndex
    }

    let historyScrollState: ChatInterfaceHistoryScrollState?
    let editState:ChatEditState?
    let timestamp: Int32
    let inputState: ChatTextInputState
    let replyMessageId: EngineMessageReplySubject?
    let replyMessage: Message?
    let themeEditing: Bool

    let forwardMessageIds: [MessageId]
    let hideSendersName: Bool
    let hideCaptions: Bool
    
    let suggestPost: ChannelSuggestPost?
    
    let linkBelowMessage: Bool
    let largeMedia: Bool?

    let tempSenderName: Bool?
    let forwardMessages: [Message]
    let dismissedPinnedMessageId:[MessageId]
    let composeDisableUrlPreview: String?
    let dismissedForceReplyId: MessageId?
    let revealedSpoilers:Set<MessageId>

    let messageActionsState: ChatInterfaceMessageActionsState
    let messageEffect: ChatInterfaceMessageEffect?
    
    static func parse(_ state: OpaqueChatInterfaceState?, peerId: PeerId?, context: AccountContext?) -> ChatInterfaceState? {
        guard let state = state else {
            return nil
        }
        guard let opaqueData = state.opaqueData else {
            return ChatInterfaceState().withUpdatedSynchronizeableInputState(state.synchronizeableInputState).updatedEditState({ _ in
                return context?.getChatInterfaceTempState(peerId)?.editState
            })
        }
        guard var decodedState = try? EngineDecoder.decode(ChatInterfaceState.self, from: opaqueData) else {
            return ChatInterfaceState().withUpdatedSynchronizeableInputState(state.synchronizeableInputState).updatedEditState({ _ in
                return context?.getChatInterfaceTempState(peerId)?.editState
            })
        }
        decodedState = decodedState
            .withUpdatedSynchronizeableInputState(state.synchronizeableInputState)
            .updatedEditState({ _ in
                return context?.getChatInterfaceTempState(peerId)?.editState
            })
        return decodedState

    }

    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.timestamp, forKey: "ts")
        try container.encode(self.inputState, forKey: "is")
        if let reply = self.replyMessageId {
            try container.encode(reply, forKey: "reply")
        }

        try container.encode(EngineMessage.Id.encodeArrayToData(self.forwardMessageIds), forKey: "fm")
        try container.encode(self.hideCaptions, forKey: "f.hc")
        try container.encode(self.hideSendersName, forKey: "f.sn")


        if self.messageActionsState.isEmpty {
            try container.encodeNil(forKey: "as")
        } else {
            try container.encode(self.messageActionsState, forKey: "as")
        }

        try container.encode(EngineMessage.Id.encodeArrayToData(dismissedPinnedMessageId), forKey: "dpl")


        if let composeDisableUrlPreview = self.composeDisableUrlPreview {
            try container.encode(composeDisableUrlPreview, forKey: "dup")
        } else {
            try container.encodeNil(forKey: "dup")
        }

        if let historyScrollState = self.historyScrollState {
            try container.encode(historyScrollState, forKey: "hss")
        } else {
            try container.encodeNil(forKey: "hss")
        }

        if let dismissedForceReplyId = self.dismissedForceReplyId {
            try container.encode(dismissedForceReplyId, forKey: "dismissed_force_reply")
        }
        
        if let messageEffect {
            try container.encode(messageEffect, forKey: "me")
        }
    }
    

    var synchronizeableInputState: SynchronizeableChatInputState? {
        if self.inputState.inputText.isEmpty && self.replyMessageId == nil {
            return nil
        } else {
            return SynchronizeableChatInputState(replySubject: self.replyMessageId, text: self.inputState.inputText, entities: self.inputState.messageTextEntities(), timestamp: self.timestamp, textSelection: self.inputState.selectionRange, messageEffectId: self.messageEffect?.effect.id, suggestedPost: self.suggestPost.flatMap { value in
                switch value.mode {
                case .new:
                    return .init(price: value.amount, timestamp: value.date)
                default:
                    return nil
                }
            })
        }
    }

    func withUpdatedSynchronizeableInputState(_ state: SynchronizeableChatInputState?) -> ChatInterfaceState {
        var result = self
        if let state = state {
            let selectRange = state.textSelection ?? state.text.length ..< state.text.length
            result = result.withUpdatedInputState(ChatTextInputState(inputText: state.text, selectionRange: selectRange, attributes: chatTextAttributes(from: TextEntitiesMessageAttribute(entities: state.entities))))
                .withUpdatedReplyMessageId(state.replySubject)
                .withUpdatedTimestamp(timestamp)
        } else {
            result = result.withUpdatedInputState(.init()).withUpdatedHistoryScrollState(self.historyScrollState)
        }
        return result
    }


    init() {
        self.timestamp = 0
        self.inputState = ChatTextInputState()
        self.replyMessageId = nil
        self.replyMessage = nil
        self.forwardMessageIds = []
        self.forwardMessages = []
        self.messageActionsState = ChatInterfaceMessageActionsState()
        self.dismissedPinnedMessageId = []
        self.composeDisableUrlPreview = nil
        self.historyScrollState = nil
        self.dismissedForceReplyId = nil
        self.editState = nil
        self.hideSendersName = false
        self.themeEditing = false
        self.hideCaptions = false
        self.tempSenderName = nil
        self.revealedSpoilers = Set()
        self.linkBelowMessage = true
        self.largeMedia = nil
        self.messageEffect = nil
        self.suggestPost = nil
    }

    init(timestamp: Int32, inputState: ChatTextInputState, replyMessageId: EngineMessageReplySubject?, replyMessage: Message?, forwardMessageIds: [MessageId], messageActionsState:ChatInterfaceMessageActionsState, dismissedPinnedMessageId: [MessageId], composeDisableUrlPreview: String?, historyScrollState: ChatInterfaceHistoryScrollState?, dismissedForceReplyId: MessageId?, editState: ChatEditState?, forwardMessages:[Message], hideSendersName: Bool, themeEditing: Bool, hideCaptions: Bool, revealedSpoilers: Set<MessageId>, tempSenderName: Bool?, linkBelowMessage: Bool, largeMedia: Bool?, messageEffect: ChatInterfaceMessageEffect?, suggestPost: ChannelSuggestPost?) {
        self.timestamp = timestamp
        self.inputState = inputState
        self.replyMessageId = replyMessageId
        self.forwardMessageIds = forwardMessageIds
        self.messageActionsState = messageActionsState
        self.dismissedPinnedMessageId = dismissedPinnedMessageId
        self.composeDisableUrlPreview = composeDisableUrlPreview
        self.historyScrollState = historyScrollState
        self.dismissedForceReplyId = dismissedForceReplyId
        self.editState = editState
        self.replyMessage = replyMessage
        self.forwardMessages = forwardMessages
        self.hideSendersName = hideSendersName
        self.themeEditing = themeEditing
        self.hideCaptions = hideCaptions
        self.revealedSpoilers = revealedSpoilers
        self.tempSenderName = tempSenderName
        self.linkBelowMessage = linkBelowMessage
        self.largeMedia = largeMedia
        self.messageEffect = messageEffect
        self.suggestPost = suggestPost
    }

    init(from decoder: Decoder) throws {
        
        let container = try decoder.container(keyedBy: StringCodingKey.self)


        
        self.timestamp = (try? container.decode(Int32.self, forKey: "ts")) ?? 0
        if let inputState = try? container.decode(ChatTextInputState.self, forKey: "is") {
            self.inputState = inputState
        } else {
            self.inputState = ChatTextInputState()
        }

        self.replyMessageId = try container.decodeIfPresent(EngineMessageReplySubject.self, forKey: "reply")

        if let forwardMessageIdsData = try container.decodeIfPresent(Data.self, forKey: "fm") {
            self.forwardMessageIds = EngineMessage.Id.decodeArrayFromData(forwardMessageIdsData)
        } else {
            self.forwardMessageIds = []
        }
        if let hideCaptions = try container.decodeIfPresent(Bool.self, forKey: "f.hc") {
            self.hideCaptions = hideCaptions
        } else {
            self.hideCaptions = false
        }
        if let hideSendersName = try container.decodeIfPresent(Bool.self, forKey: "f.sn") {
            self.hideSendersName = hideSendersName
        } else {
            self.hideSendersName = false
        }

        if let messageActionsState = try container.decodeIfPresent(ChatInterfaceMessageActionsState.self, forKey: "as") {
            self.messageActionsState = messageActionsState
        } else {
            self.messageActionsState = ChatInterfaceMessageActionsState()
        }


        if let dismissedPinnedData = try container.decodeIfPresent(Data.self, forKey: "dpl") {
            self.dismissedPinnedMessageId = EngineMessage.Id.decodeArrayFromData(dismissedPinnedData)
        } else {
            self.dismissedPinnedMessageId = []
        }

        self.composeDisableUrlPreview = try container.decodeIfPresent(String.self, forKey: "dup")
        

        self.historyScrollState = try container.decodeIfPresent(ChatInterfaceHistoryScrollState.self, forKey: "hss")


        self.dismissedForceReplyId = try container.decodeIfPresent(MessageId.self, forKey: "dismissed_force_reply")
        self.messageEffect = try container.decodeIfPresent(ChatInterfaceMessageEffect.self, forKey: "me")
        
        self.editState = nil
        self.replyMessage = nil
        self.forwardMessages = []
        self.themeEditing = false
        self.revealedSpoilers = Set()
        self.tempSenderName = nil
        self.linkBelowMessage = true
        self.largeMedia = nil
        self.suggestPost = nil
    }


    func withUpdatedInputState(_ inputState: ChatTextInputState) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.editState == nil ? inputState : self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState?.withUpdated(state: inputState), forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers, tempSenderName: self.tempSenderName,  linkBelowMessage: self.linkBelowMessage, largeMedia: self.largeMedia, messageEffect: self.messageEffect, suggestPost: self.suggestPost)
    }

    func withAddedDismissedPinnedIds(_ dismissedPinnedId: [MessageId]) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: (self.dismissedPinnedMessageId + dismissedPinnedId).uniqueElements, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers, tempSenderName: self.tempSenderName,  linkBelowMessage: self.linkBelowMessage, largeMedia: self.largeMedia, messageEffect: self.messageEffect, suggestPost: self.suggestPost)
    }

    func withUpdatedDismissedForceReplyId(_ dismissedId: MessageId?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: dismissedId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers, tempSenderName: self.tempSenderName,  linkBelowMessage: self.linkBelowMessage, largeMedia: self.largeMedia, messageEffect: self.messageEffect, suggestPost: self.suggestPost)
    }

    func updatedEditState(_ f:(ChatEditState?)->ChatEditState?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: f(self.editState), forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers, tempSenderName: self.tempSenderName,  linkBelowMessage: self.linkBelowMessage, largeMedia: self.largeMedia, messageEffect: self.messageEffect, suggestPost: self.suggestPost)
    }

    func withEditMessage(_ message:Message) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: ChatEditState(message: message), forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers, tempSenderName: self.tempSenderName,  linkBelowMessage: self.linkBelowMessage, largeMedia: self.largeMedia, messageEffect: self.messageEffect, suggestPost: self.suggestPost)
    }

    func withoutEditMessage() -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: nil, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers, tempSenderName: self.tempSenderName,  linkBelowMessage: self.linkBelowMessage, largeMedia: self.largeMedia, messageEffect: self.messageEffect, suggestPost: self.suggestPost)
    }

    func withUpdatedReplyMessageId(_ replyMessageId: EngineMessageReplySubject?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: replyMessageId, replyMessage: nil, forwardMessageIds: self.forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers, tempSenderName: self.tempSenderName,  linkBelowMessage: self.linkBelowMessage, largeMedia: self.largeMedia, messageEffect: self.messageEffect, suggestPost: self.suggestPost)
    }

    func withUpdatedReplyMessage(_ replyMessage: Message?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers, tempSenderName: self.tempSenderName,  linkBelowMessage: self.linkBelowMessage, largeMedia: self.largeMedia, messageEffect: self.messageEffect, suggestPost: self.suggestPost)
    }

    func withUpdatedForwardMessageIds(_ forwardMessageIds: [MessageId]) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: forwardMessageIds.isEmpty ? false : self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: forwardMessageIds.isEmpty ? false : self.hideCaptions, revealedSpoilers: self.revealedSpoilers, tempSenderName: self.tempSenderName,  linkBelowMessage: self.linkBelowMessage, largeMedia: self.largeMedia, messageEffect: self.messageEffect, suggestPost: self.suggestPost)
    }

    func withUpdatedForwardMessages(_ forwardMessages: [Message]) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: forwardMessages, hideSendersName: hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers, tempSenderName: self.tempSenderName,  linkBelowMessage: self.linkBelowMessage, largeMedia: self.largeMedia, messageEffect: self.messageEffect, suggestPost: self.suggestPost)
    }
    
   

    func withoutForwardMessages() -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: [], messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers, tempSenderName: self.tempSenderName,  linkBelowMessage: self.linkBelowMessage, largeMedia: self.largeMedia, messageEffect: self.messageEffect, suggestPost: self.suggestPost)
    }

    func withUpdatedTimestamp(_ timestamp: Int32) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers, tempSenderName: self.tempSenderName,  linkBelowMessage: self.linkBelowMessage, largeMedia: self.largeMedia, messageEffect: self.messageEffect, suggestPost: self.suggestPost)
    }


    func withUpdatedMessageActionsState(_ f: (ChatInterfaceMessageActionsState) -> ChatInterfaceMessageActionsState) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState:f(self.messageActionsState), dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers, tempSenderName: self.tempSenderName,  linkBelowMessage: self.linkBelowMessage, largeMedia: self.largeMedia, messageEffect: self.messageEffect, suggestPost: self.suggestPost)
    }

    func withUpdatedComposeDisableUrlPreview(_ disableUrlPreview: String?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState: self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: disableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers, tempSenderName: self.tempSenderName,  linkBelowMessage: self.linkBelowMessage, largeMedia: self.largeMedia, messageEffect: self.messageEffect, suggestPost: self.suggestPost)
    }

    func withUpdatedHistoryScrollState(_ historyScrollState: ChatInterfaceHistoryScrollState?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState: self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers, tempSenderName: self.tempSenderName,  linkBelowMessage: self.linkBelowMessage, largeMedia: self.largeMedia, messageEffect: self.messageEffect, suggestPost: self.suggestPost)
    }
    
    func withUpdatedThemeEditing(_ themeEditing: Bool) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState: self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers, tempSenderName: self.tempSenderName,  linkBelowMessage: self.linkBelowMessage, largeMedia: self.largeMedia, messageEffect: self.messageEffect, suggestPost: self.suggestPost)
    }
    
    func withRevealedSpoiler(_ messageId: MessageId) -> ChatInterfaceState {
        var set = self.revealedSpoilers
        set.insert(messageId)
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState: self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: set, tempSenderName: self.tempSenderName,  linkBelowMessage: self.linkBelowMessage, largeMedia: self.largeMedia, messageEffect: self.messageEffect, suggestPost: self.suggestPost)
    }

    func withUpdatedHideCaption(_ hideCaption: Bool) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState: self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: hideCaption, revealedSpoilers: self.revealedSpoilers, tempSenderName: self.tempSenderName,  linkBelowMessage: self.linkBelowMessage, largeMedia: self.largeMedia, messageEffect: self.messageEffect, suggestPost: self.suggestPost)
    }
    
    func withUpdatedHideSendersName(_ hideSendersName: Bool, saveTempValue: Bool) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers, tempSenderName: saveTempValue ? hideSendersName : self.tempSenderName, linkBelowMessage: self.linkBelowMessage, largeMedia: self.largeMedia, messageEffect: self.messageEffect, suggestPost: self.suggestPost)
    }
    
    func withUpdatedLinkBelowMessage(_ linkBelowMessage: Bool) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers, tempSenderName: self.tempSenderName, linkBelowMessage: linkBelowMessage, largeMedia: self.largeMedia, messageEffect: self.messageEffect, suggestPost: self.suggestPost)
    }
    
    func withUpdatedLargeMedia(_ largeMedia: Bool) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers, tempSenderName: self.tempSenderName, linkBelowMessage: self.linkBelowMessage, largeMedia: largeMedia, messageEffect: self.messageEffect, suggestPost: self.suggestPost)
    }
    
    func withUpdatedMessageEffect(_ messageEffect: ChatInterfaceMessageEffect?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers, tempSenderName: self.tempSenderName, linkBelowMessage: self.linkBelowMessage, largeMedia: self.largeMedia, messageEffect: messageEffect, suggestPost: self.suggestPost)
    }
    
    func withRemovedEffectRect() -> ChatInterfaceState {
        let messageEffect: ChatInterfaceMessageEffect?
        if let effect = self.messageEffect {
            messageEffect = .init(effect: effect.effect, fromRect: nil)
        } else {
            messageEffect = nil
        }
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers, tempSenderName: self.tempSenderName, linkBelowMessage: self.linkBelowMessage, largeMedia: self.largeMedia, messageEffect: messageEffect, suggestPost: self.suggestPost)
    }
    
    
    func withUpdatedSuggestPost(_ suggestPost: ChannelSuggestPost?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers, tempSenderName: self.tempSenderName, linkBelowMessage: self.linkBelowMessage, largeMedia: self.largeMedia, messageEffect: self.messageEffect, suggestPost: suggestPost)
    }
}
