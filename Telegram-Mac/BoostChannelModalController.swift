//
//  BoostChannelModalController.swift
//  Telegram
//
//  Created by Mike Renoir on 03.09.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private final class Arguments {
    let context: AccountContext
    let boost:()->Void
    init(context: AccountContext, boost:@escaping()->Void) {
        self.context = context
        self.boost = boost
    }
}

private struct State : Equatable {
    var peer: PeerEquatable
    var currentLevel: Int32 = 0
    var currentBoosts: Int32 = 0
    var boostsToNextLevel: Int32 = 10
    var boosted: Bool = false
    var percentToNext: CGFloat {
        return CGFloat(currentBoosts) / CGFloat(boostsToNextLevel)
    }
}



private final class BoostRowItem : TableRowItem {
    fileprivate let context: AccountContext
    fileprivate let state: State
    fileprivate let text: TextViewLayout
    fileprivate let boost:()->Void
    init(_ initialSize: NSSize, state: State, context: AccountContext, boost:@escaping()->Void) {
        self.context = context
        self.state = state
        self.boost = boost
        if state.boosted {
            self.text = .init(.initialize(string: "You Boosted this channel", color: theme.colors.text, font: .normal(.text)), alignment: .center)
        } else {
            self.text = .init(.initialize(string: "\(state.peer.peer.displayTitle) needs 3 more boosts to enable posting stories. Help make it possible!", color: theme.colors.text, font: .normal(.text)), alignment: .center)
        }

        super.init(initialSize)
        _ = makeSize(initialSize.width)
    }
    
    override var stableId: AnyHashable {
        return 0
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        text.measure(width: width - 40)

        return true
    }
    
    override var height: CGFloat {
        var height: CGFloat = 0
                        
        height += 100
        height += 20
        
        height += 50
        
        height += text.layoutSize.height
        height += 20

        height += 40 //button
        height += 20
        
        return height
    }
    
    override func viewClass() -> AnyClass {
        return BoostRowItemView.self
    }
}

private final class BoostRowItemView : TableRowView {
   

    private class ChannelView : View {
        private let avatar = AvatarControl(font: .avatar(12))
        private let textView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(avatar)
            addSubview(textView)
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            avatar.setFrameSize(NSMakeSize(30, 30))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(_ peer: Peer, context: AccountContext, maxWidth: CGFloat) {
            self.avatar.setPeer(account: context.account, peer: peer)
            
            let layout = TextViewLayout.init(.initialize(string: peer.displayTitle, color: theme.colors.text, font: .normal(.text)))
            layout.measure(width: maxWidth - 40)
            textView.update(layout)
            self.backgroundColor = theme.colors.grayBackground
            
            self.setFrameSize(NSMakeSize(layout.layoutSize.width + 10 + avatar.frame.width + 10, 30))
            
            self.layer?.cornerRadius = frame.height / 2
        }
        
        override func layout() {
            super.layout()
            textView.centerY(x: avatar.frame.maxX + 10)
        }
    }
    
    private class LineView: View {
        
        private let currentLevel = TextView()
        private let nextLevel = TextView()

        private let nextLevel_background = View()
        private let currentLevel_background = PremiumGradientView(frame: .zero)
        
        private var state: State?
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(nextLevel_background)
            addSubview(currentLevel_background)
            addSubview(nextLevel)
            addSubview(currentLevel)
            nextLevel.userInteractionEnabled = false
            currentLevel.userInteractionEnabled = false
            
            nextLevel.isSelectable = false
            currentLevel.isSelectable = false
        }
        
        func update(_ state: State, context: AccountContext, transition: ContainedViewLayoutTransition) {
            
            self.state = state
            
            let normalCountLayout = TextViewLayout(.initialize(string: "Level \(state.currentLevel)", color: theme.colors.text, font: .medium(13)))
            normalCountLayout.measure(width: .greatestFiniteMagnitude)

            currentLevel.update(normalCountLayout)

            
            let premiumCountLayout = TextViewLayout(.initialize(string: "Level \(state.currentLevel + 1)", color: .white, font: .medium(13)))
            premiumCountLayout.measure(width: .greatestFiniteMagnitude)

            nextLevel.update(premiumCountLayout)
            
            nextLevel_background.backgroundColor = theme.colors.grayForeground
            
            self.updateLayout(size: self.frame.size, transition: transition)
        }
        
        func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
            guard let state = self.state else {
                return
            }
            
            let width = frame.width * state.percentToNext

            transition.updateFrame(view: currentLevel, frame: currentLevel.centerFrameY(x: 10))
            transition.updateFrame(view: nextLevel, frame: nextLevel.centerFrameY(x: bounds.width - 10 - nextLevel.frame.width))

