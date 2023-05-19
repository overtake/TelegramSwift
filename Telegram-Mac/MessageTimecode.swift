
import Foundation
import Cocoa
import TelegramCore




private let dataDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType([.link]).rawValue)
private let dataAndPhoneNumberDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType([.link, .phoneNumber]).rawValue)
private let phoneNumberDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType([.phoneNumber]).rawValue)
private let validHashtagSet: CharacterSet = {
    var set = CharacterSet.alphanumerics
    set.insert("_")
    return set
}()
private let validIdentifierSet: CharacterSet = {
    var set = CharacterSet(charactersIn: "a".unicodeScalars.first! ... "z".unicodeScalars.first!)
    set.insert(charactersIn: "A".unicodeScalars.first! ... "Z".unicodeScalars.first!)
    set.insert(charactersIn: "0".unicodeScalars.first! ... "9".unicodeScalars.first!)
    set.insert("_")
    return set
}()
private let identifierDelimiterSet: CharacterSet = {
    var set = CharacterSet.punctuationCharacters
    set.formUnion(CharacterSet.whitespacesAndNewlines)
    return set
}()
private let externalIdentifierDelimiterSet: CharacterSet = {
    var set = CharacterSet.punctuationCharacters
    set.formUnion(CharacterSet.whitespacesAndNewlines)
    set.remove(".")
    return set
}()
private let timecodeDelimiterSet: CharacterSet = {
    var set = CharacterSet.punctuationCharacters
    set.formUnion(CharacterSet.whitespacesAndNewlines)
    set.remove(":")
    return set
}()
private let validTimecodeSet: CharacterSet = {
    var set = CharacterSet(charactersIn: "0".unicodeScalars.first! ... "9".unicodeScalars.first!)
    set.insert(":")
    return set
}()

public struct ApplicationSpecificEntityType {
    public static let Timecode: Int32 = 1
}

private enum CurrentEntityType {
    case command
    case mention
    case hashtag
    case phoneNumber
    case timecode
    
    var type: EnabledEntityTypes {
        switch self {
        case .command:
            return .command
        case .mention:
            return .mention
        case .hashtag:
            return .hashtag
        case .phoneNumber:
            return .phoneNumber
        case .timecode:
            return .timecode
        }
    }
}

public struct EnabledEntityTypes: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let command = EnabledEntityTypes(rawValue: 1 << 0)
    public static let mention = EnabledEntityTypes(rawValue: 1 << 1)
    public static let hashtag = EnabledEntityTypes(rawValue: 1 << 2)
    public static let url = EnabledEntityTypes(rawValue: 1 << 3)
    public static let phoneNumber = EnabledEntityTypes(rawValue: 1 << 4)
    public static let timecode = EnabledEntityTypes(rawValue: 1 << 5)
    public static let external = EnabledEntityTypes(rawValue: 1 << 6)
    
    public static let all: EnabledEntityTypes = [.command, .mention, .hashtag, .url, .phoneNumber]
}

private func commitEntity(_ utf16: String.UTF16View, _ type: CurrentEntityType, _ range: Range<String.UTF16View.Index>, _ enabledTypes: EnabledEntityTypes, _ entities: inout [MessageTextEntity], mediaDuration: Double? = nil) {
    if !enabledTypes.contains(type.type) {
        return
    }
    let indexRange: Range<Int> = utf16.distance(from: utf16.startIndex, to: range.lowerBound) ..< utf16.distance(from: utf16.startIndex, to: range.upperBound)
    var overlaps = false
    for entity in entities {
        if entity.range.overlaps(indexRange) {
            overlaps = true
            break
        }
    }
    if !overlaps {
        let entityType: MessageTextEntityType
        switch type {
        case .command:
            entityType = .BotCommand
        case .mention:
            entityType = .Mention
        case .hashtag:
            entityType = .Hashtag
        case .phoneNumber:
            entityType = .PhoneNumber
        case .timecode:
            entityType = .Custom(type: ApplicationSpecificEntityType.Timecode)
        }
        
        if case .timecode = type {
            if let mediaDuration = mediaDuration, let timecode = parseTimecodeString(String(utf16[range])), timecode <= mediaDuration {
                entities.append(MessageTextEntity(range: indexRange, type: entityType))
            }
        } else {
            entities.append(MessageTextEntity(range: indexRange, type: entityType))
        }
    }
}


