import Foundation
import CoreText

public extension String {
    
    var nsstring:NSString {
        return self as NSString
    }
    
    var length:Int {
        return self.nsstring.length
    }
}



public extension String {
    func prefix(_ by:Int) -> String {
        if let index = index(startIndex, offsetBy: by, limitedBy: endIndex) {
            return String(self[..<index])
        }
        return String(stringLiteral: self)
    }
    
    enum TruncationMode {
        case head
        case middle
        case tail
    }

    func prefixWithDots(_ length: Int, mode: TruncationMode = .tail) -> String {
        guard length >= 4 else {
            return String(self.prefix(length))
        }

        guard self.count > length else { return self }

        switch mode {
        case .head:
            let suffix = self.suffix(length - 3)
            return "...\(suffix)"
        case .middle:
            let prefixLength = (length - 3) / 2
            let suffixLength = (length - 3) - prefixLength
            let start = self.prefix(prefixLength)
            let end = self.suffix(suffixLength)
            return "\(start)...\(end)"
        case .tail:
            let prefix = self.prefix(length - 3)
            return "\(prefix)..."
        }
    }

    
    var transformKeyboard:[String] {
        let russianQwerty = "йцукенгшщзфывапролдячсмить".map { String($0) }
        let englishQwerty = "qwertyuiopasdfghjklzxcvbnm".map { String($0) }

        
        let value = self.lowercased()
        
        var russian: [String] = value.map { String($0) }
        var english: [String] = value.map { String($0) }
        
        for (i, char) in value.enumerated() {
            if let index = russianQwerty.firstIndex(of: String(char)) {
                english[i] = englishQwerty[index]
            }
        }
        return [english.joined()]
    }
    
    func fromSuffix(_ by:Int) -> String {
        if let index = index(startIndex, offsetBy: by, limitedBy: endIndex) {
            return String(self[index..<self.endIndex])
        }
        return String(stringLiteral: self)
    }
    
