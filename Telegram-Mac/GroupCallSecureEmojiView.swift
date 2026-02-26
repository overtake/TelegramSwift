//
//  GroupCallSecureEmojiView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25.03.2025.
//  Copyright © 2025 Telegram. All rights reserved.
//
import TGUIKit
import SwiftSignalKit
import TelegramCore
import ObjcUtils

final class GroupCallSecureEmojiView: Control {
    
    private class EmojiView : View {
        private(set) var stable: ImageView?
        private var pendingEmojiValues: [CGImage]?
        private var pendingContainerView: View?
        private var pendingEmojiViews: [SimpleLayer] = []
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(emoji: CGImage?, emojiSize: NSSize, animated: Bool) {

            let prevEmojiSize = self.frame.size
            
            if let emoji {
                let current: ImageView
                let isNew: Bool
                if let view = self.stable {
                    current = view
                    isNew = false
                } else {
                    current = ImageView()
                    addSubview(current)
                    self.stable = current
                    isNew = true
                }
                current.image = emoji
                current.setFrameSize(emojiSize)
                
                if isNew, animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                
                if let pendingContainerView = self.pendingContainerView {
                    self.pendingContainerView = nil
                    performSubviewRemoval(pendingContainerView, animated: animated)
                    self.pendingEmojiViews.removeAll()
                }
                
            } else {
                
                if let stable = self.stable {
                    self.stable = nil
                    performSubviewRemoval(stable, animated: animated)
                }
                
                let borderEmoji = 2
                let numEmoji = borderEmoji * 2 + 3
                
                if self.pendingEmojiValues?.count != numEmoji {
                    var pendingEmojiValuesValue: [CGImage] = []
                    for _ in 0 ..< numEmoji - borderEmoji - 1 {
                        let emoji = ObjcUtils.randomCallsEmoji()
                        let image = generateTextIcon(.initialize(string: emoji, color: .white, font: .medium(30)), minSize: false)
                        pendingEmojiValuesValue.append(image)
                    }
                    for i in 0 ..< borderEmoji + 1 {
                        pendingEmojiValuesValue.append(pendingEmojiValuesValue[i])
                    }
                    self.pendingEmojiValues = pendingEmojiValuesValue
                }
                
                
                if let pendingEmojiValues, pendingEmojiValues.count == numEmoji {
                    let pendingContainerView: View
                    if let current = self.pendingContainerView {
                        pendingContainerView = current
                    } else {
                        pendingContainerView = View()
                        self.pendingContainerView = pendingContainerView
                    }
                    let size = emojiSize

                    for i in 0 ..< numEmoji {
                        let pendingEmojiView: SimpleLayer
                        if self.pendingEmojiViews.count > i {
                            pendingEmojiView = self.pendingEmojiViews[i]
                        } else {
                            pendingEmojiView = SimpleLayer()
                            self.pendingEmojiViews.append(pendingEmojiView)
                            pendingContainerView.layer?.addSublayer(pendingEmojiView)
                        }
                        pendingEmojiView.contents = pendingEmojiValues[i]
                        pendingEmojiView.frame = CGRect(origin: CGPoint(x: 0.0, y: CGFloat(i) * size.height), size: emojiSize)
                    }

                    pendingContainerView.frame = CGRect(origin: CGPoint(), size: size)

                    if pendingContainerView.superview == nil || emojiSize != prevEmojiSize {
                        self.addSubview(pendingContainerView)

                        let animation = CABasicAnimation(keyPath: "sublayerTransform.translation.y")
                        //animation.duration = 4.2
                        animation.duration = 0.7
                        animation.fromValue = -CGFloat(numEmoji - borderEmoji) * size.height
                        animation.toValue = CGFloat(borderEmoji - 3) * size.height
                        animation.timingFunction = CAMediaTimingFunction(name: .linear)
                        animation.autoreverses = false
                        animation.repeatCount = .infinity
                        
                        pendingContainerView.layer?.add(animation, forKey: "offsetCycle")
                    }
                }
            }
        }
    }
    
    private let textView = TextView()
    private let emojiesView: [EmojiView] = [EmojiView(frame: .zero), EmojiView(frame: .zero), EmojiView(frame: .zero), EmojiView(frame: .zero)]
    
    private var infoTextView: TextView?
    
    private var closeView: TextView?
    private var closeBorderView: View?
    


    
    private var state: GroupCallUIState?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        for view in emojiesView {
            addSubview(view)
        }
        
        scaleOnClick = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func emojiesRects(_ state: GroupCallUIState, width: CGFloat) -> [NSRect] {
        var rects: [CGRect] = []
        if state.showConferenceKey {
            
            let size = NSMakeSize(34, 39)
            
            let between = (width - size.width * 4) / 5.0
            
            var x: CGFloat = between
            for _ in self.emojiesView {
                rects.append(NSMakeRect(x, 10, size.width, size.height))
                x += size.width + between
            }
            
        } else {
            let size = NSMakeSize(21, 22)
            var x: CGFloat = 5
            for (i, _) in self.emojiesView.enumerated() {
                rects.append(.init(origin: NSMakePoint(x, 5), size: size))
                if i == 0 || i == 2 {
                    x += size.width
                } else if i == 1 {
                    x = self.textView.frame.maxX + 5
                }
            }
            
        }
        return rects
    }
    
