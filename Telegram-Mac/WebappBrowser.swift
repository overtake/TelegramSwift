//
//  WebappBrowser.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 20.07.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import KeyboardKey
import TelegramMedia
import Postbox
import WebKit

protocol BrowserPage {
    func contextMenu() -> ContextMenu
    func backButtonPressed()
    func reloadPage()
    var externalState: Signal<WebpageModalState, NoError> { get }
    
    func add(_ tab: BrowserTabData.Data) -> Bool
}

private func makeWebViewController(context: AccountContext, data: BrowserTabData.Data, unique: BrowserTabData.Unique, makeLinkManager:@escaping(BrowserTabData.Unique)->BrowserLinkManager?) -> Signal<WebpageModalController, RequestWebViewError> {
    
    guard let bot = data.peer?._asPeer() else {
        return .fail(.generic)
    }
    
    let canBeAttach = bot.botInfo?.flags.contains(.canBeAddedToAttachMenu) ?? false

    return Signal { subscriber in
        
        let signal: Signal<(String, WebpageModalController.RequestData), RequestWebViewError>
        let themeParams = generateWebAppThemeParams(theme)
        switch data {
        case let .mainapp(_, source):
            signal = context.engine.messages.requestMainWebView(peerId: context.peerId, botId: bot.id, source: source, themeParams: themeParams) |> map {
                return ($0.url, .simple(url: $0.url, botdata: .init(queryId: $0.queryId, bot: bot, peerId: nil, buttonText: "", keepAliveSignal: $0.keepAliveSignal), source: source))
            }
        case .webapp(_, let peerId, let buttonText, let url, let payload, let threadId, let replyTo, let fromMenu):
            signal = context.engine.messages.requestWebView(peerId: peerId, botId: bot.id, url: url, payload: payload, themeParams: themeParams, fromMenu: fromMenu, replyToMessageId: replyTo, threadId: threadId) |> map {
                return ($0.url, .normal(url: $0.url, botdata: .init(queryId: $0.queryId, bot: bot, peerId: peerId, buttonText: buttonText, keepAliveSignal: $0.keepAliveSignal)))
            }
        case let .simple(_, url, buttonText, source):
            signal = context.engine.messages.requestSimpleWebView(botId: bot.id, url: url, source: source, themeParams: themeParams) |> map {
                return ($0.url, .simple(url: $0.url, botdata: .init(queryId: $0.queryId, bot: bot, peerId: nil, buttonText: buttonText, keepAliveSignal: $0.keepAliveSignal), source: source))
            }
        case let .straight(_, peerId, _, result):
            signal = .single((result.url, .normal(url: result.url, botdata: .init(queryId: result.queryId, bot: bot, peerId: peerId, buttonText: "", keepAliveSignal: result.keepAliveSignal))))
        case .tonsite:
            signal = .fail(.generic)
        case .instantView:
            signal = .fail(.generic)
        case .game:
            signal = .fail(.generic)
        }
        
                
        let attach: Signal<AttachMenuBot?, RequestWebViewError>
        if canBeAttach {
            attach = context.engine.messages.getAttachMenuBot(botId: bot.id, cached: true) |> map(Optional.init) |> mapError { _ in
                return .generic
            }
        } else {
            attach = .single(nil)
        }
        
        let settings: Signal<BotAppSettings?, RequestWebViewError>
        settings = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.BotAppSettings(id: bot.id)) |> deliverOnMainQueue |> castError(RequestWebViewError.self)

        
        let disposable = combineLatest(signal, attach, settings).start(next: { values in
            let url = values.0.0
            let requestData = values.0.1
            let attach = values.1
            let settings = values.2
            
            var thumbFile: TelegramMediaFile = MenuAnimation.menu_folder_bot.file
            let hasSettings = attach?.flags.contains(.hasSettings) ?? false
            if canBeAttach, let attach {
                if let file = attach.icons[.macOSAnimated] {
                    thumbFile = file
                } else {
                    thumbFile = MenuAnimation.menu_folder_bot.file
                }
            }
            subscriber.putNext(WebpageModalController(context: context, url: url, title: bot.displayTitle, requestData: requestData, thumbFile: thumbFile, fromMenu: true, hasSettings: hasSettings, browser: makeLinkManager(unique), settings: settings))

            subscriber.putCompletion()
        }, error: { error in
            subscriber.putError(error)
        })
        return disposable
    }
}



private func layoutTabs(_ tabs: [BrowserTabData], width: CGFloat) -> [BrowserTabData] {
    var tabs = tabs
    for i in 0 ..< tabs.count {
        tabs[i] = tabs[i].measure(width: width)
    }
    return tabs
}

private final class Arguments {
    let context: AccountContext
    let add:(Control)->Void
    let close:()->Void
    let select:(BrowserTabData.Unique)->Void
    let setLoadingState:(BrowserTabData.Unique, BrowserTabData.LoadingState)->Void
    let setExternalState:(BrowserTabData.Unique, WebpageModalState)->Void
    let closeTab:(BrowserTabData.Unique?, Bool)->Void
    let selectAtIndex:(Int)->Void
    let makeLinkManager:(BrowserTabData.Unique)->BrowserLinkManager
    let contextMenu:(BrowserTabData)->ContextMenu?
    let insertTab:(BrowserTabData.Data)->Void
    let shake:(BrowserTabData.Unique)->Void
    let getExternalState: (BrowserTabData.Unique)->WebpageModalState?
    let updateFullscreen:(Bool)->Void
    init(context: AccountContext, add: @escaping(Control)->Void, close:@escaping()->Void, select:@escaping(BrowserTabData.Unique)->Void, setLoadingState:@escaping(BrowserTabData.Unique, BrowserTabData.LoadingState)->Void, setExternalState:@escaping(BrowserTabData.Unique, WebpageModalState)->Void, closeTab:@escaping(BrowserTabData.Unique?, Bool)->Void, selectAtIndex:@escaping(Int)->Void, makeLinkManager:@escaping(BrowserTabData.Unique)->BrowserLinkManager, contextMenu:@escaping(BrowserTabData)->ContextMenu?, insertTab:@escaping(BrowserTabData.Data)->Void, shake:@escaping(BrowserTabData.Unique)->Void, getExternalState: @escaping(BrowserTabData.Unique)->WebpageModalState?, updateFullscreen:@escaping(Bool)->Void) {
        self.context = context
        self.add = add
        self.close = close
        self.select = select
        self.setLoadingState = setLoadingState
        self.setExternalState = setExternalState
        self.closeTab = closeTab
        self.selectAtIndex = selectAtIndex
        self.makeLinkManager = makeLinkManager
        self.contextMenu = contextMenu
        self.insertTab = insertTab
        self.shake = shake
        self.getExternalState = getExternalState
        self.updateFullscreen = updateFullscreen
    }
}

private func createCombinedPath(leftPath: CGPath, rightPath: CGPath, totalWidth: CGFloat) -> CGPath {
    let combinedPath = CGMutablePath()
    
    let leftPathWidth: CGFloat = 22.0
    let rightPathWidth: CGFloat = 22.0
    let middleWidth = totalWidth - leftPathWidth - rightPathWidth
    
    combinedPath.addPath(leftPath)
    combinedPath.addRect(CGRect(x: leftPathWidth, y: 0, width: middleWidth, height: 40))
    let transform = CGAffineTransform(translationX: leftPathWidth + middleWidth, y: 0)
    combinedPath.addPath(rightPath, transform: transform)
    combinedPath.closeSubpath()
    return combinedPath
}