            transition.updateFrame(view: nextLevel_background, frame: NSMakeRect(width, 0, size.width - width, frame.height))
            transition.updateFrame(view: currentLevel_background, frame: NSMakeRect(0, 0, width, frame.height))
            
        }
        
        override func layout() {
            super.layout()
            self.updateLayout(size: self.frame.size, transition: .immediate)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private final class AcceptView : Control {
        private let gradient: PremiumGradientView = PremiumGradientView(frame: .zero)
        private let textView = TextView()
        private let imageView = LottiePlayerView(frame: NSMakeRect(0, 0, 24, 24))
        private let container = View()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(gradient)
            container.addSubview(textView)
            container.addSubview(imageView)
            addSubview(container)
            scaleOnClick = true
            
            textView.userInteractionEnabled = false
            textView.isSelectable = false
        }
        
        override func layout() {
            super.layout()
            gradient.frame = bounds
            container.center()
            imageView.centerY(x: 0)
            textView.centerY(x: imageView.frame.maxX)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(lottie: LocalAnimatedSticker) {
            
            let layout = TextViewLayout(.initialize(string: "Boost Channel", color: NSColor.white, font: .medium(.text)))
            layout.measure(width: .greatestFiniteMagnitude)
            textView.update(layout)
            
            if let data = lottie.data {
                let colors:[LottieColor] = [.init(keyPath: "", color: NSColor(0xffffff))]
                imageView.set(LottieAnimation(compressed: data, key: .init(key: .bundle("bundle_\(lottie.rawValue)"), size: NSMakeSize(24, 24), colors: colors), cachePurpose: .temporaryLZ4(.thumb), playPolicy: .loop, maximumFps: 60, colors: colors, runOnQueue: .mainQueue()))
            }
                        
            container.setFrameSize(NSMakeSize(layout.layoutSize.width + imageView.frame.width, max(layout.layoutSize.height, imageView.frame.height)))
                        
            needsLayout = true
            
        }
    }
    
    private class TypeView : View {
        private let backgrounView = ImageView()
        
        private let textView = DynamicCounterTextView(frame: .zero)
        private let imageView = ImageView()
        private let container = View()
        
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(backgrounView)
            container.addSubview(textView)
            container.addSubview(imageView)
            addSubview(container)
            
            textView.userInteractionEnabled = false
        }
        
        override func layout() {
            super.layout()
            backgrounView.frame = bounds
            container.centerX()
            imageView.centerY(x: -3)
            textView.centerY(x: imageView.frame.maxX)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        
        func update(state: State, context: AccountContext, transition: ContainedViewLayoutTransition) -> NSSize {
            
            let dynamicValue = DynamicCounterTextView.make(for: "\(state.currentBoosts)", count: "\(state.currentBoosts)", font: .avatar(20), textColor: .white, width: .greatestFiniteMagnitude)
            
            textView.update(dynamicValue, animated: transition.isAnimated)
            transition.updateFrame(view: textView, frame: CGRect(origin: textView.frame.origin, size: dynamicValue.size))
            
            imageView.image = NSImage(named: "Icon_Boost_Lighting")?.precomposed()
            imageView.sizeToFit()
            
            container.setFrameSize(NSMakeSize(dynamicValue.size.width + imageView.frame.width, 40))
            
            let canPremium = !context.premiumIsBlocked
            
            let size = NSMakeSize(container.frame.width + 20, canPremium ? 50 : 40)
            
            let image = generateImage(NSMakeSize(size.width, canPremium ? size.height - 10 : size.height), contextGenerator: { size, ctx in
                ctx.clear(size.bounds)
               
                let path = CGMutablePath()
                path.addRoundedRect(in: NSMakeRect(0, 0, size.width, size.height), cornerWidth: size.height / 2, cornerHeight: size.height / 2)
                
                ctx.addPath(path)
                ctx.setFillColor(NSColor.black.cgColor)
                ctx.fillPath()
                
            })!
            
            let corner = generateImage(NSMakeSize(30, 10), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(NSColor.black.cgColor)
                context.scaleBy(x: 0.333, y: 0.333)
                let _ = try? drawSvgPath(context, path: "M85.882251,0 C79.5170552,0 73.4125613,2.52817247 68.9116882,7.02834833 L51.4264069,24.5109211 C46.7401154,29.1964866 39.1421356,29.1964866 34.4558441,24.5109211 L16.9705627,7.02834833 C12.4696897,2.52817247 6.36519576,0 0,0 L85.882251,0 ")
                context.fillPath()
            })!

            let clipImage = generateImage(size, rotatedContext: { size, ctx in
                ctx.clear(size.bounds)
                ctx.draw(image, in: NSMakeRect(0, 0, image.backingSize.width, image.backingSize.height))
                
                ctx.draw(corner, in: NSMakeRect(size.bounds.focus(corner.backingSize).minX, image.backingSize.height, corner.backingSize.width, corner.backingSize.height))
            })!
            
            let fullImage = generateImage(size, contextGenerator: { size, ctx in
                ctx.clear(size.bounds)

                if !canPremium {
                    ctx.clip(to: size.bounds, mask: image)
                    ctx.setFillColor(theme.colors.accent.cgColor)
                    ctx.fill(size.bounds)
                } else {
                    ctx.clip(to: size.bounds, mask: clipImage)
                    
                    let colors = premiumGradient.compactMap { $0?.cgColor } as NSArray
                    
                    let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
                    
                    var locations: [CGFloat] = []
                    for i in 0 ..< colors.count {
                        locations.append(delta * CGFloat(i))
                    }
                    let colorSpace = deviceColorSpace
                    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: &locations)!
                    
                    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: size.width, y: size.height), options: CGGradientDrawingOptions())
                }
            })!
            
            self.backgrounView.image = fullImage
            
            
            needsLayout = true
            
            return size
        }

    }
    

    private let headerBg = View()
    private let lineView = LineView(frame: .zero)
    private let button = AcceptView(frame: .zero)
    private let top = TypeView(frame: .zero)
    private let channel = ChannelView(frame: .zero)
    
    
    private var text: TextView?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(channel)
        addSubview(headerBg)
        headerBg.addSubview(top)
        headerBg.addSubview(lineView)
        addSubview(button)
        
        
        
        

        
        button.set(handler: { [weak self] _ in
            if let item = self?.item as? BoostRowItem {
                item.boost()
            }
        }, for: .Click)
        
        button.scaleOnClick = true
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? BoostRowItem else {
            return
        }
        
        if self.text?.textLayout?.attributedString.string != item.text.attributedString.string {
            if let view = self.text {
                performSubviewRemoval(view, animated: animated, scale: true)
                self.text = nil
            }
            let text: TextView = TextView()
            text.userInteractionEnabled = false
            text.isSelectable = false
            self.text = text
            addSubview(text)
            text.frame = text.centerFrameX(y: frame.height - 20 - 30 - text.frame.height - 20)
            text.update(item.text)
            if animated {
                text.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                text.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2)
            }
        }
       
        
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        
        channel.update(item.state.peer.peer, context: item.context, maxWidth: frame.width - 40)
        
        button.update(lottie: .menu_lighting)
        
        button.setFrameSize(NSMakeSize(frame.width - 40, 40))
        button.layer?.cornerRadius = 10
        
        lineView.update(item.state, context: item.context, transition: transition)
        lineView.setFrameSize(NSMakeSize(frame.width - 40, 30))
        lineView.layer?.cornerRadius = 10
        
        let size = top.update(state: item.state, context: item.context, transition: transition)
        top.setFrameSize(size)

        headerBg.setFrameSize(NSMakeSize(lineView.frame.width, top.frame.height + lineView.frame.height + 10))
        
      
        updateLayout(size: self.frame.size, transition: transition)
    }
    
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        guard let item = self.item as? BoostRowItem else {
            return
        }
        
        transition.updateFrame(view: channel, frame: channel.centerFrameX(y: 10))
        
        transition.updateFrame(view: headerBg, frame: headerBg.centerFrameX(y: channel.frame.maxY + 20))
        transition.updateFrame(view: lineView, frame: lineView.centerFrameX(y: headerBg.frame.height - lineView.frame.height))

        transition.updateFrame(view: top, frame: CGRect.init(origin: NSMakePoint(max(min(headerBg.frame.width * item.state.percentToNext - top.frame.width / 2, headerBg.frame.width - top.frame.width), 0), lineView.frame.minY - top.frame.height - 10), size: top.frame.size))

        transition.updateFrame(view: button, frame: button.centerFrameX(y: size.height - button.frame.height - 20))
        if let text = text {
            transition.updateFrame(view: text, frame: text.centerFrameX(y: button.frame.minY - text.frame.height - 20))
        }
        
    }
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    entries.append(.custom(sectionId: 0, index: 0, value: .none, identifier: .init("whole"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return BoostRowItem(initialSize, state: state, context: arguments.context, boost: arguments.boost)
    }))
    
    return entries
}

func BoostChannelModalController(context: AccountContext, peer: Peer) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(peer: .init(peer))
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    var close:(()->Void)? = nil
    
    let arguments = Arguments(context: context, boost: {
        updateState { current in
            var current = current
            current.currentBoosts += 1
            current.boosted = true
            return current
        }
        PlayConfetti(for: context.window)
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Enable Stories For Channel")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    let modalController = InputDataModalController(controller, modalInteractions: nil)
    
    modalController.getModalTheme = {
        return .init(text: theme.colors.text, grayText: theme.colors.grayText, background: theme.colors.listBackground, border: .clear, accent: theme.colors.accent, grayForeground: theme.colors.grayForeground)
    }
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: {
        close?()
    })
    
    close = { [weak modalController] in
        modalController?.close()
    }
    
    controller.afterViewDidLoad = {
        DispatchQueue.main.async {
            updateState { current in
                var current = current
                current.currentBoosts += 4
                return current
            }
        }
    }
    
    return modalController
}


