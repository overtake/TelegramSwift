//
//  InstantPageViewController.swift
//  Telegram
//
//  Created by keepcoder on 21/07/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac

class InstantPageModalBrowser : ModalViewController {
    
    private let navigation: NavigationViewController
    
    init(_ page: InstantPageViewController) {
        self.navigation = NavigationViewController(page)
        page._frameRect = NSMakeRect(0, 0, 400, 365)
        navigation._frameRect = NSMakeRect(0, 0, 400, 400)
        super.init(frame: page._frameRect)
        
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        if navigation.controller == navigation.empty {
            return .rejected
        }
        navigation.back()
        return .invoked
    }
    
    var currentInstantController:InstantPageViewController {
        return navigation.controller as! InstantPageViewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.ready.set(currentInstantController.ready.get())
    }
    
    

    
    override var handleEvents: Bool {
        return true
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    override func measure(size: NSSize) {
        updateSize(size)
    }
    
    private func updateSize(_ size: NSSize) {
        self.modal?.resize(with:NSMakeSize(min(size.width - 120, 600), min(size.height - 40, currentInstantController.genericView.documentSize.height)), animated: false)
    }
    
    override func initializer() -> NSView {
        return navigation.view
    }
}

class InstantPageViewController: TelegramGenericViewController<ScrollView> {
    
    
    
    var pageDidScrolled:(((documentSize: NSSize, position: ScrollPosition))->Void)?
    
    var currentLayout: InstantPageLayout?
    var instantPage: InstantPage?
    var currentLayoutTiles: [InstantPageTile] = []
    var currentLayoutItemsWithViews: [InstantPageItem] = []
    var currentLayoutItemsWithLinks: [InstantPageItem] = []
    var distanceThresholdGroupCount: [Int: Int] = [:]
    
    var visibleTiles: [Int: InstantPageTileView] = [:]
    var visibleItemsWithViews: [Int: InstantPageView] = [:]
    var visibleLinkSelectionViews: [Int: InstantPageLinkSelectionView] = [:]
    
    var previousContentOffset: CGPoint?
    var isDeceleratingBecauseOfDragging = false
    
    private var selectManager: InstantPageSelectText?
    
    private let joinDisposable = MetaDisposable()
    private let mediaDisposable = MetaDisposable()
    private var appearance: InstantViewAppearance = InstantViewAppearance.defaultSettings
    private let actualizeDisposable = MetaDisposable()
    private let saveProgressDisposable = MetaDisposable()
    private let loadWebpageDisposable = MetaDisposable()
    private let updateLayoutDisposable = MetaDisposable()
    private let appearanceDisposable = MetaDisposable()
    private var initialAnchor: String?
    private var pendingAnchor: String?
    private var initialState: InstantPageStoredState?
    
    private let loadProgress = ValuePromise<CGFloat>(0.00, ignoreRepeated: true)
    var progressSignal: Signal<CGFloat, NoError> {
        return loadProgress.get()
    }

    
    var currentWebEmbedHeights: [Int : CGFloat] = [:]
    var currentExpandedDetails: [Int : Bool]?
    var currentDetailsItems: [InstantPageDetailsItem] = []
    
    var webPage: TelegramMediaWebpage {
        didSet {
            switch webPage.content {
            case .Loaded(let content):
                self.instantPage = content.instantPage
            default:
                break
            }
        }
    }
    let message: String?
    init(_ context: AccountContext, webPage: TelegramMediaWebpage, message: String?, messageId: MessageId? = nil, anchor: String? = nil, saveToRecent: Bool = true) {
        self.webPage = webPage
        self.message = message
        self.pendingAnchor = anchor
        switch webPage.content {
        case .Loaded(let content):
            self.instantPage = content.instantPage
        default:
            break
        }
        super.init(context)
        bar = .init(height: 0)
        noticeResizeWhenLoaded = false
    }
    
    override var defaultBarTitle: String {
        switch webPage.content {
        case .Loaded(let content):
            return content.websiteName ?? super.defaultBarTitle
        default:
            return super.defaultBarTitle
        }
    }
    
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
    }
    
