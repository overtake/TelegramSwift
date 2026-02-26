//
//  Star_ReactionsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01.07.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import SwiftSignalKit
import Postbox
import TGUIKit

private let gradient = [NSColor(0xFFAC04), NSColor(0xFFCA35)]


private final class BadgeStarsViewEffect: View {
    private let staticEmitterLayer = CAEmitterLayer()
    private let dynamicEmitterLayer = CAEmitterLayer()
    
    required init(frame: CGRect) {
        super.init(frame: frame)
        
        self.layer?.addSublayer(self.staticEmitterLayer)
        self.layer?.addSublayer(self.dynamicEmitterLayer)
    }
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
        
    private func setupEmitter() {
        let color = NSColor(rgb: 0xffbe27)
        
        self.staticEmitterLayer.emitterShape = .circle
        self.staticEmitterLayer.emitterSize = CGSize(width: 10.0, height: 5.0)
        self.staticEmitterLayer.emitterMode = .outline
        self.layer?.addSublayer(self.staticEmitterLayer)
        
        self.dynamicEmitterLayer.birthRate = 0.0
        self.dynamicEmitterLayer.emitterShape = .circle
        self.dynamicEmitterLayer.emitterSize = CGSize(width: 10.0, height: 55.0)
        self.dynamicEmitterLayer.emitterMode = .surface
        self.layer?.addSublayer(self.dynamicEmitterLayer)
        
        let staticEmitter = CAEmitterCell()
        staticEmitter.name = "emitter"
        staticEmitter.contents = NSImage(resource: .starReactionParticle).precomposed(.white)
        staticEmitter.birthRate = 20.0
        staticEmitter.lifetime = 2.7
        staticEmitter.velocity = 30.0
        staticEmitter.velocityRange = 3
        staticEmitter.scale = 0.15
        staticEmitter.scaleRange = 0.08
        staticEmitter.emissionRange = .pi * 2.0
        staticEmitter.setValue(3.0, forKey: "mass")
        staticEmitter.setValue(2.0, forKey: "massRange")
        
        let dynamicEmitter = CAEmitterCell()
        dynamicEmitter.name = "emitter"
        dynamicEmitter.contents = NSImage(resource: .starReactionParticle).precomposed(.white)
        dynamicEmitter.birthRate = 0.0
        dynamicEmitter.lifetime = 2.7
        dynamicEmitter.velocity = 30.0
        dynamicEmitter.velocityRange = 3
        dynamicEmitter.scale = 0.15
        dynamicEmitter.scaleRange = 0.08
        dynamicEmitter.emissionRange = .pi / 3.0
        dynamicEmitter.setValue(3.0, forKey: "mass")
        dynamicEmitter.setValue(2.0, forKey: "massRange")
        
        let staticColors: [Any] = [
            NSColor.white.withAlphaComponent(0.0).cgColor,
            NSColor.white.withAlphaComponent(0.35).cgColor,
            color.cgColor,
            color.cgColor,
            color.withAlphaComponent(0.0).cgColor
        ]
        let staticColorBehavior = createEmitterBehavior(type: "colorOverLife")
        staticColorBehavior.setValue(staticColors, forKey: "colors")
        staticEmitter.setValue([staticColorBehavior], forKey: "emitterBehaviors")
        
        let dynamicColors: [Any] = [
            NSColor.white.withAlphaComponent(0.35).cgColor,
            color.withAlphaComponent(0.85).cgColor,
            color.cgColor,
            color.cgColor,
            color.withAlphaComponent(0.0).cgColor
        ]
        let dynamicColorBehavior = createEmitterBehavior(type: "colorOverLife")
        dynamicColorBehavior.setValue(dynamicColors, forKey: "colors")
        dynamicEmitter.setValue([dynamicColorBehavior], forKey: "emitterBehaviors")
        
        let attractor = createEmitterBehavior(type: "simpleAttractor")
        attractor.setValue("attractor", forKey: "name")
        attractor.setValue(20, forKey: "falloff")
        attractor.setValue(35, forKey: "radius")
        self.staticEmitterLayer.setValue([attractor], forKey: "emitterBehaviors")
        self.staticEmitterLayer.setValue(4.0, forKeyPath: "emitterBehaviors.attractor.stiffness")
        self.staticEmitterLayer.setValue(false, forKeyPath: "emitterBehaviors.attractor.enabled")
        
        self.staticEmitterLayer.emitterCells = [staticEmitter]
        self.dynamicEmitterLayer.emitterCells = [dynamicEmitter]
    }
    
    func update(speed: Float, delta: Float? = nil) {
        if speed > 0.0 {
            if self.dynamicEmitterLayer.birthRate.isZero {
                self.dynamicEmitterLayer.beginTime = CACurrentMediaTime()
            }
            
            self.dynamicEmitterLayer.setValue(Float(20.0 + speed * 1.4), forKeyPath: "emitterCells.emitter.birthRate")
            self.dynamicEmitterLayer.setValue(2.7 - min(1.1, 1.5 * speed / 120.0), forKeyPath: "emitterCells.emitter.lifetime")
            self.dynamicEmitterLayer.setValue(30.0 + CGFloat(speed / 80.0), forKeyPath: "emitterCells.emitter.velocity")
            
            if let delta, speed > 15.0 {
                self.dynamicEmitterLayer.setValue(delta > 0 ? .pi : 0, forKeyPath: "emitterCells.emitter.emissionLongitude")
                self.dynamicEmitterLayer.setValue(.pi / 2.0, forKeyPath: "emitterCells.emitter.emissionRange")
            } else {
                self.dynamicEmitterLayer.setValue(0.0, forKeyPath: "emitterCells.emitter.emissionLongitude")
                self.dynamicEmitterLayer.setValue(.pi * 2.0, forKeyPath: "emitterCells.emitter.emissionRange")
            }
            self.staticEmitterLayer.setValue(true, forKeyPath: "emitterBehaviors.attractor.enabled")
            
            self.dynamicEmitterLayer.birthRate = 1.0
            self.staticEmitterLayer.birthRate = 0.0
        } else {
            self.dynamicEmitterLayer.birthRate = 0.0
            
            if let staticEmitter = self.staticEmitterLayer.emitterCells?.first {
                staticEmitter.beginTime = CACurrentMediaTime()
            }
            self.staticEmitterLayer.birthRate = 1.0
            self.staticEmitterLayer.setValue(false, forKeyPath: "emitterBehaviors.attractor.enabled")
        }
    }
    
