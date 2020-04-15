//
//  EmojiViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 17/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import SyncCore



enum EmojiSegment : Int64, Comparable  {
    case Recent = 0
    case People = 1
    case AnimalsAndNature = 2
    case FoodAndDrink = 3
    case ActivityAndSport = 4
    case TravelAndPlaces = 5
    case Objects = 6
    case Symbols = 7
    case Flags = 8
    
    var localizedString: String {
        switch self {
        case .Recent: return L10n.emojiRecent
        case .People: return L10n.emojiSmilesAndPeople
        case .AnimalsAndNature: return L10n.emojiAnimalsAndNature
        case .FoodAndDrink: return L10n.emojiFoodAndDrink
        case .ActivityAndSport: return L10n.emojiActivityAndSport
        case .TravelAndPlaces: return L10n.emojiTravelAndPlaces
        case .Objects: return L10n.emojiObjects
        case .Symbols: return L10n.emojiSymbols
        case .Flags: return L10n.emojiFlags
        }
    }
    
    var hashValue:Int {
        return Int(self.rawValue)
    }
}

func ==(lhs:EmojiSegment, rhs:EmojiSegment) -> Bool {
    return lhs.rawValue == rhs.rawValue
}

func <(lhs:EmojiSegment, rhs:EmojiSegment) -> Bool {
    return lhs.rawValue < rhs.rawValue
}

let emojiesInstance:[EmojiSegment:[String]] = {
    assertNotOnMainThread()
    var local:[EmojiSegment:[String]] = [EmojiSegment:[String]]()
    
    let resource:URL?
    if #available(OSX 10.14.1, *) {
        resource = Bundle.main.url(forResource:"emoji1014-1", withExtension:"txt")
    } else  if #available(OSX 10.12, *) {
        resource = Bundle.main.url(forResource:"emoji", withExtension:"txt")
    } else {
        resource = Bundle.main.url(forResource:"emoji11", withExtension:"txt")
    }
    if let resource = resource {
        
        var file:String = ""
        
        do {
            file = try String(contentsOf: resource)
            
        } catch {
            print("emoji file not loaded")
        }
        
        let segments = file.components(separatedBy: "\n\n")
        
        for segment in segments {
            
            let list = segment.components(separatedBy: " ")
            
            if let value = EmojiSegment(rawValue: Int64(local.count + 1)) {
                local[value] = list
            }
            
        }
        
    }
    
    return local
    
}()

private func segments(_ emoji: [EmojiSegment : [String]], skinModifiers: [EmojiSkinModifier]) -> [EmojiSegment:[[NSAttributedString]]] {
    var segments:[EmojiSegment:[[NSAttributedString]]] = [:]
    for (key,list) in emoji {
        
        var line:[NSAttributedString] = []
        var lines:[[NSAttributedString]] = []
        var i = 0
        
        for emoji in list {
            
            var e:String = emoji.emojiUnmodified
            for modifier in skinModifiers {
                if e == modifier.emoji {
                    if e.length == 5 {
                        let mutable = NSMutableString()
                        mutable.insert(e, at: 0)
                        mutable.insert(modifier.modifier, at: 2)
                        e = mutable as String
                    } else {
                        e = e + modifier.modifier
                    }
                }

            }
            if !line.contains(where: {$0.string == String(e.first!) }), let first = e.first {
                line.append(.initialize(string: String(first), font: .normal(26.0)))
                i += 1
            }
            
            
            if i == 8 {
                
                lines.append(line)
                line.removeAll()
                i = 0
            }
        }
        if line.count > 0 {
            lines.append(line)
        }
        if lines.count > 0 {
            segments[key] = lines
        }
        
    }
    return segments
}


fileprivate var isReady:Bool = false