    var currentState: InstantPageStoredState {
        var details: [InstantPageStoredDetailsState] = []
        if let currentExpandedDetails = self.currentExpandedDetails {
            for (index, expanded) in currentExpandedDetails {
                details.append(InstantPageStoredDetailsState(index: Int32(clamping: index), expanded: expanded, details: []))
            }
        }
        return InstantPageStoredState(contentOffset: Double(self.genericView.contentOffset.y), details: details)
    }
    
    
    func updateWebPage(_ webPage: TelegramMediaWebpage, anchor: String?, state: InstantPageStoredState? = nil) {
        if self.webPage != webPage {
           
            self.webPage = webPage
            if let anchor = anchor {
                self.initialAnchor = anchor.removingPercentEncoding
            } else if let state = state {
                self.initialState = state
                if !state.details.isEmpty {
                    var storedExpandedDetails: [Int: Bool] = [:]
                    for state in state.details {
                        storedExpandedDetails[Int(clamping: state.index)] = state.expanded
                    }
                    self.currentExpandedDetails = storedExpandedDetails
                }
            }
            self.currentLayout = nil
            
            
            if case let .Loaded(content) = webPage.content, let instantPage = content.instantPage, instantPage.isComplete {
                self.loadProgress.set(1.0)
                
                if let anchor = self.pendingAnchor {
                    self.pendingAnchor = nil
                    self.scrollToAnchor(anchor)
                }
            }
            
            reloadData()
        }
    }

    
    private func updateLayout() {
        let currentLayout = instantPageLayoutForWebPage(webPage, boundingWidth: max(500, frame.width), safeInset: 0, theme: instantPageThemeForType(theme.insantPageThemeType, settings: appearance), webEmbedHeights: self.currentWebEmbedHeights)
        
        updateInteractions()
        
        for (_, tileView) in self.visibleTiles {
            tileView.removeFromSuperview()
        }
        self.visibleTiles.removeAll()
        
        for (_, linkView) in self.visibleLinkSelectionViews {
            linkView.removeFromSuperview()
        }
        self.visibleLinkSelectionViews.removeAll()
        
        let currentLayoutTiles = instantPageTilesFromLayout(currentLayout, boundingWidth: frame.width)
        

        var currentDetailsItems: [InstantPageDetailsItem] = []
        var currentLayoutItemsWithViews: [InstantPageItem] = []
        var currentLayoutItemsWithLinks: [InstantPageItem] = []
        var distanceThresholdGroupCount: [Int: Int] = [:]
        
        var expandedDetails: [Int : Bool] = [:]
        var detailsIndex = -1

        
        for item in currentLayout.items {
            if item.wantsView {
                currentLayoutItemsWithViews.append(item)
                if let group = item.distanceThresholdGroup() {
                    let count: Int
                    if let currentCount = distanceThresholdGroupCount[Int(group)] {
                        count = currentCount
                    } else {
                        count = 0
                    }
                    distanceThresholdGroupCount[Int(group)] = count + 1
                }
                if item.hasLinks {
                    currentLayoutItemsWithLinks.append(item)
                }
                if let detailsItem = item as? InstantPageDetailsItem {
                    detailsIndex += 1
                    expandedDetails[detailsIndex] = detailsItem.initiallyExpanded
                    currentDetailsItems.append(detailsItem)
                }
            }
           
        }
        
        if var currentExpandedDetails = self.currentExpandedDetails {
            for (index, expanded) in expandedDetails {
                if currentExpandedDetails[index] == nil {
                    currentExpandedDetails[index] = expanded
                }
            }
            self.currentExpandedDetails = currentExpandedDetails
        } else {
            self.currentExpandedDetails = expandedDetails
        }
        
        self.currentLayout = currentLayout
        self.currentLayoutTiles = currentLayoutTiles
        self.currentDetailsItems = currentDetailsItems
        self.currentLayoutItemsWithViews = currentLayoutItemsWithViews
        self.currentLayoutItemsWithLinks = currentLayoutItemsWithLinks
        self.distanceThresholdGroupCount = distanceThresholdGroupCount
        
        self.documentView.setFrameSize(currentLayout.contentSize)
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        
        
        reloadData()
    }
    
    private func reloadData() {
        updateLayout()
        self.containerLayoutUpdated(animated: false)
        updateInteractions()
    }
    
    func isExpandedItem(_ item: InstantPageDetailsItem) -> Bool {
        if let index = self.currentDetailsItems.firstIndex(where: {$0 === item}) {
            return self.currentExpandedDetails?[index] ?? item.initiallyExpanded
        } else {
            return false
        }
    }
    
