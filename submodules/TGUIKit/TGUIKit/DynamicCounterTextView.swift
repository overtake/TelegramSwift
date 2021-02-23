//
//  DynamicCounterTextView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 30/11/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation

public final class DynamicCounterTextView : View {
    
    public struct Value {
        public let values: [(TextViewLayout, DynamicCounterTextView.Text)]
        public let size: NSSize
    }
    
    public static func make(for text: String, count: String, font: NSFont, textColor: NSColor, width: CGFloat, onlyFade: Bool = false) -> Value {
        var title: [(String, DynamicCounterTextView.Text.Animation, Int)] = []
        if count.isEmpty {
            title = [(text, .crossFade, 0)]
        } else {
            var text = text
            let range = text.nsstring.range(of: count)
            if range.location != NSNotFound {
                title.append((text.nsstring.substring(to: range.location), .crossFade, 0))
                var index: Int = 0
                for _ in range.lowerBound ..< range.upperBound {
                    let symbol = text.nsstring.substring(with: NSMakeRange(range.location + index, 1))
                    let animation: Text.Animation
                    if Int(symbol) != nil {
                        animation = onlyFade ? .crossFade : .numeric
                    } else {
                        animation = .crossFade
                    }
                    title.append((symbol, animation, index + 1))
                    index += 1
                }
                title.append((text.nsstring.substring(from: range.upperBound), .crossFade, range.length + 1))
            } else {
                title.append((text, .crossFade, 0))
                text = ""
            }
        }
        title = title.filter { !$0.0.isEmpty }
        let texts:[DynamicCounterTextView.Text] = title.map {
            return .init(text: .initialize(string: $0.0, color: textColor, font: font), animation: $0.1, index: $0.2)
        }
        
        let layouts = texts.map {
            return (TextViewLayout($0.text, maximumNumberOfLines: 1, truncationType: .end), $0)
        }
        var mw: CGFloat = width
        for layout in layouts {
            layout.0.measure(width: mw)
            mw -= max(layout.0.layoutSize.width, 4) - 2
        }
        
        let size = layouts.reduce(NSZeroSize, { current, value in
            var current = current
            if value.0.attributedString.string == " " {
                current.width += 4
            } else {
                current.width += value.0.layoutSize.width
            }
            current.height = max(current.height, value.0.layoutSize.height)
            return current
        })
        
        return Value(values: layouts, size: size)
    }
    
    
    private let duration: TimeInterval = 0.4
    private let timingFunction: CAMediaTimingFunctionName = .spring
    
    public struct Text : Hashable, Comparable {
        public enum Animation : Equatable {
            case crossFade
            case numeric
        }
        let text: NSAttributedString
        let animation: Animation
        let index: Int
        
        public init(text: NSAttributedString, animation: Animation, index: Int) {
            self.text = text
            self.animation = animation
            self.index = index
        }
        
        public static func <(lhs: Text, rhs: Text) -> Bool {
            let lhsInt: Int? = Int(lhs.text.string)
            let rhsInt: Int? = Int(rhs.text.string)
            
            if let lhsInt = lhsInt, let rhsInt = rhsInt {
                return lhsInt < rhsInt
            }
            return false
        }
        
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(index)
        }
    }
    
    fileprivate var textViews: [Text : (TextView, Text)] = [:]
    public func update(_ layouts: [(TextViewLayout, Text)], animated: Bool) {
                
        enum NumericAnimation {
            case forward
            case backward
        }
        
        let texts = layouts.map { $0.1 }
        
        var addition: [Int : NumericAnimation] = [:]
        var previousTextPos:[Int: NSPoint] = [:]
        for (key, textView) in textViews {
            let title = texts.first(where: { $0.hashValue == key.hashValue })
            if textView.1 != title {
                let updated = title ?? key
                if let title = title {
                    addition[key.hashValue] = title < key ? .backward : .forward
                }
                
                textViews[key] = nil
                let field = textView.0
                previousTextPos[key.hashValue] = field.frame.origin
                if animated {
                    switch updated.animation {
                    case .crossFade:
                        field.layer?.animateAlpha(from: 1, to: 0, duration: duration - 0.1, timingFunction: timingFunction, removeOnCompletion: false, completion: { [weak field] _ in
                            field?.removeFromSuperview()
                        })
                    case .numeric:
                        field.layer?.animateAlpha(from: 1, to: 0, duration: duration - 0.1, timingFunction: timingFunction, removeOnCompletion: false, completion: { [weak field] _ in
                            field?.removeFromSuperview()
                        })
                        
                        let direction = addition[key.hashValue]
                        switch direction {
                        case .forward?:
                            field.layer?.animatePosition(from: field.frame.origin, to: NSMakePoint(field.frame.minX, field.frame.maxY), timingFunction: timingFunction, removeOnCompletion: false)
                        case .backward?:
                            field.layer?.animatePosition(from: field.frame.origin, to: NSMakePoint(field.frame.minX, field.frame.minY - field.frame.height), timingFunction: timingFunction, removeOnCompletion: false)
                        case .none:
                            break
                        }
                    }
                } else {
                    field.removeFromSuperview()
                }
            }
        }
        var pos:NSPoint = .zero
        for layout in layouts {
            if let view = textViews[layout.1] {
                if animated {
                    view.0.layer?.animatePosition(from: NSMakePoint(view.0.frame.origin.x - pos.x, view.0.frame.origin.y - pos.y), to: .zero, timingFunction: timingFunction, removeOnCompletion: true, additive: true)
                }
                view.0.setFrameOrigin(pos)
            } else {
                let current = TextView()
                current.userInteractionEnabled = false
                current.isSelectable = false
                current.disableBackgroundDrawing = true
                self.textViews[layout.1] = (current, layout.1)
                current.update(layout.0, origin: pos)
                addSubview(current)
                if animated {
                    switch layout.1.animation {
                    case .crossFade:
                        current.layer?.animateAlpha(from: 0, to: 1, duration: duration)
                    case .numeric:
                        let prevPos = previousTextPos[layout.1.hashValue] ?? pos
                        let direction = addition[layout.1.hashValue]
                        switch direction {
                        case .forward?:
                            current.layer?.animatePosition(from: NSMakePoint(pos.x, pos.y - layout.0.layoutSize.height), to: pos, timingFunction: timingFunction)
                        case .backward?:
                            current.layer?.animatePosition(from: NSMakePoint(pos.x, pos.y + layout.0.layoutSize.height), to: pos, timingFunction: timingFunction)
                        case .none:
                            break
                        }
                        
                        current.layer?.animateAlpha(from: 0, to: 1, duration: duration)
                    }
                }
            }
            if layout.0.attributedString.string == " " {
                pos.x += 4
            } else {
                pos.x += layout.0.layoutSize.width
            }
        }
        
    }
}
