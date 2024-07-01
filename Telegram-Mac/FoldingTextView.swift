//
//  File.swift
//  
//
//  Created by Mikhail Filimonov on 24.05.2024.
//

import Foundation
import Cocoa
import TGUIKit
import TelegramMedia

private let quoteIcon: CGImage = {
    return NSImage(named: "Icon_Quote")!.precomposed(flipVertical: false)
}()

private func generateMaskImage(size: NSSize, y: CGFloat) -> CGImage? {
    return generateImage(size, rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        var locations: [CGFloat] = [0.0, 0.7, 1.0]
        let colors: [CGColor] = [NSColor.white.cgColor, NSColor.white.withAlphaComponent(0.0).cgColor, NSColor.white.withAlphaComponent(0.0).cgColor]
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        
        context.setBlendMode(.copy)
        context.clip(to: CGRect(origin: CGPoint(x: 0, y: y), size: CGSize(width: size.width, height: size.height)))
        context.drawLinearGradient(gradient, start: CGPoint(x: size.width - size.width / 4, y: 0.0), end: CGPoint(x: size.width, y: 0.0), options: CGGradientDrawingOptions())
    })
}


public class FoldingTextLayout {
    
    struct ViewLayout {
        let text: TextViewLayout
        let arrowDown: CGImage?
        let arrowUp: CGImage?
        let mask: CGImage?
        let isRevealed: Bool
        let collapsable: Bool
        let size: NSSize
        func updated(width: CGFloat, revealed: Bool, collapsable: Bool, isBigEmoji: Bool) -> ViewLayout {
            text.measure(width: width, isBigEmoji: isBigEmoji)
            
            let isRevealed = revealed || text.blockQuotes.isEmpty || text.lines.count <= 3 || !collapsable
            
            let size: NSSize
            if isRevealed {
                size = text.layoutSize
            } else {
                size = NSMakeSize(text.layoutSize.width, text.lines[1].frame.maxY + 8)
            }
            
            let arrowDown: CGImage?
            let arrowUp: CGImage?
            
            if text.hasBlockQuotes && canReveal {
                let mainColor = text.blockQuotes[0].colors.main
                
                let generateArrow:(NSSize, CGContext)->Void = { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setStrokeColor(mainColor.cgColor)
                    context.setLineWidth(1.5)
                    context.setLineCap(.round)
                    context.setLineJoin(.round)
                    context.beginPath()
                    context.move(to: CGPoint(x: 1.0, y: 1.0))
                    context.addLine(to: CGPoint(x: size.width / 2.0, y: size.height - 2.0))
                    context.addLine(to: CGPoint(x: size.width - 1.0, y: 1.0))
                    context.strokePath()
                }
                
                arrowDown = self.arrowDown ?? generateImage(CGSize(width: 10, height: 7), rotatedContext: generateArrow)
                arrowUp = self.arrowUp ?? generateImage(CGSize(width: 10, height: 7), contextGenerator: generateArrow)
            } else {
                arrowDown = nil
                arrowUp = nil
            }
            
            
            if text.hasBlockQuotes && !isRevealed {
                return .init(text: text, arrowDown: arrowDown, arrowUp: arrowUp, mask: generateMaskImage(size: NSMakeSize(size.width, size.height - 5), y: text.lines[0].frame.maxY + 2), isRevealed: isRevealed, collapsable: collapsable, size: size)
            } else {
                return .init(text: text, arrowDown: arrowDown, arrowUp: arrowUp, mask: nil, isRevealed: isRevealed, collapsable: collapsable, size: size)
            }
        }
        
        var layoutSize: NSSize {
            return self.text.layoutSize
        }
        
        var canReveal: Bool {
            return collapsable && !self.text.blockQuotes.isEmpty && self.text.lines.count > 3
        }
        
        func makeImageBlock(backgroundColor: NSColor) {
            self.text.maskBlockImage = self.text.generateBlock(backgroundColor: backgroundColor)
        }
    }
    
