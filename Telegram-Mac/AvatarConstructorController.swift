//
//  AvatarConstructorController.swift
//  Telegram
//
//  Created by Mike Renoir on 13.04.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import ThemeSettings
import ColorPalette
import ObjcUtils
import AppKit

private final class Arguments {
    let context: AccountContext
    let dismiss:()->Void
    let select:(State.Item)->Void
    let selectOption:(State.Item.Option)->Void
    let selectColor:(AvatarColor)->Void
    let selectForeground:(TelegramMediaFile)->Void
    let set:()->Void
    let zoom:(CGFloat)->Void
    let updateText:(String)->Void
    init(context: AccountContext, dismiss:@escaping()->Void, select:@escaping(State.Item)->Void, selectOption:@escaping(State.Item.Option)->Void, selectColor:@escaping(AvatarColor)->Void, selectForeground:@escaping(TelegramMediaFile)->Void, set: @escaping()->Void, zoom:@escaping(CGFloat)->Void, updateText:@escaping(String)->Void) {
        self.context = context
        self.dismiss = dismiss
        self.select = select
        self.selectOption = selectOption
        self.selectColor = selectColor
        self.selectForeground = selectForeground
        self.set = set
        self.zoom = zoom
        self.updateText = updateText
    }
}

struct AvatarColor : Equatable {
    enum Content : Equatable {
        case solid(NSColor)
        case gradient([NSColor])
        case wallpaper(Wallpaper)
    }
    var selected: Bool
    var content: Content
    
    var isWallpaper: Bool {
        switch content {
        case .wallpaper:
            return true
        default:
            return false
        }
    }
    var wallpaper: Wallpaper? {
        switch content {
        case let .wallpaper(wallpaper):
            return wallpaper
        default:
            return nil
        }
    }
}

private struct State : Equatable {
    struct Item : Equatable, Identifiable, Comparable {
        
        struct Option : Equatable {
            var key: String
            var title: String
            var selected: Bool
        }
        
        var key: String
        var index: Int
        var title: String
        var thumb: MenuAnimation
        var selected: Bool
        
        var options:[Option]
        
        var foreground: TelegramMediaFile?
        var text: String?
        
        
        var selectedOption:Option {
            return self.options.first(where: { $0.selected })!
        }
        
        static func <(lhs: Item, rhs: Item) -> Bool {
            return lhs.index < rhs.index
        }
        
        var stableId: String {
            return self.key
        }
        
    }
    struct Preview : Equatable {
        var zoom: CGFloat = 1.0
        var animated: Bool?
    }
    var items: [Item]
    var preview: Preview = Preview()
    
    
    var emojies:[StickerPackItem] = []
    var colors: [AvatarColor] = []
    
    
    var selected: Item {
        return self.items.first(where: { $0.selected })!
    }
    var selectedColor: AvatarColor {
        return self.colors.first(where: { $0.selected })!
    }
}


private final class AvatarLeftView: View {
    
    private final class PreviewView: View {
        private let imageView: View = View(frame: NSMakeRect(0, 0, 150, 150))
        private var backgroundColorView: ImageView?
        private var backgroundPatternView: TransformImageView?

        
        private var foregroundView: StickerMediaContentView? = nil
        private var foregroundTextView: TextView? = nil

        private let textView = TextView()
        private var state: State?
        
        private let slider: LinearProgressControl = LinearProgressControl(progressHeight: 4)


        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(textView)
            addSubview(imageView)
            addSubview(slider)
            
            slider.scrubberImage = generateImage(NSMakeSize(14, 14), contextGenerator: { size, ctx in
                let rect = CGRect(origin: .zero, size: size)
                ctx.clear(rect)
                ctx.setFillColor(theme.colors.accent.cgColor)
                ctx.fillEllipse(in: rect)
                ctx.setFillColor(theme.colors.background.cgColor)
                ctx.fillEllipse(in: rect.insetBy(dx: 2, dy: 2))

            })
            slider.roundCorners = true
            slider.alignment = .center
            slider.containerBackground = theme.colors.grayBackground
            slider.style = ControlStyle(foregroundColor: theme.colors.accent, backgroundColor: .clear, highlightColor: .clear)
            slider.set(progress: 0.8)
            
