
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

struct ChatTextFontAttributes: OptionSet {
    var rawValue: Int32 = 0

    static let bold = ChatTextFontAttributes(rawValue: 1 << 0)
    static let italic = ChatTextFontAttributes(rawValue: 1 << 1)
    static let monospace = ChatTextFontAttributes(rawValue: 1 << 2)
    static let blockQuote = ChatTextFontAttributes(rawValue: 1 << 3)
}



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

enum ChatTextInputAttribute : Equatable, Comparable, Codable {
    case bold(Range<Int>)
    case strikethrough(Range<Int>)
    case spoiler(Range<Int>)
    case underline(Range<Int>)
    case italic(Range<Int>)
    case pre(Range<Int>)
    case code(Range<Int>)
    case uid(Range<Int>, Int64)
    case url(Range<Int>, String)
    case animated(Range<Int>, String, Int64, TelegramMediaFile?, ItemCollectionId?, CGRect?)
    case emojiHolder(Range<Int>, Int64, CGRect, String)
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
            self = .pre(range)
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
            self = .animated(range, try container.decode(String.self, forKey: "id"), try container.decode(Int64.self, forKey: "fileId"), try container.decodeIfPresent(TelegramMediaFile.self, forKey: "file"), try container.decodeIfPresent(ItemCollectionId.self, forKey: "info"), nil)
        default:
            fatalError("input attribute not supported")
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
        case .emojiHolder:
            return 10
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
        case .pre:
            try container.encode(Int32(2), forKey: "_rawValue")
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
        case let .animated(_, id, fileId, file, info, _):
            try container.encode(Int32(9), forKey: "_rawValue")
            try container.encode(id, forKey: "id")
            try container.encode(fileId, forKey: "fileId")
            if let file = file {
                try container.encode(file, forKey: "file")
            }
            if let info = info {
                try container.encode(info, forKey: "info")
            }
        case .emojiHolder:
           break
        }
    }

}

extension ChatTextInputAttribute {
    var attribute:(String, Any, NSRange) {
        switch self {
        case let .bold(range):
            return (NSAttributedString.Key.font.rawValue, NSFont.bold(.text), NSMakeRange(range.lowerBound, range.upperBound - range.lowerBound))
        case let .strikethrough(range):
            return (NSAttributedString.Key.strikethroughStyle.rawValue, NSNumber(value: NSUnderlineStyle.single.rawValue), NSMakeRange(range.lowerBound, range.upperBound - range.lowerBound))
        case let .underline(range):
            return (NSAttributedString.Key.underlineStyle.rawValue, NSNumber(value: NSUnderlineStyle.single.rawValue), NSMakeRange(range.lowerBound, range.upperBound - range.lowerBound))
        case let .spoiler(range):
            let tag = TGInputTextTag(uniqueId: Int64(arc4random()), attachment: NSNumber(value: -1), attribute: TGInputTextAttribute(name: NSAttributedString.Key.foregroundColor.rawValue, value: theme.colors.text))
            return (TGSpoilerAttributeName, tag, NSMakeRange(range.lowerBound, range.upperBound - range.lowerBound))
        case let .italic(range):
            return (NSAttributedString.Key.font.rawValue, NSFontManager.shared.convert(.normal(.text), toHaveTrait: .italicFontMask), NSMakeRange(range.lowerBound, range.upperBound - range.lowerBound))
        case let .pre(range), let .code(range):
            return (NSAttributedString.Key.font.rawValue, NSFont.menlo(.text), NSMakeRange(range.lowerBound, range.upperBound - range.lowerBound))
        case let .uid(range, uid):
            let tag = TGInputTextTag(uniqueId: Int64(arc4random()), attachment: NSNumber(value: uid), attribute: TGInputTextAttribute(name: NSAttributedString.Key.foregroundColor.rawValue, value: theme.colors.link))
            return (TGCustomLinkAttributeName, tag, NSMakeRange(range.lowerBound, range.upperBound - range.lowerBound))
        case let .url(range, url):
            let tag = TGInputTextTag(uniqueId: Int64(arc4random()), attachment: url, attribute: TGInputTextAttribute(name: NSAttributedString.Key.foregroundColor.rawValue, value: theme.colors.link))
            return (TGCustomLinkAttributeName, tag, NSMakeRange(range.lowerBound, range.upperBound - range.lowerBound))
        case let .animated(range, id, fileId, file, info, fromRect):
            let tag = TGTextAttachment(identifier: "\(id)", fileId: fileId, file: file, text: "", info: info, from: fromRect ?? .zero)
            return (TGAnimatedEmojiAttributeName, tag, NSMakeRange(range.lowerBound, range.upperBound - range.lowerBound))
        case let .emojiHolder(range, id, fromRect, emoji):
            let tag = TGInputTextEmojiHolder(uniqueId: id, emoji: emoji, rect: fromRect, attribute: TGInputTextAttribute(name: NSAttributedString.Key.foregroundColor.rawValue, value: NSColor.clear))
            return (TGEmojiHolderAttributeName, tag, NSMakeRange(range.lowerBound, range.upperBound - range.lowerBound))
        }
    }