    override var supportSwipes: Bool {
        return false
    }
    
    override var window: Window? {
        if isLoaded() {
            return self.view.window as? Window
        } else {
            return nil
        }
    }
    
    func updateInteractions() {
        if let window = window, let layout = currentLayout, let instantPage = instantPage {
            selectManager?.initializeHandlers(for: window, instantLayout: layout, instantPage: instantPage, context: context, updateLayout: { [weak self] in
                guard let `self` = self else {return}
                
                self.updateVisibleItems(visibleBounds: self.genericView.contentView.bounds, animated: false)
            }, openUrl: { [weak self] url in
                self?.openUrl(url)
            }, itemsInRect: { [weak self] rect in
                guard let `self` = self, let currentLayout = self.currentLayout else { return [] }
                return currentLayout.items.filter{rect.intersects(self.effectiveFrameForItem($0))}
            }, effectiveRectForItem: { [weak self] item in
                guard let `self` = self else { return NSZeroRect }
                return self.effectiveFrameForItem(item)
            })
        }
    }
    
    private func updateWebEmbedHeight(_ index: Int, _ height: CGFloat) {
        
        
        let currentHeight = self.currentWebEmbedHeights[index]
        if height != currentHeight {
            if let currentHeight = currentHeight, currentHeight > height {
                return
            }
            self.currentWebEmbedHeights[index] = height
            
            let signal: Signal<Void, NoError> = (.complete() |> delay(0.08, queue: Queue.mainQueue()))
            self.updateLayoutDisposable.set(signal.start(completed: { [weak self] in
                if let strongSelf = self {
                    NSLog("\(strongSelf.currentWebEmbedHeights)")

                    strongSelf.reloadData()
                    strongSelf.updateVisibleItems(visibleBounds: strongSelf.genericView.contentView.bounds, animated: false)
                }
            }))
        }
    }
    
    private func openUrl(_ url: InstantPageUrlItem) {
        var baseUrl = url.url
        var anchor: String?
        if let anchorRange = url.url.range(of: "#") {
            anchor = String(baseUrl[anchorRange.upperBound...]).removingPercentEncoding
            baseUrl = String(baseUrl[..<anchorRange.lowerBound])
        }
        
        if  case let .Loaded(content) = webPage.content, let page = content.instantPage, page.url == baseUrl, let anchor = anchor {
            self.scrollToAnchor(anchor)
            return
        }
        

        self.loadWebpageDisposable.set(nil)
        loadProgress.set(0.07)
        
        let result = inApp(for: url.url.nsstring, context: context, openInfo: { [weak self] peerId, openChat, messageId, initialAction in
            guard let `self` = self else {return}
            if openChat {
                self.context.sharedContext.bindings.rootNavigation().push(ChatController(context: self.context, chatLocation: .peer(peerId), messageId: messageId, initialAction: initialAction))
            } else {
                self.context.sharedContext.bindings.rootNavigation().push(PeerInfoController(context: self.context, peerId: peerId))
            }
        }, applyProxy: { [weak self] proxy in
            guard let `self` = self else {return}
            applyExternalProxy(proxy, accountManager: self.context.sharedContext.accountManager)
        }, confirm: false)
        
        switch result {
        case let .external(externalUrl, _):
            if let webpageId = url.webpageId {
                var anchor: String?
                if let anchorRange = externalUrl.range(of: "#") {
                    anchor = String(externalUrl[anchorRange.upperBound...])
                }
                loadWebpageDisposable.set((webpagePreviewWithProgress(account: context.account, url: externalUrl, webpageId: webpageId) |> deliverOnMainQueue).start(next: { [weak self] result in
                    guard let `self` = self else {return}
                    
                    switch result {
                    case let .result(webpage):
                        if let webpage = webpage, case .Loaded = webpage.content {
                            self.loadProgress.set(1.0)
                            showInstantPage(InstantPageViewController(self.context, webPage: webpage, message: nil, anchor: anchor))
                        }
                        break
                    case let .progress(progress):
                        self.loadProgress.set(CGFloat(0.07 + progress * (1.0 - 0.07)))
                    }
                }))
            } else {
                loadProgress.set(1.0)
                execute(inapp: result)
            }
        default:
            self.loadProgress.set(1.0)
             execute(inapp: result)
        }
    }
    
