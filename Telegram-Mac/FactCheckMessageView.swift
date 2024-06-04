//
//  FactCheckMessageView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17.05.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox


private func generateMaskImage(size: NSSize) -> CGImage? {
    return generateImage(size, rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        var locations: [CGFloat] = [0.0, 0.7, 1.0]
        let colors: [CGColor] = [NSColor.white.cgColor, NSColor.white.withAlphaComponent(0.0).cgColor, NSColor.white.withAlphaComponent(0.0).cgColor]
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        
        context.setBlendMode(.copy)
        context.clip(to: CGRect(origin: CGPoint(x: 0, y: 35), size: CGSize(width: size.width, height: size.height)))
        context.drawLinearGradient(gradient, start: CGPoint(x: size.width - size.width / 3, y: 0.0), end: CGPoint(x: size.width, y: 0.0), options: CGGradientDrawingOptions())
    })
}

class FactCheckMessageLayout {
    let text: TextViewLayout
    let title: TextViewLayout
    let whatThisLayout: TextViewLayout
    let clarification: TextViewLayout?
    let context: AccountContext
    let chatInteraction: ChatInteraction
    let presentation: WPLayoutPresentation
    let country: String
    let revealed: Bool
    let message: Message
    fileprivate var isFullView: Bool = true
    private(set) var size: NSSize = .zero
    
    
    init(_ message: Message, factCheck: FactCheckMessageAttribute, context: AccountContext, presentation: WPLayoutPresentation, chatInteraction: ChatInteraction, revealed: Bool) {
        
        self.context = context
        self.message = message
        self.presentation = presentation
        self.chatInteraction = chatInteraction
        self.revealed = revealed
        switch factCheck.content {
        case .Pending:
            fatalError()
        case let .Loaded(text, entities, country):
            let attr = ChatMessageItem.applyMessageEntities(with: [TextEntitiesMessageAttribute(entities: entities)], for: text, message: nil, context: context, fontSize: .text, openInfo: chatInteraction.openInfo, textColor: presentation.text, linkColor: presentation.link, isDark: theme.dark, bubbled: theme.bubbled, confirm: false).mutableCopy() as! NSMutableAttributedString
            InlineStickerItem.apply(to: attr, associatedMedia: message.associatedMedia, entities: entities, isPremium: context.isPremium)
            self.text = .init(attr, alwaysStaticItems: true, mayItems: true)
            self.text.interactions = globalLinkExecutor
            self.country = country
            
            if revealed {
                self.clarification = .init(.initialize(string: strings().factCheckInfoSecond(country), color: presentation.activity.main, font: .normal(.small)))
            } else {
                self.clarification = nil
            }
        }
        
       
        
        self.title = .init(.initialize(string: strings().factCheckTitle, color: presentation.activity.main, font: .medium(.text)))
        self.whatThisLayout = .init(.initialize(string: strings().factCheckWhatThis, color: presentation.activity.main, font: .normal(.small)), alignment: .center)
        
        self.title.measure(width: .greatestFiniteMagnitude)
        self.whatThisLayout.measure(width: .greatestFiniteMagnitude)
        
    }
    
    func measure(for width: CGFloat) {
        self.text.measure(width: width - 20)
        var textSize: CGFloat
        if revealed || self.text.lines.count <= 2 {
            textSize = self.text.layoutSize.height
            self.isFullView = self.text.lines.count <= 2
            if let clarification {
                clarification.measure(width: text.layoutSize.width)
                textSize += clarification.layoutSize.height + 8
            }
        } else {
            textSize = self.text.lines[min(1, self.text.lines.count - 1)].frame.maxY + 1
            self.isFullView = false
        }
        size = NSMakeSize(max(width, self.title.layoutSize.width + whatThisLayout.layoutSize.width + 30), 2 + title.layoutSize.height + textSize + 2 + 4)
    }
    
}

final class FactCheckMessageView : View {
    
    private class RevealView: Control {
        
        private let imageView = ImageView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(imageView)
            scaleOnClick = true
            self.imageView.animates = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(layout: FactCheckMessageLayout, animated: Bool) {
            let mainColor = layout.presentation.activity.main
            
            let image: CGImage?
            if layout.revealed {
                image = generateImage(CGSize(width: 15.0, height: 9.0), contextGenerator: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setStrokeColor(mainColor.cgColor)
                    context.setLineWidth(2.0)
                    context.setLineCap(.round)
                    context.setLineJoin(.round)
                    context.beginPath()
                    context.move(to: CGPoint(x: 1.0, y: 1.0))
                    context.addLine(to: CGPoint(x: size.width / 2.0, y: size.height - 2.0))
                    context.addLine(to: CGPoint(x: size.width - 1.0, y: 1.0))
                    context.strokePath()
                })
            } else {
               image = generateImage(CGSize(width: 15.0, height: 9.0), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setStrokeColor(mainColor.cgColor)
                    context.setLineWidth(2.0)
                    context.setLineCap(.round)
                    context.setLineJoin(.round)
                    context.beginPath()
                    context.move(to: CGPoint(x: 1.0, y: 1.0))
                    context.addLine(to: CGPoint(x: size.width / 2.0, y: size.height - 2.0))
                    context.addLine(to: CGPoint(x: size.width - 1.0, y: 1.0))
                    context.strokePath()
                })
            }
            
            self.imageView.image = image
            self.imageView.sizeToFit()
            