    var range:Range<Int> {
        switch self {
        case let .bold(range), let .italic(range), let .pre(range), let .code(range), let .strikethrough(range), let .spoiler(range), let .underline(range):
            return range
        case let .uid(range, _):
            return range
        case let .url(range, _):
            return range
        case let .animated(range, _, _, _, _, _):
            return range
        case let .emojiHolder(range, _, _, _):
            return range
        }
    }
    
    func updateRange(_ range: Range<Int>) -> ChatTextInputAttribute {
        switch self {
        case .bold:
            return .bold(range)
        case .italic:
            return .italic(range)
        case .pre:
            return .pre(range)
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
        case let .animated(_, id, fileId, file, info, fromRect):
            return .animated(range, id, fileId, file, info, fromRect)
        case let .emojiHolder(_, id, rect, emoji):
            return .emojiHolder(range, id, rect, emoji)
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
        case .Pre:
            inputAttributes.append(.pre(entity.range))
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
            inputAttributes.append(.animated(entity.range, "\(arc4random())", fileId, nil, nil, nil))
        default:
            break
        }
    }
    return inputAttributes
}

func chatTextAttributes(from attributed:NSAttributedString) -> [ChatTextInputAttribute] {

    var inputAttributes:[ChatTextInputAttribute] = []


    attributed.enumerateAttributes(in: attributed.range, options: []) { (keys, range, _) in
        for (key, value) in keys {
            if key == NSAttributedString.Key.underlineStyle {
                inputAttributes.append(.underline(range.location ..< range.location + range.length))
            } else if key == NSAttributedString.Key.strikethroughStyle {
                inputAttributes.append(.strikethrough(range.location ..< range.location + range.length))
            } else if let font = value as? NSFont {
                let descriptor = font.fontDescriptor
                let symTraits = descriptor.symbolicTraits
                let traitSet = NSFontTraitMask(rawValue: UInt(symTraits.rawValue))
                let isBold = traitSet.contains(.boldFontMask)
                let isItalic = traitSet.contains(.italicFontMask)
                let isMonospace = font.fontName == "Menlo-Regular"

                if isItalic {
                    inputAttributes.append(.italic(range.location ..< range.location + range.length))
                }
                if isBold {
                    inputAttributes.append(.bold(range.location ..< range.location + range.length))
                }
                if isMonospace {
                    inputAttributes.append(.code(range.location ..< range.location + range.length))
                }
            } else if let tag = value as? TGInputTextTag {
                if let uid = tag.attachment as? NSNumber {
                    if uid == -1 {
                        inputAttributes.append(.spoiler(range.location ..< range.location + range.length))
                    } else {
                        inputAttributes.append(.uid(range.location ..< range.location + range.length, uid.int64Value))
                    }
                } else if let url = tag.attachment as? String {
                    inputAttributes.append(.url(range.location ..< range.location + range.length, url))
                }
            } else if let attachment = value as? TGTextAttachment {
                if let fileId = attachment.fileId as? Int64 {
                    inputAttributes.append(.animated(range.location ..< range.location + range.length, attachment.identifier, fileId, attachment.file as? TelegramMediaFile, attachment.info as? ItemCollectionId, attachment.fromRect == .zero ? nil : attachment.fromRect))
                }
            } else if let attachment = value as? TGInputTextEmojiHolder {
                inputAttributes.append(.emojiHolder(range.location ..< range.location + range.length, attachment.uniqueId, attachment.rect, attachment.emoji))
            }
        }
    }

    var count: Int = 0
    var animatedCount: Int = 0
    var attrs:[ChatTextInputAttribute] = []
    for attr in inputAttributes {
        switch attr {
        case .emojiHolder:
            attrs.append(attr)
        case .animated:
            if animatedCount < 100 {
                attrs.append(attr)
            }
            animatedCount += 1
        default:
            if count < 100 {
                attrs.append(attr)
            }
            count += 1
        }
    }
    
    return attrs
}