    func update(size: CGSize, emitterPosition: CGPoint) {
        if self.staticEmitterLayer.emitterCells == nil {
            self.setupEmitter()
        }
        
        self.staticEmitterLayer.frame = CGRect(origin: .zero, size: size)
        self.staticEmitterLayer.emitterPosition = emitterPosition
        
        self.dynamicEmitterLayer.frame = CGRect(origin: .zero, size: size)
        self.dynamicEmitterLayer.emitterPosition = emitterPosition
        self.staticEmitterLayer.setValue(emitterPosition, forKeyPath: "emitterBehaviors.attractor.position")
    }
}


private final class Arguments {
    let context: AccountContext
    let dismiss:()->Void
    let react:()->Void
    let updateValue:(Int64)->Void
    let openPeer:(EnginePeer)->Void
    let toggleShowInTop:()->Void
    let toggleSendAs:(EnginePeer)->Void
    init(context: AccountContext, dismiss:@escaping()->Void, react:@escaping()->Void, updateValue:@escaping(Int64)->Void, openPeer:@escaping(EnginePeer)->Void, toggleShowInTop:@escaping()->Void, toggleSendAs:@escaping(EnginePeer)->Void) {
        self.context = context
        self.dismiss = dismiss
        self.react = react
        self.updateValue = updateValue
        self.openPeer = openPeer
        self.toggleShowInTop = toggleShowInTop
        self.toggleSendAs = toggleSendAs
    }
}


struct Star_SliderAmount: Equatable {
    private let sliderSteps: [Int]
    let maxRealValue: Int
    let maxSliderValue: Int
    private let isLogarithmic: Bool
    
    private(set) var realValue: Int
    private(set) var sliderValue: Int
    
    private static func makeSliderSteps(maxRealValue: Int, isLogarithmic: Bool) -> [Int] {
        if isLogarithmic {
            var sliderSteps: [Int] = [ 1, 10, 50, 100, 500, 1_000, 2_000, 5_000, 7_500, 10_000 ]
            sliderSteps.removeAll(where: { $0 >= maxRealValue })
            sliderSteps.append(maxRealValue)
            return sliderSteps
        } else {
            return [1, maxRealValue]
        }
    }
    
    private static func remapValueToSlider(realValue: Int, maxSliderValue: Int, steps: [Int]) -> Int {
        guard realValue >= steps.first!, realValue <= steps.last! else { return 0 }

        for i in 0 ..< steps.count - 1 {
            if realValue >= steps[i] && realValue <= steps[i + 1] {
                let range = steps[i + 1] - steps[i]
                let relativeValue = realValue - steps[i]
                let stepFraction = Float(relativeValue) / Float(range)
                return Int(Float(i) * Float(maxSliderValue) / Float(steps.count - 1)) + Int(stepFraction * Float(maxSliderValue) / Float(steps.count - 1))
            }
        }
        return maxSliderValue // Return max slider position if value equals the last step
    }

    private static func remapSliderToValue(sliderValue: Int, maxSliderValue: Int, steps: [Int]) -> Int {
        guard sliderValue >= 0, sliderValue <= maxSliderValue else { return steps.first! }

        let stepIndex = Int(Float(sliderValue) / Float(maxSliderValue) * Float(steps.count - 1))
        let fraction = Float(sliderValue) / Float(maxSliderValue) * Float(steps.count - 1) - Float(stepIndex)
        
        if stepIndex >= steps.count - 1 {
            return steps.last!
        } else {
            let range = steps[stepIndex + 1] - steps[stepIndex]
            return steps[stepIndex] + Int(fraction * Float(range))
        }
    }
    
    init(realValue: Int, maxRealValue: Int, maxSliderValue: Int, isLogarithmic: Bool) {
        self.sliderSteps = Star_SliderAmount.makeSliderSteps(maxRealValue: maxRealValue, isLogarithmic: isLogarithmic)
        self.maxRealValue = maxRealValue
        self.maxSliderValue = maxSliderValue
        self.isLogarithmic = isLogarithmic
        
        self.realValue = realValue
        self.sliderValue = Star_SliderAmount.remapValueToSlider(realValue: self.realValue, maxSliderValue: self.maxSliderValue, steps: self.sliderSteps)
    }
    
    init(sliderValue: Int, maxRealValue: Int, maxSliderValue: Int, isLogarithmic: Bool) {
        self.sliderSteps = Star_SliderAmount.makeSliderSteps(maxRealValue: maxRealValue, isLogarithmic: isLogarithmic)
        self.maxRealValue = maxRealValue
        self.maxSliderValue = maxSliderValue
        self.isLogarithmic = isLogarithmic
        
        self.sliderValue = sliderValue
        self.realValue = Star_SliderAmount.remapSliderToValue(sliderValue: self.sliderValue, maxSliderValue: self.maxSliderValue, steps: self.sliderSteps)
    }
    
    func withRealValue(_ realValue: Int) -> Star_SliderAmount {
        return Star_SliderAmount(realValue: realValue, maxRealValue: self.maxRealValue, maxSliderValue: self.maxSliderValue, isLogarithmic: self.isLogarithmic)
    }
    
    func withSliderValue(_ sliderValue: Int) -> Star_SliderAmount {
        return Star_SliderAmount(sliderValue: sliderValue, maxRealValue: self.maxRealValue, maxSliderValue: self.maxSliderValue, isLogarithmic: self.isLogarithmic)
    }
}

