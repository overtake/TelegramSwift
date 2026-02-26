import Foundation
import AppKit
import Cocoa

private let controlStartCharactersSet = CharacterSet(charactersIn: "[")
private let controlCharactersSet = CharacterSet(charactersIn: "[]()*_-\\")

public final class MarkdownAttributeSet {
    public let font: NSFont
    public let textColor: NSColor
    public let additionalAttributes: [String: Any]
    
    public init(font: NSFont, textColor: NSColor, additionalAttributes: [String: Any] = [:]) {
        self.font = font
        self.textColor = textColor
        self.additionalAttributes = additionalAttributes
    }
}

public final class MarkdownAttributes {
    public let body: MarkdownAttributeSet
    public let bold: MarkdownAttributeSet
    public let link: MarkdownAttributeSet
    public let linkAttribute: (String) -> (String, Any)?
    
    public init(body: MarkdownAttributeSet, bold: MarkdownAttributeSet = MarkdownAttributeSet(font: .bold(.text), textColor: presentation.colors.grayText), link: MarkdownAttributeSet, linkAttribute: @escaping (String) -> (String, Any)?) {
        self.body = body
        self.link = link
        self.bold = bold
        self.linkAttribute = linkAttribute
    }
}

public func escapedPlaintextForMarkdown(_ string: String) -> String {
    let nsString = string as NSString
    var remainingRange = NSMakeRange(0, nsString.length)
    let result = NSMutableString()
    while true {
        let range = nsString.rangeOfCharacter(from: controlCharactersSet, options: [], range: remainingRange)
        if range.location != NSNotFound {
            result.append("\\")
            result.append(nsString.substring(with: NSMakeRange(range.location, range.length)))
            remainingRange = NSMakeRange(range.location + range.length, remainingRange.location + remainingRange.length - (range.location + range.length))
        } else {
            result.append(nsString.substring(with: NSMakeRange(remainingRange.location, remainingRange.length)))
            break
        }
    }
    return result as String
}

public func paragraphStyleWithAlignment(_ alignment: NSTextAlignment) -> NSParagraphStyle {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = alignment
    return paragraphStyle
}

public func parseMarkdownIntoAttributedString(_ string: String, attributes: MarkdownAttributes, textAlignment: NSTextAlignment = .natural) -> NSAttributedString {
    let nsString = string as NSString
    let result = NSMutableAttributedString()
    var remainingRange = NSMakeRange(0, nsString.length)
    
    var bodyAttributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: attributes.body.font, NSAttributedString.Key.foregroundColor: attributes.body.textColor, NSAttributedString.Key.paragraphStyle: paragraphStyleWithAlignment(textAlignment)]
    if !attributes.body.additionalAttributes.isEmpty {
        for (key, value) in attributes.body.additionalAttributes {
            bodyAttributes[NSAttributedString.Key(rawValue: key)] = value
        }
    }
    
    while true {
        let range = nsString.rangeOfCharacter(from: controlStartCharactersSet, options: [], range: remainingRange)
        if range.location != NSNotFound {
            if range.location != remainingRange.location {
                result.append(NSAttributedString(string: nsString.substring(with: NSMakeRange(remainingRange.location, range.location - remainingRange.location)), attributes: bodyAttributes))
                remainingRange = NSMakeRange(range.location, remainingRange.location + remainingRange.length - range.location)
            }
            
            let character = nsString.character(at: range.location)
            if character == UInt16(("[" as UnicodeScalar).value) {
                remainingRange = NSMakeRange(range.location + range.length, remainingRange.location + remainingRange.length - (range.location + range.length))
                if let (parsedLinkText, parsedLinkContents) = parseLink(string: nsString, remainingRange: &remainingRange) {
                    var linkAttributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: attributes.link.font, NSAttributedString.Key.foregroundColor: attributes.link.textColor, NSAttributedString.Key.paragraphStyle: paragraphStyleWithAlignment(textAlignment)]
                    if !attributes.body.additionalAttributes.isEmpty {
                        for (key, value) in attributes.link.additionalAttributes {
                            linkAttributes[NSAttributedString.Key(rawValue: key)] = value
                        }
                    }
                    if let (attributeName, attributeValue) = attributes.linkAttribute(parsedLinkContents) {
                        linkAttributes[NSAttributedString.Key(rawValue: attributeName)] = attributeValue
                    }
                    result.append(NSAttributedString(string: parsedLinkText, attributes: linkAttributes))
                }
            } else if character == UInt16(("*" as UnicodeScalar).value) {
                if range.location + 1 != remainingRange.length {
                    let nextCharacter = nsString.character(at: range.location + 1)
                    if nextCharacter == character {
                        remainingRange = NSMakeRange(range.location + range.length + 1, remainingRange.location + remainingRange.length - (range.location + range.length + 1))
                        
                        if let bold = parseBold(string: nsString, remainingRange: &remainingRange) {
                            var boldAttributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: attributes.bold.font, NSAttributedString.Key.foregroundColor: attributes.bold.textColor, NSAttributedString.Key.paragraphStyle: paragraphStyleWithAlignment(textAlignment)]
                            if !attributes.body.additionalAttributes.isEmpty {
                                for (key, value) in attributes.bold.additionalAttributes {
                                    boldAttributes[NSAttributedString.Key(rawValue: key)] = value
                                }
                            }
                            result.append(NSAttributedString(string: bold, attributes: boldAttributes))
                        } else {
                            result.append(NSAttributedString(string: nsString.substring(with: NSMakeRange(remainingRange.location, 1)), attributes: bodyAttributes))
                            remainingRange = NSMakeRange(range.location + 1, remainingRange.length - 1)
                        }
                    } else {
                        result.append(NSAttributedString(string: nsString.substring(with: NSMakeRange(remainingRange.location, 1)), attributes: bodyAttributes))
                        remainingRange = NSMakeRange(range.location + 1, remainingRange.length - 1)
                    }
                } else {
                    result.append(NSAttributedString(string: nsString.substring(with: NSMakeRange(remainingRange.location, 1)), attributes: bodyAttributes))
                    remainingRange = NSMakeRange(range.location + 1, remainingRange.length - 1)
                }
            }
        } else {
            if remainingRange.length != 0 {
                result.append(NSAttributedString(string: nsString.substring(with: NSMakeRange(remainingRange.location, remainingRange.length)), attributes: bodyAttributes))
            }
            break
        }
    }
    return result
}