final class WebappBrowser : Window {
    let containerView = View()
    private let shadow = SimpleShapeLayer()
    private let testLayer = SimpleLayer()
    init(parent: Window) {
        
        containerView.wantsLayer = true
        
        let windowFrame = parent.frame

        
        let screen = NSScreen.main!
        
        let s = NSMakeSize(screen.frame.width + 20, screen.frame.height + 20)
        let size = NSMakeSize(420, min(420 + 420 * 0.7, s.height - 80))
        
        let originX = windowFrame.origin.x + (windowFrame.width - size.width) / 2
        let originY = windowFrame.origin.y + (windowFrame.height - size.height) / 2
        let rect = NSRect(origin: NSPoint(x: originX, y: originY), size: size)

        super.init(contentRect: rect, styleMask: [.fullSizeContentView, .titled, .borderless, .resizable], backing: .buffered, defer: true)
        
        self.minSize = rect.size
        
        self.contentView?.wantsLayer = true
        self.contentView?.autoresizesSubviews = false
        self.contentView?.layer?.masksToBounds = false
        
        self.modalInset = 10
       
        self.isOpaque = false
        self.hasShadow = false
        self.backgroundColor = NSColor.clear
        self.isMovableByWindowBackground = true
        
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        
        let shadow = SimpleShapeLayer()
        
        let cornerRadius: CGFloat = 14.0

       
        
        
        self.contentView?.layer?.addSublayer(shadow)

//        
//        

        self.contentView?.layer?.addSublayer(testLayer)

        
        containerView.backgroundColor = theme.colors.listBackground
        
        self.contentView?.addSubview(containerView)
        
      //  self.contentView?.background = .random
        
        if #available(macOS 10.15, *) {
            containerView.layer?.cornerCurve = .continuous
            shadow.cornerCurve = .continuous
            contentView?.layer?.cornerCurve = .continuous
        }
        
        self.isReleasedWhenClosed = false
                
        containerView.layer?.cornerRadius = cornerRadius
        self.contentView?.layer?.cornerRadius = cornerRadius
    }
    
    func show() {

        self.makeKeyAndOrderFront(nil)
        
        
        self.contentView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2, removeOnCompletion: false)
        self.contentView?.layer?.animateScaleSpring(from: 0.8, to: 1.0, duration: 0.2)
        
    }
    
    override func close() {
        super.close()
    }
    
    deinit {
        var bp = 0
        bp += 1
    }
    
    override func layoutIfNeeded() {
        super.layoutIfNeeded()

        
        testLayer.masksToBounds = false
        testLayer.shadowColor = NSColor.black.withAlphaComponent(1).cgColor
        testLayer.shadowOffset = CGSize(width: 0.0, height: 0)
        testLayer.shadowRadius = 5
        testLayer.shadowOpacity = 1

        testLayer.cornerRadius = 14
        testLayer.frame = bounds.insetBy(dx: 13, dy: 13)
        testLayer.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        
        
        containerView.frame = bounds.insetBy(dx: 10, dy: 10)

//        shadow.masksToBounds = false
//        shadow.shadowColor = NSColor.random.withAlphaComponent(1).cgColor
//        shadow.shadowOffset = CGSize(width: 0.0, height: 1)
//        shadow.shadowRadius = 5
//        shadow.shadowOpacity = 0.7
//        shadow.fillColor = NSColor.random.cgColor
//        shadow.backgroundColor = NSColor.black.withAlphaComponent(1).cgColor
//        
//        shadow.frame = bounds.insetBy(dx: 11, dy: 11)
//        shadow.path = CGPath(roundedRect: bounds.insetBy(dx: 11, dy: 11).size.bounds, cornerWidth: 14, cornerHeight: 14, transform: nil)
        

        self.contentView?.subviews.last?.frame = bounds.insetBy(dx: 10, dy: 10)
        
        self.standardWindowButton(.closeButton)?.isHidden = !isFullScreen
        self.standardWindowButton(.miniaturizeButton)?.isHidden = !isFullScreen
        self.standardWindowButton(.zoomButton)?.isHidden = !isFullScreen
    }
}


private final class ErrorLoadingView : View {
    private let mediaView = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 150, 150))
    private let textView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(mediaView)
        addSubview(textView)
        
        self.textView.userInteractionEnabled = false
        self.textView.isSelectable = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(arguments: Arguments, error: RequestWebViewError) {
        let text: String
        switch error {
        case .generic:
            text = strings().webBrowserError
        }
        
        self.backgroundColor = theme.colors.background
        
        let textLayout = TextViewLayout(.initialize(string: text, color: theme.colors.grayText, font: .normal(.title)).detectBold(with: .medium(.title)), alignment: .center)
        textLayout.measure(width: frame.width - 40)
        self.textView.update(textLayout)
        
        self.mediaView.update(with: LocalAnimatedSticker.duck_webapp_error.file, size: mediaView.frame.size, context: arguments.context, table: nil, animated: false)
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        var yStart = floorToScreenPixels((frame.height - (mediaView.frame.height + textView.frame.height + 10)) / 2) - 30
        mediaView.centerX(y: yStart)
        yStart += mediaView.frame.height + 10
        textView.centerX(y: yStart)
    }
}


private final class TabView: Control {
    private var arguments: Arguments?
    
    private var textView: TextView?
    private var urlText: TextView?
    private var avatarView: AvatarControl?
    private var iconView: ImageView?
    private var shadowView: ShadowView?
    
    private var loading: InfiniteProgressView?
        
    private var premiumStatus: PremiumStatusControl?
    private let backgroundView = View()
    
    private(set) var data: BrowserTabData?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(backgroundView)
        
        
        backgroundView.layer?.cornerRadius = 10
        self.scaleOnClick = true
        
        self.contextMenu = { [weak self] in
            if let item = self?.data {
                return self?.arguments?.contextMenu(item)
            } else {
                return nil
            }
        }
        