private struct State : Equatable {
    

    
    struct TopPeer : Equatable {
        var peer: EnginePeer?
        var isMy: Bool
        var count: Int64
        var isAnonymous: Bool
    }
    
    var amount: Star_SliderAmount = Star_SliderAmount(realValue: 1, maxRealValue: 2500, maxSliderValue: 2500, isLogarithmic: true)
    
    var myPeer: EnginePeer
    var myBalance: Int64 = 1000
    var countUpdated: Bool = false
    var message: EngineMessage
    var showMeInTop: Bool = true
    
    
    var privacy: TelegramPaidReactionPrivacy {
        if !showMeInTop {
            return .anonymous
        } else {
            if myPeer.id == sendAsSelected.id {
                return .default
            } else {
                return .peer(sendAsSelected.id)
            }
        }
    }
    
    var peers: [TopPeer] {
        if let myTopIndex = topPeers.firstIndex(where: { $0.isMy }) {
            var topPeers = self.topPeers
            if countUpdated {
                topPeers[myTopIndex].count += Int64(amount.realValue)
            }
            topPeers[myTopIndex].isAnonymous = !self.showMeInTop
            if sendAsSelected.id != topPeers[myTopIndex].peer?.id {
                topPeers[myTopIndex].peer = sendAsSelected
            } else {
                topPeers[myTopIndex].peer = topPeers[myTopIndex].peer ?? sendAsSelected
            }
            return Array(topPeers.sorted(by: { $0.count > $1.count }).prefix(3))
        } else {
            var topPeers = self.topPeers
            if countUpdated {
                let myTopPeer = TopPeer(peer: self.sendAsSelected, isMy: true, count: Int64(amount.realValue), isAnonymous: !self.showMeInTop)
                topPeers.append(myTopPeer)
            }
            return Array(topPeers.sorted(by: { $0.count > $1.count }).prefix(3))
        }
    }
    
    var topPeers: [TopPeer]
    
    var sendAs: [EnginePeer] = []
    
    var sendAsSelected: EnginePeer
}


private final class HeaderItem : GeneralRowItem {
    
    fileprivate struct Sender : Comparable, Identifiable {
        static func < (lhs: HeaderItem.Sender, rhs: HeaderItem.Sender) -> Bool {
            return lhs.index < rhs.index
        }

        var stableId: AnyHashable {
            return peer?.id.toInt64() ?? Int64(index)
        }
        
        let titleLayout: TextViewLayout
        let amountLayout: TextViewLayout
        let peer: EnginePeer?
        let message: EngineMessage
        let amount: Int64
        let index: Int
    }
    
    fileprivate let context: AccountContext
    fileprivate let state: State
    fileprivate let close:()->Void
    fileprivate let updateValue:(Int64)->Void
    fileprivate let openPeer:(EnginePeer)->Void
    fileprivate let toggleShowInTop:()->Void
    fileprivate let toggleSendAs:(EnginePeer)->Void

    var showMe: Bool {
        return state.showMeInTop
    }
    
    let maxValue: Int64
    
    fileprivate let balanceLayout: TextViewLayout
    fileprivate let headerLayout: TextViewLayout
    fileprivate let info: TextViewLayout
    
    fileprivate var senders: [Sender] = []
    fileprivate var sendAs: [EnginePeer] = []

    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, state: State, viewType: GeneralViewType, updateValue:@escaping(Int64)->Void, action:@escaping()->Void, close:@escaping()->Void, openPeer:@escaping(EnginePeer)->Void, toggleShowInTop:@escaping()->Void, sendAs: [EnginePeer], toggleSendAs:@escaping(EnginePeer)->Void) {
        self.context = context
        self.state = state
        self.close = close
        self.toggleShowInTop = toggleShowInTop
        self.openPeer = openPeer
        self.sendAs = sendAs
        self.updateValue = updateValue
        self.toggleSendAs = toggleSendAs
        self.maxValue = Int64(context.appConfiguration.getGeneralValue("stars_paid_reaction_amount_max", orElse: 1))
        let balanceAttr = NSMutableAttributedString()
        balanceAttr.append(string: strings().starPurchaseBalance("\(clown + TINY_SPACE)\(state.myBalance)"), color: theme.colors.text, font: .normal(.text))
        balanceAttr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file, playPolicy: .onceEnd), for: clown)
        
        self.balanceLayout = .init(balanceAttr, alignment: .right)
        
        self.headerLayout = .init(.initialize(string: strings().starsReactScreenTitle, color: theme.colors.text, font: .medium(.title)), alignment: .center)
        
        let title = state.message.peers[state.message.id.peerId]?.displayTitle ?? ""
        
        let attr = NSMutableAttributedString()
        var currentSentAmount: Int?
        if let myPeer = state.message._asMessage().reactionsAttribute?.topPeers.first(where: { $0.isMy }) {
            currentSentAmount = Int(myPeer.count)
        }
        
        attr.append(string: currentSentAmount != nil ? strings().starsReactScreenSentValueCountable(currentSentAmount!) : strings().starsReactScreenInfo(title), color: theme.colors.text, font: .normal(.text))
        attr.detectBoldColorInString(with: .medium(.text))
        self.info = .init(attr, alignment: .center)
        
        for (i, topPeer) in state.peers.enumerated() {
            let amount = topPeer.count
            let title = topPeer.isAnonymous || topPeer.peer == nil ? strings().starsReactScreenAnonymous : topPeer.peer?._asPeer().compactDisplayTitle ?? ""
            senders.append(.init(titleLayout: .init(.initialize(string: title, color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1), amountLayout: .init(.initialize(string: "\(amount.prettyNumber)", color: .white, font: .medium(.short))), peer: !topPeer.isAnonymous ? topPeer.peer : nil, message: state.message, amount: amount, index: i))

        }
        
        super.init(initialSize, stableId: stableId, viewType: viewType, action: action, inset: .init())
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.balanceLayout.measure(width: .greatestFiniteMagnitude)

        self.headerLayout.measure(width: width - 40 - balanceLayout.layoutSize.width)
        self.info.measure(width: width - 40)
        
        
        return true
    }
    
    override var height: CGFloat {
        var height: CGFloat = 50 + (48 + 12) + 10 + 30 + info.layoutSize.height + 10 + 40 + 10 + 10
        
        if !senders.isEmpty {
            height += sendersHeight + 20
        }
        height += 50
        
        return height
    }
    
    var sendersHeight: CGFloat {
        return 20 + 36 + 20 + 80
    }
    
    override func viewClass() -> AnyClass {
        return HeaderItemView.self
    }
}

