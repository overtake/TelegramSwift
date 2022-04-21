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

private final class Arguments {
    let context: AccountContext
    let dismiss:()->Void
    let select:(State.Item)->Void
    let selectOption:(State.Item.Option)->Void
    let selectColor:(AvatarColor)->Void
    init(context: AccountContext, dismiss:@escaping()->Void, select:@escaping(State.Item)->Void, selectOption:@escaping(State.Item.Option)->Void, selectColor:@escaping(AvatarColor)->Void) {
        self.context = context
        self.dismiss = dismiss
        self.select = select
        self.selectOption = selectOption
        self.selectColor = selectColor
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
    var preview: Preview?
    
    
    var emojies:[StickerPackItem] = []
    var colors: [AvatarColor] = []
    var selected: Item {
        return self.items.first(where: { $0.selected })!
    }
}


private final class AvatarLeftView: View {
    
    private final class PreviewView: View {
        private let imageView: View = View(frame: NSMakeRect(0, 0, 150, 150))
        private let textView = TextView()
        private var state: State?
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(textView)
            addSubview(imageView)
            imageView.layer?.cornerRadius = imageView.frame.height / 2
            
            let text = TextViewLayout(.initialize(string: strings().avatarPreview, color: theme.colors.grayText, font: .normal(.text)))
            text.measure(width: .greatestFiniteMagnitude)
            textView.update(text)
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            imageView.backgroundColor = .random
        }
        
        func updateState(_ state: State, arguments: Arguments, animated: Bool) {
            self.state = state
        }
        
        override func layout() {
            super.layout()
            textView.centerX(y: 0)
            imageView.centerX(y: textView.frame.maxY + 10)
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
            content.set(list: state.emojies, context: arguments.context, animated: animated)
        } else if let content = self.content.subviews.last as? Avatar_BgListView {
            content.set(colors: state.colors, context: arguments.context, select: arguments.selectColor, animated: animated)
        }
            
    }
    
    private func makeContentView(_ item: State.Item) -> View.Type {
        if item.selectedOption.key == "b" {
            return Avatar_BgListView.self
        } else if item.key == "e" {
            return Avatar_EmojiListView.self
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
}


final class AvatarConstructorController : ModalViewController {
    enum Target {
        case avatar
        case peer(PeerId)
    }
    private let context: AccountContext
    private let target: Target
    private let disposable = MetaDisposable()
    init(_ context: AccountContext, target: Target) {
        self.context = context
        self.target = target
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
        
        let actionsDisposable = DisposableSet()
        
        onDeinit = {
            actionsDisposable.dispose()
        }

        let initialState = State.init(items: [], preview: nil)
        
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
            
            current.items.append(.init(key: "m", index: 2, title: "Monogram", thumb: MenuAnimation.menu_create_group, selected: false, options: [
                    .init(key: "t", title: "Text", selected: true),
                    .init(key: "b", title: "Background", selected: false)
            ]))
            
            var colors: [AvatarColor] = []
            colors.append(.init(selected: true, content: .gradient([dayClassicPalette.peerColors(0).top, dayClassicPalette.peerColors(0).bottom])))
            colors.append(.init(selected: false, content: .gradient([dayClassicPalette.peerColors(1).top, dayClassicPalette.peerColors(1).bottom])))
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
        
        actionsDisposable.add(combineLatest(wallpapers, emojies).start(next: { wallpapers, pack in
                        
            switch pack {
            case let .result(_, items, _):
                updateState { current in
                    var current = current
                    current.emojies = items
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
        })
        
        let signal = statePromise.get() |> deliverOnMainQueue
        
        let first: Atomic<Bool> = Atomic(value: true)
        
        disposable.set(signal.start(next: { [weak self] state in
            self?.genericView.updateState(state, arguments: arguments, animated: !first.swap(false))
        }))
        
        readyOnce()
    }
}