//x/m
private let markdownRegexFormat = "(^|\\s|\\n)(````?)([\\s\\S]+?)(````?)([\\s\\n\\.,:?!;]|$)|(^|\\s)(`|\\*\\*|__|~~|\\|\\|)([^\\n]+?)\\7([\\s\\.,:?!;]|$)|@(\\d+)\\s*\\((.+?)\\)"


private let markdownRegex = try? NSRegularExpression(pattern: markdownRegexFormat, options: [.caseInsensitive, .anchorsMatchLines])

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
    
    var inlineMedia: [MediaId : Media] {
        var media:[MediaId : Media] = [:]
        for attribute in attributes {
            switch attribute {
            case .animated(_, _, let fileId, let file, _, _):
                if let file = file {
                    media[MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)] = file
                }
            default:
                break
            }
        }
        return media
    }
    var holdedEmojies: [(NSRange, Int64, NSRect, String)] {
        var values:[(NSRange, Int64, NSRect, String)] = []
        for attribute in attributes {
            switch attribute {
            case let .emojiHolder(range, id, rect, emoji):
                values.append((NSMakeRange(range.lowerBound, range.upperBound - range.lowerBound), id, rect, emoji))
            default:
                break
            }
        }
        return values
    }
    
    var upCollections: [ItemCollectionId] {
        var media:[ItemCollectionId] = []
        for attribute in attributes {
            switch attribute {
            case let .animated(_, _, _, _, info, _):
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
    
    func withRemovedHolder(_ id: Int64) -> ChatTextInputState {
        let attrs = self.attributes.filter { attr in
            switch attr {
            case .emojiHolder(_, id, _, _):
                return false
            default:
                return true
            }
        }
        return .init(inputText: self.inputText, selectionRange: self.selectionRange, attributes: attrs)
    }
    
    func isFirstAnimatedEmoji(_ string: String) -> Bool {
        for attribute in attributes {
            switch attribute {
            case let .animated(range, _, _, _, _, _):
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
            case let .animated(range, _, _, _, _, _):
                if range.lowerBound == r.lowerBound && range.upperBound == range.upperBound {
                    return true
                }
            default:
                break
            }
        }
        return false
    }
    func isEmojiHolder(at r: NSRange) -> Bool {
        for attribute in attributes {
            switch attribute {
            case let .emojiHolder(range, _, _, _):
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
            case let .animated(range, _, fileId, file, info, fromRect):
                if !isPremium && file?.isPremiumEmoji == true {
                    return nil
                }
                return .animated(range, "\(arc4random64())", fileId, file, info, fromRect)
            default:
                return attr
            }
        }
        return .init(inputText: self.inputText, selectionRange: self.selectionRange, attributes: attributes)
    }

    var attributedString:NSAttributedString {
        let string = NSMutableAttributedString()
        _ = string.append(string: inputText, color: theme.colors.text, font: .normal(theme.fontSize), coreText: false)


//        string.fixEmojiesFont(theme.fontSize)

        var fontAttributes: [NSRange: ChatTextFontAttributes] = [:]

        loop: for attribute in attributes {
            let attr = attribute.attribute

            inner: switch attribute {
            case .bold:
                if let fontAttribute = fontAttributes[attr.2] {
                    fontAttributes[attr.2] = fontAttribute.union(.bold)
                } else {
                    fontAttributes[attr.2] = .bold
                }
                continue loop
            case .italic:
                if let fontAttribute = fontAttributes[attr.2] {
                    fontAttributes[attr.2] = fontAttribute.union(.italic)
                } else {
                    fontAttributes[attr.2] = .italic
                }
                continue loop
            case .pre, .code:
                if let fontAttribute = fontAttributes[attr.2] {
                    fontAttributes[attr.2] = fontAttribute.union(.monospace)
                } else {
                    fontAttributes[attr.2] = .monospace
                }
                continue loop
            default:
                break inner
            }
            string.addAttribute(NSAttributedString.Key(rawValue: attr.0), value: attr.1, range: attr.2)
        }
        for (range, fontAttributes) in fontAttributes {
            var font: NSFont?
            if fontAttributes.contains(.blockQuote) {
                font = .menlo(theme.fontSize)
            } else if fontAttributes == [.bold, .italic] {
                font = .boldItalic(theme.fontSize)
            } else if fontAttributes == [.bold] {
                font = .bold(theme.fontSize)
            } else if fontAttributes == [.italic] {
                font = .italic(theme.fontSize)
            }else if fontAttributes == [.monospace] {
                font = .menlo(theme.fontSize)
            }
            if let font = font {
                string.addAttribute(.font, value: font, range: range)
            }
        }
        return string.copy() as! NSAttributedString
    }

    func makeAttributeString(addPreAsBlock: Bool = false) -> NSAttributedString {
        let string = NSMutableAttributedString()
        _ = string.append(string: inputText, color: theme.colors.text, font: .normal(theme.fontSize), coreText: false)
        var pres:[Range<Int>] = []

        for attribute in attributes {
            let attr = attribute.attribute

            switch attribute {
            case let .pre(range):
                if addPreAsBlock {
                    pres.append(range)
                } else {
                    string.addAttribute(NSAttributedString.Key(rawValue: attr.0), value: attr.1, range: attr.2)
                }
            case let .strikethrough(range):
                string.addAttribute(NSAttributedString.Key(rawValue: attr.0), value: attr.1, range: attr.2)
            default:
                string.addAttribute(NSAttributedString.Key(rawValue: attr.0), value: attr.1, range: attr.2)
            }
        }
        if addPreAsBlock {
            var offset: Int = 0
            for pre in pres.sorted(by: { $0.lowerBound < $1.lowerBound }) {
                let symbols = "```"
                string.insert(.initialize(string: symbols, color: theme.colors.text, font: .normal(theme.fontSize), coreText: false), at: pre.lowerBound + offset)
                offset += symbols.count
                string.insert(.initialize(string: symbols, color: theme.colors.text, font: .normal(theme.fontSize), coreText: false), at: pre.upperBound + offset)
                offset += symbols.count
            }
        }

        return string.copy() as! NSAttributedString
    }


    func subInputState(from range: NSRange) -> ChatTextInputState {

        var subText = attributedString.attributedSubstring(from: range).trimmed

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
                        let text = raw.nsstring.substring(with: pre)

                        rawOffset -= match.range(at: 2).length + match.range(at: 4).length
                        newText.append(raw.nsstring.substring(with: match.range(at: 1)) + text + raw.nsstring.substring(with: match.range(at: 5)))
                        attributes.append(.pre(matchIndex + match.range(at: 1).length ..< matchIndex + match.range(at: 1).length + text.length))
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
                case .pre:
                    attributes.append(.pre(newRange.min ..< newRange.max))
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
                case let .animated(_, id, fileId, file, info, fromRect):
                    attributes.append(.animated(newRange.min ..< newRange.max, id, fileId, file, info, fromRect))
                case let .emojiHolder(_, id, rect, emoji):
                    attributes.append(.emojiHolder(newRange.min ..< newRange.max, id, rect, emoji))
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
                let updated: ChatTextInputAttribute
                updated = attr.updateRange(attr.range.lowerBound ..< max(attr.range.upperBound - symbolLength, attr.range.lowerBound))
                attributes[i] = updated
            }
        }
    
        
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
            case let .pre(range):
                entities.append(.init(range: range, type: .Pre))
            case let .code(range):
                entities.append(.init(range: range, type: .Code))
            case let .uid(range, uid):
                entities.append(.init(range: range, type: .TextMention(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(uid)))))
            case let .url(range, url):
                entities.append(.init(range: range, type: .TextUrl(url: url)))
            case let .animated(range, _, fileId, _, _, _):
                entities.append(.init(range: range, type: .CustomEmoji(stickerPack: nil, fileId: fileId)))
            case .emojiHolder:
                break sw
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

    init(message:Message, originalMedia: Media? = nil, state:ChatTextInputState? = nil, loadingState: EditStateLoading = .none, editMedia: RequestEditMessageMedia = .keep, editedData: EditedImageData? = nil) {
        self.message = message
        if originalMedia == nil {
            self.originalMedia = message.effectiveMedia
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
            let temporaryState = ChatTextInputState(inputText:message.text, selectionRange: 0 ..< 0, attributes: attributes)


            let newText = temporaryState.makeAttributeString(addPreAsBlock: true)

            self.inputState = ChatTextInputState(inputText: newText.string, selectionRange: newText.string.length ..< newText.string.length, attributes: chatTextAttributes(from: newText))

        }
        self.loadingState = loadingState
        self.editMedia = editMedia
        self.editedData = editedData
    }

    var canEditMedia: Bool {
        return !message.media.isEmpty && (message.media[0] is TelegramMediaImage || message.media[0] is TelegramMediaFile)
    }
    func withUpdatedMedia(_ media: Media) -> ChatEditState {

        return ChatEditState(message: self.message.withUpdatedMedia([media]), originalMedia: self.originalMedia ?? self.message.effectiveMedia, state: self.inputState, loadingState: loadingState, editMedia: .update(AnyMediaReference.standalone(media: media)), editedData: self.editedData)
    }
    func withUpdatedLoadingState(_ loadingState: EditStateLoading) -> ChatEditState {
        return ChatEditState(message: self.message, originalMedia: self.originalMedia, state: self.inputState, loadingState: loadingState, editMedia: self.editMedia, editedData: self.editedData)
    }
    func withUpdated(state:ChatTextInputState) -> ChatEditState {
        return ChatEditState(message: self.message, originalMedia: self.originalMedia, state: state, loadingState: loadingState, editMedia: self.editMedia, editedData: self.editedData)
    }

    func withUpdatedEditedData(_ editedData: EditedImageData?) -> ChatEditState {
        return ChatEditState(message: self.message, originalMedia: self.originalMedia, state: self.inputState, loadingState: self.loadingState, editMedia: self.editMedia, editedData: editedData)
    }

    static func ==(lhs:ChatEditState, rhs:ChatEditState) -> Bool {
        return lhs.message.id == rhs.message.id && lhs.inputState == rhs.inputState && lhs.loadingState == rhs.loadingState && lhs.editMedia == rhs.editMedia && lhs.editedData == rhs.editedData
    }

}