private final class AcceptView : Control {
    private let textView = InteractiveTextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        layer?.cornerRadius = 10
        scaleOnClick = true
        self.set(background: theme.colors.accent, for: .Normal)
        
        textView.userInteractionEnabled = false
        
    }
    
    func update(_ item: HeaderItem, animated: Bool) {
        let attr = NSMutableAttributedString()
        
        attr.append(string: strings().starsReactScreenSendCountable(clown_space, Int(item.state.amount.realValue)), color: theme.colors.underSelectedColor, font: .medium(.text))
        attr.insertEmbedded(.embedded(name: XTR_ICON, color: theme.colors.underSelectedColor, resize: false), for: clown)
        
        let layout = TextViewLayout(attr)
        layout.measure(width: item.width - 60)
        
        textView.set(text: layout, context: item.context)
        
        self.removeAllHandlers()
        self.set(handler: { [weak item] _ in
            item?.action()
        }, for: .Click)
        
        
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        textView.center()
    }
}

private final class SendersView: View {
    
    private class BadgeView : View {
        private let container: View = View()
        private let gradientLayer = SimpleGradientLayer()
        private let textView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(container)
            
            container.layer?.addSublayer(gradientLayer)
            
            container.addSubview(textView)
            
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            
            let layout = TextViewLayout(.initialize(string: strings().starsReactScreenTopSenders, color: NSColor.white, font: .medium(.text)), alignment: .center)
            layout.measure(width: .greatestFiniteMagnitude)
            self.textView.update(layout)
            
            container.setFrameSize(NSMakeSize(textView.frame.width + 20, frameRect.height))
            container.layer?.cornerRadius = container.frame.height / 2
            
            gradientLayer.colors = gradient.map { $0.cgColor }
            gradientLayer.startPoint = NSMakePoint(0, 0.5)
            gradientLayer.endPoint = NSMakePoint(1, 0.5)
            
            gradientLayer.frame = container.bounds
        }
        
        override func layout() {
            super.layout()
            textView.center()
            container.center()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func draw(_ layer: CALayer, in ctx: CGContext) {
            super.draw(layer, in: ctx)
            
            ctx.setFillColor(theme.colors.border.cgColor)
            ctx.fill(NSMakeRect(10, frame.height / 2, container.frame.minX - 20, .borderSize))
            ctx.fill(NSMakeRect(container.frame.maxX + 10, frame.height / 2, container.frame.minX - 20, .borderSize))

        }
    }
    
    private final class PeerView : Control {
        private let avatarView = AvatarControl(font: .avatar(18))
        private let nameView = TextView()
        
        private let badgeView = View()
        private let amountView = InteractiveTextView()
        private let amountIcon = ImageView()
        private let badgeGradient = SimpleGradientLayer()
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            avatarView.userInteractionEnabled = false
            self.avatarView.setFrameSize(70, 70)
            addSubview(avatarView)
            self.badgeView.layer?.addSublayer(badgeGradient)
            self.badgeView.addSubview(amountView)
            self.badgeView.addSubview(amountIcon)
            addSubview(self.badgeView)
            addSubview(nameView)
            
            badgeGradient.colors = gradient.map { $0.cgColor }
            badgeGradient.startPoint = NSMakePoint(0, 0.5)
            badgeGradient.endPoint = NSMakePoint(1, 0.5)
            
            
            nameView.userInteractionEnabled = false
            nameView.isSelectable = false
            self.layer?.masksToBounds = false
            
            self.scaleOnClick = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(_ sender: HeaderItem.Sender, context: AccountContext, animated: Bool) {
            if let peer = sender.peer?._asPeer() {
                self.avatarView.setPeer(account: context.account, peer: peer, message: sender.message._asMessage())
            } else {
                let icon = theme.icons.chat_hidden_author
                self.avatarView.setState(account: context.account, state: .Empty)
                let size = self.avatarView.frame.size
                self.avatarView.setSignal(generateEmptyPhoto(size, type: .icon(colors: (top: NSColor(0xb8b8b8), bottom: NSColor(0xb8b8b8).withAlphaComponent(0.6)), icon: icon, iconSize: icon.backingSize, cornerRadius: nil), bubble: false) |> map {($0, false)})
            }
            
            sender.titleLayout.measure(width: frame.width + 20)
            nameView.update(sender.titleLayout)
            
            sender.amountLayout.measure(width: .greatestFiniteMagnitude)
            amountView.set(text: sender.amountLayout, context: context)
            
            badgeView.layer?.borderColor = theme.colors.background.cgColor
            badgeView.layer?.borderWidth = 2
            
            amountIcon.image = NSImage(resource: .iconPeerPremium).precomposed(NSColor.white, zoom: 0.875)
            amountIcon.sizeToFit()
            
            badgeView.setFrameSize(NSMakeSize(amountView.frame.width + 14 + amountIcon.frame.width, amountView.frame.height + 5))
            badgeView.layer?.cornerRadius = badgeView.frame.height / 2
            
            needsLayout = true
        }
        