        set(handler: { [weak self] _ in
            if let item = self?.data {
                self?.arguments?.select(item.unique)
            }
        }, for: .Click)
    }
    
    override func stateDidUpdate(_ state: ControlState) {
        super.stateDidUpdate(state)
    }
    
    func updateLayer(transition: ContainedViewLayoutTransition) {
        super.updateLayer()
    }
    
    func update(item: BrowserTabData, arguments: Arguments, transition: ContainedViewLayoutTransition) {
        self.arguments = arguments
        self.data = item
        self.backgroundView.backgroundColor = item.selected ? item.tabColor : .clear
        let animated = transition.isAnimated && !self.isHidden
        if animated {
            self.layer?.animateBackground(duration: transition.duration, function: transition.timingFunction)
        }
        
        self.toolTip = item.external?.url
        

        if let enginePeer = item.peer {
            let current: AvatarControl
            if let view = self.avatarView {
                current = view
            } else {
                current = AvatarControl(font: .avatar(8))
                current.setFrameSize(20, 20)
                current.userInteractionEnabled = false
                self.avatarView = current
                addSubview(current)
                if item.selected {
                    current.centerY(x: 20)
                } else {
                    current.center()
                }
            }
            current.setPeer(account: arguments.context.account, peer: enginePeer._asPeer())
        } else if let avatarView {
            performSubviewRemoval(avatarView, animated: animated)
            self.avatarView = nil
        }
        
        if item.external?.isSite == true {
            let current: ImageView
            if let view = self.iconView {
                current = view
            } else {
                current = ImageView()
                current.setFrameSize(20, 20)
                current.isEventLess = true
                current.layer?.cornerRadius = 4
                self.iconView = current
                addSubview(current)
                current.animates = true
                if item.selected {
                    current.centerY(x: 20)
                } else {
                    current.center()
                }
            }
            
            let color: NSColor = item.selected ? theme.colors.listBackground : theme.colors.background

            if case .instantView = item.unique {
                current.nsImage = generateContextMenuInstantView(color: color)
            } else  if let favicon = item.external?.favicon {
                current.nsImage = favicon
            } else {
                current.nsImage = generateContextMenuUrl(color: color, state: item.external)
            }
        } else if let iconView {
            performSubviewRemoval(iconView, animated: animated)
            self.iconView = nil
        }
        
        
        switch item.loadingState {
        case .none:
            if let loading {
                performSubviewRemoval(loading, animated: animated)
                self.loading = nil
            }
        case .loading:
            let current: InfiniteProgressView
            if let view = self.loading {
                current = view
            } else {
                current = InfiniteProgressView(color: NSColor.white, lineWidth: 1.5, insets: 3)
                current.setFrameSize(NSMakeSize(20, 20))
                current.progress = nil
                self.loading = current
                addSubview(current)
                current.centerY(x: self.avatarView?.frame.minX ?? 20)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            current.layer?.cornerRadius = item.peer != nil ? 10 : 4
            current.backgroundColor = NSColor.black.withAlphaComponent(0.6)
        case .error:
            if let loading {
                performSubviewRemoval(loading, animated: animated)
                self.loading = nil
            }
        }
        
        if item.selected {
            let current: TextView
            let isNew: Bool
            if let view = self.textView {
                current = view
                isNew = false
            } else {
                current = TextView()
                current.userInteractionEnabled = false
                current.isSelectable = false
                self.textView = current
                addSubview(current)
                isNew = true
            }
            current.update(item.title)
            
            if isNew {
                current.centerY(x: 50)
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            
            do {
                if let urlText = item.urlText {
                    let current: TextView
                    let isNew: Bool
                    if let view = self.urlText {
                        current = view
                        isNew = false
                    } else {
                        current = TextView()
                        current.userInteractionEnabled = false
                        current.isSelectable = false
                        self.urlText = current
                        addSubview(current)
                        isNew = true
                    }
                    current.update(urlText)
                    
                    if isNew {
                        current.centerY(x: 50)
                        if animated {
                            current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                        }
                    }
                } else if let urlText {
                    performSubviewRemoval(urlText, animated: animated)
                    self.urlText = nil
                }
            }
            
            if let peer = item.peer {
                let statusControl = PremiumStatusControl.control(peer._asPeer(), account: arguments.context.account, inlinePacksContext: arguments.context.inlinePacksContext, left: false, isSelected: false, cached: self.premiumStatus, animated: false)

                if let statusControl = statusControl, let textView {
                    let isNew = self.premiumStatus == nil
                    self.premiumStatus = statusControl
                    self.addSubview(statusControl)
                    
                    if isNew {
                        statusControl.setFrameOrigin(NSMakePoint(textView.frame.maxX + 3, textView.frame.minY))
                        statusControl.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                } else if let view = self.premiumStatus {
                    performSubviewRemoval(view, animated: animated)
                    self.premiumStatus = nil
                }
            } else if let view = self.premiumStatus {
                performSubviewRemoval(view, animated: animated)
                self.premiumStatus = nil
            }
            
        } else {
            if let view = self.textView {
                performSubviewRemoval(view, animated: animated)
                self.textView = nil
            }
            if let view = self.shadowView {
                performSubviewRemoval(view, animated: animated)
                self.shadowView = nil
            }
            if let view = self.premiumStatus {
               performSubviewRemoval(view, animated: animated)
               self.premiumStatus = nil
           }
            if let urlText {
                performSubviewRemoval(urlText, animated: animated)
                self.urlText = nil
            }
        }
        
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
         
        
        guard let data = self.data else {
            return
        }
        
        transition.updateFrame(view: self.backgroundView, frame: size.bounds.insetBy(dx: 10, dy: 0))
        
        let imageView = avatarView ?? iconView
        
        if let imageView {
            if data.selected {
                transition.updateFrame(view: imageView, frame: imageView.centerFrameY(x: 20))
            } else {
                transition.updateFrame(view: imageView, frame: imageView.centerFrame())
            }
            if let loading {
                transition.updateFrame(view: loading, frame: imageView.frame)
            }
        }
        if let urlText {
            if let textView {
                transition.updateFrame(view: textView, frame: CGRect(origin: NSMakePoint(50, 4), size: textView.frame.size))
            }
            transition.updateFrame(view: urlText, frame: CGRect(origin: NSMakePoint(50, size.height - urlText.frame.height - 4), size: urlText.frame.size))
        } else {
            if let textView {
                transition.updateFrame(view: textView, frame: textView.centerFrameY(x: 50))
            }
        }
        if let premiumStatus, let textView {
            transition.updateFrame(view: premiumStatus, frame: CGRect(origin: NSMakePoint(textView.frame.maxX + 3, textView.frame.minY), size: premiumStatus.frame.size))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class TabsView: View {
    private var views: [TabView] = []
    private var items: [BrowserTabData] = []
    private let scrollView = HorizontalScrollView()
    private let documentView = View()
    private var isLocked: Bool = false
    private var selectedView: TabView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(scrollView)
        self.scrollView.documentView = documentView
        self.scrollView.background = .clear
        
        NotificationCenter.default.addObserver(forName: NSScrollView.boundsDidChangeNotification, object: scrollView.clipView, queue: nil, using: { [weak self] _ in
            guard let self, !self.isLocked else {
                return
            }
            self.updateSelectingView(transition: .immediate)
        })
        
        scrollView._mouseDownCanMoveWindow = true
        scrollView.clipView._mouseDownCanMoveWindow = true
    }
    
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
    
    private func updateSelectingView(transition: ContainedViewLayoutTransition) {
        guard let selectedView, let item = selectedView.data else {
            return
        }
        let point = self.scrollView.clipView.destination ?? self.scrollView.documentOffset
        
        var rect = getRect(item.index, items: items)
        rect.origin.x -= point.x
        
        rect.origin.x = min(max(0, rect.origin.x), frame.width - rect.width)
        
        transition.updateFrame(view: selectedView, frame: rect)
        selectedView.updateLayout(size: rect.size, transition: transition)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: frame.size, transition: .immediate)
    }
    
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        for (i, view) in views.enumerated() {
            view.isHidden = view.data?.selected == true
            transition.updateFrame(view: view, frame: getRect(i, items: self.items))
            view.updateLayout(size: view.frame.size, transition: transition)
        }
        
        let scrollRect = NSMakeRect(0, 0, size.width, size.height)
        let documentRect = NSMakeRect(0, 0, max(width, size.width), size.height)
        
        
        let documentOffset = scrollView.documentOffset

        let difference = documentRect.width - documentView.frame.width
        
        if documentOffset.x > 0, difference != 0 {
            documentView.setFrameOrigin(NSMakePoint(difference, 0))
        }
        
        transition.updateFrame(view: documentView, frame: documentRect)
        transition.updateFrame(view: scrollView.contentView, frame: scrollRect)
        transition.updateFrame(view: scrollView, frame: scrollRect)

    }
    
    func shake(_ unique: BrowserTabData.Unique) {
        if self.window?.isKeyWindow == true {
            if self.selectedView?.data?.unique == unique {
                self.selectedView?.shake(beep: false)
            } else {
                self.views.first(where: { $0.data?.unique == unique })?.shake(beep: false)
            }
        }
    }
    
    func merge(_ items: [BrowserTabData], arguments: Arguments, transition: ContainedViewLayoutTransition) {
        let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: self.items, rightList: items)
        
        CATransaction.begin()
        isLocked = true
        
        for rdx in deleteIndices.reversed() {
            performSubviewRemoval(views.remove(at: rdx), animated: transition.isAnimated, scale: true)
        }
        
        for (idx, item, _) in indicesAndItems {
            let view = TabView(frame: NSMakeRect(width, 0, 40, 38))
            view.update(item: item, arguments: arguments, transition: .immediate)
            
            views.insert(view, at: idx)
            documentView.addSubview(view)
            if transition.isAnimated {
                view.layer?.animateAlpha(from: 0, to: 1, duration: transition.duration, timingFunction: transition.timingFunction)
            }
           
        }
        for (idx, item, _) in updateIndices {
            let item = item
            views[idx].update(item: item, arguments: arguments, transition: transition)
        }
        self.items = items
        
        
        
        let selected = items.first(where: { $0.selected })
        
        let selectedUpdated = selected?.unique != self.selectedView?.data?.unique
        
        if let selected {
            let current: TabView
            
            var rect = getRect(selected.index, items: items)
            rect = self.documentView.convert(rect, to: self)

            if let view = self.selectedView {
                current = view
            } else {
                current = TabView(frame: rect)
                current.handleScrollEventOnInteractionEnabled = false
                addSubview(current)
                self.selectedView = current
            }
            
            if selected.unique != current.data?.unique {
               // current.frame = self.documentView.convert(views[selected.index].frame, to: self)
            }
            
            current.update(item: selected, arguments: arguments, transition: transition)
                        
        } else if let view = self.selectedView {
            performSubviewRemoval(view, animated: transition.isAnimated)
            self.selectedView = nil
        }
        
       
        
        self.updateLayout(size: self.frame.size, transition: transition)
        CATransaction.commit()
        
        if selectedUpdated, let selected {
            let frame = getRect(selected.index, items: items)
            scrollView.clipView.scroll(to: NSMakePoint(max(0, frame.maxX - scrollView.frame.width), 0), animated: transition.isAnimated)
        }

        updateSelectingView(transition: transition)


        
        isLocked = false

    }
    
    func getRect(_ index: Int, items: [BrowserTabData]) -> NSRect {
        var x: CGFloat = 0
        for (i, item) in items.enumerated() {
            if i < index {
                x += item.width
            }
        }
        return NSMakeRect(x, (50 - 38) / 2, items[index].width, 38)
    }
    
    var width: CGFloat {
        return views.reduce(0, { $0 + $1.frame.width })
    }
}

private final class ContentController: View {
    private var current: NSView?
    private var item: BrowserTabData?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.cornerRadius = 10
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(newView: NSView, item: BrowserTabData, animated: Bool) {
        self.item = item
        self.backgroundColor = item.external?.backgroundColor ?? item.tabColor
        if current != newView {
            if let current {
                performSubviewRemoval(current, animated: animated)
            }
            newView.frame = bounds
            addSubview(newView)
            if animated {
                newView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
            current = newView
        }
    }
    
    override func layout() {
        super.layout()
        current?.frame = bounds
    }
}

extension RequestWebViewResult : Equatable {
    public static func == (lhs: RequestWebViewResult, rhs: RequestWebViewResult) -> Bool {
        return lhs.queryId == rhs.queryId  && lhs.flags == rhs.flags && lhs.url == rhs.url
    }
}

struct BrowserTabData : Comparable, Identifiable {
    
    enum LoadingState : Equatable {
        case none
        case loading
        case error(RequestWebViewError)
    }
   
    enum Unique : Hashable {
        case webapp(Int64)
        case url(String)
        case instantView(MediaId)
        case game(MessageId)
    }
    
    
    enum Data : Equatable {
        case mainapp(bot: EnginePeer, source: RequestSimpleWebViewSource)
        case webapp(bot: EnginePeer, peerId: PeerId, buttonText: String, url: String?, payload: String?, threadId: Int64?, replyTo: MessageId?, fromMenu: Bool)
        case simple(bot: EnginePeer, url: String?, buttonText: String, source: RequestSimpleWebViewSource)
        case straight(bot: EnginePeer, peerId: PeerId, title: String, result: RequestWebViewResult)
        case tonsite(url: String)
        case instantView(url: String, webPage: TelegramMediaWebpage, anchor: String?)
        case game(url: String, peerId: PeerId, messageId: MessageId)
        var peer: EnginePeer? {
            switch self {
            case .mainapp(let bot, _):
                return bot
            case .webapp(let bot, _, _, _, _, _, _, _):
                return bot
            case .simple(let bot, _, _, _):
                return bot
            case let .straight(bot, _, _, _):
                return bot
            case .tonsite:
                return nil
            case .instantView:
                return nil
            case .game:
                return nil
            }
        }
        
        var savebleId: PeerId? {
            switch self {
            case let .mainapp(bot, _):
                return bot.id
            case let .webapp(bot, _, _, _, _, _, _, fromMenu):
                if fromMenu {
                    return bot.id
                } else {
                    return nil
                }
            default:
                return nil
            }
        }
        
        var canBeRecent: Bool {
            switch self {
            case let .mainapp(bot, _):
                return true
            case let .webapp(bot, _, _, _, _, _, _, fromMenu):
                if fromMenu {
                    return true
                } else {
                    return false
                }
            case .instantView:
                return true
            case .game:
                return true
            case .tonsite:
                return true
            default:
                return false
            }
        }
        
        var newUniqueId: Unique {
            switch self {
            case let .mainapp(bot, _):
                return .webapp(bot.id.toInt64())
            case let .webapp(bot, _, _, _, _, _, _, fromMenu):
                if fromMenu {
                    return .webapp(bot.id.toInt64())
                } else {
                    return .webapp(arc4random64())
                }
            case let .simple(bot, _, _, source):
                switch source {
                case .generic:
                    return .webapp(arc4random64())
                case .inline:
                    return .webapp(bot.id.toInt64())
                case .settings:
                    return .webapp(bot.id.toInt64())
                }
            case .straight:
                return .webapp(arc4random64())
            case let .tonsite(url):
                return .url(url)
            case let .instantView(_, webPage, _):
                return .instantView(webPage.webpageId)
            case let .game(_, _, messageId):
                return .game(messageId)
            }
        }
    }
    
    var titleText: String {
        switch data {
        case let .mainapp(peer, _):
            return peer._asPeer().displayTitle
        case let .simple(peer, _, _, _):
            return peer._asPeer().displayTitle
        case let .webapp(peer, _, _, _, _, _, _, _):
            return peer._asPeer().displayTitle
        case let .straight(_, _, title, _):
            return title
        case let .tonsite(url):
            if let title = external?.title {
                return title
            }
            if let parsedUrl = URL(string: url) {
                return parsedUrl.host ?? ""
            } else {
                return url
            }
        case .instantView:
            if let title = external?.title {
                return title
            }
            return strings().webBrowserInstantView
        case .game:
            return external?.title ?? "Game"
        }
    }
    
    
    var index: Int
    let unique: Unique
    let data: Data
    var loadingState: LoadingState = .none
    
    var isLoading: Bool {
        if let external, external.isLoading {
            return true
        } else {
            switch self.loadingState {
            case .loading:
                return true
            default:
                return false
            }
        }
    }
    
    var external: WebpageModalState? = nil
    
    var selected: Bool
    
    var title: TextViewLayout?
    var urlText: TextViewLayout?
    
    var tabColor: NSColor = .black
    
    var textColor: NSColor {
        return tabColor.lightness > 0.8 ? NSColor(0x000000) : NSColor(0xffffff)
    }

    var stableId: AnyHashable {
        return self.unique
    }
    static func < (lhs: BrowserTabData, rhs: BrowserTabData) -> Bool {
        return lhs.index < rhs.index
    }
    
    var peer: EnginePeer? {
        return external?.peer ?? self.data.peer
    }
    
    var width: CGFloat {
        if let title {
            let textWidth = max(title.layoutSize.width, urlText?.layoutSize.width ?? 0)
            var width = textWidth + 20 + 20 + 10 + 20
            if let peer = self.peer {
                if let size = PremiumStatusControl.controlSize(peer._asPeer(), false, left: false) {
                    width += (size.width) + 2
                }
            }
            
            return width
        } else {
            return 40
        }
    }
    
    func measure(width: CGFloat) -> BrowserTabData {
        
        var tabColor: NSColor = theme.colors.background
        
        
//        if let key = self.external?.headerColorKey {
//            if key == "bg_color" {
//                tabColor = self.external?.backgroundColor ?? tabColor
//            } else {
//                tabColor = theme.colors.listBackground
//            }
//        } else if let color = external?.headerColor {
//            tabColor = color
//        } else {
//            tabColor = self.external?.backgroundColor ?? tabColor
//        }
        
        if selected {
            let color: NSColor = tabColor.lightness > 0.8 ? NSColor(0x000000) : NSColor(0xffffff)
            let layout = TextViewLayout(.initialize(string: titleText, color: color, font: .normal(.text)), maximumNumberOfLines: 1)
            layout.measure(width: width - 100)
            
            let urlLayout: TextViewLayout?
            
            if let subtitle = self.external?.subtitle {
                let attributedString = NSMutableAttributedString()
                attributedString.append(string: subtitle, color: theme.colors.grayText, font: .normal(.small))
                urlLayout = .init(attributedString, maximumNumberOfLines: 1)
                urlLayout?.measure(width: width - 100)
            } else if let url = external?.url, let url = URL(string: url), let (result, host) = urlWithoutScheme(from: url), external?.title != host {
                
                let attributedString = NSMutableAttributedString()
                attributedString.append(string: result, color: theme.colors.grayText, font: .normal(.small))
                let range = attributedString.string.nsstring.range(of: host)
                if range.location != NSNotFound {
                    attributedString.addAttribute(.foregroundColor, value: theme.colors.text, range: range)
                }
                urlLayout = .init(attributedString, maximumNumberOfLines: 1)
                urlLayout?.measure(width: width - 100)
            } else {
                urlLayout = nil
            }
            
            var tab = self
            tab.title = layout
            tab.urlText = urlLayout
            tab.tabColor = tabColor
            return tab
        } else {
            var tab = self
            tab.title = nil
            tab.tabColor = tabColor
            return tab
        }
    }
}

private final class TabsController: GenericViewController<TabsView> {
        
    
    override init() {
        super.init()
        bar = .init(height: 0)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func merge(_ data: [BrowserTabData], arguments: Arguments, transition: ContainedViewLayoutTransition) {
        self.genericView.merge(data, arguments: arguments, transition: transition)
    }
    
    func shake(_ unique: BrowserTabData.Unique) {
        self.genericView.shake(unique)
    }
}


private final class BackOrClose : Control {
    
    enum State : Equatable {
        case none
        case close(NSColor)
        case back(NSColor)
        
        func file(_ animated: Bool) -> LocalAnimatedSticker {
            switch self {
            case .close:
                return LocalAnimatedSticker.browser_back_to_close
            case .back:
                return LocalAnimatedSticker.browser_close_to_back
            case .none:
                fatalError()
            }
        }
    }
    
    private var state: State = .none
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(animationView)
        self.updateState(state: .close(theme.colors.text.withAlphaComponent(0.5)), animated: false)
    }
    
    private let animationView: LottiePlayerView = .init(frame: NSMakeRect(0, 0, 30, 30))

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func withUpdatedColor(_ color: NSColor) -> State {
        switch self.state {
        case .none:
            return .none
        case .close:
            return .close(color)
        case .back:
            return .back(color)
        }
    }
    
    func updateState(state: State, animated: Bool) {
        if self.state != state {
            switch state {
            case let .back(color), let .close(color):
                let renderSize = self.animationView.frame.size
                let colorChanged = self.animationView.animation?.colors.first?.color != color
                let animation = state.file(animated)
                
                guard let data = animation.data else {
                    return
                }
                
                let playPolicy: LottiePlayPolicy
                
                if animated && !colorChanged {
                    playPolicy = .toEnd(from: 0)
                } else {
                    playPolicy = .toEnd(from: .max)
                }
                            
                animationView.set(LottieAnimation(compressed: data, key: .init(key: .bundle(animation.rawValue), size: renderSize), cachePurpose: .none, playPolicy: playPolicy, maximumFps: 60, colors: [.init(keyPath: "", color: color)], runOnQueue: .mainQueue()))
            default:
                break
            }

            
            
        }
        
        self.state = state
    }
    
    override func layout() {
        super.layout()
        animationView.center()
    }
}

private final class MoreControl : Control {
    
    private var lottieAnimation: LottieAnimation?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(animationView)
        set(handler: { [weak self] _ in
            self?.animationView.set(self?.lottieAnimation?.withUpdatedPolicy(.onceEnd), reset: true)
        }, for: .Down)
    }
    private let animationView: LottiePlayerView = .init(frame: NSMakeRect(0, 0, 30, 30))

    func set(color: NSColor) {
        let renderSize = NSMakeSize(30, 30)
        let animation = LocalAnimatedSticker.browser_more
        guard let data = animation.data else {
            return
        }
        let lottieAnimation = LottieAnimation(compressed: data, key: .init(key: .bundle(animation.rawValue), size: renderSize), cachePurpose: .none, playPolicy: .toEnd(from: .max), maximumFps: 60, colors: [.init(keyPath: "", color: color)], runOnQueue: .mainQueue())
        
        if lottieAnimation != self.lottieAnimation {
            animationView.set(lottieAnimation)
        }
        self.lottieAnimation = lottieAnimation
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        animationView.center()
    }
}

private final class FullscreenControls : View {
    
    fileprivate final class MoreButton : Control {
        private let visual = VisualEffect()
        let more = MoreControl(frame: NSMakeRect(0, 0, 30, 30))
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(visual)
            addSubview(more)
            visual.bgColor = theme.colors.grayForeground.withAlphaComponent(0.6)
            self.layer?.cornerRadius = frameRect.height / 2
        }
        
         required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layout() {
            super.layout()
            visual.frame = bounds
        }
    }
    
    
    fileprivate final class BackCloseButton : Control {
        private let visual = VisualEffect()
        let close = BackOrClose(frame: NSMakeRect(0, 0, 30, 30))
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(visual)
            addSubview(close)
            visual.bgColor = theme.colors.grayForeground.withAlphaComponent(0.6)
            self.layer?.cornerRadius = frameRect.height / 2
        }
        
         required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layout() {
            super.layout()
            visual.frame = bounds
        }
    }
    fileprivate let more = MoreButton(frame: NSMakeRect(0, 0, 30, 30))
    fileprivate let close: BackCloseButton = BackCloseButton(frame: NSMakeRect(0, 0, 30, 30))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(close)
        addSubview(more)
        
        more.more.userInteractionEnabled = false
        more.more.isEventLess = true
        
        close.close.userInteractionEnabled = false
        close.close.isEventLess = true

        close.scaleOnClick = true
        more.scaleOnClick = true
    }
    
     required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        close.centerY(x: 30)
        more.centerY(x: frame.width - more.frame.width - 30)
    }
    
    func updateState(state: BackOrClose.State, animated: Bool) {
        self.close.close.updateState(state: state, animated: animated)
    }
    func set(color: NSColor) {
        self.more.more.set(color: color)
    }
}

