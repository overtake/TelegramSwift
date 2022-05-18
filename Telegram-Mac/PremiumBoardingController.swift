//
//  PremiumBoardingController.swift
//  Telegram
//
//  Created by Mike Renoir on 10.05.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit

private final class Arguments {
    let context: AccountContext
    let showTerms:()->Void
    let showPrivacy:()->Void
    init(context: AccountContext, showTerms: @escaping()->Void, showPrivacy:@escaping()->Void) {
        self.context = context
        self.showPrivacy = showPrivacy
        self.showTerms = showTerms
    }
}

enum PremiumValue : String {
    case limits
    case fileSize
    case downloadSpeed
    case voice
    case noAds
    case uniqueReactions
    case premiumStickers
    case chats
    case profileBadge
    case animatedProfilePicture
    
    var gradient: [NSColor] {
        switch self {
        case .limits:
            return [NSColor(rgb: 0xF17D2F)]
        case .fileSize:
            return [NSColor(rgb: 0xE9574A)]
        case .downloadSpeed:
            return [NSColor(rgb: 0xD84C7D)]
        case .voice:
            return [NSColor(rgb: 0xc14998)]
        case .noAds:
            return [NSColor(rgb: 0xC258B7)]
        case .uniqueReactions:
            return [NSColor(rgb: 0xA868FC)]
        case .premiumStickers:
            return [NSColor(rgb: 0x9279FF)]
        case .chats:
            return [NSColor(rgb: 0x7561eb)]
        case .profileBadge:
            return [NSColor(rgb: 0x758EFF)]
        case .animatedProfilePicture:
            return [NSColor(rgb: 0x59A4FF)]
        }
    }
    
    var icon: CGImage {
        let image = self.image
        let size = image.backingSize
        let img = generateImage(size, contextGenerator: { size, ctx in
            ctx.clear(size.bounds)
            ctx.clip(to: size.bounds, mask: image)
            
            let colors = gradient.compactMap { $0.cgColor } as NSArray

            if gradient.count == 1 {
                ctx.setFillColor(gradient[0].cgColor)
                ctx.fill(size.bounds)
            } else {
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
        
        return generateImage(size, contextGenerator: { size, ctx in
            ctx.clear(size.bounds)
            
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fill(size.bounds.insetBy(dx: 2, dy: 2))
            
            ctx.draw(img, in: size.bounds)
        })!
    }
    
    var image: CGImage {
        switch self {
        case .limits:
            return NSImage(named: "Icon_Premium_Boarding_X2")!.precomposed(theme.colors.accent)
        case .fileSize:
            return NSImage(named: "Icon_Premium_Boarding_Files")!.precomposed(theme.colors.accent)
        case .downloadSpeed:
            return NSImage(named: "Icon_Premium_Boarding_Speed")!.precomposed(theme.colors.accent)
        case .voice:
            return NSImage(named: "Icon_Premium_Boarding_Voice")!.precomposed(theme.colors.accent)
        case .noAds:
            return NSImage(named: "Icon_Premium_Boarding_Ads")!.precomposed(theme.colors.accent)
        case .uniqueReactions:
            return NSImage(named: "Icon_Premium_Boarding_Reactions")!.precomposed(theme.colors.accent)
        case .premiumStickers:
            return NSImage(named: "Icon_Premium_Boarding_Stickers")!.precomposed(theme.colors.accent)
        case .chats:
            return NSImage(named: "Icon_Premium_Boarding_Chats")!.precomposed(theme.colors.accent)
        case .profileBadge:
            return NSImage(named: "Icon_Premium_Boarding_Badge")!.precomposed(theme.colors.accent)
        case .animatedProfilePicture:
            return NSImage(named: "Icon_Premium_Boarding_Profile")!.precomposed(theme.colors.accent)
        }
    }
    
    func title(_ limits: PremiumLimitConfig) -> String {
        switch self {
        case .limits:
            return strings().premiumBoardingDoubleTitle
        case .fileSize:
            return strings().premiumBoardingFileSizeTitle(String.prettySized(with: limits.upload_max_fileparts_premium, afterDot: 0, round: true))
        case .downloadSpeed:
            return strings().premiumBoardingDownloadTitle
        case .voice:
            return strings().premiumBoardingVoiceTitle
        case .noAds:
            return strings().premiumBoardingNoAdsTitle
        case .uniqueReactions:
            return strings().premiumBoardingReactionsTitle
        case .premiumStickers:
            return strings().premiumBoardingStickersTitle
        case .chats:
            return strings().premiumBoardingChatsTitle
        case .profileBadge:
            return strings().premiumBoardingBadgeTitle
        case .animatedProfilePicture:
            return strings().premiumBoardingAvatarTitle
        }
    }
    func info(_ limits: PremiumLimitConfig) -> String {
        switch self {
        case .limits:
            return strings().premiumBoardingDoubleInfo("\(limits.channels_limit_premium)", "\(limits.dialog_filters_limit_premium)", "\(limits.dialog_pinned_limit_premium)", "\(limits.channels_public_limit_premium)")
        case .fileSize:
            return strings().premiumBoardingFileSizeInfo(String.prettySized(with: limits.upload_max_fileparts_default, afterDot: 0, round: true), String.prettySized(with: limits.upload_max_fileparts_premium, afterDot: 0, round: true))
        case .downloadSpeed:
            return strings().premiumBoardingDownloadInfo
        case .voice:
            return strings().premiumBoardingVoiceInfo
        case .noAds:
            return strings().premiumBoardingNoAdsInfo
        case .uniqueReactions:
            return strings().premiumBoardingReactionsInfo
        case .premiumStickers:
            return strings().premiumBoardingStickersInfo
        case .chats:
            return strings().premiumBoardingChatsInfo
        case .profileBadge:
            return strings().premiumBoardingBadgeInfo
        case .animatedProfilePicture:
            return strings().premiumBoardingAvatarInfo
        }
    }
}

private struct State : Equatable {
    var values:[PremiumValue] = [.limits, .fileSize, .downloadSpeed, .voice, .noAds, .uniqueReactions, .premiumStickers, .chats, .profileBadge, .animatedProfilePicture]
}



private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .custom(35)))
    sectionId += 1

    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
        return PremiumBoardingHeaderItem(initialSize, stableId: stableId, viewType: .legacy)
    }))
    index += 1
    
    for (i, value) in state.values.enumerated() {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init(value.rawValue), equatable: InputDataEquatable(value), comparable: nil, item: { initialSize, stableId in
            return PremiumBoardingRowItem(initialSize, stableId: stableId, viewType: .legacy, value: value, limits: arguments.context.premiumLimits, isLast: false)
        }))
        index += 1
    }
    
    entries.append(.sectionId(sectionId, type: .custom(15)))
    sectionId += 1

    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("about"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return PremiumAboutRowItem(initialSize, stableId: stableId, terms: arguments.showTerms, privacy: arguments.showPrivacy)
    }))
    
    entries.append(.sectionId(sectionId, type: .custom(15)))
    sectionId += 1

   
    
    return entries
}