        override func layout() {
            super.layout()
            nameView.centerX(y: frame.height - nameView.frame.height)
            badgeView.centerX(y: avatarView.frame.maxY - floorToScreenPixels(badgeView.frame.height / 2))
            amountIcon.centerY(x: 6, addition: -1)
            amountView.centerY(x: amountIcon.frame.maxX, addition: -1)
            badgeGradient.frame = badgeView.bounds
        }
    }
    
  
    private let badge: BadgeView
    private let container: View
    required init(frame frameRect: NSRect) {
        badge = BadgeView(frame: NSMakeRect(0, 0, frameRect.width, 36))
        container = View(frame: NSMakeRect(0, badge.frame.height + 20, frameRect.width, 100))
        super.init(frame: frameRect)
        addSubview(badge)
        addSubview(container)
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var senders: [HeaderItem.Sender] = []
    private var views: [PeerView] = []
    
    func update(_ senders: [HeaderItem.Sender], item: HeaderItem, context: AccountContext, animated: Bool) {
        
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
        
        let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: self.senders, rightList: senders)
        self.senders = senders

        
        for rdx in deleteIndices.reversed() {
            performSubviewRemoval(views.remove(at: rdx), animated: transition.isAnimated)
        }
        
        for (idx, sender, prev) in indicesAndItems {
            let view = PeerView(frame: getRect(prev ?? idx))
            view.update(sender, context: context, animated: animated)
            view.setSingle(handler: { [weak item] _ in
                if let item = item, let peer = sender.peer {
                    item.openPeer(peer)
                }
            }, for: .Click)
            views.insert(view, at: idx)
            container.addSubview(view)
           
        }
        for (idx, sender, _) in updateIndices {
            views[idx].update(sender, context: context, animated: animated)
            views[idx].setSingle(handler: { [weak item] _ in
                if let item = item, let peer = sender.peer {
                    item.openPeer(peer)
                }
            }, for: .Click)
        }
        
        self.updateLayout(size: self.frame.size, transition: transition)
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    private func getRect(_ index: Int) -> CGRect {
        let between = floorToScreenPixels((frame.width - (CGFloat(senders.count) * 70)) / CGFloat(senders.count + 1))
        let x: CGFloat = between + (CGFloat(index) * 70) + (CGFloat(index) * between)
        return NSMakeRect(x, 0, 70, container.frame.height)
    }
    
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        for (i, view) in views.enumerated() {
            transition.updateFrame(view: view, frame: getRect(i))
        }
    }
}

final class Star_SliderView : Control {
    let dotLayer = View(frame: NSMakeRect(0, 0, 28, 28))
    private let foregroundLayer = SimpleGradientLayer()
    private let emptyLayer = SimpleLayer()

    private let effectLayer = BadgeStarsViewEffect(frame: .zero)
    
    private var progress: CGFloat = 0.0
    
    var updateProgress:((CGFloat, Bool)->Void)? = nil
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        dotLayer.backgroundColor = theme.colors.background
        dotLayer.layer?.cornerRadius = dotLayer.frame.width / 2.0
        
        self.layer?.cornerRadius = 15
        
        self.layer?.addSublayer(emptyLayer)
        self.layer?.addSublayer(foregroundLayer)
        addSubview(effectLayer)
        self.addSubview(dotLayer)
        
        emptyLayer.backgroundColor = theme.colors.listBackground.cgColor

        
        foregroundLayer.colors = gradient.map { $0.cgColor }
        foregroundLayer.startPoint = NSMakePoint(0, 0.5)
        foregroundLayer.endPoint = NSMakePoint(1, 0.2)

        
        foregroundLayer.cornerRadius = frameRect.height / 2
        
        
        var maybeFirst = true
        
        self.set(handler: { [weak self] control in
            let point = NSApp.currentEvent?.locationInWindow ?? .zero
            let converted = control.superview?.convert(point, from: nil) ?? .zero
            let isControl = control.superview?.hitTest(converted) == control
            self?.checkAndUpdate(maybeToBalance: isControl)
            maybeFirst = true
        }, for: .Down)
        
        self.set(handler: { [weak self] _ in
            self?.checkAndUpdate(maybeToBalance: maybeFirst)
            maybeFirst = false
        }, for: .MouseDragging)
        
        
        handleScrollEventOnInteractionEnabled = false
        
    }
    
    override func scrollWheel(with event: NSEvent) {
        window?.scrollWheel(with: event)
        
        var scrollPoint = NSZeroPoint
        let isInverted: Bool = System.isScrollInverted

        if event.scrollingDeltaY != 0 {
            if isInverted {
                scrollPoint.x += -event.scrollingDeltaY
            } else {
                scrollPoint.x -= event.scrollingDeltaY
            }
        }
        
        if event.scrollingDeltaX != 0 {
            if !isInverted {
                scrollPoint.x -= -event.scrollingDeltaX
            } else {
                scrollPoint.x += event.scrollingDeltaX
            }
        }

        let percent = self.progress + (scrollPoint.x * (1 / 100))

        
        self.updateProgress?(min(max(0, percent), 1), false)
        
    }
    
    func checkAndUpdate(maybeToBalance: Bool = false) {
        if var current = self.window?.mouseLocationOutsideOfEventStream {
            let width = self.frame.width - dotLayer.frame.width / 2
            current.x -= dotLayer.frame.width / 2
            let newValue = self.convert(current, from: nil)
            let percent = max(0, min(1, newValue.x / width))
                        
            self.updateProgress?(percent, maybeToBalance && self.progress < percent)
        }
    }
    
    override func layout() {
        super.layout()
        
        
        emptyLayer.frame = bounds
        dotLayer.frame = NSMakeRect(1, 1, 26, 26)
        
        dotLayer.frame = NSMakeRect(max(2, min(2 + floor((frame.width - dotLayer.frame.width - 2) * progress), frame.width - dotLayer.frame.width - 2)), 2, dotLayer.frame.width, dotLayer.frame.height)
        
        foregroundLayer.frame = NSMakeRect(0, 0, dotLayer.frame.maxX + 2, frame.height)
        
        effectLayer.frame = bounds
        effectLayer.update(size: effectLayer.frame.size, emitterPosition: NSMakePoint(dotLayer.frame.midX, dotLayer.frame.midY))

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func update(count: Int64, minValue: Int64, maxValue: Int64) {
        
        self.progress = CGFloat(max(minValue - 1, min(maxValue, count - 1))) / CGFloat(maxValue - 1)
        
        layout()
    }
}