    static func durationTransformed(elapsed:Int) -> String {
        let h = elapsed / 3600
        let m = (elapsed / 60) % 60
        let s = elapsed % 60
        
        if h > 0 {
            return String.init(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String.init(format: "%02d:%02d", m, s)
        }
    }
    
    static func durationTransformed(elapsed: Double) -> String {
        let elapsed = Int(elapsed)
        let h = elapsed / 3600
        let m = (elapsed / 60) % 60
        let s = elapsed % 60
        
        if h > 0 {
            return String.init(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String.init(format: "%02d:%02d", m, s)
        }
    }
}


public extension String {
    var emojiSkinToneModifiers: [String] {
        return [ "🏻", "🏼", "🏽", "🏾", "🏿" ]
    }
    
    var emojiVisibleLength: Int {
        var count = 0
        enumerateSubstrings(in: startIndex..<endIndex, options: .byComposedCharacterSequences) { _,_,_,_  in
            count += 1
        }
        return count
    }
    
    var emojiUnmodified: String {
        var emoji = self
        for skin in emoji.emojiSkinToneModifiers {
            emoji = emoji.replacingOccurrences(of: skin, with: "")
        }
        emoji = String(emoji.unicodeScalars.filter {
            $0 != "\u{fe0f}"
        })
        return emoji
    }
    
    func emojiWithSkinModifier(_ modifier: String) -> String {
        var string = ""
        var installed: Bool = false
        for scalar in self.unicodeScalars {
            if scalar == UnicodeScalar.ZeroWidthJoiner {
                string.append(modifier)
                installed = true
            }
            string.unicodeScalars.append(scalar)
        }
        if !installed {
            string.append(modifier)
        }
        return string
    }
    
    var emojiSkin: String {
        if self.length < 2 {
            return ""
        }
        
        for modifier in emojiSkinToneModifiers {
            if let range = self.range(of: modifier) {
                return String(self[range])
            }
        }
        return ""
    }
    
    var basicEmoji: (String, String?) {
        let fitzCodes: [UInt32] = [
            0x1f3fb,
            0x1f3fc,
            0x1f3fd,
            0x1f3fe,
            0x1f3ff
        ]
        
        var string = ""
        var fitzModifier: String?
        for scalar in self.unicodeScalars {
            if fitzCodes.contains(scalar.value) {
                fitzModifier = String(scalar)
                continue
            }
            string.unicodeScalars.append(scalar)
            if scalar.value == 0x2764, self.unicodeScalars.count > 1, self.emojis.count == 1 {
                break
            }
        }
        return (string, fitzModifier)
    }
    

    
    var canHaveSkinToneModifier: Bool {
        if self.isEmpty {
            return false
        }
        
        
        let modified = self.basicEmoji.0.strippedEmoji + self.emojiSkinToneModifiers[0]
        if modified.glyphCount == 1 {
            return true
        }
        
        return self.emojiWithSkinModifier(self.emojiSkinToneModifiers[0]).glyphCount == 1
    }
    
    var glyphCount: Int {
        
        let richText = NSAttributedString(string: self)
        let line = CTLineCreateWithAttributedString(richText)
        return CTLineGetGlyphCount(line)
    }
    
    var isSingleEmoji: Bool {
        return glyphCount == 1 && containsEmoji
    }
    
    var containsEmoji: Bool {
        return unicodeScalars.first(where: { $0.isEmoji }) != nil
    }
    
    var containsOnlyEmoji: Bool {
        guard !self.isEmpty else {
            return false
        }
        var nextShouldBeVariationSelector = false
        for scalar in self.unicodeScalars {
            if nextShouldBeVariationSelector {
                if scalar == UnicodeScalar.VariationSelector {
                    nextShouldBeVariationSelector = false
                    continue
                } else {
                    return false
                }
            }
            if !scalar.isEmoji && scalar.maybeEmoji {
                nextShouldBeVariationSelector = true
            }
            else if !scalar.isEmoji && scalar != UnicodeScalar.ZeroWidthJoiner {
                return false
            }
        }
        return !nextShouldBeVariationSelector
    }
    

    var emojiString: String {
        
        return emojiScalars.map { String($0) }.reduce("", +)
    }
    
    var emojis: [String] {
        var emojis: [String] = []
        self.enumerateSubstrings(in: self.startIndex ..< self.endIndex, options: .byComposedCharacterSequences) { substring, _, _, _ in
            if let substring = substring, substring.isSingleEmoji {
                emojis.append(substring)
            }
        }
        return emojis
    }
    
    
    fileprivate var emojiScalars: [UnicodeScalar] {
        var chars: [UnicodeScalar] = []
        var previous: UnicodeScalar?
        for cur in unicodeScalars {
            if let previous = previous, previous != UnicodeScalar.ZeroWidthJoiner && previous != UnicodeScalar.VariationSelector, cur.isEmoji {
                chars.append(previous)
                chars.append(cur)
                
            } else if cur.isEmoji {
                chars.append(cur)
            }
            
            previous = cur
        }
        
        return chars
    }
    
    var normalizedEmoji: String {
        var string = ""
        
        var nextShouldBeVariationSelector = false
        for scalar in self.unicodeScalars {
            if nextShouldBeVariationSelector {
                if scalar != UnicodeScalar.VariationSelector {
                    string.unicodeScalars.append(UnicodeScalar.VariationSelector)
                }
                nextShouldBeVariationSelector = false
            }
            string.unicodeScalars.append(scalar)
            if !scalar.isEmoji && scalar.maybeEmoji {
                nextShouldBeVariationSelector = true
            }
        }
        
        if nextShouldBeVariationSelector {
            string.unicodeScalars.append(UnicodeScalar.VariationSelector)
        }
        
        return string
    }

    
    var strippedEmoji: (String) {
        var string = ""
        for scalar in self.unicodeScalars {
            if scalar.value != 0xfe0f {
                string.unicodeScalars.append(scalar)
            }
        }
        return string
    }

}

public extension UnicodeScalar {
    var isEmoji: Bool {
        
        if #available(macOS 10.12.2, *) {
            if self.properties.isEmoji && self.properties.isEmojiPresentation {
                return true
            }
        }
        
        
        switch self.value {
            case 0x1F600...0x1F64F, 0x1F300...0x1F5FF, 0x1F680...0x1F6FF, 0x1F1E6...0x1F1FF, 0xE0020...0xE007F, 0xFE00...0xFE0F, 0x1F900...0x1F9FF, 0x1F018...0x1F0F5, 0x1F200...0x1F270, 65024...65039, 9100...9300, 8400...8447, 0x1F004, 0x1F18E, 0x1F191...0x1F19A, 0x1F5E8, 0x1FA70...0x1FA73, 0x1FA78...0x1FA7A, 0x1FA80...0x1FA82, 0x1FA90...0x1FA95, 0x1F382, 0x1FAF1, 0x1FAF2:
                return true
            case 0x2603, 0x265F, 0x267E, 0x2692, 0x26C4, 0x26C8, 0x26CE, 0x26CF, 0x26D1...0x26D3, 0x26E9, 0x26F0...0x26F9, 0x2705, 0x270A, 0x270B, 0x2728, 0x274E, 0x2753...0x2755, 0x274C, 0x2795...0x2797, 0x27B0, 0x27BF:
                return true
            default:
                return false
        }
    }

    
    var maybeEmoji: Bool {
        switch self.value {
            case 0x2A, 0x23, 0x30...0x39, 0xA9, 0xAE:
                return true
            case 0x2600...0x26FF, 0x2700...0x27BF, 0x1F100...0x1F1FF:
                return true
            case 0x203C, 0x2049, 0x2122, 0x2194...0x2199, 0x21A9, 0x21AA, 0x2139, 0x2328, 0x231A, 0x231B, 0x24C2, 0x25AA, 0x25AB, 0x25B6, 0x25FB...0x25FE, 0x25C0, 0x2934, 0x2935, 0x2B05...0x2B07, 0x2B1B...0x2B1E, 0x2B50, 0x2B55, 0x3030, 0x3297, 0x3299:
                return true
            default:
                return false
        }
    }

    
    static var ZeroWidthJoiner = UnicodeScalar(0x200D)!
    static var VariationSelector = UnicodeScalar(0xFE0F)!
}