private final class BrowserView : View {
    fileprivate var tabsView: TabsView?
    fileprivate let more = MoreControl(frame: NSMakeRect(0, 0, 50, 50))
    fileprivate let close = BackOrClose(frame: NSMakeRect(0, 0, 50, 50))
    
    let header = View()
    
    weak var arguments: Arguments?
    
    var state: State? {
        didSet {
            if oldValue?.fullscreen != state?.fullscreen {
                updateFullscreenControls()
            }
        }
    }

    fileprivate let contentView: ContentController = .init(frame: .zero)
    
    private var fullscreenControls: FullscreenControls?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.cornerRadius = 10
        addSubview(contentView)
        addSubview(header)
        
        more.scaleOnClick = true
        close.scaleOnClick = true



        header.addSubview(more)
        header.addSubview(close)
        
        updateLocalizationAndTheme(theme: theme)
        
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    private var fullscreen: Bool = false
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        guard let tabsView, let state else {
            return
        }
        
        let transition: ContainedViewLayoutTransition = fullscreen != state.fullscreen ? .immediate : transition
        
        let startY: CGFloat = state.fullscreen ? -50 : 0
        
        transition.updateFrame(view: header, frame: NSMakeRect(0, startY, size.width, 50))

        transition.updateFrame(view: tabsView, frame: NSMakeRect(40, startY, size.width - 80, header.frame.height))