final class Star_BadgeView : View {
    private let shapeLayer = SimpleShapeLayer()
    private let foregroundLayer = SimpleGradientLayer()
    private let textView = InteractiveTextView()
    private(set) var inlineView: InlineStickerView?
    private let container = View()
    private let effectLayer = StarsButtonEffectLayer()
    
    private(set) var tailPosition: CGFloat = 0.0
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        textView.userInteractionEnabled = false
        
        foregroundLayer.colors = gradient.map { $0.cgColor }
        foregroundLayer.startPoint = NSMakePoint(0, 0.5)
        foregroundLayer.endPoint = NSMakePoint(1, 0.2)
        foregroundLayer.mask = shapeLayer
        
        
        self.layer?.masksToBounds = false
        self.foregroundLayer.masksToBounds = false
        
        
        self.layer?.addSublayer(foregroundLayer)


        self.layer?.masksToBounds = false
        
        shapeLayer.fillColor = NSColor.red.cgColor
        shapeLayer.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
        
        container.layer?.addSublayer(effectLayer)

        
        container.addSubview(textView)
        addSubview(container)
        container.layer?.masksToBounds = false
    }
    
    func update(sliderValue: Int64, realValue: Int64, max maxValue: Int64, context: AccountContext) -> NSSize {
        
        
        if inlineView == nil {
            let view = InlineStickerView(account: context.account, file: LocalAnimatedSticker.star_currency_new.file, size: NSMakeSize(30, 30), getColors: { _ in
                return [.init(keyPath: "", color: .init(0xffffff))]
            }, playPolicy: .framesCount(1), controlContent: false, synchronyous: true)
            self.inlineView = view
            container.addSubview(view)
        }
        
        let attr = NSMutableAttributedString()
        attr.append(string: "\(realValue)", color: NSColor.white, font: .avatar(25))
        let textLayout = TextViewLayout(attr)
        textLayout.measure(width: .greatestFiniteMagnitude)
        self.textView.set(text: textLayout, context: context)

        
        container.setFrameSize(NSMakeSize(container.subviewsWidthSize.width + 2, container.subviewsWidthSize.height))
        
        self.tailPosition = max(0, min(1, CGFloat(sliderValue) / CGFloat(maxValue)))
                
        let size = NSMakeSize(max(100, container.frame.width + 30), frame.height)
        
        
        foregroundLayer.frame = size.bounds.insetBy(dx: 0, dy: -10)
        shapeLayer.frame = foregroundLayer.frame.focus(size)
        
        shapeLayer.path = generateRoundedRectWithTailPath(rectSize: size, tailPosition: tailPosition)._cgPath
        
        return size
        
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: container, frame: container.centerFrameX(y: 1))

        if let inlineView {
            transition.updateFrame(view: inlineView, frame: inlineView.centerFrameY(x: 0, addition: -2))
            transition.updateFrame(view: textView, frame: textView.centerFrameY(x: inlineView.frame.maxX + 2))
        }
        
        effectLayer.frame = size.bounds.insetBy(dx: -20, dy: -20)
        effectLayer.update(size: size)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
     //   shapeLayer.frame = bounds
    }
}


private final class ShowMeInTopView: View {
    private let textView = TextView()
    private let selection = SelectingControl(unselectedImage: theme.icons.chatToggleUnselected, selectedImage: theme.icons.chatToggleSelected, selected: false)
    private var container = Control()
    private let separator = View()
    
    fileprivate var callback: (()->Void)? = nil
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        container.addSubview(selection)
        container.addSubview(textView)
        addSubview(container)
        addSubview(separator)
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        selection.userInteractionEnabled = false
        
        container.set(handler: { [weak self] _ in
            self?.callback?()
        }, for: .Click)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(showMe: Bool) {
        selection.set(selected: showMe)
        let layout = TextViewLayout(.initialize(string: strings().starsReactScreenShowMeInTop, color: theme.colors.text, font: .normal(.text)))
        layout.measure(width: .greatestFiniteMagnitude)
        self.textView.update(layout)
        
        container.setFrameSize(NSMakeSize(layout.layoutSize.width + selection.frame.width + 10, 40))
        separator.backgroundColor = theme.colors.border
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        container.center()
        selection.centerY(x: 0)
        textView.centerY(x: selection.frame.maxX + 10)
        separator.frame = NSMakeRect(10, 0, frame.width - 20, .borderSize)
    }
}



private final class FromPeerView: Control {
    private let avatarView = AvatarControl(font: .avatar(13))
    private var select: ImageView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(avatarView)
        avatarView.userInteractionEnabled = false
        self.avatarView.setFrameSize(NSMakeSize(26, 26))
        
        layer?.cornerRadius = 12.5
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(_ peer: EnginePeer, sendas: [EnginePeer], _ context: AccountContext, maxWidth: CGFloat, selectAction:@escaping(EnginePeer)->Void) {
        self.avatarView.setPeer(account: context.account, peer: peer._asPeer(), disableForum: true)
        
        self.userInteractionEnabled = !sendas.isEmpty
        self.scaleOnClick = true
        
        if !sendas.isEmpty {
            let current: ImageView
            if let view = self.select {
                current = view
            } else {
                current = ImageView()
                self.select = current
                addSubview(current)
            }
            current.image = NSImage(resource: .iconAffiliateExpand).precomposed(theme.colors.accent)
            current.sizeToFit()
        } else if let select {
            performSubviewRemoval(select, animated: false)
            self.select = nil
        }
        
        if !sendas.isEmpty {
            self.contextMenu = {
                let menu = ContextMenu()
                for senda in sendas {
                    menu.addItem(ContextSendAsMenuItem(peer: .init(peer: senda._asPeer(), subscribers: nil, isPremiumRequired: false), context: context, isSelected: peer.id == senda._asPeer().id, handler: {
                        selectAction(senda)
                    }))
                }
                return menu
            }
        } else {
            self.contextMenu = nil
        }

        setFrameSize(NSMakeSize(avatarView.frame.width + 5 + (sendas.isEmpty ? 0 : 20), 26))
        
        self.background = theme.colors.grayForeground
    }
    