    func update(_ state: GroupCallUIState, encryptionKeyEmoji: [String]?, _ account: Account, toggle: @escaping()->Void, transition: ContainedViewLayoutTransition) -> NSSize {
    
        let animated = transition.isAnimated
        self.state = state
        
        let textLayout = TextViewLayout(.initialize(string: strings().groupCallEndToEndTitle, color: .white, font: .normal(.text)), alignment: .center)
        textLayout.measure(width: .greatestFiniteMagnitude)
        self.textView.update(textLayout)
        
        
        background = GroupCallTheme.membersColor
        
        setSingle(handler: { _ in
            toggle()
        }, for: .Click)
        
        let views = self.emojiesView
        
        let width = textView.frame.width + 84 + 10 + 10
        let emojiRects = emojiesRects(state, width: width)

        for (i, view) in views.enumerated() {
            var image: CGImage? = nil
            if let encryptionKeyEmoji {
                let emoji = encryptionKeyEmoji[i]
                image = generateTextIcon(.initialize(string: emoji, color: .white, font: .medium(30)), minSize: false)
            }
            let isNew: Bool = view.stable == nil
            
            view.update(emoji: image, emojiSize: emojiRects[i].size, animated: animated)
                                    
            if isNew {
                view.frame = emojiRects[i]
            } else {
                transition.updateFrame(view: view, frame: emojiRects[i])
            }
        }
        
        
        self.textView.change(opacity: state.showConferenceKey ? 0 : 1, animated: animated)
        
        if state.showConferenceKey {
            let current: TextView
            let isNew: Bool
            if let view = self.infoTextView {
                current = view
                isNew = false
            } else {
                current = TextView()
                current.userInteractionEnabled = false
                current.isSelectable = false
                self.infoTextView = current
                addSubview(current)
                isNew = true
            }
            
            let layout = TextViewLayout(.initialize(string: "These four emojis represent the call's encryption key. They must match for all participants and change when someone joins or leaves.", color: .white, font: .normal(.text)))
            layout.measure(width: width - 20)
            
            current.update(layout)
            
            if isNew {
                current.centerX(y: 50)
            }
            
        } else if let view = self.infoTextView {
            performSubviewRemoval(view, animated: animated)
            self.infoTextView = nil
        }
        
        if state.showConferenceKey, let infoTextView {
            let current: TextView
            let isNew: Bool
            if let view = self.closeView {
                current = view
                isNew = false
            } else {
                current = TextView()
                current.userInteractionEnabled = false
                current.isSelectable = false
                self.closeView = current
                addSubview(current)
                isNew = true
            }
            
            let layout = TextViewLayout(.initialize(string: strings().navigationClose, color: .white, font: .normal(.title)), alignment: .center)
            layout.measure(width: width - 20)
            current.update(layout)
            current.setFrameSize(NSMakeSize(width, 40))

            if isNew {
                current.centerX(y: infoTextView.frame.maxY + 10)
            }
            
        } else if let view = self.closeView {
            performSubviewRemoval(view, animated: animated)
            self.closeView = nil
        }
        
        if state.showConferenceKey, let infoTextView {
            let current: View
            let isNew: Bool
            if let view = self.closeBorderView {
                current = view
                isNew = false
            } else {
                current = View()
                self.closeBorderView = current
                addSubview(current)
                isNew = true
            }
            
            current.backgroundColor = NSColor.white.withAlphaComponent(0.15)
            current.setFrameSize(NSMakeSize(width, .borderSize))
            
            if isNew {
                current.centerX(y: infoTextView.frame.maxY + 10)
            }
            
        } else if let view = self.closeBorderView {
            performSubviewRemoval(view, animated: animated)
            self.closeBorderView = nil
        }
        
        
        self.layer?.cornerRadius = 15

        if let infoTextView {
            return NSMakeSize(width, 30 + infoTextView.frame.height + 50 + 10 + 10)
        } else {
            return NSMakeSize(width, 30)
        }
        
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
        
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: textView, frame: textView.centerFrameX(y: 7))
        
        guard let state else {
            return
        }
        
        let views = self.emojiesView
        let rects = self.emojiesRects(state, width: size.width)
        for (i, view) in views.enumerated() {
            transition.updateFrame(view: view, frame: rects[i])
        }
        
        if let view = self.infoTextView {
            transition.updateFrame(view: view, frame: view.centerFrameX(y: 50))
        }
        if let view = self.closeView {
            transition.updateFrame(view: view, frame: view.centerFrameX(y: size.height - view.frame.height))
        }
        if let view = self.closeBorderView {
            transition.updateFrame(view: view, frame: view.centerFrameX(y: size.height - 40))
        }
    }
}
