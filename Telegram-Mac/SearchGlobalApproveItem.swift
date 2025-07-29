//
//  SearchGlobalApproveItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 28.07.2025.
//  Copyright © 2025 Telegram. All rights reserved.
//

import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit

final class SearchGlobalApproveItem : GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let postState: TelegramGlobalPostSearchState?
    fileprivate let isPremium: Bool
    

    fileprivate let titleLayout: TextViewLayout
    fileprivate let infoLayout: TextViewLayout
    fileprivate let descLayout: TextViewLayout?
    
    
    fileprivate private(set) var approveState: SearchGlobalApproveView.ApproveView.State
    
    fileprivate let approve:(String, StarsAmount?)->Void
    
    private var remainingTimer: SwiftSignalKit.Timer?
    
    private let disposable = MetaDisposable()
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, query: String, postState: TelegramGlobalPostSearchState?, isPremium: Bool, approve:@escaping(String, StarsAmount?)->Void) {
        self.context = context
        self.postState = postState
        self.isPremium = isPremium
        self.approve = approve
        
        if let state = postState {
            
            var remainingTime: Int32? = nil
            if let unlockTimestamp = state.unlockTimestamp {
                remainingTime = unlockTimestamp - context.timestamp
            }
            approveState = .limited(count: state.remainingFreeSearches, maxCount: state.totalFreeSearches, query: query, price: state.price, remainingTimestamp: remainingTime)
        } else {
            approveState = .requiredPremium
        }
        
        //TODOLANG
        
        let descText: String?
        let title: String
        let info: String
        switch approveState {
        case .requiredPremium:
            descText = "Global search is a Premium feature."
            title = "Global Search"
            info = "Type a keyword to search all posts from public channels."
        case .limited(let count, let maxCount, let query, _, _):
            if count > 0 {
                title = "Global Search"
                info = "Type a keyword to search all posts from public channels."
                descText = "\(count) free searches remaining today";
            } else {
                title = "Limit Reached"
                info = "You can make up to \(maxCount) search queries per day."
                descText = nil
            }
        }
        if let descText {
            self.descLayout = .init(.initialize(string: descText, color: theme.colors.grayText, font: .normal(.text)))
        } else {
            self.descLayout = nil
        }
        
        self.titleLayout = .init(.initialize(string: title, color: theme.colors.text, font: .medium(.header)), maximumNumberOfLines: 1, alignment: .center)
        
        self.infoLayout = .init(.initialize(string: info, color: theme.colors.grayText, font: .normal(.text)), alignment: .center)

        
        super.init(initialSize, stableId: stableId)
        
        
        switch approveState {
        case let .limited(count, maxCount, query, price, remainingTimestamp):
            if var remainingTimestamp {
                self.remainingTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
                    guard let self else {
                        return
                    }
                    remainingTimestamp -= 1
                    self.approveState = .limited(count: count, maxCount: maxCount, query: query, price: price, remainingTimestamp: remainingTimestamp)
                    self.redraw(animated: true)
                    
                    if remainingTimestamp <= 0 {
                        self.refresh()
                    }
                    
                }, queue: .mainQueue())
                
                self.remainingTimer?.start()

            }
        default:
            break
        }
    }
    
    private func refresh() {
        disposable.set(context.engine.messages.refreshGlobalPostSearchState().startStrict())
    }
    
    deinit {
        self.remainingTimer?.invalidate()
        disposable.dispose()
    }
    
    func invoke() {
        let context = self.context
        
        switch approveState {
        case .requiredPremium:
            //TODOLANG
            prem(with: PremiumBoardingController(context: context, source: .settings, openFeatures: false), for: context.window)
        case let .limited(count, _, query, price, _):
            if count <= 0 {
                let balance = context.starsContext.state |> take(1) |> deliverOnMainQueue
                _ = balance.startStandalone(next: { [weak self] state in
                    if let state, state.balance.value > price.value {
                        self?.approve(query, price)
                    } else {
                        //todolang
                        showModal(with: Star_ListScreen(context: context, source: .buy(suffix: "global_search", amount: price.value)), for: context.window)
                    }
                })
            } else {
                approve(query, nil)
            }
        }
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        infoLayout.measure(width: width - 40)
        titleLayout.measure(width: width - 40)
        descLayout?.measure(width: width - 40)
        
        return true
    }
    
    override var height: CGFloat {
        if let table = table {
            var basic:CGFloat = 0
            table.enumerateItems(with: { [weak self] item in
                if let strongSelf = self {
                    if item.index < strongSelf.index {
                        basic += item.height
                    }
                }
                return true
            })
            return table.frame.height - basic
        } else {
            return initialSize.height
        }
    }
    
    override func viewClass() -> AnyClass {
        return SearchGlobalApproveView.self
    }
}


private final class SearchGlobalApproveView : GeneralRowView {
    
