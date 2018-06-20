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
    private let openPeerInfoDisposable = MetaDisposable()
    private let mediaDisposable = MetaDisposable()
    
    private var appearance: InstantViewAppearance = InstantViewAppearance.defaultSettings
    private let actualizeDisposable = MetaDisposable()
    
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
    init(_ account: Account, webPage: TelegramMediaWebpage, message: String?) {
        self.webPage = webPage
        self.message = message
        switch webPage.content {
        case .Loaded(let content):
            self.instantPage = content.instantPage
        default:
            break
        }
        super.init(account)
        bar = .init(height: 0)
        noticeResizeWhenLoaded = false
    }
    
    override var defaultBarTitle: String {
        switch webPage.content {
        case .Loaded(let content):
            return content.title ?? super.defaultBarTitle
        default:
            return super.defaultBarTitle
        }
    }
    
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        reloadData()
    }
    
    private func updateLayout() {
        
        let currentLayout = instantPageLayoutForWebPage(webPage, boundingWidth: frame.width, presentation: appearance, openChannel: { [weak self] channel in
            if let account = self?.account {
                self?.account.context.mainNavigation?.push(ChatController(account: account, chatLocation: .peer(channel.id)))
               self?.closeModal()
            }
        }, joinChannel: { [weak self] channel in
            if let strongSelf = self, let window = self?.window {
                strongSelf.joinDisposable.set(showModalProgress(signal: joinChannel(account: strongSelf.account, peerId: channel.id), for: window).start(next: { [weak strongSelf] in
                    strongSelf?.updateLayout()
                    strongSelf?.containerLayoutUpdated(transition: .immediate)
                }))
            }
        })
        
        for (_, tileNode) in self.visibleTiles {
            tileNode.removeFromSuperview()
        }
        self.visibleTiles.removeAll()
        
        for (_, linkView) in self.visibleLinkSelectionViews {
            linkView.removeFromSuperview()
        }
        self.visibleLinkSelectionViews.removeAll()
        
        let currentLayoutTiles = instantPageTilesFromLayout(currentLayout, boundingWidth: frame.width)
        
        var currentLayoutItemsWithViews: [InstantPageItem] = []
        var currentLayoutItemsWithLinks: [InstantPageItem] = []
        var distanceThresholdGroupCount: [Int: Int] = [:]
        
        for item in currentLayout.items {
            if item.wantsNode {
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
            }
            if item.hasLinks {
                currentLayoutItemsWithLinks.append(item)
            }
        }
        
        self.currentLayout = currentLayout
        self.currentLayoutTiles = currentLayoutTiles
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
        self.containerLayoutUpdated(transition: .immediate)
        updateInteractions()
    }
    
    func updateInteractions() {
        if let window = window, let layout = currentLayout, let instantPage = instantPage {
            selectManager?.initializeHandlers(for: window, instantLayout: layout, instantPage: instantPage, account: account, updateLayout: { [weak self] in
                self?.updateVisibleItems()
                }, openInfo: { [weak self] peerId, openChat, postId, action in
                    self?.openInfo(peerId, openChat, postId, action)
                    self?.modal?.close()
                }, openNewTab: { [weak self] mediaId, url in
                    self?.openNewTab(mediaId, url)
            })
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
            account.context.mainNavigation?.push(ChatController(account: account, chatLocation: .peer(peerId), messageId: postId, initialAction: action))
            closeModal()
        } else {
            openPeerInfoDisposable.set((account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue).start(next: { [weak self] peer in
                if let strongSelf = self {
                    strongSelf.account.context.mainNavigation?.push(PeerInfoController(account: strongSelf.account, peer: peer))
                    strongSelf.closeModal()
                }
            }))
        }
        
    }
    
    func openNewTab(_ mediaId: MediaId, _ url: String) {
        let getMedia = account.postbox.transaction { transaction -> Media? in
            return transaction.getMedia(mediaId)
        } |> deliverOnMainQueue
        mediaDisposable.set(getMedia.start(next: { [weak self] media in
            if let media = media as? TelegramMediaWebpage, let strongSelf = self {
                strongSelf.navigationController?.push(InstantPageViewController(strongSelf.account, webPage: media, message: nil))
            } else if let window = self?.window, let account = self?.account {
                _ = showModalProgress(signal: webpagePreview(account: account, url: url) |> timeout(0.5, queue: Queue.mainQueue(), alternate: .single(nil)) |> deliverOnMainQueue, for: window).start(next: { page in
                    if let page = page {
                        switch page.content {
                        case let .Loaded(content):
                            if content.instantPage != nil {
                                showInstantPage(InstantPageViewController(account, webPage: page, message: nil))
                            } else {
                                execute(inapp: .external(link: url, false))
                            }
                        default:
                            execute(inapp: .external(link: url, false))
                        }
                    } else {
                        execute(inapp: .external(link: url, false))
                    }
                })
            } else {
                execute(inapp: .external(link: url, false))
            }
        }))
    }
    

    
    override func viewDidLoad() {
        view.background = theme.colors.background
        genericView.deltaCorner = -1
        genericView.documentView = View(frame: genericView.bounds)
        NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: genericView.contentView, queue: nil, using: { [weak self] _ in
			guard let strongSelf = self else { return }
			strongSelf.updateVisibleItems()
			strongSelf.pageDidScrolled?((documentSize: strongSelf.genericView.frame.size, position: strongSelf.genericView.scrollPosition().current))
        })
        genericView.hasVerticalScroller = true
        selectManager = InstantPageSelectText(genericView)
        super.viewDidLoad()
        
        var firstLoad: Bool = true
        
        ready.set((ivAppearance(postbox: account.postbox) |> deliverOnMainQueue |> map { [weak self] appearance -> Bool in
            self?.appearance = appearance
            self?.reloadData()
            
            if firstLoad, let currentLayout = self?.currentLayout, let webPage = self?.webPage, let message = self?.message, let scrollView = self?.genericView {
                firstLoad = false
                
                if let mediaId = webPage.id, let state = appearance.state[mediaId] {
                    self?.applyScrollState(state)
                } else  {
                    switch webPage.content {
                    case .Loaded(let content):
                        
                        let attr = NSMutableAttributedString()
                        _ = attr.append(string: message)
                        attr.detectLinks(type: [.Links])
                        
                        let range = message.nsstring.range(of: content.url)
                        if range.location != NSNotFound {
                            if let link = attr.attribute(NSAttributedStringKey.link, at: range.location, effectiveRange: nil) as? inAppLink {
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
                                                    break
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
            }
            
            return true
        }))
//        actualizeDisposable.set((actualizedWebpage(postbox: account.postbox, network: account.network, webpage: webPage) |> delay(1.0, queue: Queue.mainQueue()) |> deliverOnMainQueue).start(next: { [weak self] webpage in
//            switch webpage.content {
//            case .Loaded(let content):
//                if content.instantPage != nil {
//                    self?.webPage = webpage
//                    self?.reloadData()
//                }
//            default:
//                break
//            }
//            
//        }))

    }
	
    
    func containerLayoutUpdated(transition: ContainedViewLayoutTransition) {
        if visibleItemsWithViews.isEmpty && visibleTiles.isEmpty {
            genericView.contentView.bounds = NSZeroRect
        }
        self.updateVisibleItems()
    }
    
    override var enableBack: Bool {
        if let navigation = navigationController {
            return self != navigation.empty
        }
        return false
    }
    
    private var documentView: View {
        return genericView.documentView as! View
    }
    
    func updateVisibleItems() {
        var visibleTileIndices = Set<Int>()
        var visibleItemIndices = Set<Int>()
        
        let visibleBounds = genericView.contentView.bounds
        
        var tileIndex = -1
        for tile in self.currentLayoutTiles {
            tileIndex += 1
            var tileVisibleFrame = tile.frame
            tileVisibleFrame.origin.y -= 800.0
            tileVisibleFrame.size.height += 800.0 * 2.0
            if tileVisibleFrame.intersects(visibleBounds) {
                visibleTileIndices.insert(tileIndex)
                
                if let tile = visibleTiles[tileIndex] {
                    tile.needsDisplay = true
                } else {
                    let tileNode = InstantPageTileView(tile: tile)
                    tileNode.frame = tile.frame
                    documentView.addSubview(tileNode)
                    self.visibleTiles[tileIndex] = tileNode
                }
               
            }
        }
        
        var itemIndex = -1
        for item in self.currentLayoutItemsWithViews {
            itemIndex += 1
            var itemThreshold: CGFloat = 0.0
            if let group = item.distanceThresholdGroup() {
                var count: Int = 0
                if let currentCount = self.distanceThresholdGroupCount[group] {
                    count = currentCount
                }
                itemThreshold = item.distanceThresholdWithGroupCount(count)
            }
            var itemFrame = item.frame
            itemFrame.origin.y -= itemThreshold
            itemFrame.size.height += itemThreshold * 2.0
            if visibleBounds.intersects(itemFrame) {
                visibleItemIndices.insert(itemIndex)
                
                var itemNode = self.visibleItemsWithViews[itemIndex]
                if let currentItemNode = itemNode {
                    if !item.matchesNode(currentItemNode) {
                        (currentItemNode as! View).removeFromSuperview()
                        self.visibleItemsWithViews.removeValue(forKey: itemIndex)
                        itemNode = nil
                    }
                }
                
                if itemNode == nil {
                    if let itemNode = item.node(account: self.account) {
                        (itemNode as! View).frame = item.frame
                        documentView.addSubview(itemNode as! View)
                        self.visibleItemsWithViews[itemIndex] = itemNode
                    }
                } else {
                    (itemNode as! View).removeFromSuperview()
                    documentView.addSubview((itemNode as! View))
                    if (itemNode as! View).frame != item.frame {
                        (itemNode as! View).frame = item.frame
                    }
                }
            }
        }
        
        var removeTileIndices: [Int] = []
        for (index, tileNode) in self.visibleTiles {
            if !visibleTileIndices.contains(index) {
                removeTileIndices.append(index)
                tileNode.removeFromSuperview()
            }
        }
        for index in removeTileIndices {
            self.visibleTiles.removeValue(forKey: index)
        }
        
        var removeItemIndices: [Int] = []
        for (index, itemNode) in self.visibleItemsWithViews {
            if !visibleItemIndices.contains(index) {
                removeItemIndices.append(index)
                (itemNode as! View).removeFromSuperview()
            } else {
                var itemFrame = (itemNode as! View).frame
                let itemThreshold: CGFloat = 200.0
                itemFrame.origin.y -= itemThreshold
                itemFrame.size.height += itemThreshold * 2.0
                itemNode.updateIsVisible(visibleBounds.intersects(itemFrame))
            }
        }
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
            let offset = CGPoint(x: 0, y: genericView.contentInsets.top + item.frame.origin.y + CGFloat(scrollState.blockOffset) - 8)
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
		updateVisibleItems()
		
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
	
    deinit {
        NotificationCenter.default.removeObserver(self)
        selectManager?.removeHandlers(for: mainWindow)
        joinDisposable.dispose()
        actualizeDisposable.dispose()
        openPeerInfoDisposable.dispose()
        mediaDisposable.dispose()
        if let window = window {
            selectManager?.removeHandlers(for: window)
        }
        if let state = scrollState, let mediaId = webPage.id {
            _ = updateInstantViewAppearanceSettingsInteractively(postbox: account.postbox, {$0.withUpdatedIVState(state, for: mediaId)}).start()
        }
    }
    
}