    private func effectiveFrameForTile(_ tile: InstantPageTile) -> CGRect {
        let layoutOrigin = tile.frame.origin
        var origin = layoutOrigin
        for item in self.currentDetailsItems {
            let expanded = self.currentExpandedDetails?[item.index] ?? item.initiallyExpanded
            if layoutOrigin.y >= item.frame.maxY {
                let height = expanded ? self.effectiveSizeForDetails(item).height : item.titleHeight
                origin.y += height - item.frame.height
            }
        }
        return CGRect(origin: origin, size: tile.frame.size)
    }
    
    private func effectiveFrameForItem(_ item: InstantPageItem) -> CGRect {
        let layoutOrigin = item.frame.origin
        var origin = layoutOrigin
        
        for item in self.currentDetailsItems {
            let expanded = self.currentExpandedDetails?[item.index] ?? item.initiallyExpanded
            if layoutOrigin.y >= item.frame.maxY {
                let height = expanded ? self.effectiveSizeForDetails(item).height : item.titleHeight
                origin.y += height - item.frame.height
            }
        }
        
        if let item = item as? InstantPageDetailsItem {
            let expanded = self.currentExpandedDetails?[item.index] ?? item.initiallyExpanded
            let height = expanded ? self.effectiveSizeForDetails(item).height : item.titleHeight
            return CGRect(origin: origin, size: CGSize(width: item.frame.width, height: height))
        } else {
            return CGRect(origin: origin, size: item.frame.size)
        }
    }
    
    private func viewForDetailsItem(_ item: InstantPageDetailsItem) -> InstantPageDetailsView? {
        for (_, itemView) in self.visibleItemsWithViews {
            if let detailsView = itemView as? InstantPageDetailsView, detailsView.item === item {
                return detailsView
            }
        }
        return nil
    }
    
    private func effectiveSizeForDetails(_ item: InstantPageDetailsItem) -> CGSize {
        if let view = viewForDetailsItem(item) {
            return CGSize(width: item.frame.width, height: view.effectiveContentSize.height + item.titleHeight)
        } else {
            return item.frame.size
        }
    }
    
    private func findAnchorItem(_ anchor: String, items: [InstantPageItem]) -> (InstantPageItem, CGFloat, Bool, [InstantPageDetailsItem])? {
        for item in items {
            if let item = item as? InstantPageAnchorItem, item.anchor == anchor {
                return (item, -10.0, false, [])
            } else if let item = item as? InstantPageTextItem {
                if let (lineIndex, empty) = item.anchors[anchor] {
                    return (item, item.lines[lineIndex].frame.minY - 10.0, !empty, [])
                }
            }
            else if let item = item as? InstantPageTableItem {
                if let (offset, empty) = item.anchors[anchor] {
                    return (item, offset - 10.0, !empty, [])
                }
            }
            else if let item = item as? InstantPageDetailsItem {
                if let (foundItem, offset, reference, detailsItems) = self.findAnchorItem(anchor, items: item.items) {
                    var detailsItems = detailsItems
                    detailsItems.insert(item, at: 0)
                    return (foundItem, offset, reference, detailsItems)
                }
            }
        }
        return nil
    }
    
    
    private func scrollToAnchor(_ anchor: String) {
        guard let items = self.currentLayout?.items else {
            return
        }

        if !anchor.isEmpty {
            if let (item, lineOffset, reference, detailsItems) = findAnchorItem(String(anchor), items: items) {
                var previousDetailsView: InstantPageDetailsView?
                var containerOffset: CGFloat = 0.0
                for detailsItem in detailsItems {
                    if let previousView = previousDetailsView {
                        previousView.contentView.updateDetailsExpanded(detailsItem.index, true, animated: false)
                        let frame = previousView.effectiveFrameForItem(detailsItem)
                        containerOffset += frame.minY
                        
                        previousDetailsView = previousView.contentView.viewForDetailsItem(detailsItem)
                        previousDetailsView?.setExpanded(true, animated: false)
                    } else {
                        self.updateDetailsExpanded(detailsItem.index, true, animated: false)
                        let frame = self.effectiveFrameForItem(detailsItem)
                        containerOffset += frame.minY
                        
                        previousDetailsView = self.viewForDetailsItem(detailsItem)
                        previousDetailsView?.setExpanded(true, animated: false)
                    }
                }
                
                let frame: CGRect
                if let previousDetailsView = previousDetailsView {
                    frame = previousDetailsView.effectiveFrameForItem(item)
                } else {
                    frame = self.effectiveFrameForItem(item)
                }
                
                let targetY = min(containerOffset + frame.minY + (reference ? -5 : lineOffset), self.documentView.frame.height - self.genericView.frame.height)
                genericView.clipView.scroll(to: CGPoint(x: 0.0, y: targetY), animated: true)
            } else if case let .Loaded(content) = webPage.content, let instantPage = content.instantPage, !instantPage.isComplete {
               // self.loadProgress.set(0.5)
                self.pendingAnchor = anchor
            }
        } else {
             genericView.clipView.scroll(to: NSZeroPoint, animated: true)
        }
        

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateInteractions()
    }
    