    fileprivate final class ApproveView : Control {
        private let titleView = InteractiveTextView()
        private var searchView: ImageView?
        private var chevronView: ImageView?
        private var timeoutView: TextView?
        enum State {
            case requiredPremium
            case limited(count: Int32, maxCount: Int32, query: String, price: StarsAmount, remainingTimestamp: Int32?)
        }
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(titleView)
            titleView.userInteractionEnabled = false
            self.layer?.cornerRadius = 10
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(state: State, animated: Bool, context: AccountContext) {
            
            self.backgroundColor = theme.colors.accent
            
            let title = NSMutableAttributedString()
            //TODOLANG
            switch state {
            case .requiredPremium:
                if let searchView {
                    performSubviewRemoval(searchView, animated: animated)
                    self.searchView = nil
                }
                if let chevronView {
                    performSubviewRemoval(chevronView, animated: animated)
                    self.chevronView = nil
                }
                if let timeoutView {
                    performSubviewRemoval(timeoutView, animated: animated)
                    self.timeoutView = nil
                }
                
                title.append(string: "Premium Required", color: theme.colors.underSelectedColor, font: .medium(.header))
            case let .limited(count, _, query, price, remainingTimestamp):
                
                if count <= 0, let remainingTimestamp {
                    
                    if let searchView {
                        performSubviewRemoval(searchView, animated: animated)
                        self.searchView = nil
                    }
                    if let chevronView {
                        performSubviewRemoval(chevronView, animated: animated)
                        self.chevronView = nil
                    }
                    
                    title.append(string: "Search for \(clown) \(price.value)", color: theme.colors.underSelectedColor, font: .medium(.header))
                    title.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_mono.file, color: theme.colors.underSelectedColor), for: clown)
                    
                    let current: TextView
                    if let view = self.timeoutView {
                        current = view
                    } else {
                        current = TextView()
                        current.isEventLess = true
                        self.timeoutView = current
                        self.addSubview(current)
                    }
                    let layout = TextViewLayout(.initialize(string: "free search unlocks in \(timerText(Int(max(remainingTimestamp, 0))))", color: theme.colors.underSelectedColor.withAlphaComponent(0.6), font: .normal(.text)))
                    layout.measure(width: .greatestFiniteMagnitude)
                    
                    current.update(layout)
                    
                } else {
                    
                    if let timeoutView {
                        performSubviewRemoval(timeoutView, animated: animated)
                        self.timeoutView = nil
                    }
                    
                    title.append(string: "Search", color: theme.colors.underSelectedColor, font: .medium(.header))
                    
                    title.append(string: " ")
                    title.append(string: query, color: theme.colors.underSelectedColor.withAlphaComponent(0.6), font: .normal(.header))
                    
                    do {
                        let current: ImageView
                        if let view = self.searchView {
                            current = view
                        } else {
                            current = ImageView()
                            current.isEventLess = true
                            self.searchView = current
                            self.addSubview(current)
                        }
                        current.image = NSImage(resource: .iconGlobalSearch).precomposed(theme.colors.underSelectedColor)
                        current.sizeToFit()
                    }
                    
                    do {
                        let current: ImageView
                        if let view = self.chevronView {
                            current = view
                        } else {
                            current = ImageView()
                            current.isEventLess = true
                            self.chevronView = current
                            self.addSubview(current)
                        }
                        current.image = NSImage(resource: .iconGlobalSearchChevron).precomposed(theme.colors.underSelectedColor)
                        current.sizeToFit()
                    }
                }
                
              
            }
            
            
            let titleLayout = TextViewLayout(title, maximumNumberOfLines: 1)
            self.titleView.set(text: titleLayout, context: context)
            needsLayout = true
        }
        
        override func layout() {
            super.layout()
            self.searchView?.centerY(x: 0)
            
            var maxWidth: CGFloat = frame.width - 20
            if let searchView {
                maxWidth -= (searchView.frame.width + 5)
            }
            if let chevronView {
                maxWidth -= (chevronView.frame.width + 5)
            }
            
            self.titleView.resize(maxWidth)
            
            var width: CGFloat = titleView.frame.width
            if let searchView {
                width += searchView.frame.width + 5
                if let chevronView {
                    width += chevronView.frame.width + 5
                }
            }
            
            let center = focus(NSMakeSize(width, frame.height))
            
            if let searchView {
                searchView.centerY(x: center.minX)
                titleView.centerY(x: searchView.frame.maxX + 5)
                if let chevronView {
                    chevronView.centerY(x: titleView.frame.maxX + 5)
                }
            } else {
                if let timeoutView {
                    self.titleView.centerX(y: 6)
                    timeoutView.centerX(y: frame.height - timeoutView.frame.height - 6)
                } else {
                    self.titleView.center()
                }
            }
        }
    }
    
    private let container = View()
    private let titleView = TextView()
    private let infoView = TextView()
    private let descView = TextView()
    
    private let approveView = ApproveView(frame: NSMakeRect(0, 0, 100, 46))
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(container)
        container.addSubview(titleView)
        container.addSubview(infoView)
        container.addSubview(approveView)
        container.addSubview(descView)
        approveView.scaleOnClick = true
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        infoView.userInteractionEnabled = false
        infoView.isSelectable = false
        
        descView.userInteractionEnabled = false
        descView.isSelectable = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func layout() {
        super.layout()
        container.center()
        
        titleView.centerX(y: 0)
        infoView.centerX(y: titleView.frame.maxY + 10)
        approveView.frame = NSMakeRect(20, infoView.frame.maxY + 20, frame.width - 40, 46)
        descView.centerX(y: approveView.frame.maxY + 10)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? SearchGlobalApproveItem else {
            return
        }
        
        
        titleView.update(item.titleLayout)
        infoView.update(item.infoLayout)
        descView.update(item.descLayout)
        approveView.update(state: item.approveState, animated: animated, context: item.context)
        
        approveView.setSingle(handler: { [weak item] _ in
            item?.invoke()
        }, for: .Click)
        
        container.setFrameSize(NSMakeSize(frame.width, titleView.frame.height + 10 + infoView.frame.height + 20 + approveView.frame.height + 10 + descView.frame.height))
        
        needsLayout = true
    }
}