public func generateTextEntities(_ text: String, enabledTypes: EnabledEntityTypes, currentEntities: [MessageTextEntity] = []) -> [MessageTextEntity] {
    var entities: [MessageTextEntity] = currentEntities
    
    let utf16 = text.utf16
    
    var detector: NSDataDetector?
    if enabledTypes.contains(.phoneNumber) && enabledTypes.contains(.url) {
        detector = dataAndPhoneNumberDetector
    } else if enabledTypes.contains(.phoneNumber) {
        detector = phoneNumberDetector
    } else if enabledTypes.contains(.url) {
        detector = dataDetector
    }
    
    let delimiterSet = enabledTypes.contains(.external) ? externalIdentifierDelimiterSet : identifierDelimiterSet
    
    if let detector = detector {
        detector.enumerateMatches(in: text, options: [], range: NSMakeRange(0, utf16.count), using: { result, _, _ in
            if let result = result {
                if result.resultType == NSTextCheckingResult.CheckingType.link || result.resultType == NSTextCheckingResult.CheckingType.phoneNumber {
                    let lowerBound = utf16.index(utf16.startIndex, offsetBy: result.range.location).samePosition(in: text)
                    let upperBound = utf16.index(utf16.startIndex, offsetBy: result.range.location + result.range.length).samePosition(in: text)
                    if let lowerBound = lowerBound, let upperBound = upperBound {
                        let type: MessageTextEntityType
                        if result.resultType == NSTextCheckingResult.CheckingType.link {
                            type = .Url
                        } else {
                            type = .PhoneNumber
                        }
                        entities.append(MessageTextEntity(range: utf16.distance(from: text.startIndex, to: lowerBound) ..< utf16.distance(from: text.startIndex, to: upperBound), type: type))
                    }
                }
            }
        })
    }
    
    var index = utf16.startIndex
    var currentEntity: (CurrentEntityType, Range<String.UTF16View.Index>)?
    
    var previousScalar: UnicodeScalar?
    while index != utf16.endIndex {
        let c = utf16[index]
        let scalar = UnicodeScalar(c)
        var notFound = true
        if let scalar = scalar {
            if scalar == "/" {
                notFound = false
                if previousScalar != nil && !delimiterSet.contains(previousScalar!) {
                    currentEntity = nil
                } else {
                    if let (type, range) = currentEntity {
                        commitEntity(utf16, type, range, enabledTypes, &entities)
                    }
                    currentEntity = (.command, index ..< index)
                }
            } else if scalar == "@" {
                notFound = false
                if let (type, range) = currentEntity {
                    if case .command = type {
                        currentEntity = (type, range.lowerBound ..< utf16.index(after: index))
                    } else {
                        commitEntity(utf16, type, range, enabledTypes, &entities)
                        currentEntity = (.mention, index ..< index)
                    }
                } else {
                    currentEntity = (.mention, index ..< index)
                }
            } else if scalar == "#" {
                notFound = false
                if let (type, range) = currentEntity {
                    commitEntity(utf16, type, range, enabledTypes, &entities)
                }
                currentEntity = (.hashtag, index ..< index)
            }
            
            if notFound {
                if let (type, range) = currentEntity {
                    switch type {
                    case .command, .mention:
                        if validIdentifierSet.contains(scalar) {
                            currentEntity = (type, range.lowerBound ..< utf16.index(after: index))
                        } else if delimiterSet.contains(scalar) {
                            if let (type, range) = currentEntity {
                                commitEntity(utf16, type, range, enabledTypes, &entities)
                            }
                            currentEntity = nil
                        }
                    case .hashtag:
                        if validHashtagSet.contains(scalar) {
                            currentEntity = (type, range.lowerBound ..< utf16.index(after: index))
                        } else if delimiterSet.contains(scalar) {
                            if let (type, range) = currentEntity {
                                commitEntity(utf16, type, range, enabledTypes, &entities)
                            }
                            currentEntity = nil
                        }
                    default:
                        break
                    }
                }
            }
        }
        index = utf16.index(after: index)
        previousScalar = scalar
    }
    if let (type, range) = currentEntity {
        commitEntity(utf16, type, range, enabledTypes, &entities)
    }
    
    return entities
}