class EmojiControllerView : View {
    fileprivate let tableView:TableView = TableView(frame:NSZeroRect)
    private let tabsContainer = View()
    fileprivate let tabs:HorizontalTableView = HorizontalTableView(frame:NSZeroRect)
    private let borderView:View = View()
    private let emptyResults: ImageView = ImageView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        addSubview(emptyResults)
        tabsContainer.addSubview(tabs)
        tabsContainer.addSubview(borderView)
        addSubview(tabsContainer)
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        self.backgroundColor = theme.colors.background
        self.borderView.backgroundColor = theme.colors.border
        emptyResults.image = theme.icons.stickersEmptySearch
        emptyResults.sizeToFit()
    }
    
    
    func updateVisibility(_ isEmpty: Bool, isSearch: Bool) {
        emptyResults.isHidden = !isEmpty
        tableView.isHidden = isEmpty
        tabs.isHidden = isSearch
        borderView.isHidden = isSearch
    }
    
    
    override func layout() {
        super.layout()
        tabsContainer.frame = NSMakeRect(0, 0, frame.width, 50)
        tabs.center()
        borderView.frame = NSMakeRect(0, tabsContainer.frame.height - .borderSize, frame.width, .borderSize)
        tableView.frame = NSMakeRect(0, tabsContainer.frame.maxY, frame.width , frame.height - tabs.frame.maxY)
        emptyResults.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class EmojiViewController: TelegramGenericViewController<EmojiControllerView>, TableViewDelegate {
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    private let searchValue = ValuePromise<SearchState>()
    private var searchState: SearchState = .init(state: .None, request: nil) {
        didSet {
            self.searchValue.set(searchState)
        }
    }
    private let disposable:MetaDisposable = MetaDisposable()
    private let searchStateDisposable = MetaDisposable()

    private var interactions:EntertainmentInteractions?
    var makeSearchCommand:((ESearchCommand)->Void)?

    init(_ context: AccountContext, search: Signal<SearchState, NoError>) {
        super.init(context)
        
        _frameRect = NSMakeRect(0, 0, 350, 300)
        self.bar = .init(height: 0)
        
        self.searchStateDisposable.set(search.start(next: { [weak self] state in
            self?.searchState = state
            if !state.request.isEmpty {
                self?.makeSearchCommand?(.loading)
            }
        }))
    }
    
    
    override func loadView() {
        super.loadView()
        genericView.tabs.delegate = self
        updateLocalizationAndTheme(theme: theme)
    }
    
    
    func isSelectable(row: Int, item: TableRowItem) -> Bool {
        return true
    }
    
    func selectionWillChange(row: Int, item: TableRowItem, byClick: Bool) -> Bool {
        return true
    }
    
    func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) {
        
    }
    
    func loadResource() -> Signal <Void, NoError> {
        return Signal { (subscriber) -> Disposable in
                _ = emojiesInstance
                subscriber.putNext(Void())
                subscriber.putCompletion()
            return ActionDisposable(action: {
                
            });
        } |> runOn(resourcesQueue)
    }
    
    deinit {
        disposable.dispose()
        searchStateDisposable.dispose()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        genericView.needsLayout = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.genericView.tableView.performScrollEvent()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        

        
        
        // DO NOT WRITE CODE OUTSIZE READY BLOCK
      
        let ready:(RecentUsedEmoji, [String]?)->Void = { [weak self] recent, search in
            if let strongSelf = self {
                strongSelf.makeSearchCommand?(.normal)
                strongSelf.readyForDisplay(recent, search)
                strongSelf.readyOnce()
            }
        }
        
        let context = self.context
        
        let s:Signal = combineLatest(queue: resourcesQueue, loadResource(), recentUsedEmoji(postbox: context.account.postbox), appearanceSignal, self.searchValue.get() |> distinctUntilChanged(isEqual: { prev, new in
            return prev.request == new.request
        }) |> mapToSignal { state -> Signal<[String]?, NoError> in
            if state.request.isEmpty {
                return .single(nil)
            } else {
                return context.sharedContext.inputSource.searchEmoji(postbox: context.account.postbox, sharedContext: context.sharedContext, query: state.request, completeMatch: false, checkPrediction: false) |> map(Optional.init) |> delay(0.2, queue: .concurrentDefaultQueue())
            }
        }) |> deliverOnMainQueue
        
        disposable.set(s.start(next: { (_, recent, _, search) in
            isReady = true
            
            ready(recent, search)
        }))
        
        
        genericView.tableView.addScroll(listener: TableScrollListener(dispatchWhenVisibleRangeUpdated: false, { [weak self] _ in
            if let view = self?.genericView {
                view.tableView.enumerateVisibleItems(with: { item -> Bool in
                    if let item = item as? EStickItem {
                        view.tabs.changeSelection(stableId: AnyHashable(Int64(item.segment.rawValue)))
                    } else if let item = item as? EBlockItem {
                        view.tabs.changeSelection(stableId: AnyHashable(Int64(item.segment.rawValue)))
                    }
                    return false
                })
            }
        }))
    }
    
    func readyForDisplay(_ recent: RecentUsedEmoji, _ search: [String]?) -> Void {
        
       
        let initialSize = atomicSize.modify({$0})
        genericView.tableView.beginTableUpdates()
        genericView.tableView.removeAll()
        genericView.tabs.removeAll()
        
        if let search = search {
            
            let lines = search.chunks(8).map({ clues -> [NSAttributedString] in
                return clues.map({NSAttributedString.initialize(string: $0, font: .normal(26.0))})
            })
            if lines.count > 0 {
                let _ = genericView.tableView.addItem(item: EBlockItem(initialSize, attrLines: lines, segment: .Recent, account: context.account, selectHandler: { [weak self] emoji in
                    self?.interactions?.sendEmoji(emoji)
                }))
            }

        } else {
            var e = emojiesInstance
            e[EmojiSegment.Recent] = recent.emojies
            let seg = segments(e, skinModifiers: recent.skinModifiers)
            let seglist = seg.map { (key,_) -> EmojiSegment in
                return key
            }.sorted(by: <)
            
            
            
            let w = floorToScreenPixels(System.backingScale, frame.width / CGFloat(seg.count))
            
            genericView.tabs.setFrameSize(NSMakeSize(w * CGFloat(seg.count), 40))
            genericView.tabs.center()
            var tabIcons:[CGImage] = []
            tabIcons.append(theme.icons.emojiRecentTab)
            tabIcons.append(theme.icons.emojiSmileTab)
            tabIcons.append(theme.icons.emojiNatureTab)
            tabIcons.append(theme.icons.emojiFoodTab)
            tabIcons.append(theme.icons.emojiSportTab)
            tabIcons.append(theme.icons.emojiCarTab)
            tabIcons.append(theme.icons.emojiObjectsTab)
            tabIcons.append(theme.icons.emojiSymbolsTab)
            tabIcons.append(theme.icons.emojiFlagsTab)
            
            var tabIconsSelected:[CGImage] = []
            tabIconsSelected.append(theme.icons.emojiRecentTabActive)
            tabIconsSelected.append(theme.icons.emojiSmileTabActive)
            tabIconsSelected.append(theme.icons.emojiNatureTabActive)
            tabIconsSelected.append(theme.icons.emojiFoodTabActive)
            tabIconsSelected.append(theme.icons.emojiSportTabActive)
            tabIconsSelected.append(theme.icons.emojiCarTabActive)
            tabIconsSelected.append(theme.icons.emojiObjectsTabActive)
            tabIconsSelected.append(theme.icons.emojiSymbolsTabActive)
            tabIconsSelected.append(theme.icons.emojiFlagsTabActive)
            for key in seglist {
                if key != .Recent {
                    let _ = genericView.tableView.addItem(item: EStickItem(initialSize, segment:key, segmentName:key.localizedString))
                }
                let _ = genericView.tableView.addItem(item: EBlockItem(initialSize, attrLines: seg[key]!, segment: key, account: context.account, selectHandler: { [weak self] emoji in
                    self?.interactions?.sendEmoji(emoji)
                }))
                let _ = genericView.tabs.addItem(item: ETabRowItem(initialSize, icon: tabIcons[key.hashValue], iconSelected:tabIconsSelected[key.hashValue], stableId:key.rawValue, width:w, clickHandler:{[weak self] (stableId) in
                    self?.scrollTo(stableId: stableId)
                }))
            }
        }
        genericView.tableView.endTableUpdates()
        genericView.updateVisibility(genericView.tableView.isEmpty, isSearch: search != nil)
        
        self.genericView.tableView.scroll(to: .up(true))
    }
    
    func update(with interactions: EntertainmentInteractions) {
        self.interactions = interactions
    }
    
    override var supportSwipes: Bool {
        return !genericView.tabs._mouseInside()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    func scrollTo(stableId:AnyHashable) -> Void {
        genericView.tabs.changeSelection(stableId: stableId)
        genericView.tableView.scroll(to: .top(id: stableId, innerId: nil, animated: true, focus: .init(focus: false), inset: 0), inset:NSEdgeInsets(top:3))
    }
    override func scrollup(force: Bool = false) {
        self.genericView.tableView.scroll(to: .up(true))
    }

}