            imageView.layer?.cornerRadius = imageView.frame.height / 2
            
            let text = TextViewLayout(.initialize(string: strings().avatarPreview, color: theme.colors.grayText, font: .normal(.text)))
            text.measure(width: .greatestFiniteMagnitude)
            textView.update(text)
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            imageView.backgroundColor = theme.colors.listBackground
        }
        
        func updateState(_ state: State, arguments: Arguments, animated: Bool) {
            self.state = state
            
            self.slider.set(progress: state.preview.zoom)
            
            let selectedBg = state.colors.first(where: { $0.selected })!
            
            self.applyBg(selectedBg, context: arguments.context, animated: animated)
            self.applyFg(state.selected.foreground, text: state.selected.text, zoom: state.preview.zoom, context: arguments.context, animated: animated)
            
            slider.onUserChanged = { value in
                arguments.zoom(CGFloat(value))
            }
            needsLayout = true
        }
        
        private var previousFile: TelegramMediaFile?
        private var previousText: String?
        
        private func applyFg(_ file: TelegramMediaFile?, text: String?, zoom: CGFloat, context: AccountContext, animated: Bool) {
            if let text = text {
                if let view = foregroundView {
                    performSubviewRemoval(view, animated: animated, scale: true)
                    self.foregroundView = nil
                }
                
                if self.previousText != text {
                    if let view = foregroundTextView {
                        performSubviewRemoval(view, animated: animated, scale: true)
                        self.foregroundTextView = nil
                    }
                    
                    let foregroundTextView = TextView()
                    foregroundTextView.userInteractionEnabled = false
                    foregroundTextView.isSelectable = false
                    
                    let layout = TextViewLayout(.initialize(string: text, color: .white, font: .avatar(80)))
                    layout.measure(width: .greatestFiniteMagnitude)
                    foregroundTextView.update(layout)
                    
                    
                    self.imageView.addSubview(foregroundTextView)
                    foregroundTextView.center()
                    foregroundTextView.frame.origin.y += 4

                    self.foregroundTextView = foregroundTextView
                    
                    if animated {
                        foregroundTextView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                        foregroundTextView.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2)
                    }
                }
                
            } else {
                
                if let view = foregroundTextView {
                    performSubviewRemoval(view, animated: animated, scale: true)
                    self.foregroundTextView = nil
                }
                
                if let file = file, self.previousFile != file {
                    
                    if let view = foregroundView {
                        performSubviewRemoval(view, animated: animated, scale: true)
                        self.foregroundView = nil
                    }
                    let foregroundView = StickerMediaContentView(frame: NSMakeRect(0, 0, 120, 120))
                    
                    foregroundView.update(with: file, size: foregroundView.frame.size, context: context, parent: nil, table: nil)
                    
                    self.imageView.addSubview(foregroundView)
                    foregroundView.center()
                    
                    self.foregroundView = foregroundView
                    
                    if animated {
                        foregroundView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                        foregroundView.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2)
                    }
                } else if file == nil {
                    if let view = foregroundView {
                        performSubviewRemoval(view, animated: animated, scale: true)
                        self.foregroundView = nil
                    }
                }
            }
            
            
            if let foregroundView = foregroundView {
                let zoom = mappingRange(zoom, 0, 1, 0.5, 1)

                let valueScale = CGFloat(truncate(double: Double(zoom), places: 2))
                            
                let rect = foregroundView.bounds
                var fr = CATransform3DIdentity
                fr = CATransform3DTranslate(fr, rect.width / 2, rect.height / 2, 0)
                fr = CATransform3DScale(fr, valueScale, valueScale, 1)
                fr = CATransform3DTranslate(fr, -(rect.width / 2), -(rect.height / 2), 0)
                foregroundView.layer?.transform = fr
            }
            if let foregroundView = foregroundTextView {
                let zoom = mappingRange(zoom, 0, 1, 0.5, 1)

                let valueScale = CGFloat(truncate(double: Double(zoom), places: 2))
                            
                let rect = foregroundView.bounds
                var fr = CATransform3DIdentity
                fr = CATransform3DTranslate(fr, rect.width / 2, rect.height / 2, 0)
                fr = CATransform3DScale(fr, valueScale, valueScale, 1)
                fr = CATransform3DTranslate(fr, -(rect.width / 2), -(rect.height / 2), 0)
                foregroundView.layer?.transform = fr
            }
            
            
            self.previousText = text
            self.previousFile = file
        }

        
        private func applyBg(_ color: AvatarColor, context: AccountContext, animated: Bool) {
            var colors: [NSColor] = []
            switch color.content {
            case let .solid(color):
                colors = [color]
            case let .gradient(c):
                colors = c
            default:
                break
            }
            
            if !colors.isEmpty {
                
                if let view = backgroundPatternView {
                    performSubviewRemoval(view, animated: animated)
                    self.backgroundPatternView = nil
                }
                
                let current: ImageView
                if let view = backgroundColorView {
                    current = view
                } else {
                    current = ImageView(frame: imageView.bounds)
                    self.backgroundColorView = current
                    self.imageView.addSubview(current, positioned: .below, relativeTo: foregroundView ?? foregroundTextView)
                }
                
                current.animates = animated
                
                current.image = generateImage(current.frame.size, contextGenerator: { size, ctx in
                    ctx.clear(size.bounds)
                    let imageRect = size.bounds
                    if colors.count == 1, let color = colors.first {
                        ctx.setFillColor(color.cgColor)
                        ctx.fill(imageRect)
                    } else {
                        let gradientColors = colors.map { $0.cgColor } as CFArray
                        let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
                        
                        var locations: [CGFloat] = []
                        for i in 0 ..< colors.count {
                            locations.append(delta * CGFloat(i))
                        }
                        let colorSpace = CGColorSpaceCreateDeviceRGB()
                        let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
                                            
                        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: imageRect.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                    }
                })
            } else if let wallpaper = color.wallpaper {
                if let view = backgroundColorView {
                    performSubviewRemoval(view, animated: animated)
                    self.backgroundColorView = nil
                }
                
                let current: TransformImageView
                if let view = backgroundPatternView {
                    current = view
                } else {
                    current = TransformImageView(frame: imageView.bounds)
                    self.backgroundPatternView = current
                    self.imageView.addSubview(current, positioned: .below, relativeTo: foregroundView ?? foregroundTextView)
                }
                
                let emptyColor: TransformImageEmptyColor
                
                let colors = wallpaper.settings.colors.compactMap { NSColor($0) }
                
                if colors.count > 1 {
                    let colors = colors.map {
                        return $0.withAlphaComponent($0.alpha == 0 ? 0.5 : $0.alpha)
                    }
                    emptyColor = .gradient(colors: colors, intensity: colors.first!.alpha, rotation: nil)
                } else if let color = colors.first {
                    emptyColor = .color(color)
                } else {
                    emptyColor = .color(NSColor(rgb: 0xd6e2ee, alpha: 0.5))
                }
                
                let arguments = TransformImageArguments(corners: ImageCorners(radius: 0), imageSize: wallpaper.dimensions.aspectFilled(NSMakeSize(300, 300)), boundingSize: current.frame.size, intrinsicInsets: NSEdgeInsets(), emptyColor: emptyColor)
                
                current.set(arguments: arguments)

                switch wallpaper {
                case let .file(_, file, _, _):
                    var representations:[TelegramMediaImageRepresentation] = []
                    if let dimensions = file.dimensions {
                        representations.append(TelegramMediaImageRepresentation(dimensions: dimensions, resource: file.resource, progressiveSizes: [], immediateThumbnailData: nil))
                    } else {
                        representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(current.frame.size), resource: file.resource, progressiveSizes: [], immediateThumbnailData: nil))
                    }
                    
                    let updateImageSignal = chatWallpaper(account: context.account, representations: representations, file: file, mode: .thumbnail, isPattern: true, autoFetchFullSize: true, scale: backingScaleFactor, isBlurred: false, synchronousLoad: false, drawPatternOnly: false, palette: dayClassicPalette)
                    
                    current.setSignal(signal: cachedMedia(media: file, arguments: arguments, scale: backingScaleFactor), clearInstantly: false)
                     
                     if !current.isFullyLoaded {
                         current.setSignal(updateImageSignal, animate: true, cacheImage: { result in
                             cacheMedia(result, media: file, arguments: arguments, scale: System.backingScale)
                         })
                     }
                    
                default:
                    break
                }
            } else {
                if let view = backgroundColorView {
                    performSubviewRemoval(view, animated: animated)
                    self.backgroundColorView = nil
                }
                if let view = backgroundPatternView {
                    performSubviewRemoval(view, animated: animated)
                    self.backgroundPatternView = nil
                }
            }
            
            
        }
        
        override func layout() {
            super.layout()
            textView.centerX(y: 0)
            imageView.centerX(y: textView.frame.maxY + 10)
            backgroundColorView?.frame = imageView.bounds
            backgroundPatternView?.frame = imageView.bounds
            foregroundView?.centerX()
            if let foregroundTextView = foregroundTextView {
                var center = foregroundTextView.centerFrame()
                center.origin.y += 4
                foregroundTextView.setFrameOrigin(center.origin)
            }
            slider.setFrameSize(NSMakeSize(imageView.frame.width, 14))
            slider.centerX(y: imageView.frame.maxY + 20)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
 
    private final class ItemView: Control {
        private let textView = TextView()
        private let player = LottiePlayerView(frame: NSMakeRect(0, 0, 20, 20))
        private var animation: LottieAnimation?
        private var item: State.Item?
        private var select:((State.Item)->Void)? = nil
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(textView)
            addSubview(player)
            
            layer?.cornerRadius = .cornerRadius
            
            scaleOnClick = true
            
            set(background: theme.colors.background, for: .Normal)

            textView.userInteractionEnabled = false
            textView.isEventLess = true
            textView.isSelectable = false
            
            player.isEventLess = true
            player.userInteractionEnabled = false
            
            self.set(handler: { [weak self] _ in
                if let item = self?.item {
                    self?.select?(item)
                }
            }, for: .Click)
            
        }
        
        override func layout() {
            super.layout()
            player.centerY(x: 10)
            textView.centerY(x: player.frame.maxX + 10)
        }
        
        func set(item: State.Item, select: @escaping(State.Item)->Void, animated: Bool) {
            let text = TextViewLayout(.initialize(string: item.title, color: theme.colors.text, font: .normal(.text)))
            text.measure(width: 150)
            textView.update(text)
            
            self.select = select
            self.item = item
            
            if item.selected {
                set(background: theme.colors.grayBackground, for: .Normal)
            } else {
                set(background: theme.colors.background, for: .Normal)
            }
            
            if let data = item.thumb.data {
                let colors:[LottieColor] = [.init(keyPath: "", color: theme.colors.accent)]
                let animation = LottieAnimation(compressed: data, key: LottieAnimationEntryKey(key: .bundle(item.thumb.rawValue), size: player.frame.size), type: .lottie, cachePurpose: .none, playPolicy: .framesCount(1), maximumFps: 60, colors: colors, metalSupport: false)
                self.animation = animation
                player.set(animation, reset: true, saveContext: false, animated: false)
            }
            
            needsLayout = true
        }
        
        override func stateDidUpdate(_ state: ControlState) {
            super.stateDidUpdate(state)
            
            switch state {
            case .Hover:
                if player.animation?.playPolicy == .framesCount(1) {
                    player.set(self.animation?.withUpdatedPolicy(.once), reset: false)
                } else {
                    player.playAgain()
                }
            default:
                break
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private let itemsView: View = View()
    private let previewView: PreviewView
    
    private var state: State?
    
    required init(frame frameRect: NSRect) {
        previewView = PreviewView(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height / 2))
        super.init(frame: frameRect)
        addSubview(itemsView)
        addSubview(previewView)
        border = [.Right]
        borderColor = theme.colors.border
        
        itemsView.layer?.cornerRadius = .cornerRadius
    }
    
    func updateState(_ state: State, arguments: Arguments, animated: Bool) {
        
        
        previewView.updateState(state, arguments: arguments, animated: animated)
        
        let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: self.state?.items ?? [], rightList: state.items)
        
        
        for rdx in deleteIndices.reversed() {
            itemsView.subviews[rdx].removeFromSuperview()
        }
        
        for (idx, item, _) in indicesAndItems {
            let view = ItemView(frame: NSMakeRect(0, CGFloat(idx) * 30, itemsView.frame.width, 30))
            itemsView.addSubview(view, positioned: .above, relativeTo: idx == 0 ? nil : itemsView.subviews[idx - 1])
            view.set(item: item, select: arguments.select, animated: animated)
        }
        for (idx, item, _) in updateIndices {
            let item =  item
            (itemsView.subviews[idx] as? ItemView)?.set(item: item, select: arguments.select, animated: animated)
        }

        self.state = state
        
        self.updateLayout(frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)

    }
    
    override func layout() {
        super.layout()
        self.updateLayout(self.frame.size, transition: .immediate)
    }
    
    func updateLayout(_ size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: itemsView, frame: NSMakeRect(0, 0, size.width, size.height / 2).insetBy(dx: 10, dy: 10))
        
        transition.updateFrame(view: previewView, frame: NSMakeRect(0, size.height / 2, size.width, size.height / 2).insetBy(dx: 10, dy: 10))
        
        
        for (i, itemView) in itemsView.subviews.enumerated() {
            transition.updateFrame(view: itemView, frame: NSMakeRect(0, CGFloat(i) * 30, itemsView.frame.width, 30))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
private final class AvatarRightView: View {
    private final class HeaderView : View {
        let segment: CatalinaStyledSegmentController
        let dismiss = ImageButton()
        
        private var state: State?
        
        required init(frame frameRect: NSRect) {
            segment = CatalinaStyledSegmentController(frame: NSMakeRect(0, 0, frameRect.width, 30))
            super.init(frame: frameRect)
            addSubview(segment.view)
            addSubview(dismiss)
            self.border = [.Bottom]
            borderColor = theme.colors.border
            backgroundColor = theme.colors.background
            segment.theme = CatalinaSegmentTheme(backgroundColor: theme.colors.listBackground, foregroundColor: theme.colors.background, activeTextColor: theme.colors.text, inactiveTextColor: theme.colors.listGrayText)

        }
        
        func updateState(_ state: State, arguments: Arguments, animated: Bool) {
            
            if state.selected.key != self.state?.selected.key {
                segment.removeAll()
                for option in state.selected.options {
                    segment.add(segment: .init(title: option.title, handler: {
                        arguments.selectOption(option)
                    }))
                }
                
            }
            for i in 0 ..< state.selected.options.count {
                if state.selected.options[i].selected {
                    segment.set(selected: i, animated: animated)
                }
            }
            
            dismiss.set(image: theme.icons.modalClose, for: .Normal)
            dismiss.sizeToFit()
            
            dismiss.removeAllHandlers()
            dismiss.set(handler: { _ in
                arguments.dismiss()
            }, for: .Click)
            
            self.state = state
            
            needsLayout = true
        }
        
        override func layout() {
            super.layout()
            segment.view.setFrameSize(frame.width - 140, 30)
            segment.view.center()
            dismiss.centerY(x: frame.width - dismiss.frame.width - 10)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private let headerView = HeaderView(frame: .zero)
    private let bottomView = TitleButton(frame: .zero)
    private let content = View()
    
    private var state: State?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(headerView)
        addSubview(bottomView)
        addSubview(content)
        content.backgroundColor = theme.colors.listBackground
        bottomView.border = [.Top]
        bottomView.backgroundColor = theme.colors.background
        self.bottomView.autohighlight = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func layout() {
        super.layout()
        self.updateLayout(self.frame.size, transition: .immediate)
    }
    
    func updateState(_ state: State, arguments: Arguments, animated: Bool) {
        self.headerView.updateState(state, arguments: arguments, animated: animated)
        
        self.updateContent(state, previous: self.state, arguments: arguments, animated: animated)
        
        self.bottomView.set(text: strings().modalSet, for: .Normal)
        self.bottomView.set(font: .medium(.text), for: .Normal)
        self.bottomView.set(color: theme.colors.accent, for: .Normal)
        
        bottomView.removeAllHandlers()
        bottomView.set(handler: { _ in
            arguments.set()
        }, for: .Click)
        
        self.state = state
        needsLayout = true
    }

    
    private func updateContent(_ state: State, previous: State?, arguments: Arguments, animated: Bool) {
        if state.selected != previous?.selected {
            if let content = content.subviews.last, let previous = previous {
                if makeContentView(state.selected) != makeContentView(previous.selected) {
                    performSubviewRemoval(content, animated: animated)
                    
                    let content = makeContentView(state.selected)
                    let initiedContent = content.init(frame: self.content.bounds)
                    
                    self.content.addSubview(initiedContent)
                    if animated {
                        initiedContent.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                }
            } else {
                let content = makeContentView(state.selected)
                let initiedContent = content.init(frame: self.content.bounds)
                
                self.content.addSubview(initiedContent)
            }
        }
        
        if let content = self.content.subviews.last as? Avatar_EmojiListView {
            content.set(list: state.emojies, context: arguments.context, selectForeground: arguments.selectForeground, animated: animated)
        } else if let content = self.content.subviews.last as? Avatar_BgListView {
            content.set(colors: state.colors, context: arguments.context, select: arguments.selectColor, animated: animated)
        } else if let content = self.content.subviews.last as? Avatar_MonogramView {
            content.set(text: state.selected.text, updateText: arguments.updateText, animated: animated)
        }
            
    }
    
    private func makeContentView(_ item: State.Item) -> View.Type {
        if item.selectedOption.key == "b" {
            return Avatar_BgListView.self
        } else if item.key == "e" {
            return Avatar_EmojiListView.self
        } else if item.key == "m" {
            return Avatar_MonogramView.self
        } else {
            return View.self
        }
    }
    
    func updateLayout(_ size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: headerView, frame: NSMakeRect(0, 0, size.width, 50))
        transition.updateFrame(view: bottomView, frame: NSMakeRect(0, size.height - 50, size.width, 50))
        transition.updateFrame(view: content, frame: NSMakeRect(0, headerView.frame.height, size.width, size.height - headerView.frame.height - bottomView.frame.height))
        
        for subview in content.subviews {
            transition.updateFrame(view: subview, frame: content.bounds)
        }
    }
    
    var firstResponder: NSResponder? {
        if let view = self.content.subviews.last as? Avatar_MonogramView {
            return view.firstResponder
        }
        return content.subviews.last
        
    }
}

 
private final class AvatarConstructorView : View {
    private let leftView: AvatarLeftView = AvatarLeftView(frame: .zero)
    private let rightView: AvatarRightView = AvatarRightView(frame: .zero)
    
    private var state: State?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(leftView)
        addSubview(rightView)
        updateLayout(frameRect.size, transition: .immediate)
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(self.frame.size, transition: .immediate)
    }
    
    func updateLayout(_ size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: leftView, frame: NSMakeRect(0, 0, 180, frame.height))
        leftView.updateLayout(leftView.frame.size, transition: transition)
        
        transition.updateFrame(view: rightView, frame: NSMakeRect(leftView.frame.maxX, 0, size.width - leftView.frame.width, frame.height))
        rightView.updateLayout(rightView.frame.size, transition: transition)
    }
    
    func updateState(_ state: State, arguments: Arguments, animated: Bool) {
        self.state = state
        self.leftView.updateState(state, arguments: arguments, animated: animated)
        self.rightView.updateState(state, arguments: arguments, animated: animated)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var firstResponder: NSResponder? {
        return self.rightView.firstResponder
    }
}


final class AvatarConstructorController : ModalViewController {
    enum Target {
        case avatar
        case peer(PeerId)
    }
    private let context: AccountContext
    private let target: Target
    private let disposable = MetaDisposable()
    
    private var contextObject: AnyObject?
    private let videoSignal:(MediaObjectToAvatar)->Void
    
    init(_ context: AccountContext, target: Target, videoSignal:@escaping(MediaObjectToAvatar)->Void) {
        self.context = context
        self.target = target
        self.videoSignal = videoSignal
        super.init(frame: NSMakeRect(0, 0, 350, 450))
        bar = .init(height: 0)
    }
    
    override func measure(size: NSSize) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with: effectiveSize(contentSize), animated: false)
        }
    }
    
    func effectiveSize(_ size: NSSize) -> NSSize {
        let updated = size - NSMakeSize(50, 20)
        return NSMakeSize(min(updated.width, 540), min(updated.height, 540))
    }
    
    func updateSize(_ animated: Bool) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with: effectiveSize(contentSize), animated: animated)
        }
    }
    
    
    override var dynamicSize: Bool {
        return true
    }
    
    override func viewClass() -> AnyClass {
        return AvatarConstructorView.self
    }
    
    private var genericView: AvatarConstructorView {
        return self.view as! AvatarConstructorView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let context = self.context
        
        let actionsDisposable = DisposableSet()
        
        onDeinit = {
            actionsDisposable.dispose()
        }

        let initialState = State.init(items: [])
        
        let statePromise = ValuePromise(initialState, ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((State) -> State) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }

        updateState { current in
            var current = current
            
            current.items.append(.init(key: "e", index: 0, title: "Emoji", thumb: MenuAnimation.menu_smile, selected: true, options: [
                    .init(key: "e", title: "Emoji", selected: true),
                    .init(key: "b", title: "Background", selected: false)
            ]))
            
            current.items.append(.init(key: "s", index: 1, title: "Sticker", thumb: MenuAnimation.menu_view_sticker_set, selected: false, options: [
                    .init(key: "s", title: "Sticker", selected: true),
                    .init(key: "b", title: "Background", selected: false)
            ]))
            
            current.items.append(.init(key: "m", index: 2, title: "Monogram", thumb: MenuAnimation.menu_monogram, selected: false, options: [
                    .init(key: "t", title: "Text", selected: true),
                    .init(key: "b", title: "Background", selected: false)
            ]))
            
            var colors: [AvatarColor] = []
            colors.append(.init(selected: false, content: .gradient([dayClassicPalette.peerColors(0).top, dayClassicPalette.peerColors(0).bottom])))
            colors.append(.init(selected: true, content: .gradient([dayClassicPalette.peerColors(1).top, dayClassicPalette.peerColors(1).bottom])))
            colors.append(.init(selected: false, content: .gradient([dayClassicPalette.peerColors(2).top, dayClassicPalette.peerColors(2).bottom])))
            colors.append(.init(selected: false, content: .gradient([dayClassicPalette.peerColors(3).top, dayClassicPalette.peerColors(3).bottom])))
            colors.append(.init(selected: false, content: .gradient([dayClassicPalette.peerColors(4).top, dayClassicPalette.peerColors(4).bottom])))
            colors.append(.init(selected: false, content: .gradient([dayClassicPalette.peerColors(5).top, dayClassicPalette.peerColors(5).bottom])))
            colors.append(.init(selected: false, content: .gradient([dayClassicPalette.peerColors(6).top, dayClassicPalette.peerColors(6).bottom])))

            current.colors = colors
            
            return current
        }
        
        let emojies = context.engine.stickers.loadedStickerPack(reference: .animatedEmoji, forceActualized: false)
                
        let wallpapers = telegramWallpapers(postbox: context.account.postbox, network: context.account.network) |> map { wallpapers -> [Wallpaper] in
            return wallpapers.compactMap { wallpaper in
                switch wallpaper {
                case let .file(file):
                    return file.isPattern ? Wallpaper(wallpaper) : nil
                default:
                    return nil
                }
            }
        } |> deliverOnMainQueue
        
        let peerId: PeerId
        switch self.target {
        case .avatar:
            peerId = context.peerId
        case let .peer(pid):
            peerId = pid
        }
        
        let _video:(MediaObjectToAvatar)->Void = { [weak self] convertor in
            self?.videoSignal(convertor)
            self?.close()
        }
        
        let peer = context.account.postbox.loadedPeerWithId(peerId)
        
        actionsDisposable.add(combineLatest(wallpapers, emojies, peer).start(next: { wallpapers, pack, peer in
                        
            switch pack {
            case let .result(_, items, _):
                updateState { current in
                    var current = current
                    current.emojies = items
                    var itms = current.items
                    for i in 0 ..< itms.count {
                        var item = itms[i]
                        if item.key == "e" {
                            item.foreground = items.first(where: { $0.file.stickerText == "🤖" })?.file ?? items.first?.file
                        } else if item.key == "m" {
                            item.text = peer.displayLetters.joined()
                        }
                        itms[i] = item
                    }
                    current.items = itms
                    current.colors += wallpapers.map { .init(selected: false, content: .wallpaper($0)) }
                    return current
                }
            default:
                break
            }
        }))
        
        let arguments = Arguments(context: context, dismiss: { [weak self] in
            self?.close()
        }, select: { selected in
            updateState { current in
                var current = current
                var items = current.items
                for i in 0 ..< items.count {
                    var item = items[i]
                    item.selected = false
                    if selected.key == item.key {
                        item.selected = true
                    }
                    items[i] = item
                }
                current.items = items
                return current
            }
        }, selectOption: { selected in
            updateState { current in
                var current = current
                var items = current.items
                for i in 0 ..< items.count {
                    var item = items[i]
                    if item.selected {
                        for j in 0 ..< item.options.count {
                            var option = item.options[j]
                            option.selected = option.key == selected.key
                            item.options[j] = option
                        }
                    }
                    items[i] = item
                }
                current.items = items
                return current
            }
        }, selectColor: { selected in
            updateState { current in
                var current = current
                for i in 0 ..< current.colors.count {
                    var color = current.colors[i]
                    color.selected = color.content == selected.content
                    current.colors[i] = color
                }
                return current
            }
        }, selectForeground: { file in
            updateState { current in
                var current = current
                var items = current.items
                for i in 0 ..< items.count {
                    var item = items[i]
                    if item.selected {
                        item.foreground = file
                    }
                    items[i] = item
                }
                current.items = items
                return current
            }
        }, set: {
            let state = stateValue.with { $0 }
            if let file = state.selected.foreground {
                let background:MediaObjectToAvatar.Object.Background
                let source: MediaObjectToAvatar.Object.Foreground.Source
                switch state.selectedColor.content {
                case let .gradient(colors):
                    background = .colors(colors)
                case let .solid(color):
                    background = .colors([color])
                case let .wallpaper(wallpaper):
                    background = .pattern(wallpaper)
                }
                if file.isAnimated && file.isVideo {
                    source = .gif(file)
                } else if file.isAnimatedSticker {
                    source = .animated(file)
                } else {
                    source = .sticker(file)
                }
                
                let zoom = mappingRange(state.preview.zoom, 0, 1, 0.5, 0.8)
                let object = MediaObjectToAvatar(context: context, object: .init(foreground: .init(type: source, zoom: zoom), background: background))
                _video(object)
            }
        }, zoom: { value in
            updateState { current in
                var current = current
                current.preview.zoom = value
                return current
            }
        }, updateText: { text in
            updateState { current in
                var current = current
                var items = current.items
                for i in 0 ..< items.count {
                    var item = items[i]
                    if item.selected {
                        item.text = text
                    }
                    items[i] = item
                }
                current.items = items
                return current
            }
        })
        
        let signal = statePromise.get() |> deliverOnMainQueue
        
        let first: Atomic<Bool> = Atomic(value: true)
        
        disposable.set(signal.start(next: { [weak self] state in
            self?.genericView.updateState(state, arguments: arguments, animated: !first.swap(false))
        }))
        
        readyOnce()
    }
    
    override var canBecomeResponder: Bool {
        return true
    }
    override func firstResponder() -> NSResponder? {
        return genericView.firstResponder
    }
}