    var blocks:[ViewLayout]
    var revealed: Set<Int>
    let context: AccountContext
    let attributedString: NSAttributedString
    private var width: CGFloat = 0
    
    var string: String {
        return attributedString.string
    }
    
    init(attributedString: NSAttributedString, blocks: [TextViewLayout], context: AccountContext, revealed: Set<Int>) {
        self.context = context
        self.attributedString = attributedString
        self.blocks = blocks.enumerated().map {
            ViewLayout(text: $0.element, arrowDown: nil, arrowUp: nil, mask: nil, isRevealed: revealed.contains($0.offset), collapsable: $0.element.blockCollapsable, size: .zero)
        }
        self.revealed = revealed
    }
    
    func toggle(_ index: Int) {
        if revealed.contains(index) {
            revealed.remove(index)
        } else {
            revealed.insert(index)
        }
        self.measure(width: self.width)
    }
    
    func applyRanges(_ ranges: [(NSRange, Int)]) {
        for range in ranges {
            if blocks.count > range.1 {
                self.blocks[range.1].text.selectedRange.range = range.0
            }
        }
    }
    
    func set(_ interactions: TextViewInteractions) {
        for block in blocks {
            block.text.interactions = interactions
        }
    }
    
    var lastLineIsRtl: Bool {
        return blocks.last?.text.lastLineIsRtl ?? false
    }
    
    var lastLineIsBlock: Bool {
        return blocks.last?.text.lastLineIsBlock ?? false
    }
    
    var linesCount: Int {
        return blocks.reduce(0, { $0 + $1.text.lines.count })
    }
    
    var lastLine: TextViewLine? {
        return blocks.last?.text.lines.last
    }
    
    var hasBlockQuotes: Bool {
        return blocks.contains(where: { $0.text.hasBlockQuotes })
    }
    
    var lastLineIsQuote: Bool {
        return blocks.last?.text.lastLineIsQuote ?? false
    }
    
    func makeImageBlock(backgroundColor: NSColor) {
        for i in 0 ..< blocks.count {
            blocks[i].makeImageBlock(backgroundColor: backgroundColor)
        }
    }
    
    var hasSelectedText: Bool {
        return blocks.contains(where: { $0.text.selectedRange.hasSelectText })
    }
    
    var merged: TextViewLayout {
        let lines = self.blocks.reduce([], {
            $0 + $1.text.lines
        })
        var range: NSRange = NSMakeRange(NSNotFound, 0)
        
        var offset: Int = 0
        for block in blocks {
            let current = block.text.selectedRange.range
            if current.location != NSNotFound {
                if range.location == NSNotFound {
                    range.location = offset + current.location
                }
                range.length += current.length
            }
            offset += block.text.string.length
        }
        let merged = TextViewLayout(attributedString)
        merged.lines = lines
        merged.selectedRange.range = range

        return merged
    }

    var size: NSSize {
        var size: NSSize = .zero
        for block in blocks {
            if block.isRevealed {
                size.height += block.layoutSize.height
            } else {
                size.height += block.size.height
            }
            size.width = max(block.layoutSize.width, size.width)
        }
        return size
    }
    
