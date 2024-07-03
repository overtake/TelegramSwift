//
//  File.swift
//  
//
//  Created by Mike Renoir on 05.01.2024.
//

import Foundation
import AppKit


public enum EmojiFitzModifier: Int32, Equatable {
    case type12
    case type3
    case type4
    case type5
    case type6
    
    public init?(emoji: String) {
        switch emoji.unicodeScalars.first?.value {
        case 0x1f3fb:
            self = .type12
        case 0x1f3fc:
            self = .type3
        case 0x1f3fd:
            self = .type4
        case 0x1f3fe:
            self = .type5
        case 0x1f3ff:
            self = .type6
        default:
            return nil
        }
    }
}



private let colorKeyRegex = try? NSRegularExpression(pattern: "\"k\":\\[[\\d\\.]+\\,[\\d\\.]+\\,[\\d\\.]+\\,[\\d\\.]+\\]")

public func transformedWithFitzModifier(data: Data, fitzModifier: EmojiFitzModifier?) -> Data {
    if let fitzModifier = fitzModifier, var string = String(data: data, encoding: .utf8)?.replacingOccurrences(of: " ", with: "") {
        let colors: [NSColor] = [0xf77e41, 0xffb139, 0xffd140, 0xffdf79].map { NSColor(rgb: $0) }
        let replacementColors: [NSColor]
        switch fitzModifier {
        case .type12:
            replacementColors = [0xca907a, 0xedc5a5, 0xf7e3c3, 0xfbefd6].map { NSColor(rgb: $0) }
        case .type3:
            replacementColors = [0xaa7c60, 0xc8a987, 0xddc89f, 0xe6d6b2].map { NSColor(rgb: $0) }
        case .type4:
            replacementColors = [0x8c6148, 0xad8562, 0xc49e76, 0xd4b188].map { NSColor(rgb: $0) }
        case .type5:
            replacementColors = [0x6e3c2c, 0x925a34, 0xa16e46, 0xac7a52].map { NSColor(rgb: $0) }
        case .type6:
            replacementColors = [0x291c12, 0x472a22, 0x573b30, 0x68493c].map { NSColor(rgb: $0) }
        }
        
        func colorToString(_ color: NSColor) -> String {
            var r: CGFloat = 0.0
            var g: CGFloat = 0.0
            var b: CGFloat = 0.0
            color.getRed(&r, green: &g, blue: &b, alpha: nil)
            return "\"k\":[\(r),\(g),\(b),1]"
        }
        
        func match(_ a: Double, _ b: Double, eps: Double) -> Bool {
            return abs(a - b) < eps
        }
        
        var replacements: [(NSTextCheckingResult, String)] = []
        
        if let colorKeyRegex = colorKeyRegex {
            let results = colorKeyRegex.matches(in: string, range: NSRange(string.startIndex..., in: string))
            for result in results.reversed()  {
                if let range = Range(result.range, in: string) {
                    let substring = String(string[range])
                    let color = substring[substring.index(string.startIndex, offsetBy: "\"k\":[".count) ..< substring.index(before: substring.endIndex)]
                    let components = color.split(separator: ",")
                    if components.count == 4, let r = Double(components[0]), let g = Double(components[1]), let b = Double(components[2]), let a = Double(components[3]) {
                        if match(a, 1.0, eps: 0.01) {
                            for i in 0 ..< colors.count {
                                let color = colors[i]
                                var cr: CGFloat = 0.0
                                var cg: CGFloat = 0.0
                                var cb: CGFloat = 0.0
                                color.getRed(&cr, green: &cg, blue: &cb, alpha: nil)
                                if match(r, Double(cr), eps: 0.01) && match(g, Double(cg), eps: 0.01) && match(b, Double(cb), eps: 0.01) {
                                    replacements.append((result, colorToString(replacementColors[i])))
                                }
                            }
                        }
                    }
                }
            }
        }
        
        for (result, text) in replacements {
            if let range = Range(result.range, in: string) {
                string = string.replacingCharacters(in: range, with: text)
            }
        }
        
        return string.data(using: .utf8) ?? data
    } else {
        return data
    }
}

public func applyLottieColor(data: Data, color: NSColor) -> Data {
    if var string = String(data: data, encoding: .utf8)?.replacingOccurrences(of: " ", with: "") {
        func colorToString(_ color: NSColor) -> String {
            let rgbColor = color.usingColorSpace(.deviceRGB) ?? NSColor(0x000000)
            var r: CGFloat = 0.0
            var g: CGFloat = 0.0
            var b: CGFloat = 0.0
            rgbColor.getRed(&r, green: &g, blue: &b, alpha: nil)
            return "\"k\":[\(r),\(g),\(b),1]"
        }
        var replacements: [(NSTextCheckingResult, String)] = []
        if let colorKeyRegex = colorKeyRegex {
            let results = colorKeyRegex.matches(in: string, range: NSRange(string.startIndex..., in: string))
            for result in results.reversed()  {
                replacements.append((result, colorToString(color)))
            }
        }
        for (result, text) in replacements {
            if let range = Range(result.range, in: string) {
                string = string.replacingCharacters(in: range, with: text)
            }
        }
        return string.data(using: .utf8) ?? data
    } else {
        return data
    }
}