private final class PremiumBoardingView : View {
    
    private final class AcceptView : Control {
        private let gradient: PremiumGradientView = PremiumGradientView(frame: .zero)
        private let shimmer = ShimmerEffectView()
        private let textView = TextView()
        private let container = View()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(gradient)
            addSubview(shimmer)
            container.addSubview(textView)
            addSubview(container)
            scaleOnClick = true
            
            textView.userInteractionEnabled = false
            textView.isSelectable = false
        }
        
        override func layout() {
            super.layout()
            gradient.frame = bounds
            shimmer.frame = bounds
            container.center()
            textView.center()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(animated: Bool) -> NSSize {
            let layout = TextViewLayout(.initialize(string: "Subscribe for $5 per month", color: NSColor.white, font: .medium(.text)))
            layout.measure(width: .greatestFiniteMagnitude)
            textView.update(layout)
                        
            container.setFrameSize(layout.layoutSize)
            
            let size = NSMakeSize(container.frame.width + 100, 40)
            
            shimmer.updateAbsoluteRect(size.bounds, within: size)
            shimmer.update(backgroundColor: .clear, foregroundColor: .clear, shimmeringColor: NSColor.white.withAlphaComponent(0.3), shapes: [.roundedRect(rect: size.bounds, cornerRadius: size.height / 2)], horizontal: true, size: size)

            needsLayout = true
            
            return size
        }
    }
    
    final class HeaderView: View {
        let dismiss = ImageButton()
        private let container = View()
        private let titleView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(container)
            addSubview(dismiss)
            
            dismiss.scaleOnClick = true
            dismiss.autohighlight = false
            
            dismiss.set(image: theme.icons.modalClose, for: .Normal)
            dismiss.sizeToFit()
            
            titleView.userInteractionEnabled = false
            titleView.isSelectable = false
            titleView.isEventLess = true
            
            container.backgroundColor = theme.colors.background
            container.border = [.Bottom]

            let layout = TextViewLayout(.initialize(string: strings().premiumBoardingTitle, color: theme.colors.text, font: .medium(.header)))
            layout.measure(width: 300)
            
            titleView.update(layout)
            container.addSubview(titleView)
        }
        
        func update(isHidden: Bool, animated: Bool) {
            container.change(opacity: isHidden ? 0 : 1, animated: animated)
        }
        