    private func closeModal() {
        closeAllModals()
    }

    func openInfo(_ peerId:PeerId, _ openChat: Bool, _ postId:MessageId?, _ action:ChatInitialAction?) {
        if openChat {
            context.sharedContext.bindings.rootNavigation().push(ChatController(context: context, chatLocation: .peer(peerId), messageId: postId, initialAction: action))
            closeModal()
        } else {
            context.sharedContext.bindings.rootNavigation().push(PeerInfoController(context: context, peerId: peerId))
            closeModal()
        }
        
    }
    
//    func openNewTab(_) {
//        let getMedia = account.postbox.transaction { transaction -> Media? in
//            return transaction.getMedia(mediaId)
//        } |> deliverOnMainQueue
//        mediaDisposable.set(getMedia.start(next: { [weak self] media in
//            if let media = media as? TelegramMediaWebpage, let strongSelf = self, case let .Loaded(content) = media.content, let page = content.instantPage {
//                strongSelf.navigationController?.push(InstantPageViewController(strongSelf.account, webPage: media, message: nil))
//            } else if let window = self?.window, let account = self?.account {
//                self.loadProgress.set(0.02)
//                _ = (webpagePreviewWithProgress(account: account, url: url, webpageId: mediaId) |> deliverOnMainQueue).start(next: { result in
//
//                    if let page = page {
//                        switch page.content {
//                        case let .Loaded(content):
//                            if let _ = content.instantPage {
//                                showInstantPage(InstantPageViewController(account, webPage: page, message: nil))
//                            } else {
//                                execute(inapp: .external(link: url, false))
//                            }
//                        default:
//                            execute(inapp: .external(link: url, false))
//                        }
//                    } else {
//                        execute(inapp: .external(link: url, false))
//                    }
//                })
//            } else {
//                execute(inapp: .external(link: url, false))
//            }
//        }))
//    }
//

    
    
    override func viewDidLoad() {
        
        
        
        genericView.deltaCorner = -1
        genericView.documentView = View(frame: genericView.bounds)
        NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: genericView.contentView, queue: nil, using: { [weak self] _ in
            guard let `self` = self else { return }
            self.updateVisibleItems(visibleBounds: self.genericView.contentView.bounds, animated: false)
			self.pageDidScrolled?((documentSize: self.genericView.frame.size, position: self.genericView.scrollPosition().current))
            self.saveArticleProgress()
        })
        genericView.hasVerticalScroller = true
        selectManager = InstantPageSelectText(genericView)
        super.viewDidLoad()
        
        var firstLoad: Bool = true
        