    func measure(width: CGFloat, isBigEmoji: Bool = false) {
        self.width = width
        for i in 0 ..< blocks.count {
            blocks[i] = blocks[i].updated(width: width, revealed: self.revealed.contains(i), collapsable: blocks[i].collapsable, isBigEmoji: isBigEmoji)
        }
    }
    
    
    static func breakString(_ string: NSAttributedString) -> [NSAttributedString] {
        
        var results = [NSAttributedString]()
        let length = string.length

        var rangeStart = 0
        var insideBlockquote = false

        string.enumerateAttributes(in: NSRange(location: 0, length: length), options: []) { (attributes, range, _) in
            if attributes[TextInputAttributes.quote] != nil {
                if !insideBlockquote {
                    if rangeStart < range.location {
                        let textRange = NSRange(location: rangeStart, length: range.location - rangeStart)
                        var text = string.attributedSubstring(from: textRange)
                        if text.string.hasPrefix("\n") {
                            text = text.attributedSubstring(from: NSRange(location: 1, length: text.length - 1))
                        }
                        if !text.string.isEmpty {
                            results.append(text)
                        }
                    }
                    rangeStart = range.location
                    insideBlockquote = true
                }
            } else {
                if insideBlockquote {
                    let blockquoteRange = NSRange(location: rangeStart, length: range.location - rangeStart)
                    let blockquoteText = string.attributedSubstring(from: blockquoteRange)
                    if !blockquoteText.string.isEmpty {
                        results.append(blockquoteText)
                    }
                    rangeStart = range.location
                    insideBlockquote = false
                }
            }
        }

        if rangeStart < length {
            let finalRange = NSRange(location: rangeStart, length: length - rangeStart)
            var finalText = string.attributedSubstring(from: finalRange)
            
            if finalText.string.hasPrefix("\n") {
                finalText = finalText.attributedSubstring(from: NSRange(location: 1, length: finalText.length - 1))
            }
            if !finalText.string.isEmpty {
                results.append(finalText)
            }
        }

        return results
    }
    
    static func make(_ string: NSAttributedString, context: AccountContext, revealed: Set<Int>, takeLayout:@escaping(NSAttributedString)->TextViewLayout) -> FoldingTextLayout {
        return FoldingTextLayout(attributedString: string, blocks: FoldingTextLayout.breakString(string).map(takeLayout), context: context, revealed: revealed)
    }
}

private final class WrapperView : View {
    