        override func layout() {
            super.layout()
            dismiss.centerY(x: 10)
            container.frame = bounds
            titleView.center()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    
    private let headerView: HeaderView = HeaderView(frame: .zero)
    let tableView = TableView()
    private let bottomView = View()
    private let bottomBorder = View()
    private let acceptView = AcceptView(frame: .zero)
    
    var dismiss:(()->Void)?
    var accept:(()->Void)?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        addSubview(headerView)
        addSubview(bottomView)
        
        bottomBorder.backgroundColor = theme.colors.border
        
        bottomView.addSubview(bottomBorder)
        bottomView.addSubview(acceptView)
        
        tableView.addScroll(listener: TableScrollListener(dispatchWhenVisibleRangeUpdated: false, { [weak self] position in
            self?.updateScroll(position, animated: true)
        }))
        
        headerView.dismiss.set(handler: { [weak self] _ in
            self?.dismiss?()
        }, for: .Click)
        
        acceptView.set(handler: { [weak self] _ in
            self?.accept?()
        }, for: .Click)
    }
    
    private func updateScroll(_ scroll: ScrollPosition, animated: Bool) {
        let offset = scroll.rect.minY - tableView.frame.height
        
        if scroll.rect.minY >= tableView.listHeight {
            bottomBorder.change(opacity: 0, animated: true)
        } else {
            bottomBorder.change(opacity: 1, animated: animated)
        }
        
        headerView.update(isHidden: offset <= 127, animated: animated)
    }
    
    override func layout() {
        super.layout()
        updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: headerView, frame: NSMakeRect(0, 0, size.width, 50))
        transition.updateFrame(view: tableView, frame: NSMakeRect(0, 0, size.width, size.height - 60))
        transition.updateFrame(view: bottomView, frame: NSMakeRect(0, tableView.frame.maxY, size.width, 60))
        
        transition.updateFrame(view: acceptView, frame: bottomView.focus(acceptView.frame.size))
        transition.updateFrame(view: bottomBorder, frame: NSMakeRect(0, 0, bottomView.frame.width, .borderSize))
    }
    
    func contentSize(maxSize size: NSSize) -> NSSize {
        return NSMakeSize(size.width, min(headerView.frame.height + tableView.listHeight + bottomView.frame.height, size.height))
    }
    
    func update(animated: Bool) {
        let size = acceptView.update(animated: animated)
        acceptView.setFrameSize(size)
        acceptView.layer?.cornerRadius = size.height / 2
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        self.updateScroll(tableView.scrollPosition().current, animated: false)

        updateLayout(size: frame.size, transition: transition)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class PremiumBoardingController : ModalViewController {

    private let context: AccountContext
    init(context: AccountContext) {
        self.context = context
        super.init(frame: NSMakeRect(0, 0, 350, 300))
    }
    
    override func measure(size: NSSize) {
        updateSize(false)
    }
    
    func updateSize(_ animated: Bool) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with: genericView.contentSize(maxSize: NSMakeSize(350, contentSize.height - 80)), animated: animated)
        }
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    private var genericView: PremiumBoardingView {
        return self.view as! PremiumBoardingView
    }
    
    override func viewClass() -> AnyClass {
        return PremiumBoardingView.self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let actionsDisposable = DisposableSet()

        let initialState = State()
        
        let statePromise = ValuePromise(initialState, ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((State) -> State) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }
        
        let arguments = Arguments(context: context, showTerms: {
            
        }, showPrivacy: {
            
        })
        
        let stateSignal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
            return InputDataSignalValue(entries: entries(state, arguments: arguments))
        }
        
        let previous: Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])
        let initialSize = self.atomicSize
        
        
        let inputArguments = InputDataArguments.init(select: { _, _ in }, dataUpdated: {
            
        })
        
        let signal: Signal<TableUpdateTransition, NoError> = combineLatest(queue: .mainQueue(), appearanceSignal, stateSignal) |> mapToQueue { appearance, state in
            let entries = state.entries.map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
            return prepareInputDataTransition(left: previous.swap(entries), right: entries, animated: state.animated, searchState: state.searchState, initialSize: initialSize.modify{ $0 }, arguments: inputArguments, onMainQueue: true)
        } |> deliverOnMainQueue |> afterDisposed {
            previous.swap([])
        }
        
        actionsDisposable.add(signal.start(next: { [weak self] transition in
            self?.genericView.tableView.merge(with: transition)
            self?.genericView.update(animated: transition.animated)
            self?.updateSize(transition.animated)
            self?.readyOnce()
        }))

        
        genericView.dismiss = { [weak self] in
            self?.close()
        }
        genericView.accept = { [weak self] in
            self?.close()
        }
                
        self.onDeinit = {
            actionsDisposable.dispose()
        }
        
    }
}