struct ChatInterfaceTempState: Equatable {
    let editState: ChatEditState?
}


struct ChatInterfaceState: Codable, Equatable {
    static func == (lhs: ChatInterfaceState, rhs: ChatInterfaceState) -> Bool {
        return lhs.associatedMessageIds == rhs.associatedMessageIds && lhs.historyScrollMessageIndex == rhs.historyScrollMessageIndex && lhs.historyScrollState == rhs.historyScrollState && lhs.editState == rhs.editState && lhs.timestamp == rhs.timestamp && lhs.inputState == rhs.inputState && lhs.replyMessageId == rhs.replyMessageId && lhs.forwardMessageIds == rhs.forwardMessageIds && lhs.dismissedPinnedMessageId == rhs.dismissedPinnedMessageId && lhs.composeDisableUrlPreview == rhs.composeDisableUrlPreview && lhs.dismissedForceReplyId == rhs.dismissedForceReplyId && lhs.messageActionsState == rhs.messageActionsState && isEqualMessageList(lhs: lhs.forwardMessages, rhs: rhs.forwardMessages) && lhs.hideSendersName == rhs.hideSendersName && lhs.themeEditing == rhs.themeEditing && lhs.hideCaptions == rhs.hideCaptions && lhs.revealedSpoilers == rhs.revealedSpoilers
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
    let replyMessageId: MessageId?
    let replyMessage: Message?
    let themeEditing: Bool

    let forwardMessageIds: [MessageId]
    let hideSendersName: Bool
    let hideCaptions: Bool
    let forwardMessages: [Message]
    let dismissedPinnedMessageId:[MessageId]
    let composeDisableUrlPreview: String?
    let dismissedForceReplyId: MessageId?
    let revealedSpoilers:Set<MessageId>

    let messageActionsState: ChatInterfaceMessageActionsState
    
    
    static func parse(_ state: OpaqueChatInterfaceState?, peerId: PeerId?, context: AccountContext?) -> ChatInterfaceState? {
        guard let state = state else {
            return nil
        }

        guard let opaqueData = state.opaqueData else {
            return ChatInterfaceState().withUpdatedSynchronizeableInputState(state.synchronizeableInputState)
        }
        guard var decodedState = try? EngineDecoder.decode(ChatInterfaceState.self, from: opaqueData) else {
            return ChatInterfaceState().withUpdatedSynchronizeableInputState(state.synchronizeableInputState)
        }
        decodedState = decodedState.withUpdatedSynchronizeableInputState(state.synchronizeableInputState)
        return decodedState
    }

    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.timestamp, forKey: "ts")
        try container.encode(self.inputState, forKey: "is")
        if let replyMessageId = self.replyMessageId {
            try container.encode(replyMessageId.peerId.toInt64(), forKey: "r.p")
            try container.encode(replyMessageId.namespace, forKey: "r.n")
            try container.encode(replyMessageId.id, forKey: "r.i")
        } else {
            try container.encodeNil(forKey: "r.p")
            try container.encodeNil(forKey: "r.n")
            try container.encodeNil(forKey: "r.i")
        }

