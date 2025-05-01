import Foundation
import Cocoa

private class PathDataReader {
    private let input: String
    private var current: UnicodeScalar?
    private var previous: UnicodeScalar?
    private var iterator: String.UnicodeScalarView.Iterator

    private static let spaces: Set<UnicodeScalar> = Set("\n\r\t ,".unicodeScalars)

    init(input: String) {
        self.input = input
        self.iterator = input.unicodeScalars.makeIterator()
    }

    public func read() -> [PathSegment] {
        readNext()
        var segments = [PathSegment]()
        while let array = readSegments() {
            segments.append(contentsOf: array)
        }
        return segments
    }

    private func readSegments() -> [PathSegment]? {
        if let type = readSegmentType() {
            let argCount = getArgCount(segment: type)
            if argCount == 0 {
                return [PathSegment(type: type)]
            }
            var result = [PathSegment]()
            let data: [Double]
            if type == .a || type == .A {
                data = readDataOfASegment()
            } else {
                data = readData()
            }
            var index = 0
            var isFirstSegment = true
            while index < data.count {
                let end = index + argCount
                if end > data.count {
                    break
                }
                var currentType = type
                if type == .M && !isFirstSegment {
                    currentType = .L
                }
                if type == .m && !isFirstSegment {
                    currentType = .l
                }
                result.append(PathSegment(type: currentType, data: Array(data[index..<end])))
                isFirstSegment = false
                index = end
            }
            return result
        }
        return nil
    }

    private func readData() -> [Double] {
        var data = [Double]()
        while true {
            skipSpaces()
            if let value = readNum() {
                data.append(value)
            } else {
                return data
            }
        }
    }

    private func readDataOfASegment() -> [Double] {
        let argCount = getArgCount(segment: .A)
        var data: [Double] = []
        var index = 0
        while true {
            skipSpaces()
            let value: Double?
            let indexMod = index % argCount
            if indexMod == 3 || indexMod == 4 {
                value = readFlag()
            } else {
                value = readNum()
            }
            guard let doubleValue = value else {
                return data
            }
            data.append(doubleValue)
            index += 1
        }
        return data
    }

    private func skipSpaces() {
        var currentCharacter = current
        while let character = currentCharacter, Self.spaces.contains(character) {
            currentCharacter = readNext()
        }
    }

    private func readFlag() -> Double? {
        guard let ch = current else {
            return .none
        }
        readNext()
        switch ch {
        case "0":
            return 0
        case "1":
            return 1
        default:
            return .none
        }
    }

    fileprivate func readNum() -> Double? {
        guard let ch = current else {
            return .none
        }

        guard ch >= "0" && ch <= "9" || ch == "." || ch == "-" else {
            return .none
        }

        var chars = [ch]
        var hasDot = ch == "."
        while let ch = readDigit(&hasDot) {
            chars.append(ch)
        }

        var buf = ""
        buf.unicodeScalars.append(contentsOf: chars)
        guard let value = Double(buf) else {
            return .none
        }
        return value
    }

    fileprivate func readDigit(_ hasDot: inout Bool) -> UnicodeScalar? {
        if let ch = readNext() {
            if (ch >= "0" && ch <= "9") || ch == "e" || (previous == "e" && ch == "-") {
                return ch
            } else if ch == "." && !hasDot {
                hasDot = true
                return ch
            }
        }
        return nil
    }

    fileprivate func isNum(ch: UnicodeScalar, hasDot: inout Bool) -> Bool {
        switch ch {
        case "0"..."9":
            return true
        case ".":
            if hasDot {
                return false
            }
            hasDot = true
        default:
            return true
        }
        return false
    }

    @discardableResult
    private func readNext() -> UnicodeScalar? {
        previous = current
        current = iterator.next()
        return current
    }

    private func isAcceptableSeparator(_ ch: UnicodeScalar?) -> Bool {
        if let ch = ch {
            return "\n\r\t ,".contains(String(ch))
        }
        return false
    }

    private func readSegmentType() -> PathSegment.SegmentType? {
        while true {
            if let type = getPathSegmentType() {
                readNext()
                return type
            }
            if readNext() == nil {
                return nil
            }
        }
    }

    fileprivate func getPathSegmentType() -> PathSegment.SegmentType? {
        if let ch = current {
            switch ch {
            case "M":
                return .M
            case "m":
                return .m
            case "L":
                return .L
            case "l":
                return .l
            case "C":
                return .C
            case "c":
                return .c
            case "Q":
                return .Q
            case "q":
                return .q
            case "A":
                return .A
            case "a":
                return .a
            case "z", "Z":
                return .z
            case "H":
                return .H
            case "h":
                return .h
            case "V":
                return .V
            case "v":
                return .v
            case "S":
                return .S
            case "s":
                return .s
            case "T":
                return .T
            case "t":
                return .t
            default:
                break
            }
        }
        return nil
    }

    fileprivate func getArgCount(segment: PathSegment.SegmentType) -> Int {
        switch segment {
        case .H, .h, .V, .v:
            return 1
        case .M, .m, .L, .l, .T, .t:
            return 2
        case .S, .s, .Q, .q:
            return 4
        case .C, .c:
            return 6
        case .A, .a:
            return 7
        default:
            return 0
        }
    }
}


private let decodingMap: [String] = ["A", "A", "C", "A", "A", "A", "A", "H", "A", "A", "A", "L", "M", "A", "A", "A", "Q", "A", "S", "T", "A", "V", "A", "A", "A", "Z", "a", "a", "c", "a", "a", "a", "a", "h", "a", "a", "a", "l", "m", "a", "a", "a", "q", "a", "s", "t", "a", "v", "a", ".", "a", "z", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "-", ","]
private func decodeStickerThumbnailData(_ data: Data) -> String {
    var string = "M"
    data.forEach { byte in
        if byte >= 128 + 64 {
            string.append(decodingMap[Int(byte) - 128 - 64])
        } else {
            if byte >= 128 {
                string.append(",")
            } else if byte >= 64 {
                string.append("-")
            }
            string.append("\(byte & 63)")
        }
    }
    string.append("z")
    return string
}

public func generateStickerPlaceholderImage(data: Data, size: CGSize, scale: CGFloat? = nil, imageSize: CGSize, backgroundColor: NSColor?, foregroundColor: NSColor) -> CGImage? {
    return generateImage(size, scale: scale, rotatedContext: { size, context in
        if let backgroundColor = backgroundColor {
            context.setFillColor(backgroundColor.cgColor)
            context.setBlendMode(.copy)
            context.fill(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(NSColor.clear.cgColor)
        } else {
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(foregroundColor.cgColor)
        }
        
        var path = decodeStickerThumbnailData(data)
        if !path.hasSuffix("z") {
            path = "\(path)z"
        }
        let reader = PathDataReader(input: path)
        let segments = reader.read()
        
        let scale = max(size.width, size.height) / max(imageSize.width, imageSize.height)
        context.scaleBy(x: scale, y: scale)
        renderPath(segments, context: context)
    })
}