private func parseLink(string: NSString, remainingRange: inout NSRange) -> (text: String, contents: String)? {
    var localRemainingRange = remainingRange
    let maxRange = NSMaxRange(remainingRange)

    // 1. Find unescaped closing square bracket ']'
    var closingSquareBraceIndex: Int?
    var i = localRemainingRange.location
    while i < maxRange {
        let char = string.character(at: i)
        if char == UInt16(("]" as UnicodeScalar).value),
           !(i > 0 && string.character(at: i - 1) == UInt16(("\\" as UnicodeScalar).value)) {
            closingSquareBraceIndex = i
            break
        }
        i += 1
    }
    guard let closeBracket = closingSquareBraceIndex else {
        return nil
    }

    // 2. Prepare to search for ( and )
    localRemainingRange = NSMakeRange(closeBracket + 1, maxRange - (closeBracket + 1))

    // 3. Check if the next character is unescaped '('
    guard localRemainingRange.length > 0,
          string.character(at: localRemainingRange.location) == UInt16(("(" as UnicodeScalar).value) else {
        return nil
    }

    // 4. Find unescaped closing parenthesis ')'
    var closingRoundBraceIndex: Int?
    i = localRemainingRange.location + 1
    while i < maxRange {
        let char = string.character(at: i)
        if char == UInt16((")" as UnicodeScalar).value),
           !(i > 0 && string.character(at: i - 1) == UInt16(("\\" as UnicodeScalar).value)) {
            closingRoundBraceIndex = i
            break
        }
        i += 1
    }
    guard let closeParen = closingRoundBraceIndex else {
        return nil
    }

    // 5. Extract text and contents
    let linkTextRange = NSRange(location: remainingRange.location, length: closeBracket - remainingRange.location)
    let linkContentRange = NSRange(location: localRemainingRange.location + 1, length: closeParen - (localRemainingRange.location + 1))

    let rawText = string.substring(with: linkTextRange)
    let rawContents = string.substring(with: linkContentRange)

    // 6. Unescape markdown
    func unescape(_ s: String) -> String {
        var result = ""
        var escape = false
        for c in s {
            if escape {
                result.append(c)
                escape = false
            } else if c == "\\" {
                escape = true
            } else {
                result.append(c)
            }
        }
        return result
    }

    // 7. Update remaining range
    remainingRange = NSMakeRange(closeParen + 1, maxRange - (closeParen + 1))

    return (unescape(rawText), unescape(rawContents))
}


private func parseBold(string: NSString, remainingRange: inout NSRange) -> String? {
    var localRemainingRange = remainingRange
    let closingRange = string.range(of: "**", options: [], range: localRemainingRange)
    if closingRange.location != NSNotFound {
        localRemainingRange = NSMakeRange(closingRange.location + closingRange.length, remainingRange.location + remainingRange.length - (closingRange.location + closingRange.length))
        
        let result = string.substring(with: NSRange(location: remainingRange.location, length: closingRange.location - remainingRange.location))
        remainingRange = localRemainingRange
        return result
    }
    return nil
}