        appearanceDisposable.set((ivAppearance(postbox: context.account.postbox) |> deliverOnMainQueue).start(next: { [weak self] appearance in
            self?.appearance = appearance
            self?.reloadData()
            self?.readyOnce()
            if firstLoad, let currentLayout = self?.currentLayout, let webPage = self?.webPage, let scrollView = self?.genericView {
                firstLoad = false
                if let message = self?.message {
                    switch webPage.content {
                    case .Loaded(let content):
                        
                        let attr = NSMutableAttributedString()
                        _ = attr.append(string: message)
                        attr.detectLinks(type: [.Links])
                        
                        let range = message.nsstring.range(of: content.url)
                        if range.location != NSNotFound {
                            if let link = attr.attribute(NSAttributedString.Key.link, at: range.location, effectiveRange: nil) as? inAppLink {
                                switch link {
                                case let .external(url, _):
                                    let anchorRange = url.nsstring.range(of: "#")
                                    if anchorRange.location != NSNotFound {
                                        let anchor = url.nsstring.substring(from: anchorRange.location + anchorRange.length)
                                        if !anchor.isEmpty {
                                            for item in currentLayout.items {
                                                if item.matchesAnchor(anchor) {
                                                    scrollView.clipView.scroll(to: item.frame.origin, animated: false)
                                                    scrollView.reflectScrolledClipView(scrollView.clipView)
                                                }
                                            }
                                        }
                                    }
                                default:
                                    break
                                }
                            }
                        }
                        
                    default:
                        break
                    }
                }
                if let mediaId = webPage.id, let state = appearance.state[mediaId] {
                    self?.applyScrollState(state)
                }
            }
        }))
        
      
        actualizeDisposable.set((actualizedWebpage(postbox: context.account.postbox, network: context.account.network, webpage: webPage) |> delay(1.0, queue: Queue.mainQueue()) |> deliverOnMainQueue).start(next: { [weak self] webpage in
            self?.updateWebPage(webpage, anchor: self?.pendingAnchor)
        }))

    }
	
    override func readyOnce() {
        if !didSetReady {
            loadProgress.set(1.0)
        }
        super.readyOnce()
    }
    
    func containerLayoutUpdated(animated: Bool) {
        if visibleItemsWithViews.isEmpty && visibleTiles.isEmpty {
            genericView.contentView.bounds = NSZeroRect
        }
        self.updateVisibleItems(visibleBounds: self.genericView.contentView.bounds, animated: animated)
    }
    
    override var enableBack: Bool {
        if let navigation = navigationController {
            return self != navigation.empty
        }
        return false
    }
    
    private var documentView: NSView {
        return genericView.documentView!
    }
    
    
    private func updateDetailsExpanded(_ index: Int, _ expanded: Bool, animated: Bool = true) {
        if var currentExpandedDetails = self.currentExpandedDetails {
            currentExpandedDetails[index] = expanded
            self.currentExpandedDetails = currentExpandedDetails
        }
        self.updateVisibleItems(visibleBounds: self.genericView.contentView.bounds, animated: animated)
    }
    
    func updateVisibleItems(visibleBounds: CGRect, animated: Bool = false) {

        
        CATransaction.begin()
        
        defer {
            CATransaction.commit()
        }
                
        var visibleTileIndices = Set<Int>()
        var visibleItemIndices = Set<Int>()
        
        
        var topView: NSView?
        let topTileView = topView
        for view in documentView.subviews.reversed() {
            if let view = view as? InstantPageTileView {
                topView = view
                break
            }
        }
        
        let visibleBounds = genericView.contentView.bounds
        

        
        var collapseOffset: CGFloat = 0.0

        
        var itemIndex = -1
        var embedIndex = -1
        var detailsIndex = -1
        
        var previousDetailsView: InstantPageDetailsView?

        
        for item in self.currentLayoutItemsWithViews {
            itemIndex += 1
            
            if item is InstantPageWebEmbedItem {
                embedIndex += 1
            }
            if item is InstantPageDetailsItem {
                detailsIndex += 1
            }
            
            var itemThreshold: CGFloat = 0.0
            if let group = item.distanceThresholdGroup() {
                var count: Int = 0
                if let currentCount = self.distanceThresholdGroupCount[group] {
                    count = currentCount
                }
                itemThreshold = item.distanceThresholdWithGroupCount(count)
            }

            
            var itemFrame = item.frame.offsetBy(dx: 0.0, dy: -collapseOffset)
            var thresholdedItemFrame = itemFrame
            thresholdedItemFrame.origin.y -= itemThreshold
            thresholdedItemFrame.size.height += itemThreshold * 2.0
            
            if let detailsItem = item as? InstantPageDetailsItem, let expanded = self.currentExpandedDetails?[detailsIndex] {
                let height = expanded ? self.effectiveSizeForDetails(detailsItem).height : detailsItem.titleHeight
                collapseOffset += itemFrame.height - height
                itemFrame = CGRect(origin: itemFrame.origin, size: CGSize(width: itemFrame.width, height: height))
            }
            
            if visibleBounds.intersects(thresholdedItemFrame) {
                visibleItemIndices.insert(itemIndex)
                
                var itemView = self.visibleItemsWithViews[itemIndex]
                if let currentItemView = itemView {
                    if !item.matchesView(currentItemView) {
                        (currentItemView as! NSView).removeFromSuperview()
                        self.visibleItemsWithViews.removeValue(forKey: itemIndex)
                        itemView = nil
                    }
                }
                
                if itemView == nil {
                    let embedIndex = embedIndex
                    let detailsIndex = detailsIndex

                    let arguments = InstantPageItemArguments(context: context, theme: instantPageThemeForType(theme.insantPageThemeType, settings: appearance), openMedia: { media in
                        
                    }, openPeer: { peerId in
                        
                    }, openUrl: { [weak self] url in
                        self?.openUrl(url)
                    }, updateWebEmbedHeight: { [weak self] height in
                        self?.updateWebEmbedHeight(embedIndex, height)
                    }, updateDetailsExpanded: { [weak self] expanded in
                        self?.updateDetailsExpanded(detailsIndex, expanded)
                    }, isExpandedItem: { [weak self] item in
                        return self?.isExpandedItem(item) ?? false
                    }, effectiveRectForItem: { [weak self] item in
                        return self?.effectiveFrameForItem(item) ?? item.frame
                    })
                    
                    if let newView = item.view(arguments: arguments, currentExpandedDetails: self.currentExpandedDetails) {
                        newView.frame = itemFrame
                        documentView.addSubview(newView)
                        topView = newView
                        self.visibleItemsWithViews[itemIndex] = newView
                        itemView = newView
                        
                        if let itemView = itemView as? InstantPageDetailsView {
                            itemView.requestLayoutUpdate = { [weak self] animated in
                                if let strongSelf = self {
                                    strongSelf.updateVisibleItems(visibleBounds: strongSelf.genericView.contentView.bounds, animated: animated)
                                }
                            }
                            
                            if let previousDetailsView = previousDetailsView {
                                if itemView.frame.minY - previousDetailsView.frame.maxY < 1.0 {
                                    itemView.previousView = previousDetailsView
                                }
                            }
                            previousDetailsView = itemView
                        }

                    }
                } else {
                    if (itemView as! NSView).frame != itemFrame {
                        (itemView as! NSView)._change(size: itemFrame.size, animated: animated)
                        (itemView as! NSView)._change(pos: itemFrame.origin, animated: animated)
                    } else {
                        (itemView as! NSView).needsDisplay = true
                    }
                }
                
                if let itemView = itemView as? InstantPageDetailsView {
                    itemView.updateVisibleItems(visibleBounds: visibleBounds.offsetBy(dx: -itemView.frame.minX, dy: -itemView.frame.minY), animated: animated)
                }
            }
        }
        
        topView = topTileView
        
        var tileIndex = -1
        for tile in self.currentLayoutTiles {
            tileIndex += 1
            
            let tileFrame = effectiveFrameForTile(tile)
            var tileVisibleFrame = tileFrame
            tileVisibleFrame.origin.y -= 800.0
            tileVisibleFrame.size.height += 800.0 * 2.0
            if tileVisibleFrame.intersects(visibleBounds) {
                visibleTileIndices.insert(tileIndex)
                
                if self.visibleTiles[tileIndex] == nil {
                    let tileView = InstantPageTileView(tile: tile, backgroundColor: .clear)
                    tileView.frame = tileFrame
                    documentView.addSubview(tileView)
                    topView = tileView
                    self.visibleTiles[tileIndex] = tileView
                } else {
                    if visibleTiles[tileIndex]!.frame != tileFrame {
                        let view = self.visibleTiles[tileIndex]!
                        view._change(pos: tileFrame.origin, animated: animated)
                        view._change(size: tileFrame.size, animated: animated)
                    } else {
                        visibleTiles[tileIndex]!.needsDisplay = true
                    }
                }
            } else {
                var bp:Int = 0
                bp += 1
            }
        }
        
        if let currentLayout = self.currentLayout {
            let effectiveContentHeight = currentLayout.contentSize.height - collapseOffset
            if effectiveContentHeight != self.genericView.contentSize.height {
                documentView.setFrameSize(CGSize(width: currentLayout.contentSize.width, height: effectiveContentHeight))
            }
        }

        var removeTileIndices: [Int] = []
        for (index, tileView) in self.visibleTiles {
            if !visibleTileIndices.contains(index) {
                removeTileIndices.append(index)
                tileView.removeFromSuperview()
            }
        }
        for index in removeTileIndices {
            self.visibleTiles.removeValue(forKey: index)
        }
        
        var removeItemIndices: [Int] = []
        for (index, itemView) in self.visibleItemsWithViews {
            if !visibleItemIndices.contains(index) {
                removeItemIndices.append(index)
                (itemView as! NSView).removeFromSuperview()
            } else {
                var itemFrame = (itemView as! NSView).frame
                let itemThreshold: CGFloat = 200.0
                itemFrame.origin.y -= itemThreshold
                itemFrame.size.height += itemThreshold * 2.0
                itemView.updateIsVisible(visibleBounds.intersects(itemFrame))
            }
        }
        let subviews = documentView.subviews.sorted(by: {$0.frame.minY < $1.frame.minY})
        documentView.subviews = subviews
        documentView.needsLayout = true
        
        for index in removeItemIndices {
            self.visibleItemsWithViews.removeValue(forKey: index)
        }
        
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let window = window {
            selectManager?.removeHandlers(for: window)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        pageDidScrolled?((documentSize: genericView.frame.size, position: genericView.scrollPosition().current))
    }
    
    var scrollState: IVReadState? {
        if let currentLayout = currentLayout {
            var blockIndex:Int32? = nil
            var offset:Int32 = 0
            let point = CGPoint(x: genericView.frame.size.width / 2.0, y: genericView.contentOffset.y + genericView.contentInsets.top)
            
            let found = currentLayout.items(in: NSMakeRect(point.x, point.y, 1, 30)).last
            if let found = found {
                for i in 0 ..< currentLayout.items.count {
                    if found.frame == currentLayout.items[i].frame {
                        blockIndex = Int32(i)
                        offset = Int32(point.y - found.frame.minY)
                        break
                    }
                }
            }
            
            
            if let blockIndex = blockIndex {
                return IVReadState(blockId: blockIndex, blockOffset: offset)
            }
        }
        return nil
    }
    
    private func applyScrollState(_ state: IVReadState) {
        if let currentLayout = currentLayout, Int32(currentLayout.items.count) > state.blockId, let scrollState = scrollState {
            let item = currentLayout.items[Int(state.blockId)]
            let offset = CGPoint(x: 0, y: genericView.contentInsets.top + item.frame.origin.y + CGFloat(scrollState.blockOffset))
            genericView.clipView.scroll(to: offset, animated: false)
            genericView.reflectScrolledClipView(genericView.clipView)

        }
    }

	// Called when space button is enabled to trigger scrolling
	enum Direction {
		case up
		case down
	}
	func scrollPage(direction: Direction) {
        self.updateVisibleItems(visibleBounds: self.genericView.contentView.bounds, animated: false)
		
		var newOrigin = genericView.clipView.bounds.origin
		switch direction {
		case .up:
            // without *2 we will stay at current position
            newOrigin.y -= 50
			if newOrigin.y < 0 {
				newOrigin.y = 0
			}
		case .down:
			newOrigin.y += 50
			let maxY = genericView.documentSize.height - genericView.clipView.frame.height
			if newOrigin.y > maxY {
				newOrigin.y = maxY
			}
		}
		
		genericView.clipView.scroll(to: newOrigin, animated: true)
		genericView.reflectScrolledClipView(genericView.clipView)
		pageDidScrolled?((documentSize: genericView.frame.size, position: genericView.scrollPosition().current))
	}
	
    private func saveArticleProgress() {
        let point = CGPoint(x: genericView.frame.size.width / 2.0, y: genericView.contentOffset.y + genericView.contentInsets.top)
        
        let id = self.webPage.webpageId
        
        let percent = Int32((point.y + frame.height) / genericView.documentSize.height * 100.0)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        selectManager?.removeHandlers(for: mainWindow)
        joinDisposable.dispose()
        actualizeDisposable.dispose()
        saveProgressDisposable.dispose()
        mediaDisposable.dispose()
        updateLayoutDisposable.dispose()
        loadWebpageDisposable.dispose()
        appearanceDisposable.dispose()
        if let window = window {
            selectManager?.removeHandlers(for: window)
        }
        if let state = scrollState, let mediaId = webPage.id {
          //  _ = updateInstantViewAppearanceSettingsInteractively(postbox: account.postbox, {$0.withUpdatedIVState(state, for: mediaId)}).start()
        }
        
    }
    
}