        transition.updateFrame(view: close, frame: close.centerFrameY(x: 0))
        transition.updateFrame(view: more, frame: more.centerFrameY(x: size.width - more.frame.width))

        transition.updateFrame(view: contentView, frame: NSMakeRect(0, header.frame.maxY, size.width, size.height - header.frame.maxY))
        
        if let current = fullscreenControls {
            transition.updateFrame(view: current, frame: NSMakeRect(0, 0, size.width, 60))
        }
        
        self.fullscreen = state.fullscreen
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        self.more.set(color: theme.colors.text.withAlphaComponent(0.5))
        self.close.updateState(state: self.close.withUpdatedColor(theme.colors.text.withAlphaComponent(0.5)), animated: false)
    }
    
    func update(tab: BrowserTabData, animated: Bool) {
        let isBackButton = tab.external?.isBackButton ?? false
        let color = theme.colors.text.withAlphaComponent(0.5)
        self.close.updateState(state: isBackButton ? .back(color) : .close(color), animated: animated)
        
        updateFullscreenControls()
        
        self.fullscreenControls?.updateState(state: isBackButton ? .back(NSColor(0xffffff)) : .close(NSColor(0xffffff)), animated: animated)
        self.fullscreenControls?.set(color: NSColor(0xffffff))
    }
    
    private func updateFullscreenControls() {
        if self.state?.fullscreen == true {
            let current: FullscreenControls
            if let view = self.fullscreenControls {
                current = view
            } else {
                current = FullscreenControls(frame: NSMakeRect(0, 0, frame.width, 60))
                self.fullscreenControls = current
                addSubview(current)
            }
            
            current.close.setSingle(handler: { [weak self] _ in
                self?.arguments?.close()
            }, for: .Click)
            
            current.more.setSingle(handler: { [weak self] control in
                self?.arguments?.add(control)
            }, for: .Click)
            
        } else if let view = self.fullscreenControls {
            performSubviewRemoval(view, animated: false)
            self.fullscreenControls = nil
        }
    }
}