    class BlockLayer: SimpleLayer {
        var blockQuotes: [TextViewBlockQuote] = [] {
            didSet {
                setNeedsDisplay()
            }
        }
        override func draw(in ctx: CGContext) {
            for blockQuote in blockQuotes {
                let radius: CGFloat = 3.0
                let lineWidth: CGFloat = 3.0
                
                
                let blockFrame = blockQuote.frame
                let blockColor = blockQuote.isCode ? blockQuote.colors.tertiary ?? blockQuote.colors.main : blockQuote.colors.main
                let tintColor = blockQuote.colors.main
                let secondaryTintColor = blockQuote.colors.secondary
                let tertiaryTintColor = blockQuote.colors.tertiary
                
                
                var bg = blockColor
                if blockQuote.isCode {
                    bg = bg.darker(amount: 0.5).withAlphaComponent(0.5)
                } else {
                    bg = bg.withAlphaComponent(0.1)
                }
                ctx.setFillColor(bg.cgColor)
                ctx.addPath(CGPath(roundedRect: blockFrame, cornerWidth: radius, cornerHeight: radius, transform: nil))
                ctx.fillPath()
                
                ctx.setFillColor(tintColor.cgColor)
                
                if !blockQuote.isCode {
                    let iconSize = quoteIcon.backingSize
                    let quoteRect = CGRect(origin: CGPoint(x: blockFrame.maxX - 4.0 - iconSize.width, y: blockFrame.minY + 4.0), size: iconSize)
                    ctx.saveGState()
                    ctx.translateBy(x: quoteRect.midX, y: quoteRect.midY)
                    ctx.scaleBy(x: 1.0, y: -1.0)
                    ctx.translateBy(x: -quoteRect.midX, y: -quoteRect.midY)
                    ctx.clip(to: quoteRect, mask: quoteIcon)
                    ctx.fill(quoteRect)
                    ctx.restoreGState()
                    ctx.resetClip()
                }
                
                
                let lineFrame = CGRect(origin: CGPoint(x: blockFrame.minX, y: blockFrame.minY), size: CGSize(width: lineWidth, height: blockFrame.height))
                ctx.move(to: CGPoint(x: lineFrame.minX, y: lineFrame.minY + radius))
                ctx.addArc(tangent1End: CGPoint(x: lineFrame.minX, y: lineFrame.minY), tangent2End: CGPoint(x: lineFrame.minX + radius, y: lineFrame.minY), radius: radius)
                ctx.addLine(to: CGPoint(x: lineFrame.minX + radius, y: lineFrame.maxY))
                ctx.addArc(tangent1End: CGPoint(x: lineFrame.minX, y: lineFrame.maxY), tangent2End: CGPoint(x: lineFrame.minX, y: lineFrame.maxY - radius), radius: radius)
                ctx.closePath()
                ctx.clip()
                
               
                
                if let secondaryTintColor = secondaryTintColor {
                    let isMonochrome = secondaryTintColor.alpha == 0.2

                    do {
                        ctx.saveGState()
                        
                        let dashHeight: CGFloat = tertiaryTintColor != nil ? 6.0 : 9.0
                        let dashOffset: CGFloat
                        if let _ = tertiaryTintColor {
                            dashOffset = isMonochrome ? -2.0 : 0.0
                        } else {
                            dashOffset = isMonochrome ? -4.0 : 5.0
                        }
                    
                        if isMonochrome {
                            ctx.setFillColor(tintColor.withMultipliedAlpha(0.2).cgColor)
                            ctx.fill(lineFrame)
                            ctx.setFillColor(tintColor.cgColor)
                        } else {
                            ctx.setFillColor(tintColor.cgColor)
                            ctx.fill(lineFrame)
                            ctx.setFillColor(secondaryTintColor.cgColor)
                        }
                        
                        func drawDashes() {
                            ctx.translateBy(x: blockFrame.minX, y: blockFrame.minY + dashOffset)
                            
                            var offset = 0.0
                            while offset < blockFrame.height {
                                ctx.move(to: CGPoint(x: 0.0, y: 3.0))
                                ctx.addLine(to: CGPoint(x: lineWidth, y: 0.0))
                                ctx.addLine(to: CGPoint(x: lineWidth, y: dashHeight))
                                ctx.addLine(to: CGPoint(x: 0.0, y: dashHeight + 3.0))
                                ctx.closePath()
                                ctx.fillPath()
                                
                                ctx.translateBy(x: 0.0, y: 18.0)
                                offset += 18.0
                            }
                        }
                        
                        drawDashes()
                        ctx.restoreGState()
                        
                        if let tertiaryTintColor = tertiaryTintColor{
                            ctx.saveGState()
                            ctx.translateBy(x: 0.0, y: dashHeight)
                            if isMonochrome {
                                ctx.setFillColor(tintColor.withAlphaComponent(0.4).cgColor)
                            } else {
                                ctx.setFillColor(tertiaryTintColor.cgColor)
                            }
                            drawDashes()
                            ctx.restoreGState()
                        }
                    }
                } else {
                    ctx.setFillColor(tintColor.cgColor)
                    ctx.fill(lineFrame)
                }
                
                ctx.resetClip()
                
                if let header = blockQuote.header {
                    let headerHeight = blockQuote.headerInset + 2
                    ctx.setFillColor(blockQuote.colors.main.withAlphaComponent(0.2).cgColor)
                    let rect = NSMakeRect(blockFrame.minX, blockFrame.minY, blockFrame.width, headerHeight)
                    ctx.drawRoundedRect(rect: rect, topLeftRadius: radius, topRightRadius: radius)
                    header.1.draw(CGRect(x: blockFrame.minX + 8, y: blockFrame.minY + (headerHeight - header.0.size.height) / 2 - 1, width: header.0.size.width, height: header.0.size.height), in: ctx, backingScaleFactor: System.backingScale, backgroundColor: .clear)
                    if let image = NSImage(named: "Icon_CopyCode")?.precomposed(blockQuote.colors.main, flipVertical: true) {
                        ctx.draw(image, in: CGRect(origin: NSMakePoint(blockFrame.width - image.backingSize.width - 3, blockFrame.minY + (headerHeight - image.backingSize.height) / 2), size: image.backingSize))
                    }
                }
            }
        }
    }
    