        try container.encode(EngineMessage.Id.encodeArrayToData(forwardMessageIds), forKey: "fm")


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
            try container.encode(dismissedForceReplyId.peerId.toInt64(), forKey: "d.f.p")
            try container.encode(dismissedForceReplyId.namespace, forKey: "d.f.n")
            try container.encode(dismissedForceReplyId.id, forKey: "d.f.i")
        } else {
            try container.encodeNil(forKey: "d.f.p")
            try container.encodeNil(forKey: "d.f.n")
            try container.encodeNil(forKey: "d.f.i")
        }
        
//        try container.encode(self.hideSendersName, forKey: "h.s.n")
//        try container.encode(self.hideCaptions, forKey: "h.c")

    }
    

    var synchronizeableInputState: SynchronizeableChatInputState? {
        if self.inputState.inputText.isEmpty && self.replyMessageId == nil {
            return nil
        } else {
            return SynchronizeableChatInputState(replyToMessageId: self.replyMessageId, text: self.inputState.inputText, entities: self.inputState.messageTextEntities(), timestamp: self.timestamp, textSelection: self.inputState.selectionRange)
        }
    }

    func withUpdatedSynchronizeableInputState(_ state: SynchronizeableChatInputState?) -> ChatInterfaceState {
        var result = self
        if let state = state {
            if !state.entities.isEmpty {
                var bp = 0
                bp += 1
            } else {
                var bp = 0
                bp += 1
            }
            let selectRange = state.textSelection ?? state.text.length ..< state.text.length
            result = result.withUpdatedInputState(ChatTextInputState(inputText: state.text, selectionRange: selectRange, attributes: chatTextAttributes(from: TextEntitiesMessageAttribute(entities: state.entities))))
                .withUpdatedReplyMessageId(state.replyToMessageId)
                .withUpdatedTimestamp(timestamp)
        } else {
            return ChatInterfaceState().withUpdatedHistoryScrollState(self.historyScrollState)
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
        self.revealedSpoilers = Set()
    }

    init(timestamp: Int32, inputState: ChatTextInputState, replyMessageId: MessageId?, replyMessage: Message?, forwardMessageIds: [MessageId], messageActionsState:ChatInterfaceMessageActionsState, dismissedPinnedMessageId: [MessageId], composeDisableUrlPreview: String?, historyScrollState: ChatInterfaceHistoryScrollState?, dismissedForceReplyId: MessageId?, editState: ChatEditState?, forwardMessages:[Message], hideSendersName: Bool, themeEditing: Bool, hideCaptions: Bool, revealedSpoilers: Set<MessageId>) {
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
    }

    init(from decoder: Decoder) throws {
        
        let container = try decoder.container(keyedBy: StringCodingKey.self)


        
        self.timestamp = (try? container.decode(Int32.self, forKey: "ts")) ?? 0
        if let inputState = try? container.decode(ChatTextInputState.self, forKey: "is") {
            self.inputState = inputState
        } else {
            self.inputState = ChatTextInputState()
        }

        let replyMessageIdPeerId: Int64? = try container.decodeIfPresent(Int64.self, forKey: "r.p")
        let replyMessageIdNamespace: Int32? = try container.decodeIfPresent(Int32.self, forKey: "r.n")
        let replyMessageIdId: Int32? = try container.decodeIfPresent(Int32.self, forKey: "r.i")
        if let replyMessageIdPeerId = replyMessageIdPeerId, let replyMessageIdNamespace = replyMessageIdNamespace, let replyMessageIdId = replyMessageIdId {
            self.replyMessageId = EngineMessage.Id(peerId: EnginePeer.Id(replyMessageIdPeerId), namespace: replyMessageIdNamespace, id: replyMessageIdId)
        } else {
            self.replyMessageId = nil
        }

        if let forwardMessageIdsData = try container.decodeIfPresent(Data.self, forKey: "fm") {
            self.forwardMessageIds = EngineMessage.Id.decodeArrayFromData(forwardMessageIdsData)
        } else {
            self.forwardMessageIds = []
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


        let dismissedForceReplyIdPeerId: Int64? = try container.decodeIfPresent(Int64.self, forKey: "d.f.p")
        let dismissedForceReplyIdNamespace: Int32? = try container.decodeIfPresent(Int32.self, forKey: "d.f.n")
        let dismissedForceReplyIdId: Int32? = try container.decodeIfPresent(Int32.self, forKey: "d.f.i")
        if let dismissedForceReplyIdPeerId = dismissedForceReplyIdPeerId, let dismissedForceReplyIdNamespace = dismissedForceReplyIdNamespace, let dismissedForceReplyIdId = dismissedForceReplyIdId {
            self.dismissedForceReplyId = MessageId(peerId: PeerId(dismissedForceReplyIdPeerId), namespace: dismissedForceReplyIdNamespace, id: dismissedForceReplyIdId)
        } else {
            self.dismissedForceReplyId = nil
        }
        //TODO
        self.editState = nil
        self.replyMessage = nil
        self.forwardMessages = []
        self.hideSendersName = false
        self.themeEditing = false
        self.hideCaptions = false
        self.revealedSpoilers = Set()
    }


    func withUpdatedInputState(_ inputState: ChatTextInputState) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.editState == nil ? inputState : self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState?.withUpdated(state: inputState), forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers)
    }

    func withAddedDismissedPinnedIds(_ dismissedPinnedId: [MessageId]) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: (self.dismissedPinnedMessageId + dismissedPinnedId).uniqueElements, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers)
    }

    func withUpdatedDismissedForceReplyId(_ dismissedId: MessageId?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: dismissedId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers)
    }

    func updatedEditState(_ f:(ChatEditState?)->ChatEditState?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: f(self.editState), forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers)
    }

    func withEditMessage(_ message:Message) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: ChatEditState(message: message), forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers)
    }

    func withoutEditMessage() -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: nil, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers)
    }

    func withUpdatedReplyMessageId(_ replyMessageId: MessageId?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: replyMessageId, replyMessage: nil, forwardMessageIds: self.forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers)
    }

    func withUpdatedReplyMessage(_ replyMessage: Message?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers)
    }

    func withUpdatedForwardMessageIds(_ forwardMessageIds: [MessageId]) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers)
    }

    func withUpdatedForwardMessages(_ forwardMessages: [Message]) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: forwardMessages, hideSendersName: hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers)
    }
    
    func withUpdatedHideSendersName(_ hideSendersName: Bool) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers)
    }

    func withoutForwardMessages() -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: [], messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers)
    }

    func withUpdatedTimestamp(_ timestamp: Int32) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState:self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers)
    }


    func withUpdatedMessageActionsState(_ f: (ChatInterfaceMessageActionsState) -> ChatInterfaceMessageActionsState) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState:f(self.messageActionsState), dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers)
    }

    func withUpdatedComposeDisableUrlPreview(_ disableUrlPreview: String?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState: self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: disableUrlPreview, historyScrollState: self.historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers)
    }

    func withUpdatedHistoryScrollState(_ historyScrollState: ChatInterfaceHistoryScrollState?) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState: self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers)
    }
    
    func withUpdatedThemeEditing(_ themeEditing: Bool) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState: self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: self.revealedSpoilers)
    }
    
    func withRevealedSpoiler(_ messageId: MessageId) -> ChatInterfaceState {
        var set = self.revealedSpoilers
        set.insert(messageId)
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState: self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: self.hideCaptions, revealedSpoilers: set)
    }

    func withUpdatedHideCaption(_ hideCaption: Bool) -> ChatInterfaceState {
        return ChatInterfaceState(timestamp: self.timestamp, inputState: self.inputState, replyMessageId: self.replyMessageId, replyMessage: self.replyMessage, forwardMessageIds: self.forwardMessageIds, messageActionsState: self.messageActionsState, dismissedPinnedMessageId: self.dismissedPinnedMessageId, composeDisableUrlPreview: self.composeDisableUrlPreview, historyScrollState: historyScrollState, dismissedForceReplyId: self.dismissedForceReplyId, editState: self.editState, forwardMessages: self.forwardMessages, hideSendersName: self.hideSendersName, themeEditing: self.themeEditing, hideCaptions: hideCaption, revealedSpoilers: self.revealedSpoilers)
    }
    
}