private struct State : Equatable {
    var tabs: [BrowserTabData] = []
    var fullscreen: Bool = false
    
    var selected: BrowserTabData? {
        return tabs.first(where: { $0.selected })
    }

    func newTab(_ data: BrowserTabData.Data, unique: BrowserTabData.Unique, external: WebpageModalState?) -> (State, BrowserTabData?) {
        var tabs = self.tabs
        for i in 0 ..< tabs.count {
            tabs[i].selected = false
        }
        
        let newData: BrowserTabData?
        
        if let index = tabs.firstIndex(where: { $0.unique == unique }) {
            tabs[index].selected = true
            newData = nil
        } else {
            var new = BrowserTabData(index: tabs.count, unique: unique, data: data, selected: true)
            new.external = external
            newData = new
            tabs.append(new)
        }
        
        return (.init(tabs: tabs, fullscreen: self.fullscreen), newData)
    }
    
    func select(_ item: BrowserTabData) -> State {
        var tabs = self.tabs
        for i in 0 ..< tabs.count {
            tabs[i].selected = tabs[i].unique == item.unique
        }
        return .init(tabs: tabs, fullscreen: self.fullscreen)
    }
    
    func select(_ unique: BrowserTabData.Unique) -> State {
        var tabs = self.tabs
        for i in 0 ..< tabs.count {
            tabs[i].selected = tabs[i].unique == unique
        }
        return .init(tabs: tabs, fullscreen: self.fullscreen)
    }
    
    func selectAt(_ index: Int) -> State {
                
        var tabs = self.tabs
        
        if index < tabs.count {
            for i in 0 ..< tabs.count {
                tabs[i].selected = i == index
            }
        }
        
        return .init(tabs: tabs, fullscreen: self.fullscreen)
    }
    
    func setIsLoading(_ unqiue: BrowserTabData.Unique, loadingState: BrowserTabData.LoadingState) -> State {
        var tabs = self.tabs
        if let index = tabs.firstIndex(where: { $0.unique == unqiue }) {
            tabs[index].loadingState = loadingState
        }
        return .init(tabs: tabs, fullscreen: self.fullscreen)
    }
    func setExternal(_ unique: BrowserTabData.Unique, external: WebpageModalState) -> State {
        var tabs = self.tabs
        if let index = tabs.firstIndex(where: { $0.unique == unique }) {
            tabs[index].external = external
        }
        return .init(tabs: tabs, fullscreen: self.fullscreen)
    }
    
    func closeTab(_ unique: BrowserTabData.Unique) -> State {
        var tabs = self.tabs
        if let index = tabs.firstIndex(where: { $0.unique == unique }) {
            tabs.remove(at: index)
            
            let selectedIndex: Int
            if index == tabs.count {
                selectedIndex = tabs.count - 1
            } else {
                selectedIndex = index
            }
            
            for i in 0 ..< tabs.count {
                tabs[i].index = i
                tabs[i].selected = selectedIndex == i
            }
        }
       
        return .init(tabs: tabs, fullscreen: self.fullscreen)
    }
}