    let textView = TextView()
    private let mask: SimpleShapeLayer = SimpleShapeLayer()
    private var textMask: SimpleLayer?
    private var blockLayer: BlockLayer?
    private var arrow: SimpleLayer?
    
    private var shimmerEffect: ShimmerView?
    private var shimmerMask: SimpleLayer?

    
    var currentLayout: FoldingTextLayout.ViewLayout?
    
    var isLite: Bool = false
    
    private var inlineStickerItemViews: [InlineStickerItemLayer.Key: SimpleLayer] = [:]

    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        self.layer?.mask = mask
//        self.layer?.masksToBounds = false
    }
    
    func update(_ layout: FoldingTextLayout.ViewLayout, isRevealed: Bool, context: AccountContext, transition: ContainedViewLayoutTransition) {
        
        let previousLayout = self.currentLayout
        
        self.currentLayout = layout
        
        let isRevealed = layout.isRevealed
        
        self.isLite = context.isLite(.emoji)
        
        textView.canDrawBlocks = !layout.canReveal

        self.textView.update(layout.text)
        
        let size = layout.size
 
        
        
        let path = CGMutablePath()
        
        if layout.canReveal {
            path.addRoundedRect(in: size.bounds, cornerWidth: min(size.width / 2, 4), cornerHeight: min(size.height / 2, 4))
        } else {
            path.addRoundedRect(in: size.bounds, cornerWidth: 0, cornerHeight: 0)
        }
        
        
        let animation = mask.makeAnimation(from: self.mask.path ?? CGMutablePath(), to: path, keyPath: "path", timingFunction: transition.timingFunction, duration: transition.duration)
        if transition.isAnimated {
            mask.add(animation, forKey: "path")
        }
        mask.path = path
        
        self.layer?.masksToBounds = layout.text.hasBlockQuotes
        self.layer?.mask = layout.text.hasBlockQuotes ? mask : nil


        if layout.canReveal {
            let current: BlockLayer
            if let layer = self.blockLayer {
                current = layer
            } else {
                current = BlockLayer(frame: size.bounds)
                self.layer?.addSublayer(current)
                self.blockLayer = current
            }
            current.blockQuotes = layout.text.blockQuotes
            transition.updateFrame(layer: current, frame: layout.layoutSize.bounds)
            current.mask = mask
        } else {
            if let layer = self.blockLayer {
                performSublayerRemoval(layer, animated: transition.isAnimated)
                self.blockLayer = nil
            }
        }
        
        if !isRevealed {
            let current: SimpleLayer
            if let layer = self.textMask {
                current = layer
            } else {
                current = .init(frame: size.bounds)
                self.textMask = current
            }
            current.contents = layout.mask
            current.contentsGravity = .bottom
            current.frame = size.bounds
            if transition.isAnimated {
                delay(transition.duration, closure: { [weak self] in
                    self?.textView.set(mask: self?.textMask)
                })
            } else {
                self.textView.set(mask: current)
            }
        } else {
            self.textMask = nil
            self.textView.set(mask: nil)
        }
        
        if layout.canReveal {
            let current: SimpleLayer
            if let layer = self.arrow {
                current = layer
            } else {
                let s = NSMakeSize(10, 7)
                current = SimpleLayer(frame: NSMakeRect(size.width - s.width - 5, size.height - s.height - 6, s.width, s.height))
                self.arrow = current
                self.layer?.addSublayer(current)
            }
            current.anchorPoint = NSMakePoint(0, 0)
            current.contents = layout.isRevealed ? layout.arrowUp : layout.arrowDown
            
            if previousLayout?.isRevealed != layout.isRevealed, transition.isAnimated {
                current.animateContents()
            }
        } else if let arrow = self.arrow {
            performSublayerRemoval(arrow, animated: transition.isAnimated)
            self.arrow = nil
        }
        
        self.textView.setIsShimmering(true, animated: transition.isAnimated)
        
        self.updateInlineStickers(context: context, textLayout: layout.text, itemViews: &self.inlineStickerItemViews)
        
        transition.updateFrame(view: self, frame: CGRect(origin: self.frame.origin, size: size))
        self.updateLayout(size: size, transition: transition)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        if let arrow = arrow {
            transition.updateFrame(layer: arrow, frame: NSMakeRect(size.width - arrow.frame.width - 5, size.height - arrow.frame.height - 6, arrow.frame.width, arrow.frame.height))
        }
    }
    
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
    func updateInlineStickers(context: AccountContext, textLayout: TextViewLayout, itemViews: inout [InlineStickerItemLayer.Key: SimpleLayer]) {
        var validIds: [InlineStickerItemLayer.Key] = []
        var index: Int = self.textView.hashValue
        
        let textColor: NSColor
        if textLayout.attributedString.length > 0 {
            var range:NSRange = NSMakeRange(NSNotFound, 0)
            let attrs = textLayout.attributedString.attributes(at: max(0, textLayout.attributedString.length - 1), effectiveRange: &range)
            textColor = attrs[.foregroundColor] as? NSColor ?? theme.colors.text
        } else {
            textColor = theme.colors.text
        }

        for item in textLayout.embeddedItems {
            if let stickerItem = item.value as? InlineStickerItem, item.rect.width > 10 {
                if case let .attribute(emoji) = stickerItem.source {
                    
                    let id = InlineStickerItemLayer.Key(id: emoji.fileId, index: index, color: emoji.color ?? textColor)
                    validIds.append(id)
                    
                    let rect = item.rect.insetBy(dx: 0, dy: 0)
                    
                    let view: InlineStickerItemLayer
                    if let current = itemViews[id] as? InlineStickerItemLayer, current.frame.size == rect.size && current.textColor == id.color {
                        view = current
                    } else {
                        itemViews[id]?.removeFromSuperlayer()
                        view = InlineStickerItemLayer(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: emoji, size: rect.size, playPolicy: stickerItem.playPolicy ?? .loop, textColor: textColor)
                        itemViews[id] = view
                        view.superview = textView
                        textView.addEmbeddedLayer(view)
                    }
                    index += 1
                    
                    view.frame = rect
                } else if case let .avatar(peer) = stickerItem.source {
                    let id = InlineStickerItemLayer.Key(id: peer.id.toInt64(), index: index)
                    validIds.append(id)
                    let rect = NSMakeRect(item.rect.minX, item.rect.minY + 3, item.rect.width - 3, item.rect.width - 3)
                   
                    let view: InlineAvatarLayer
                    if let current = itemViews[id] as? InlineAvatarLayer {
                        view = current
                    } else {
                        itemViews[id]?.removeFromSuperlayer()
                        view = InlineAvatarLayer(context: context, frame: rect, peer: peer)
                        itemViews[id] = view
                        textView.addEmbeddedLayer(view)
                    }
                    index += 1
                    view.frame = rect
               }
                
            }
        }
        
        var removeKeys: [InlineStickerItemLayer.Key] = []
        for (key, itemLayer) in itemViews {
            if !validIds.contains(key) {
                removeKeys.append(key)
                itemLayer.removeFromSuperlayer()
            }
        }
        for key in removeKeys {
            itemViews.removeValue(forKey: key)
        }
        updateAnimatableContent()
    }
    
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.updateListeners()
        self.updateAnimatableContent()
    }
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        self.updateListeners()
        self.updateAnimatableContent()
    }
    
    @objc func updateAnimatableContent() -> Void {
        for (_, value) in inlineStickerItemViews {
            if let value = value as? InlineStickerItemLayer {
                if let superview = value.superview {
                    value.isPlayable = NSIntersectsRect(value.frame, superview.visibleRect) && window != nil && window!.isKeyWindow && !isLite
                }
            }
        }
    }
    private func updateListeners() {
        let center = NotificationCenter.default
        if let window = window {
            center.removeObserver(self)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSWindow.didBecomeKeyNotification, object: window)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSWindow.didResignKeyNotification, object: window)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.boundsDidChangeNotification, object: self.enclosingScrollView?.contentView)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.frameDidChangeNotification, object: self.enclosingScrollView?.documentView)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.frameDidChangeNotification, object: self)
        } else {
            center.removeObserver(self)
        }
    }
    
}