    override func layout() {
        super.layout()
        if let select {
            select.centerY(x: self.avatarView.frame.maxX + 5)
        }
    }
}

private final class HeaderItemView : GeneralContainableRowView {
    
    private let dismiss = ImageButton()
    private let balance = InteractiveTextView()
    private let header = InteractiveTextView()
    private let info = InteractiveTextView()
    
    
    
    private let accept: AcceptView = AcceptView(frame: .zero)
    
    let badgeView = Star_BadgeView(frame: NSMakeRect(0, 0, 100, 48))
    let sliderView = Star_SliderView(frame: NSMakeRect(0, 0, 100, 30))
    
    private var sendersView: SendersView?
    
    private let showMeInTop: ShowMeInTopView = .init(frame: .zero)
    
    
    private var sendFromView: FromPeerView?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(dismiss)
        addSubview(balance)
        addSubview(header)
        addSubview(info)
        addSubview(accept)
        
        addSubview(badgeView)
        addSubview(sliderView)
        
        addSubview(showMeInTop)
        
        
        sliderView.updateProgress = { [weak self] progress, maybeToBalance in
            if let item = self?.item as? HeaderItem {
                
                var value = progress * CGFloat(item.maxValue)
                let myBalance = CGFloat(item.state.myBalance)
                if maybeToBalance, item.state.amount.realValue < item.state.myBalance, value > myBalance {
                    value = Double(item.state.amount.withRealValue(Int(myBalance + 1)).sliderValue)
                }
                item.updateValue(Int64(ceil(value)))
            }
        }
        
        info.userInteractionEnabled = false
        
        dismiss.set(handler: { [weak self] _ in
            if let item = self?.item as? HeaderItem {
                item.close()
            }
        }, for: .Click)
        
        accept.set(handler: { [weak self] _ in
            if let item = self?.item as? HeaderItem {
                item.action()
            }
        }, for: .Click)
        
        showMeInTop.callback = { [weak self] in
            if let item = self?.item as? HeaderItem {
                item.toggleShowInTop()
            }
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? HeaderItem else {
            return
        }
        
        let transition: ContainedViewLayoutTransition = .immediate
        
        
        showMeInTop.update(showMe: item.showMe)

        let size = badgeView.update(sliderValue: Int64(item.state.amount.sliderValue), realValue: Int64(item.state.amount.realValue), max: item.maxValue, context: item.context)
        
        transition.updateFrame(view: self.badgeView, frame: self.focus(size))
        badgeView.updateLayout(size: size, transition: transition)
        
        info.set(text: item.info, context: item.context)
        
        sliderView.update(count: Int64(item.state.amount.sliderValue), minValue: 1, maxValue: item.maxValue)
        
                
        dismiss.set(image: theme.icons.modalClose, for: .Normal)
        dismiss.sizeToFit()
        dismiss.scaleOnClick = true
        dismiss.autohighlight = false
        
        balance.set(text: item.balanceLayout, context: item.context)
        header.set(text: item.headerLayout, context: item.context)
        
        accept.update(item, animated: animated)
        accept.setFrameSize(NSMakeSize(frame.width - 20, 40))
        
        if !item.senders.isEmpty {
            let current: SendersView
            if let view = self.sendersView {
                current = view
            } else {
                current = .init(frame: NSMakeRect(0, 0, frame.width, item.sendersHeight))
                addSubview(current)
                self.sendersView = current
            }
            current.update(item.senders, item: item, context: item.context, animated: animated)
        } else if let view = self.sendersView {
            performSubviewRemoval(view, animated: animated)
            self.sendersView = nil
        }
        
        
        if !item.sendAs.isEmpty {
            let current: FromPeerView
            if let view = self.sendFromView {
                current = view
            } else {
                current = .init(frame: NSMakeRect(0, 0, frame.width, 30))
                addSubview(current)
                self.sendFromView = current
            }
            current.set(item.state.sendAsSelected, sendas: item.sendAs, item.context, maxWidth: 50, selectAction: item.toggleSendAs)
        } else if let view = self.sendFromView {
            performSubviewRemoval(view, animated: animated)
            self.sendFromView = nil
        }
        
        dismiss.isHidden = sendFromView != nil
        
        needsLayout = true

    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func layout() {
        super.layout()
        dismiss.setFrameOrigin(NSMakePoint(10, floorToScreenPixels((50 - dismiss.frame.height) / 2) - 10))
        balance.setFrameOrigin(NSMakePoint(frame.width - 12 - balance.frame.width, floorToScreenPixels((50 - balance.frame.height) / 2) - 10))
                
        header.centerX(y: floorToScreenPixels((50 - header.frame.height) / 2) - 10)
        accept.centerX(y: frame.height - accept.frame.height)
        
        
        showMeInTop.frame = NSMakeRect(0, accept.frame.minY - 50, frame.width, 50)

                
        if let sendersView {
            sendersView.setFrameOrigin(NSMakePoint(0, showMeInTop.frame.minY - sendersView.frame.height - 20))
        }
        
        sliderView.frame = NSMakeRect(10, 50 + badgeView.frame.height + 10, frame.width - 20, 30)
        sliderView.layout()
        
        badgeView.centerX(y: 50)
        
        badgeView.setFrameOrigin(NSMakePoint(10 + sliderView.dotLayer.frame.midX - badgeView.frame.width * badgeView.tailPosition, 50))
        
        info.centerX(y: sliderView.frame.maxY + 20)
        

        if let sendFromView {
            sendFromView.setFrameOrigin(NSMakePoint(10, floorToScreenPixels((50 - sendFromView.frame.height) / 2) - 10))
        }
    }
}

private let _id_header = InputDataIdentifier("_id_header")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    if !state.sendAs.isEmpty {
        var bp = 0
        bp += 1
    }
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("h1"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GeneralRowItem(initialSize, height: 10, stableId: stableId, backgroundColor: theme.colors.background)
    }))
    sectionId += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return HeaderItem(initialSize, stableId: stableId, context: arguments.context, state: state, viewType: .legacy, updateValue: arguments.updateValue, action: arguments.react, close: arguments.dismiss, openPeer: arguments.openPeer, toggleShowInTop: arguments.toggleShowInTop, sendAs: state.sendAs, toggleSendAs: arguments.toggleSendAs)
    }))
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("h2"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GeneralRowItem(initialSize, height: 10, stableId: stableId, backgroundColor: theme.colors.background)
    }))
    sectionId += 1
  
    entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(strings().starsReactScreenFooter, linkHandler: { link in
    }), data: .init(color: theme.colors.grayText, viewType: .textBottomItem, fontSize: 12, centerViewAlignment: true, alignment: .center, linkColor: theme.colors.link)))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("h2"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GeneralRowItem(initialSize, height: 10, stableId: stableId, backgroundColor: theme.colors.background)
    }))
    sectionId += 1
    
    return entries
}