private final class WebpageContainerView : View {
    private var loading: ProgressIndicator?
    private var mainView: NSView?
    private var errorView: ErrorLoadingView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(data: BrowserTabData, arguments: Arguments, animated: Bool) {
        
        self.backgroundColor = data.external?.backgroundColor ?? theme.colors.background
        
        let error: RequestWebViewError?
        switch data.loadingState {
        case let  .error(value):
            error = value
        default:
            if let value = data.external?.error {
                error = value
            } else {
                error = nil
            }
        }
        
        if data.isLoading {
            let current: ProgressIndicator
            if let view = self.loading {
                current = view
            } else {
                current = ProgressIndicator(frame: focus(NSMakeSize(40, 40)))
                self.loading = current
                addSubview(current)
            }
            current.progressColor = theme.colors.grayText
            current.animates = true
        } else {
            if let view = loading {
                performSubviewRemoval(view, animated: animated)
                self.loading = nil
            }
        }

        if let error {
            let current: ErrorLoadingView
            if let view = self.errorView {
                current = view
            } else {
                current = ErrorLoadingView(frame: bounds)
                self.errorView = current
                addSubview(current)
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            current.update(arguments: arguments, error: error)
        } else if let view = errorView {
            performSubviewRemoval(view, animated: animated)
            self.errorView = nil
        }
    }
    
    func setMainView(_ newView: NSView, animated: Bool) {
        if mainView != newView {
            if let mainView {
                performSubviewRemoval(mainView, animated: animated)
            }
            addSubview(newView)
            if animated {
                newView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
            mainView = newView
        }
    }
    
    override func layout() {
        super.layout()
        loading?.center()
        mainView?.frame = bounds
    }
}

private final class WebpageContainerController : GenericViewController<WebpageContainerView> {
    private let data: BrowserTabData
    private let context: AccountContext
    private let arguments: Arguments
    private var controller: (ViewController & BrowserPage)?
    private let disposable = MetaDisposable()
    private let externalState = MetaDisposable()

    private var appeared: Bool = false
    
    init(data: BrowserTabData, context: AccountContext, arguments: Arguments) {
        self.data = data
        self.context = context
        self.arguments = arguments
        super.init()
        self.bar = .init(height: 0)
    }
    
    func contextMenu() -> ContextMenu? {
        return self.controller?.contextMenu()
    }
    
    func backPressed() {
        controller?.backButtonPressed()
    }
    
    func reloadPage() {
        controller?.reloadPage()
    }
    
    func add(_ tab: BrowserTabData.Data) -> Bool {
        return controller?.add(tab) ?? false
    }
    
    deinit {
        disposable.dispose()
        externalState.dispose()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        arguments.setLoadingState(data.unique, .loading)
        
        switch data.data {
        case let .tonsite(url):
            let controller = WebsiteController(context: context, url: url, browser: arguments.makeLinkManager(data.unique))
            self.set(controller, animated: true)
            arguments.setLoadingState(data.unique, .none)
        case let .instantView(url, webPage, anchor):
            let controller = InstantViewInBrowser(webPage: webPage, context: arguments.context, url: url, anchor: anchor, browser: arguments.makeLinkManager(data.unique))
            self.set(controller, animated: true)
            arguments.setLoadingState(data.unique, .none)
        case let .game(url, peerId, messageId):
            let controller = WebGameViewController(arguments.context, peerId: peerId, messageId: messageId, gameUrl: url, browser: arguments.makeLinkManager(data.unique))
            self.set(controller, animated: true)
            arguments.setLoadingState(data.unique, .none)
        case .mainapp, .simple, .straight, .webapp:
            let signal = makeWebViewController(context: context, data: data.data, unique: data.unique, makeLinkManager: arguments.makeLinkManager) |> deliverOnMainQueue
            disposable.set(signal.startStrict(next: { [weak self] controller in
                guard let self else {
                    return
                }
                self.set(controller, animated: true)
                arguments.setLoadingState(self.data.unique, .none)
            }, error: { [weak self] error in
                guard let self else {
                    return
                }
                arguments.setLoadingState(self.data.unique, .error(error))
            }))
        }
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        controller?.updateLocalizationAndTheme(theme: theme)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appeared = true
        controller?.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        controller?.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        appeared = false
        controller?.viewWillDisappear(animated)
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        controller?.viewDidDisappear(animated)
    }
    
    private func set(_ controller: (ViewController & BrowserPage), animated: Bool) {
        self.controller = controller
        controller._frameRect = bounds
        if appeared {
            controller.viewWillAppear(animated)
        }
        self.genericView.setMainView(controller.view, animated: animated)
        if appeared {
            controller.viewDidAppear(animated)
        }
        
        externalState.set(controller.externalState.startStrict(next: { [weak self] state in
            guard let self else {
                return
            }
            self.arguments.setExternalState(self.data.unique, state)
        }))
    }
    
    func update(data: BrowserTabData, arguments: Arguments, animated: Bool) {
        self.genericView.update(data: data, arguments: arguments, animated: animated)
    }
    
}

final class BrowserLinkManager {
    weak var window: Window?
    let context: AccountContext
    let unique: BrowserTabData.Unique
    private weak var arguments: Arguments?
    fileprivate init(context: AccountContext, window: Window?, unique: BrowserTabData.Unique, arguments: Arguments?) {
        self.window = window
        self.context = context
        self.unique = unique
        self.arguments = arguments
    }
    
    func back() {
        
    }
    func close(confirm: Bool) {
        arguments?.closeTab(unique, confirm)
    }
    func open(_ tab: BrowserTabData.Data) {
        arguments?.insertTab(tab)
    }
    
    func getExternal() -> WebpageModalState? {
        return arguments?.getExternalState(unique)
    }
}


final class WebappBrowserController : ViewController {
    private let tabs = TabsController()
    private var webpages: [BrowserTabData.Unique : WebpageContainerController] = [:]
    private var current: WebpageContainerController?
    let context: AccountContext
    private var arguments: Arguments?
    
    private var initialTab: BrowserTabData.Data?
    
    private(set) var markAsDeinit: Bool = false
    
    private let publicStateValue: Promise<[BrowserTabData]> = Promise()
    var publicState:Signal<[BrowserTabData], NoError> {
        return publicStateValue.get()
    }
    
    init(context: AccountContext, initialTab: BrowserTabData.Data? = nil) {
        self.context = context
        self.initialTab = initialTab
        super.init()
        bar = .init(height: 0)
        _window = WebappBrowser(parent: context.window)
    }
    
    func add(_ tab: BrowserTabData.Data, uniqueId: BrowserTabData.Unique? = nil) {
        if let uniqueId, let webpage = webpages[uniqueId] {
            arguments?.select(uniqueId)
            _ = webpage.add(tab)
        } else {
            arguments?.insertTab(tab)
        }
    }
    
    func makeKeyAndOrderFront() {
        browser.makeKeyAndOrderFront(nil)
    }
    
    func closeTab() {
        self.arguments?.closeTab(nil, false)
    }
    
    private var browser: WebappBrowser {
        return _window! as! WebappBrowser
    }
    
    func show() {
                
        loadViewIfNeeded()
        browser.contentView?.addSubview(self.view)
        browser.show()
        
        browser.onToggleFullScreen = { [weak self] value in
            self?.arguments?.updateFullscreen(value)
        }
        

        browser.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.current?.reloadPage()
            return .invoked
        }, with: self, for: .R, priority: .modal, modifierFlags: [.command])
        
        browser.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.arguments?.selectAtIndex(0)
            return .invoked
        }, with: self, for: .One, priority: .modal, modifierFlags: [.command])
        
        browser.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.arguments?.selectAtIndex(1)
            return .invoked
        }, with: self, for: .Two, priority: .modal, modifierFlags: [.command])
        
        browser.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.arguments?.selectAtIndex(2)
            return .invoked
        }, with: self, for: .Three, priority: .modal, modifierFlags: [.command])
        
        browser.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.arguments?.selectAtIndex(3)
            return .invoked
        }, with: self, for: .Four, priority: .modal, modifierFlags: [.command])
        
        browser.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.arguments?.selectAtIndex(4)
            return .invoked
        }, with: self, for: .Five, priority: .modal, modifierFlags: [.command])
        
        browser.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.arguments?.selectAtIndex(5)
            return .invoked
        }, with: self, for: .Six, priority: .modal, modifierFlags: [.command])
        
        browser.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.arguments?.selectAtIndex(6)
            return .invoked
        }, with: self, for: .Seven, priority: .modal, modifierFlags: [.command])
        
        browser.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.arguments?.selectAtIndex(7)
            return .invoked
        }, with: self, for: .Eight, priority: .modal, modifierFlags: [.command])
        
        browser.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.arguments?.selectAtIndex(8)
            return .invoked
        }, with: self, for: .Nine, priority: .modal, modifierFlags: [.command])
        
        browser.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.arguments?.selectAtIndex(9)
            return .invoked
        }, with: self, for: .Zero, priority: .modal, modifierFlags: [.command])
        
        browser.set(handler: { [weak self] _ -> KeyHandlerResult in
            guard let self else {
                return .rejected
            }
            self.arguments?.add(self.genericView.more)
            return .invoked
        }, with: self, for: .T, priority: .modal, modifierFlags: [.command])
        
        
        
    }
    
    func hide(_ completion: @escaping()->Void, close: Bool = true) {
        markAsDeinit = true
        if close {
            closeAllModals(window: browser)
        }
        
        browser.removeAllHandlers(for: self)
        
        self.browser.contentView?.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak self] _ in
            self?.browser.orderOut(nil)
            if close {
                self?._window = nil
            }
            completion()
        })
    }
    
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        self.genericView.updateLayout(size: size, transition: .immediate)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        WKWebsiteDataStore.default().removeData(ofTypes: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache], modifiedSince: Date(timeIntervalSince1970: 0), completionHandler:{ })
        
        self.genericView.tabsView = tabs.genericView
        self.genericView.header.addSubview(tabs.view)
        self.genericView.layout()
        
        let rect = browser.frame.size.bounds.insetBy(dx: 10, dy: 10)
        self.view.frame = rect
        
        let actionsDisposable = DisposableSet()
        let context = self.context
        let initialState = State()
        
        let statePromise = ValuePromise(initialState, ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((State) -> State) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }
        
        var getArguments:(()->Arguments?)? = nil
        
        let insertTab:(BrowserTabData.Data)->Void = { [weak self] data in
            
            let unique = data.newUniqueId
            
            let invoke:()->Void = {
                
                var state = stateValue.with { $0 }
                
                let selectedId = state.selected?.unique
                
                var insertedData: BrowserTabData? = nil
                
                (state, insertedData) = state.newTab(data, unique: unique, external: BrowserStateContext.get(context).getExternal(unique))
                
                if let insertedData, let arguments = getArguments?() {
                    let controller = WebpageContainerController(data: insertedData, context: context, arguments: arguments)
                    self?.webpages[unique] = controller
                    
                    updateState { current in
                        return state
                    }
                    BrowserStateContext.get(context).add(.init(tabdata: insertedData))
                    
                }  else {
                    let added = self?.webpages[unique]?.add(data) ?? false
                    
                    if selectedId == unique, !added {
                        getArguments?()?.shake(unique)
                    } else {
                        updateState { current in
                            return state.select(unique)
                        }
                    }
                }
            }
            
            invoke()
        }
        
        let arguments = Arguments(context: context, add: { [weak self] control in
            guard let event = NSApp.currentEvent else {
                return
            }
            let state = BrowserStateContext.get(context).fullState()
            |> take(1)
            |> deliverOnMainQueue
            actionsDisposable.add(state.startStrict(next: { [weak control] webapps in
                if let control {
                    let menu = ContextMenu(betterInside: true)
                    
                    let appItem:(BrowserStateContext.FullState.Recommended)->ContextMenuItem? = { webapp in
                        if let user = webapp.peer._asPeer() as? TelegramUser {
                            
                            let afterNameBadge = generateContextMenuSubsCount((webapp.peer._asPeer() as? TelegramUser)?.subscriberCount)
                            
                            let data = BrowserTabData.Data.mainapp(bot: webapp.peer, source: .generic)
                            return ReactionPeerMenu(title: user.displayTitle, handler: {
                                BrowserStateContext.get(context).open(tab: data)
                            }, peer: user, context: context, reaction: nil, afterNameBadge: afterNameBadge)
                        } else {
                            return nil
                        }
                    }
                    
                    let submenu = ContextMenu(betterInside: true)
                    
                    if !webapps.recentUsedApps.isEmpty {
                        for webapp in webapps.recentUsedApps {
                            if let item = appItem(webapp) {
                                submenu.addItem(item)
                            }
                        }
                    }
                    if !submenu.items.isEmpty && !webapps.recommended.isEmpty {
                        submenu.addItem(ContextSeparatorItem())
                    }
                    for webapp in webapps.recommended {
                        if let item = appItem(webapp) {
                            submenu.addItem(item)
                        }
                    }
                    
                    
                    let selected = stateValue.with { $0.selected }
                    
                    if let selected {
                        let menuItems = getArguments?()?.contextMenu(selected)?.contextItems ?? []
                        if !menuItems.isEmpty {
                            for menuItems in menuItems {
                                menu.addItem(menuItems)
                            }
                        }
                    }
                    
                   
                    
                    if !submenu.items.isEmpty {
                        
                        menu.addItem(ContextSeparatorItem())
                        
                        let item = ContextMenuItem(strings().chatListAppsPopular, itemImage: MenuAnimation.menu_apps.value)
                        item.submenu = submenu
                        menu.addItem(item)
                    }
                    
                    if !menu.items.isEmpty, stateValue.with ({ $0.tabs.count > 1 }) {
                        menu.addItem(ContextMenuItem(strings().chatListAppsCloseAll, handler: {
                            BrowserStateContext.get(context).hide()
                        }, itemMode: .destruct, itemImage: MenuAnimation.menu_close_multiple.value))
                    }
                    
                    AppMenu.show(menu: menu, event: event, for: control)
                }
            }))
        }, close: { [weak self] in
            let current = stateValue.with { $0.selected }
            guard let current else {
                BrowserStateContext.get(context).closeAll()
                return
            }
            if current.external?.isBackButton == true {
                self?.webpages[current.unique]?.backPressed()
            } else {
                getArguments?()?.closeTab(nil, true)
            }
        }, select: { uniqueId in
            updateState { current in
                var current = current
                current = current.select(uniqueId)
                return current
            }
        }, setLoadingState: { unique, state in
            updateState { current in
                var current = current
                current = current.setIsLoading(unique, loadingState: state)
                return current
            }
        }, setExternalState: { unique, state in
            updateState { current in
                var current = current
                current = current.setExternal(unique, external: state)
                return current
            }
            BrowserStateContext.get(context).setExternalState(unique, external: state)
        }, closeTab: { [weak self] unique, checkAdmission in
            let unique = unique ?? stateValue.with { $0.selected?.unique }
            let count = stateValue.with { $0.tabs.count }
            let data = stateValue.with { $0.tabs.first(where: { $0.unique == unique }) }

            guard let unique, let data else {
                return
            }
            let invoke:()->Void = {
                
                if count == 1, let window = self?.window, !hasModals(window) {
                    if window.isFullScreen == true {
                        window.toggleFullScreen(nil)
                    } else {
                        BrowserStateContext.get(context).hide()
                    }
                } else {
                    updateState {
                        $0.closeTab(unique)
                    }
                    self?.webpages.removeValue(forKey: unique)
                }
            }
            let needAdmit = data.external?.needConfirmation ?? false
            if needAdmit, checkAdmission, let window = self?.browser, window.isFullScreen == false {
                verifyAlert_button(for: window, information: strings().webpageConfirmClose, ok: strings().webpageConfirmOk, successHandler: { _ in
                   invoke()
                })
            } else {
                invoke()
            }
            
        }, selectAtIndex: { index in
            updateState { current in
                var current = current
                current = current.selectAt(index)
                return current
            }
        }, makeLinkManager: { [weak self] id in
            return BrowserLinkManager(context: context, window: self?.browser, unique: id, arguments: getArguments?())
        }, contextMenu: { [weak self] item in
            let unique = item.unique
            let webpageItems = self?.webpages[item.unique]?.contextMenu()?.contextItems ?? []
            
            var items: [ContextMenuItem] = []
            
            if item.selected {
                items.append(contentsOf: webpageItems)
                if self?.window?.isFullScreen == false {
                    items.append(ContextMenuItem(strings().webAppClose, handler: {
                        getArguments?()?.closeTab(unique, true)
                    }, itemImage: MenuAnimation.menu_clear_history.value))
                }
                
            } else {
                if self?.window?.isFullScreen == false {
                    items.append(ContextMenuItem(strings().webAppClose, handler: {
                        getArguments?()?.closeTab(unique, true)
                    }, itemImage: MenuAnimation.menu_clear_history.value))
                }
            }
            if !items.isEmpty {
                let menu = ContextMenu(betterInside: true)
                for item in items {
                    menu.addItem(item)
                }
                return menu
            }
            return nil
        }, insertTab: { data in
            insertTab(data)
        }, shake: { [weak self] unique in
            self?.tabs.shake(unique)
        }, getExternalState: { unique in
            return stateValue.with {
                $0.tabs.first(where: { $0.unique == unique })?.external
            }
        }, updateFullscreen: { value in
            updateState { current in
                var current = current
                current.fullscreen = value
                return current
            }
        })
        
        self.arguments = arguments
         
        getArguments = { [weak arguments] in
            return arguments
        }
        
        let animated = Atomic(value: false)
        
        
        
        actionsDisposable.add(combineLatest(queue: .mainQueue(), statePromise.get(), appearanceSignal).start(next: { [weak self] state, appearance in
            guard let self else {
                return
            }
            let animated = animated.swap(true)
            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.35, curve: .spring) : .immediate
            
            let tabs = layoutTabs(state.tabs, width: self.genericView.frame.width - 80 - 80)
            
            self.genericView.state = state
            self.genericView.arguments = self.arguments
            
            self.tabs.merge(tabs, arguments: arguments, transition: transition)
            if let tab = state.tabs.first(where: { $0.selected }) {
                self.genericView.update(tab: tab, animated: transition.isAnimated)
            }
            self.genericView.updateLayout(size: self.frame.size, transition: transition)
            self.updateLocalizationAndTheme(theme: appearance.presentation)

            DispatchQueue.main.async {
                self.updateWebpage(tabs, animated: transition.isAnimated)
            }
        }))
        
        genericView.close.set(handler: { _ in
            arguments.close()
        }, for: .Click)
        
        genericView.more.set(handler: { control in
            arguments.add(control)
        }, for: .Click)
        
        onDeinit = {
            actionsDisposable.dispose()
        }
        
        if let initialTab {
            insertTab(initialTab)
        }
        
        publicStateValue.set(statePromise.get() |> map { $0.tabs })

    }
    
    private func updateWebpage(_ tabs: [BrowserTabData], animated: Bool) {
        guard let arguments else {
            return
        }
        
        if let tab = tabs.first(where: { $0.selected }), let controller = webpages[tab.unique] {
            
            if current != controller {
                controller._frameRect = genericView.contentView.bounds
                current?.viewWillDisappear(animated)
                controller.viewWillAppear(animated)
            }
            
            genericView.contentView.update(newView: controller.view, item: tab, animated: animated)

            if current != controller {
                controller.viewDidAppear(animated)
                current?.viewDidDisappear(animated)
            }
            
            
            for tab in tabs {
                webpages[tab.unique]?.update(data: tab, arguments: arguments, animated: animated)
            }
            self.current = controller
        } else {
            self.current?.viewWillDisappear(animated)
            if let view = self.current?.view {
                performSubviewRemoval(view, animated: animated)
            }
            self.current = nil
        }
        
     
        
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        browser.containerView.backgroundColor = theme.colors.listBackground
    }
    
    override func viewClass() -> AnyClass {
        return BrowserView.self
    }
    
    deinit {
        
    }
    
    private var genericView: BrowserView {
        return self.view as! BrowserView
    }
}