public func addLocallyGeneratedEntities(_ text: String, enabledTypes: EnabledEntityTypes, entities: [MessageTextEntity], mediaDuration: Double? = nil) -> [MessageTextEntity]? {
    var resultEntities = entities
    
    var hasDigits = false
    var hasColons = false
    
    let detectPhoneNumbers = enabledTypes.contains(.phoneNumber)
    let detectTimecodes = enabledTypes.contains(.timecode)
    if detectPhoneNumbers || detectTimecodes {
        loop: for c in text.utf16 {
            if let scalar = UnicodeScalar(c) {
                if scalar >= "0" && scalar <= "9" {
                    hasDigits = true
                    if !detectTimecodes || hasColons {
                        break loop
                    }
                } else if scalar == ":" {
                    hasColons = true
                    if hasDigits {
                        break loop
                    }
                }
            }
        }
    }
    
    if hasDigits {
        if let phoneNumberDetector = phoneNumberDetector, detectPhoneNumbers {
            let utf16 = text.utf16
            phoneNumberDetector.enumerateMatches(in: text, options: [], range: NSMakeRange(0, utf16.count), using: { result, _, _ in
                if let result = result {
                    if result.resultType == NSTextCheckingResult.CheckingType.phoneNumber {
                        let lowerBound = utf16.index(utf16.startIndex, offsetBy: result.range.location).samePosition(in: text)
                        let upperBound = utf16.index(utf16.startIndex, offsetBy: result.range.location + result.range.length).samePosition(in: text)
                        if let lowerBound = lowerBound, let upperBound = upperBound {
                            commitEntity(utf16, .phoneNumber, lowerBound ..< upperBound, enabledTypes, &resultEntities)
                        }
                    }
                }
            })
        }
        if hasColons && detectTimecodes {
            let utf16 = text.utf16
            let delimiterSet = timecodeDelimiterSet
            
            var index = utf16.startIndex
            var currentEntity: (CurrentEntityType, Range<String.UTF16View.Index>)?
            
            var previousScalar: UnicodeScalar?
            while index != utf16.endIndex {
                let c = utf16[index]
                let scalar = UnicodeScalar(c)
                var notFound = true
                if let scalar = scalar {
                    if validTimecodeSet.contains(scalar) {
                        notFound = false
                        if let (type, range) = currentEntity, type == .timecode {
                            currentEntity = (.timecode, range.lowerBound ..< utf16.index(after: index))
                        } else if previousScalar == nil || CharacterSet.whitespacesAndNewlines.contains(previousScalar!) {
                            currentEntity = (.timecode, index ..< index)
                        }
                    }
                    
                    if notFound {
                        if let (type, range) = currentEntity {
                            switch type {
                            case .timecode:
                                if delimiterSet.contains(scalar) {
                                    commitEntity(utf16, type, range, enabledTypes, &resultEntities, mediaDuration: mediaDuration)
                                    currentEntity = nil
                                }
                            default:
                                break
                            }
                        }
                    }
                }
                index = utf16.index(after: index)
                previousScalar = scalar
            }
            if let (type, range) = currentEntity {
                commitEntity(utf16, type, range, enabledTypes, &resultEntities, mediaDuration: mediaDuration)
            }
        }
    }
    
    if resultEntities.count != entities.count {
        return resultEntities
    } else {
        return nil
    }
}

public func parseTimecodeString(_ string: String?) -> Double? {
    if let string = string, string.rangeOfCharacter(from: validTimecodeSet.inverted) == nil {
        let components = string.components(separatedBy: ":")
        if components.count > 1 && components.count <= 3 {
            if components.count == 3 {
                if let hours = Int(components[0]), let minutes = Int(components[1]), let seconds = Int(components[2]) {
                    if hours >= 0 && hours < 48 && minutes >= 0 && minutes < 60 && seconds >= 0 && seconds < 60 {
                        return Double(seconds) + Double(minutes) * 60.0 + Double(hours) * 60.0 * 60.0
                    }
                }
            } else if components.count == 2 {
                if let minutes = Int(components[0]), let seconds = Int(components[1]) {
                    if minutes >= 0 && minutes < 60 && seconds >= 0 && seconds < 60 {
                        return Double(seconds) + Double(minutes) * 60.0
                    }
                }
            }
        }
    }
    return nil
}