func Star_ReactionsController(context: AccountContext, message: Message) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let max_value = Int(context.appConfiguration.getGeneralValue("stars_paid_reaction_amount_max", orElse: 1))
    
    let amount = Star_SliderAmount(realValue: 50, maxRealValue: max_value, maxSliderValue: max_value, isLogarithmic: true)
    
    context.reactions.forceSendStarReactions?()
    
    let initialState = State(amount: amount, myPeer: .init(context.myPeer!), message: .init(message), showMeInTop: !message.isAnonymousInStarReaction, topPeers: [], sendAsSelected: .init(context.myPeer!))
    
    let statePromise = ValuePromise<State>(ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var getController:(()->InputDataController?)? = nil
    var close:(()->Void)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }
    context.starsContext.load(force: true)
    

    
    let topPeers = message.reactionsAttribute?.topPeers ?? []
    
    let topPeersSignal = context.engine.data.get(EngineDataMap(
        topPeers.map(\.peerId).compactMap { $0 }.map { peerId -> TelegramEngine.EngineData.Item.Peer.Peer in
            return TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
        }
    ))
    
    let messageView = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Messages.Message(id: message.id))
    
    
    let sendAs = context.engine.peers.channelsForPublicReaction(useLocalCache: false)
    
    var isFirst: Bool = true
    actionsDisposable.add(combineLatest(context.starsContext.state, topPeersSignal, messageView, sendAs).start(next: { state, top, updatedMessage, sendAs in
        
        var values: [State.TopPeer] = []
        for topPeer in topPeers {
            let currentPeer: EnginePeer?
            if let peerId = topPeer.peerId, let peer = top[peerId] as? EnginePeer {
                currentPeer = peer
            } else {
                currentPeer = nil
            }
            values.append(.init(peer: currentPeer, isMy: topPeer.isMy, count: Int64(topPeer.count), isAnonymous: topPeer.isAnonymous))
        }
        updateState { current in
            var current = current
            current.myBalance = state?.balance.value ?? 0
            current.topPeers = values
            current.message = updatedMessage ?? .init(message)
            current.sendAs = sendAs.isEmpty ? [] : [.init(context.myPeer!)] + sendAs
            current.sendAsSelected = values.first(where: { $0.isMy })?.peer ?? current.sendAsSelected
            if isFirst {
                current.showMeInTop = !message.isAnonymousInStarReaction
            }
            return current
        }
        isFirst = false
    }))
    
    let react:()->Void = {
        let count = stateValue.with { Int($0.amount.realValue) }
        let myBalance = stateValue.with { $0.myBalance }
        
        if let peer = message.peers[message.id.peerId] {
            if count > myBalance {
                showModal(with: Star_ListScreen(context: context, source: .purchase(.init(peer), Int64(count))), for: context.window)
            } else {
                let view = getController?()?.tableView.item(stableId: InputDataEntryId.custom(_id_header))?.view as? HeaderItemView
                let rect: NSRect?
                if let view = view {
                    rect = view.sliderView.convert(view.sliderView.dotLayer.frame, to: nil)
                } else {
                    rect = nil
                }
                context.reactions.sendStarsReaction(message.id, count: count, privacy: stateValue.with { $0.privacy }, fromRect: rect)
                close?()
            }
        }
        
    }

    let arguments = Arguments(context: context, dismiss: {
        close?()
    }, react: react, updateValue: { value in
        
        updateState { current in
            var current = current
            current.amount = current.amount.withSliderValue(Int(value))
            current.countUpdated = true
            return current
        }
        let current = stateValue.with { $0.amount.realValue }
        let myBalance = stateValue.with { $0.myBalance }
        if current == myBalance {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
        }
    }, openPeer: { peer in
        close?()
        PeerInfoController.push(navigation: context.bindings.rootNavigation(), context: context, peerId: peer.id)
    }, toggleShowInTop: {
        updateState { current in
            var current = current
            current.showMeInTop = !current.showMeInTop
            return current
        }
        _ = context.engine.messages.updateStarsReactionPrivacy(id: message.id, privacy: stateValue.with { $0.privacy }).startStandalone()

    }, toggleSendAs: { peer in
        updateState { current in
            var current = current
            current.sendAsSelected = peer
            return current
        }
    })
    
    let signal = statePromise.get() |> deliverOnMainQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "")
    
    controller.validateData = { _ in
        react()
        return .none
    }
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    
    let modalController = InputDataModalController(controller, modalInteractions: nil)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    controller.getBackgroundColor = {
        theme.colors.background
    }
    
    getController = { [weak controller] in
        return controller
    }
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}