            self.setFrameSize(NSMakeSize(15, 15))
        }
        
        override func layout() {
            super.layout()
            imageView.center()
        }
    }
    
    let textView = InteractiveTextView()
    private let titleView = TextView()
    private let whatThisView = TextView()
    private let dashLayer = DashLayer()
    
    private var revealView: RevealView?
    
    private var textMask: SimpleLayer = SimpleLayer()
    
    private var currentLayout: FactCheckMessageLayout?
    
    private var clarification: TextView?
    private var clarificationSeparator: View?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(titleView)
        addSubview(whatThisView)
        
        textView.textView.userInteractionEnabled = true
        textView.textView.isSelectable = true
        
        
        
        self.layer?.addSublayer(dashLayer)
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        whatThisView.isSelectable = false
        whatThisView.scaleOnClick = true
        whatThisView.tooltipOnclick = true
        layer?.cornerRadius = 4
        
        self.textView.set(handler: { [weak self] _ in
            if let layout = self?.currentLayout {
                if !layout.isFullView {
                    layout.chatInteraction.revealFactCheck(layout.message.id)
                }
            }
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(layout: FactCheckMessageLayout, animated: Bool) {
        self.currentLayout = layout
        
        self.textView.set(text: layout.text, context: layout.context)
        self.titleView.update(layout.title)
        self.whatThisView.update(layout.whatThisLayout)
        self.whatThisView.setFrameSize(NSMakeSize(self.whatThisView.frame.width + 6, self.whatThisView.frame.height + 2))
        self.whatThisView.backgroundColor = layout.presentation.activity.main.withAlphaComponent(0.2)
        self.whatThisView.layer?.cornerRadius = self.whatThisView.frame.height / 2
        self.dashLayer.colors = layout.presentation.activity
        self.whatThisView.appTooltip = strings().factCheckInfo(layout.country)
        self.backgroundColor = layout.presentation.activity.main.withAlphaComponent(0.1)
        
        let isFullView = layout.revealed || layout.isFullView
        
        self.textView.textView.isSelectable = isFullView
        self.textView.textView.userInteractionEnabled = isFullView
        self.textView.userInteractionEnabled = !isFullView
        
        if !layout.isFullView {
            let current: RevealView
            if let view = self.revealView {
                current = view
            } else {
                current = RevealView(frame: .zero)
                self.revealView = current
                addSubview(current)
                
                current.set(handler: { [weak self] _ in
                    if let layout = self?.currentLayout {
                        layout.chatInteraction.revealFactCheck(layout.message.id)
                    }
                }, for: .Click)
            }
            current.update(layout: layout, animated: animated)
            
            if !layout.revealed {
                textView.textView.drawingLayer?.mask = textMask
                textMask.contents = generateMaskImage(size: textView.textView.frame.size)
                textMask.frame = textView.textView.bounds
            } else {
                textView.textView.drawingLayer?.mask = nil
            }
            
        } else {
            if let view = revealView {
                performSubviewRemoval(view, animated: animated)
                self.revealView = nil
            }
            textView.textView.drawingLayer?.mask = nil
        }
        
        if let clarification = layout.clarification {
            let current: TextView
            if let view = self.clarification {
                current = view
            } else {
                current = .init(frame: NSMakeRect(10, textView.frame.maxY + 10, clarification.layoutSize.width, clarification.layoutSize.height))
                current.userInteractionEnabled = false
                current.isSelectable = false
                addSubview(current, positioned: .below, relativeTo: self.revealView)
                self.clarification = current
            }
            current.update(clarification)
            
            let separator: View
            if let view = self.clarificationSeparator {
                separator = view
            } else {
                separator = .init(frame: NSMakeRect(10, textView.frame.maxY + 5, frame.width - 20, .borderSize))
                addSubview(separator, positioned: .below, relativeTo: self.revealView)
                self.clarificationSeparator = separator
            }
            separator.background = layout.presentation.activity.main.withAlphaComponent(0.2)
            
        } else {
            if let view = self.clarificationSeparator {
                performSubviewRemoval(view, animated: animated)
                self.clarificationSeparator = nil
            }
            if let view = self.clarification {
                performSubviewRemoval(view, animated: animated)
                self.clarification = nil
            }
        }
        
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
        self.updateLayout(size: layout.size, transition: transition)
    }
    
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: titleView, frame: NSMakeRect(10, 2, titleView.frame.width, titleView.frame.height))
        transition.updateFrame(view: whatThisView, frame: NSMakeRect(titleView.frame.maxX + 6, 4, whatThisView.frame.width, whatThisView.frame.height))
        transition.updateFrame(view: textView, frame: NSMakeRect(10, titleView.frame.maxY, textView.frame.width, textView.frame.height))
        transition.updateFrame(layer: dashLayer, frame: NSMakeRect(0, 0, 3, titleView.frame.height + textView.frame.height + 200))
        if let view = revealView {
            transition.updateFrame(view: view, frame: NSMakeRect(size.width - view.frame.width - 10, size.height - view.frame.height - 2, view.frame.width, view.frame.height))
        }
        if let clarification {
            transition.updateFrame(view: clarification, frame: NSMakeRect(10, textView.frame.maxY + 10, clarification.frame.width, clarification.frame.height))
        }
        if let clarificationSeparator {
            transition.updateFrame(view: clarificationSeparator, frame: NSMakeRect(10, textView.frame.maxY + 5, size.width - 20, .borderSize))
        }
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
}