class FoldingTextView : View {
    
    var revealBlockAtIndex:((Int)->Void)? = nil
    
    private var layouts: FoldingTextLayout?
    
    var textSelectable: Bool = true {
        didSet {
            self.updateLayouts()
        }
    }
    
    override var userInteractionEnabled: Bool {
        didSet {
        }
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        layer?.masksToBounds = false
                
        self.revealBlockAtIndex = { [weak self] index in
            if let layout = self?.layouts {
                layout.toggle(index)
                self?.update(layout: layout, animated: true)
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(layout: FoldingTextLayout, animated: Bool) {
        self.layouts = layout
        
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate

        while self.subviews.count > layout.blocks.count {
            self.subviews.last?.removeFromSuperview()
        }
        while self.subviews.count < layout.blocks.count {
            self.subviews.append(WrapperView(frame: .zero))
        }
        for (i, textLayout) in layout.blocks.enumerated() {
            let view = self.subviews[i] as! WrapperView
            view.update(textLayout, isRevealed: layout.revealed.contains(i), context: layout.context, transition: transition)
            view.textView.userInteractionEnabled = userInteractionEnabled
            view.textView.sendDownAnyway = true
            view.textView.removeAllHandlers()
            
            var ignoreNext: Bool = false
            view.textView.set(handler: { control in
                if let view = control as? TextView {
                    ignoreNext = view.selectionWasCleared
                }
            }, for: .Down)
            
            view.textView.set(handler: { [weak self] control in
                if self?.hasSelectedText == false, !ignoreNext {
                    self?.revealBlockAtIndex?(i)
                }
            }, for: .Click)
        }
        
        self.updateLayout(size: layout.size, transition: transition)
    }
    
    var hasSelectedText: Bool {
        return self.layouts?.hasSelectedText ?? false
    }
    
    private func updateLayouts() {
        for subview in subviews {
            let view = subview as! WrapperView
            view.textView.userInteractionEnabled = userInteractionEnabled
            view.textView.isSelectable = textSelectable
        }
    }
    
    var textViews: [TextView] {
        return self.subviews.compactMap {
            ($0 as? WrapperView)?.textView
        }
    }
    
    var string: String? {
        return self.layouts?.string
    }
    
    var textLayouts: [TextViewLayout] {
        return self.layouts?.blocks.map { $0.text } ?? []
    }
    func highlight(text: String, color: NSColor) {
        for textView in textViews {
            textView.highlight(text: text, color: color)
        }
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        var y: CGFloat = 0
        for view in subviews {
            transition.updateFrame(view: view, frame: CGRect(origin: NSPoint(x: 0, y: y), size: view.frame.size))
            y += view.frame.height
        }
    }
    
    func clickInContent(point: NSPoint) -> Bool {
        let point = self.convert(point, from: self)
        
        for subview in subviews {
            if subview.frame.contains(point) {
                let view = subview as! WrapperView
                let point = view.convert(point, from: self)
                if let layout = view.currentLayout?.text {
                    let index = layout.findIndex(location: point)
                    return index >= 0 && point.x < layout.lines[index].frame.maxX
                }
            }
        }
        
        return false
    }
    
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
}
