//
//  FragmentMonetizationController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07.03.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import TGUIKit
import SwiftSignalKit
import CurrencyFormat
import InputView
import GraphCore


private final class TransactionTypesItem : GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let items: [ScrollableSegmentItem]
    fileprivate let callback:(State.TransactionMode)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, modes: [State.TransactionMode], transactionMode: State.TransactionMode, viewType: GeneralViewType, callback:@escaping(State.TransactionMode)->Void) {
        self.context = context
        self.callback = callback
        
        let theme = ScrollableSegmentTheme(background: .clear, border: .clear, selector: theme.colors.accent, inactiveText: theme.colors.grayText, activeText: theme.colors.text, textFont: .normal(.text))
        
        var items: [ScrollableSegmentItem] = []
        
        for mode in modes {
            items.append(.init(title: mode.text, index: mode.rawValue, uniqueId: Int64(mode.rawValue), selected: transactionMode == mode, insets: NSEdgeInsets(left: 10, right: 10), icon: nil, theme: theme, equatable: UIEquatable(mode)))
        }
        
        self.items = items
        super.init(initialSize, height: 50, stableId: stableId, viewType: viewType)
    }
    
    override func viewClass() -> AnyClass {
        return TransactionTypesView.self
    }
}

private final class TransactionTypesView: GeneralContainableRowView {
    fileprivate let segmentControl: ScrollableSegmentView
    required init(frame frameRect: NSRect) {
        self.segmentControl = ScrollableSegmentView(frame: NSMakeRect(0, 0, frameRect.width, 50))
        super.init(frame: frameRect)
        addSubview(segmentControl)
        
        segmentControl.didChangeSelectedItem = { [weak self] selected in
            if let item = self?.item as? TransactionTypesItem {
                if selected.uniqueId == 0 {
                    item.callback(.ton)
                } else if selected.uniqueId == 1 {
                    item.callback(.xtr)
                }
            }
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? TransactionTypesItem else {
            return
        }
        segmentControl.updateItems(item.items, animated: animated)
        needsLayout = true
    }
    
    override func layout() {
        segmentControl.frame = containerView.bounds
    }
}

private func insertSymbolIntoMiddle(of string: String, with symbol: Character) -> String {
    var modifiedString = string
    let middleIndex = modifiedString.index(modifiedString.startIndex, offsetBy: modifiedString.count / 2)
    modifiedString.insert(contentsOf: [symbol], at: middleIndex)
    return modifiedString
}



extension String {
    var prettyCurrencyNumber: String {
        let nsString = self as NSString
        let range = nsString.range(of: ".")
        var string = self
        if range.location != NSNotFound {
            var lastIndex = self.count - 1
            while lastIndex > range.location && (self[self.index(self.startIndex, offsetBy: lastIndex)] == "0" || self[self.index(self.startIndex, offsetBy: lastIndex)] == "." || lastIndex > range.location + 4) {
                lastIndex -= 1
            }
            string = String(self.prefix(lastIndex + 1))
        }
        if string.hasSuffix(".") {
            _ = string.removeLast()
        }
        return string
    }
    var prettyCurrencyNumberUsd: String {
        let nsString = self as NSString
        let range = nsString.range(of: ".")
        var string = self
        if range.location != NSNotFound {
            var lastIndex = self.count - 1
            while lastIndex > range.location && (self[self.index(self.startIndex, offsetBy: lastIndex)] == "0" || self[self.index(self.startIndex, offsetBy: lastIndex)] == "." || lastIndex > range.location + 2) {
                lastIndex -= 1
            }
            string = String(self.prefix(lastIndex + 1))
        }
        if string.hasSuffix(".") {
            _ = string.removeLast()
        }
        return string
    }
}


extension StarsContext.State {
    var usdRate: Double {
        return 0.01
    }
    var fractional: Double {
        return currencyToFractionalAmount(value: balance.totalValue, currency: XTR) ?? 0
    }
    var usdAmount: String {
        return "$" + "\(self.fractional * self.usdRate)".prettyCurrencyNumberUsd
    }
    
}

private final class Arguments {
    let context: AccountContext
    let interactions: TextView_Interactions
    let updateState:(Updated_ChatTextInputState)->Void
    let executeLink:(String)->Void
    let withdraw:()->Void
    let withdrawStars:()->Void
    let promo:()->Void
    let loadDetailedGraph:(StatsGraph, Int64) -> Signal<StatsGraph?, NoError>
    let transaction:(Star_Transaction)->Void
    let toggleAds:()->Void
    let loadMore:(State.TransactionMode)->Void
    let toggleTransactionType:(State.TransactionMode)->Void
    let openStarsTransaction:(Star_Transaction)->Void
    let openAffiliate:()->Void
    init(context: AccountContext, interactions: TextView_Interactions, updateState:@escaping(Updated_ChatTextInputState)->Void, executeLink:@escaping(String)->Void, withdraw:@escaping()->Void, promo: @escaping()->Void, loadDetailedGraph:@escaping(StatsGraph, Int64) -> Signal<StatsGraph?, NoError>, transaction:@escaping(Star_Transaction)->Void, toggleAds:@escaping()->Void, loadMore:@escaping(State.TransactionMode)->Void, toggleTransactionType:@escaping(State.TransactionMode)->Void, openStarsTransaction:@escaping(Star_Transaction)->Void, withdrawStars:@escaping()->Void, openAffiliate:@escaping()->Void) {
        self.context = context
        self.interactions = interactions
        self.updateState = updateState
        self.executeLink = executeLink
        self.withdraw = withdraw
        self.promo = promo
        self.loadDetailedGraph = loadDetailedGraph
        self.transaction = transaction
        self.toggleAds = toggleAds
        self.loadMore = loadMore
        self.toggleTransactionType = toggleTransactionType
        self.openStarsTransaction = openStarsTransaction
        self.withdrawStars = withdrawStars
        self.openAffiliate = openAffiliate
    }
}



private struct StarsState : Equatable {

    enum TransactionType : Equatable {
        enum Source : Equatable {
            case bot
            case appstore
            case fragment
            case playmarket
            case premiumbot
            case unknown
        }
        case incoming(Source)
        case outgoing
    }
    struct Transaction : Equatable {
        let id: String
        let amount: StarsAmount
        let date: Int32
        let name: String
        let peer: EnginePeer?
        let type: TransactionType
        let native: StarsContext.State.Transaction
    }
    
    struct Balance : Equatable {
        var stars: StarsAmount
        var usdRate: Double
        
        var fractional: Double {
            return currencyToFractionalAmount(value: stars.totalValue, currency: XTR) ?? 0
        }
        
        var usd: String {
            return "$" + "\(self.fractional * self.usdRate)".prettyCurrencyNumberUsd
        }
    }
    struct Overview : Equatable {
        var balance: Balance
        var current: Balance
        var all: Balance
    }
    
    var config_withdraw: Bool
        
    var nextWithdrawalTimestamp: Int32? = nil

    var overview: Overview = .init(balance: .init(stars: .zero, usdRate: 0), current: .init(stars: .zero, usdRate: 0), all: .init(stars: .zero, usdRate: 0))
    var balance: Balance = .init(stars: .init(value: 0, nanos: 0), usdRate: 0)
    var transactions: [Star_Transaction] = []
        
    var transactionsState: StarsTransactionsContext.State?
    var adsUrl: String?
    var inputState: Updated_ChatTextInputState = .init()
    
    
    var withdrawError: RequestStarsRevenueWithdrawalError? = nil
    
    var peer: EnginePeer? = nil
    
    var canWithdraw: Bool {
        if let nextWithdrawalTimestamp {
            if nextWithdrawalTimestamp < Int32(Date().timeIntervalSince1970) {
                return config_withdraw
            }
        }
        return config_withdraw
    }
    
    var revenueGraph: StatsGraph?
    
}



private struct State : Equatable {

    enum TransactionMode : Int {
        case ton = 0
        case xtr = 1
        
        var text: String {
            switch self {
            case .xtr:
                return strings().monetizationTransactionsStars
            case .ton:
                return strings().monetizationTransactionsTON
            }
        }
    }

    struct Balance : Equatable {
        var ton: Int64
        var usdRate: Double
        
        var fractional: Double {
            return currencyToFractionalAmount(value: Double(ton), currency: "TON") ?? 0
        }
        
        var usd: String {
            return "$" + "\(self.fractional * self.usdRate)".prettyCurrencyNumberUsd
        }
    }
    struct Overview : Equatable {
        var balance: Balance
        var last: Balance
        var all: Balance
    }
    
    var config_withdraw: Bool
    
    
    var overview: Overview = .init(balance: .init(ton: 0, usdRate: 0), last: .init(ton: 0, usdRate: 0), all: .init(ton: 0, usdRate: 0))
    var balance: Balance = .init(ton: 0, usdRate: 0)
    var transactions: [Star_Transaction] = []
    var transactionsState: StarsTransactionsContext.State?
    
    
    var withdrawError: RequestStarsRevenueWithdrawalError? = nil
    
    var peer: EnginePeer? = nil
    
    var canWithdraw: Bool {
        return (peer?._asPeer().groupAccess.isCreator ?? false) && config_withdraw
    }
    
    var revenueGraph: StatsGraph?
    var topHoursGraph: StatsGraph?
    
    
    var status: ChannelBoostStatus?
    var myStatus: MyBoostStatus?
    
    var adsRestricted: Bool = false
    
    var transactionMode: TransactionMode = .ton
    
    var starsState: StarsState?
    
}

private func _id_overview(_ index: Int) -> InputDataIdentifier {
    return InputDataIdentifier("_id_overview_\(index)")
}
private func _id_transaction(_ index: Int) -> InputDataIdentifier {
    return InputDataIdentifier("_id_transaction\(index)")
}

private func _id_transaction(_ transaction: Star_Transaction) -> InputDataIdentifier {
    return InputDataIdentifier("_id_transaction_\(transaction.id)_\(transaction.type)")
}


private let _id_balance_stars = InputDataIdentifier("_id_stars_balance")
private let _id_balance_ton = InputDataIdentifier("_id_ton_balance")

private let _id_top_hours_graph = InputDataIdentifier("_id_top_hours_graph")
private let _id_revenue_graph = InputDataIdentifier("_id_revenue_graph")

private let _id_switch_ad = InputDataIdentifier("_id_switch_ad")

private let _id_loading = InputDataIdentifier("_id_loading")
private let _id_load_more = InputDataIdentifier("_id_load_more")

private let _id_transaction_mode = InputDataIdentifier("_id_transaction_mode")


private func entries(_ state: State, arguments: Arguments, detailedDisposable: DisposableDict<InputDataIdentifier>) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
        
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(state.peer?._asPeer().isBot == true ? strings().monetizationHeaderBot("%") : strings().monetizationHeader("%"), linkHandler: { _ in
        arguments.promo()
    }), data: .init(color: theme.colors.listGrayText, viewType: .singleItem)))
    index += 1
    
    
    do {
        
        struct Graph {
            let graph: StatsGraph
            let title: String
            let identifier: InputDataIdentifier
            let type: ChartItemType
            let rate: Double
            let load:(InputDataIdentifier)->Void
        }
        
        var graphs: [Graph] = []
        if let graph = state.topHoursGraph, !graph.isEmpty {
            graphs.append(Graph(graph: graph, title: strings().monetizationImpressionsTitle, identifier: _id_top_hours_graph, type: .hourlyStep, rate: 1.0, load: { identifier in
               
            }))
        }
        if let graph = state.revenueGraph, !graph.isEmpty {
            graphs.append(Graph(graph: graph, title: strings().monetizationAdRevenueTitle, identifier: _id_revenue_graph, type: .currency(TON), rate: state.balance.usdRate, load: { identifier in
                
            }))
        }
        
        
        for graph in graphs {
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(graph.title), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
            
            switch graph.graph {
            case let .Loaded(_, string):
                ChartsDataManager.readChart(data: string.data(using: .utf8)!, sync: true, success: { collection in
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), comparable: nil, item: { initialSize, stableId in
                        return StatisticRowItem(initialSize, stableId: stableId, context: arguments.context, collection: collection, viewType: .singleItem, type: graph.type, rate: graph.rate, getDetailsData: { date, completion in
                            detailedDisposable.set(arguments.loadDetailedGraph(graph.graph, Int64(date.timeIntervalSince1970) * 1000).start(next: { graph in
                                if let graph = graph, case let .Loaded(_, data) = graph {
                                    completion(data)
                                }
                            }), forKey: graph.identifier)
                        })
                    }))
                }, failure: { error in
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), comparable: nil, item: { initialSize, stableId in
                        return StatisticLoadingRowItem(initialSize, stableId: stableId, error: error.localizedDescription)
                    }))
                })
                                
                index += 1
            case .OnDemand:
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), comparable: nil, item: { initialSize, stableId in
                    return StatisticLoadingRowItem(initialSize, stableId: stableId, error: nil)
                }))
                index += 1
//                if !uiState.loading.contains(graph.identifier) {
//                    graph.load(graph.identifier)
//                }
            case let .Failed(error):
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), comparable: nil, item: { initialSize, stableId in
                    return StatisticLoadingRowItem(initialSize, stableId: stableId, error: error)
                }))
                index += 1
               // updateIsLoading(graph.identifier, false)
            case .Empty:
                break
            }
        }
        
    }
    
    do {
        if let state = state.starsState {
            struct Graph {
                let graph: StatsGraph
                let title: String
                let identifier: InputDataIdentifier
                let type: ChartItemType
                let rate: Double
                let load:(InputDataIdentifier)->Void
            }
            
            var graphs: [Graph] = []
            if let graph = state.revenueGraph, !graph.isEmpty {
                graphs.append(Graph(graph: graph, title: strings().fragmentStarsRevenueTitle, identifier: _id_revenue_graph, type: .currency(XTR), rate: state.balance.usdRate, load: { identifier in
                    
                }))
            }
            
            for graph in graphs {
                entries.append(.sectionId(sectionId, type: .normal))
                sectionId += 1
                entries.append(.desc(sectionId: sectionId, index: index, text: .plain(graph.title), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
                index += 1
                
                switch graph.graph {
                case let .Loaded(_, string):
                    ChartsDataManager.readChart(data: string.data(using: .utf8)!, sync: true, success: { collection in
                        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), comparable: nil, item: { initialSize, stableId in
                            return StatisticRowItem(initialSize, stableId: stableId, context: arguments.context, collection: collection, viewType: .singleItem, type: graph.type, rate: graph.rate, getDetailsData: { date, completion in
                                detailedDisposable.set(arguments.loadDetailedGraph(graph.graph, Int64(date.timeIntervalSince1970) * 1000).start(next: { graph in
                                    if let graph = graph, case let .Loaded(_, data) = graph {
                                        completion(data)
                                    }
                                }), forKey: graph.identifier)
                            })
                        }))
                    }, failure: { error in
                        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), comparable: nil, item: { initialSize, stableId in
                            return StatisticLoadingRowItem(initialSize, stableId: stableId, error: error.localizedDescription)
                        }))
                    })
                                    
                    index += 1
                case .OnDemand:
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), comparable: nil, item: { initialSize, stableId in
                        return StatisticLoadingRowItem(initialSize, stableId: stableId, error: nil)
                    }))
                    index += 1
                case let .Failed(error):
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), comparable: nil, item: { initialSize, stableId in
                        return StatisticLoadingRowItem(initialSize, stableId: stableId, error: error)
                    }))
                    index += 1
                case .Empty:
                    break
                }
            }
        }
    }
    
    
    do {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        struct Tuple : Equatable {
            let overview: Fragment_OverviewRowItem.Overview
            let viewType: GeneralViewType
        }
        
        let tuples: [Tuple] = [
            .init(overview: .init(amount: state.overview.balance.ton, usdAmount: state.overview.balance.usd, info: strings().monetizationOverviewAvailable, stars: state.starsState.flatMap { .init(amount: $0.overview.balance.stars, usdRate: $0.overview.balance.usdRate) }), viewType: .firstItem),
            .init(overview: .init(amount: state.overview.all.ton, usdAmount: state.overview.all.usd, info: strings().monetizationOverviewTotal, stars: state.starsState.flatMap { .init(amount: $0.overview.all.stars, usdRate: $0.overview.all.usdRate) }), viewType: .lastItem)
        ]
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().monetizationOverviewTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        for (i, tuple) in tuples.enumerated() {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_overview(i), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
                return Fragment_OverviewRowItem(initialSize, stableId: stableId, context: arguments.context, overview: tuple.overview, currency: .ton, viewType: tuple.viewType)
            }))
        }
    }
    
    
    if state.balance.ton > 0 {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
      
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().monetizationBalanceTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_balance_ton, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return Fragment_BalanceRowItem(initialSize, stableId: stableId, context: arguments.context, balance: .init(amount: Double(state.balance.ton), usd: state.balance.usd, currency: .ton), canWithdraw: state.canWithdraw, viewType: .singleItem, transfer: arguments.withdraw)
        }))
        
        let text: String
        if state.config_withdraw {
            text = strings().monetizationBalanceInfo
        } else {
            text = strings().monetizationBalanceComingLaterInfo
        }
        entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(text, linkHandler: { link in
            arguments.executeLink(link)
        }), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
    }
    
    if let state = state.starsState {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
      
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().fragmentStarsBalanceTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_balance_stars, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return Fragment_BalanceRowItem(initialSize, stableId: stableId, context: arguments.context, balance: .init(amount: state.balance.stars.totalValue, usd: state.balance.usd, currency: .xtr), canWithdraw: state.canWithdraw, buyAds: {
                if let url = state.adsUrl {
                    arguments.executeLink(url)
                }
            }, nextWithdrawalTimestamp: state.nextWithdrawalTimestamp, viewType: .singleItem, transfer: arguments.withdrawStars)
        }))
        
        let text: String
        text = strings().fragmentStarsWithdrawInfo
        entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(text, linkHandler: { link in
            arguments.executeLink(link)
        }), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
        
    }
    
  
    let affiliateEnabled = arguments.context.appConfiguration.getBoolValue("starref_connect_allowed", orElse: false)
    
    if affiliateEnabled {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("affiliate"), data: .init(name: strings().affilateProgramEarn, color: theme.colors.text, icon: NSImage(resource: .iconAffiliateEarnStars).precomposed(flipVertical: true), type: .next, viewType: .singleItem, description: strings().affilateProgramEarnInfo, descTextColor: theme.colors.grayText, action: arguments.openAffiliate, afterNameImage: generateTextIcon_NewBadge_Flipped(bgColor: theme.colors.accent, textColor: theme.colors.underSelectedColor))))

    }
        

    if let transactionsState = state.transactionsState, let starsState = state.starsState, let starsTransactionsState = starsState.transactionsState {
       
        
        var modes: [State.TransactionMode] = []
        if !state.transactions.isEmpty {
            modes.append(.ton)
        }
        if !starsState.transactions.isEmpty {
            modes.append(.xtr)
        }
        
        var mode = state.transactionMode
        if state.transactionMode == .ton, !modes.contains(.ton) {
            mode = .xtr
        }
        if state.transactionMode == .xtr, !modes.contains(.xtr) {
            mode = .ton
        }
        if !modes.isEmpty {
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
          
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().monetizationTransactionsTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_transaction_mode, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
                return TransactionTypesItem(initialSize, stableId: stableId, context: arguments.context, modes: modes, transactionMode: mode, viewType: .firstItem, callback: arguments.toggleTransactionType)
            }))
        }
        
        
        switch mode {
        case .ton:
            
            struct Tuple : Equatable {
                let transaction: Star_Transaction
                let viewType: GeneralViewType
            }
            
            var tuples: [Tuple] = []
            for (i, transaction) in state.transactions.enumerated() {
                var viewType = bestGeneralViewTypeAfterFirst(state.transactions, for: i)
                if transactionsState.canLoadMore || transactionsState.isLoading {
                    if i == state.transactions.count - 1 {
                        viewType = .innerItem
                    }
                }
                tuples.append(.init(transaction: transaction, viewType: viewType))
            }
            
            for (i, tuple) in tuples.enumerated() {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_transaction(i), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
                    return Star_TransactionItem(initialSize, stableId: stableId, context: arguments.context, viewType: tuple.viewType, transaction: tuple.transaction, callback: arguments.transaction)
                }))
            }
            
            if transactionsState.isLoading {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_loading, equatable: nil, comparable: nil, item: { initialSize, stableId in
                    return LoadingTableItem(initialSize, height: 40, stableId: stableId, viewType: .lastItem)
                }))
            } else if transactionsState.canLoadMore {
                entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_load_more, data: .init(name: strings().starListTransactionsShowMore, color: theme.colors.accent, type: .none, viewType: .lastItem, action: {
                    arguments.loadMore(.ton)
                })))
            }
        case .xtr:
            struct Tuple : Equatable {
                let transaction: Star_Transaction
                let viewType: GeneralViewType
            }
            var tuples: [Tuple] = []
            for (i, transaction) in starsState.transactions.enumerated() {
                var viewType = bestGeneralViewTypeAfterFirst(starsState.transactions, for: i)
                if starsTransactionsState.canLoadMore || starsTransactionsState.isLoading {
                    if i == starsState.transactions.count - 1 {
                        viewType = .innerItem
                    }
                }
                tuples.append(.init(transaction: transaction, viewType: viewType))
            }
            
            for tuple in tuples {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_transaction(tuple.transaction), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
                    return Star_TransactionItem(initialSize, stableId: stableId, context: arguments.context, viewType: tuple.viewType, transaction: tuple.transaction, callback: arguments.openStarsTransaction)
                }))
            }
            
            if starsTransactionsState.isLoading {
                
                if modes.isEmpty {
                    entries.append(.sectionId(sectionId, type: .normal))
                    sectionId += 1
                }

                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_loading, equatable: nil, comparable: nil, item: { initialSize, stableId in
                    return LoadingTableItem(initialSize, height: 40, stableId: stableId, viewType: .lastItem)
                }))
            } else if starsTransactionsState.canLoadMore {
                entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_load_more, data: .init(name: strings().fragmentStarsShowMore, color: theme.colors.accent, type: .none, viewType: .lastItem, action: {
                    arguments.loadMore(.xtr)
                })))
            }
        }

    }
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    if state.peer?._asPeer().isChannel == true {
        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: arguments.context.appConfiguration)
        
        let afterNameImage = generateDisclosureActionBoostLevelBadgeImage(text: strings().boostBadgeLevel(Int(premiumConfiguration.minChannelRestrictAdsLevel)))


        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_switch_ad, data: .init(name: strings().monetizationSwitchOffAds, color: theme.colors.text, type: .switchable(state.adsRestricted), viewType: .singleItem, action: arguments.toggleAds, afterNameImage: afterNameImage, autoswitch: false)))
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().monetizationSwitchOffAdsInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1

    }

    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func FragmentMonetizationController(context: AccountContext, peerId: PeerId, onlyTonContext: StarsRevenueStatsContext? = nil) -> InputDataController {

    let actionsDisposable = DisposableSet()
    
    let detailedDisposable: DisposableDict<InputDataIdentifier> = DisposableDict()
    actionsDisposable.add(detailedDisposable)
    

    let initialState = State(config_withdraw: context.appConfiguration.getBoolValue("channel_revenue_withdrawal_enabled", orElse: false))
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    class ContextObject {
        let stats: StarsRevenueStatsContext
        let transactions: StarsTransactionsContext
        let starsRevenue: StarsRevenueStatsContext?
        let starsTransactions: StarsTransactionsContext?

        init(stats: StarsRevenueStatsContext, transactions: StarsTransactionsContext, starsRevenue: StarsRevenueStatsContext?, starsTransactions: StarsTransactionsContext?) {
            self.stats = stats
            self.transactions = transactions
            self.starsRevenue = starsRevenue
            self.starsTransactions = starsTransactions
        }
        
        var starsStateValue: Signal<StarsRevenueStatsContextState?, NoError> {
            if let starsRevenue {
                return starsRevenue.state |> map(Optional.init)
            } else {
                return .single(nil)
            }
        }
        var starsTransactionsValue: Signal<StarsTransactionsContext.State?, NoError> {
            if let starsTransactions {
                return starsTransactions.state |> map(Optional.init)
            } else {
                return .single(nil)
            }
        }
    }
    
    let stats = onlyTonContext ?? StarsRevenueStatsContext(account: context.account, peerId: peerId, ton: true)
    let transactions = context.engine.payments.peerStarsTransactionsContext(subject: .peer(peerId: peerId, ton: true), mode: .all)
    let starsTransactions = onlyTonContext != nil ? nil : context.engine.payments.peerStarsTransactionsContext(subject: .peer(peerId: peerId, ton: false), mode: .all)
    
    starsTransactions?.loadMore()
    
    let revenueContext = onlyTonContext != nil ? nil : StarsRevenueStatsContext(account: context.account, peerId: peerId, ton: false)
    revenueContext?.reload()
    
    let contextObject = ContextObject(stats: stats, transactions: transactions, starsRevenue: revenueContext, starsTransactions: starsTransactions)
        
    let peer = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
    let adsUrl: Signal<String?, NoError> = .single(nil) |> then(context.engine.peers.requestStarsRevenueAdsAccountlUrl(peerId: peerId))

    actionsDisposable.add(combineLatest(contextObject.stats.state, contextObject.transactions.state, peer, contextObject.starsStateValue, contextObject.starsTransactionsValue, adsUrl).start(next: { state, transactions, peer, starsRevenue, starsTransactions, adsUrl in
        if let stats = state.stats {
            updateState { current in
                var current = current
                
                current.peer = peer
                
                current.balance = .init(ton: stats.balances.availableBalance.amount.value, usdRate: stats.usdRate)
                current.overview.balance = .init(ton: stats.balances.availableBalance.amount.value, usdRate: stats.usdRate)
                current.overview.all = .init(ton: stats.balances.overallRevenue.amount.value, usdRate: stats.usdRate)
                current.overview.last = .init(ton: stats.balances.currentBalance.amount.value, usdRate: stats.usdRate)
                
                current.revenueGraph = stats.revenueGraph
                current.topHoursGraph = stats.topHoursGraph
                                                
                current.transactions = transactions.transactions.map { value in
                    let type: Star_TransactionType
                    var botPeer: EnginePeer?
                    let incoming: Bool = value.count.amount.totalValue > 0
                    let source: Star_TransactionType.Source
                    switch value.peer {
                    case let .peer(peer):
                        source = .peer
                        botPeer = peer
                    case .appStore:
                        source = .appstore
                    case .fragment:
                        source = .fragment
                    case .playMarket:
                        source = .playmarket
                    case .premiumBot:
                        source = .premiumbot
                    case .unsupported:
                        source = .unknown
                    case .ads:
                        source = .ads
                    case .apiLimitExtension:
                        source = .apiLimitExtension
                    }
                    if incoming {
                        type = .incoming(source)
                    } else {
                        type = .outgoing(source)
                    }
                    
                    return Star_Transaction(id: value.id, currency: value.count.currency, amount: value.count.amount, date: value.date, name: "", peer: botPeer, type: type, native: value)
                } ?? []
                
                current.transactionsState = transactions
                
                
                if let revenue = starsRevenue?.stats {
                    var starsState = StarsState(config_withdraw: false)
                    starsState.balance = .init(stars: revenue.balances.availableBalance.amount, usdRate: revenue.usdRate)
                    starsState.overview.balance = .init(stars: revenue.balances.availableBalance.amount, usdRate: revenue.usdRate)
                    starsState.overview.all = .init(stars: revenue.balances.overallRevenue.amount, usdRate: revenue.usdRate)
                    starsState.overview.current = .init(stars: revenue.balances.currentBalance.amount, usdRate: revenue.usdRate)
                    starsState.config_withdraw = revenue.balances.withdrawEnabled
                    starsState.nextWithdrawalTimestamp = revenue.balances.nextWithdrawalTimestamp
                    starsState.transactionsState = starsTransactions
                    starsState.adsUrl = adsUrl
                    
                    starsState.revenueGraph = revenue.revenueGraph
                    starsState.transactions = starsTransactions?.transactions.map { value in
                        let type: Star_TransactionType
                        var botPeer: EnginePeer?
                        let incoming: Bool = value.count.amount.totalValue > 0
                        let source: Star_TransactionType.Source
                        switch value.peer {
                        case let .peer(peer):
                            source = .peer
                            botPeer = peer
                        case .appStore:
                            source = .appstore
                        case .fragment:
                            source = .fragment
                        case .playMarket:
                            source = .playmarket
                        case .premiumBot:
                            source = .premiumbot
                        case .unsupported:
                            source = .unknown
                        case .ads:
                            source = .ads
                        case .apiLimitExtension:
                            source = .apiLimitExtension
                        }
                        if incoming {
                            type = .incoming(source)
                        } else {
                            type = .outgoing(source)
                        }
                        
                        return Star_Transaction(id: value.id, currency: value.count.currency, amount: value.count.amount, date: value.date, name: "", peer: botPeer, type: type, native: value)
                    } ?? []
                    current.starsState = starsState
                }
                
                return current
            }
        }
        
        
    }))
    
    actionsDisposable.add(context.engine.peers.checkStarsRevenueWithdrawalAvailability().start(error: { error in
        updateState { current in
            var current = current
            current.withdrawError = error
            return current
        }
    }))
    
    
    let boostStatus = combineLatest(context.engine.peers.getChannelBoostStatus(peerId: peerId), context.engine.peers.getMyBoostStatus(), context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.AdsRestricted(id: peerId)))
    
    actionsDisposable.add(boostStatus.startStandalone(next: { stats, myStatus, adsRestricted in
        updateState { current in
            var current = current
            current.status = stats
            current.myStatus = myStatus
            current.adsRestricted = adsRestricted
            return current
        }
    }))
    
    
    let textInteractions = TextView_Interactions()

    
    textInteractions.processEnter = { event in
        return false
    }
    textInteractions.processAttriburedCopy = { attributedString in
        return globalLinkExecutor.copyAttributedString(attributedString)
    }
    textInteractions.processPaste = { pasteboard in
        if let data = pasteboard.data(forType: .kInApp) {
            let decoder = AdaptedPostboxDecoder()
            if let decoded = try? decoder.decode(ChatTextInputState.self, from: data) {
                let state = decoded.unique(isPremium: true)
                textInteractions.update { _ in
                    return textInteractions.insertText(state.attributedString())
                }
                return true
            }
        }
        return false
    }
    
    let processWithdraw:(Int64)->Void = { amount in
        
        _ = showModalProgress(signal: context.engine.peers.checkStarsRevenueWithdrawalAvailability(), for: context.window).startStandalone(error: { error in
            switch error {
            case .authSessionTooFresh, .twoStepAuthTooFresh, .twoStepAuthMissing:
                alert(for: context.window, info: strings().monetizationWithdrawErrorText)
            case .requestPassword:
                showModal(with: InputPasswordController(context: context, title: strings().monetizationWithdrawEnterPasswordTitle, desc: strings().monetizationWithdrawEnterPasswordText, checker: { value in
                    return context.engine.peers.requestStarsRevenueWithdrawalUrl(peerId: peerId, ton: true, amount: amount, password: value)
                    |> deliverOnMainQueue
                    |> afterNext { url in
                        execute(inapp: .external(link: url, false))
                    }
                    |> ignoreValues
                    |> mapError { error in
                        switch error {
                        case .invalidPassword:
                            return .wrong
                        case .limitExceeded:
                            return .custom(strings().loginFloodWait)
                        case .generic:
                            return .generic
                        default:
                            return .custom(strings().monetizationWithdrawErrorText)
                        }
                    }
                }), for: context.window)
            default:
                break
            }
        })
    }

    let arguments = Arguments(context: context, interactions: textInteractions, updateState: { state in
        textInteractions.update { _ in
            return state
        }
    }, executeLink: { link in
        execute(inapp: .external(link: link, false))
    }, withdraw: {
        let error = stateValue.with { $0.withdrawError }
        if let error {
            switch error {
            case .authSessionTooFresh, .twoStepAuthTooFresh, .twoStepAuthMissing:
                alert(for: context.window, info: strings().monetizationWithdrawErrorText)
            case .requestPassword:
                showModal(with: InputPasswordController(context: context, title: strings().monetizationWithdrawEnterPasswordTitle, desc: strings().monetizationWithdrawEnterPasswordText, checker: { value in
                    return context.engine.peers.requestStarsRevenueWithdrawalUrl(peerId: peerId, ton: true, amount: nil, password: value)
                    |> deliverOnMainQueue
                    |> afterNext { url in
                        execute(inapp: .external(link: url, false))
                    } 
                    |> ignoreValues
                    |> mapError { error in
                        switch error {
                        case .invalidPassword:
                            return .wrong
                        case .limitExceeded:
                            return .custom(strings().loginFloodWait)
                        case .generic:
                            return .generic
                        default:
                            return .custom(strings().monetizationWithdrawErrorText)
                        }
                    }
                }), for: context.window)
            default:
                alert(for: context.window, info: strings().unknownError)
            }
        }
    }, promo: {
        let isBot = stateValue.with { $0.peer?._asPeer().isBot ?? false }
        showModal(with: FragmentMonetizationPromoController(context: context, peerId: peerId, isBot: isBot), for: context.window)
    }, loadDetailedGraph: { [weak contextObject] graph, x in
        return contextObject?.stats.loadDetailedGraph(graph, x: x) ?? .complete()
    }, transaction: { transaction in
        showModal(with: Star_TransactionScreen(context: context, fromPeerId: peerId, peer: stateValue.with { $0.peer }, transaction: transaction.native), for: context.window)
    }, toggleAds: {
        
        let status = stateValue.with { $0.status }
        let peer = stateValue.with { $0.peer }
        let myBoost = stateValue.with { $0.myStatus }
        let restricted = stateValue.with { $0.adsRestricted }
        
        let needLevel = PremiumConfiguration.with(appConfiguration: context.appConfiguration).minChannelRestrictAdsLevel
        
        if let status, let myBoost, let peer {
            if status.level >= needLevel {
                _ = context.engine.peers.updateChannelRestrictAdMessages(peerId: peerId, restricted: !restricted).startStandalone()
            } else {
                showModal(with: BoostChannelModalController(context: context, peer: peer._asPeer(), boosts: status, myStatus: myBoost, infoOnly: true, source: .noAds(needLevel)), for: context.window)
            }
        }
    }, loadMore: { [weak contextObject] mode in
        switch mode {
        case .ton:
            contextObject?.transactions.loadMore()
        case .xtr:
            contextObject?.starsTransactions?.loadMore()
        }
    }, toggleTransactionType: { mode in
        updateState { current in
            var current = current
            current.transactionMode = mode
            return current
        }
    }, openStarsTransaction: { transaction in
        showModal(with: Star_TransactionScreen(context: context, fromPeerId: peerId, peer: transaction.peer, transaction: transaction.native), for: context.window)
    }, withdrawStars: {
        let defaultState = stateValue.with { $0.starsState ?? .init(config_withdraw: false) }
        showModal(with: withdrawStarBalance(context: context, state: defaultState, stateValue: statePromise.get() |> map { $0.starsState ?? defaultState }, updateState: { f in
            updateState { current in
                var current = current
                current.starsState = f(current.starsState ?? defaultState)
                return current
            }
        }, callback: processWithdraw), for: context.window)
    }, openAffiliate: {
        context.bindings.rootNavigation().push(Affiliate_PeerController(context: context, peerId: peerId))
    })
    
    let signal = statePromise.get() |> deliverOnMainQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments, detailedDisposable: detailedDisposable))
    }
    
    let controller = InputDataController(dataSignal: signal, title: onlyTonContext == nil ?  strings().statsMonetization : strings().statsTon, hasDone: false)
    
    controller.contextObject = contextObject
    
    
//    controller.didLoad = { [weak contextObject] controller, _ in
//        controller.tableView.setScrollHandler({ position in
//            switch position.direction {
//            case .bottom:
//                contextObject?.transactions.loadMore()
//            default:
//                break
//            }
//        })
//    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}






private final class WithdrawHeaderItem : GeneralRowItem {
    fileprivate let titleLayout: TextViewLayout
    fileprivate let balance: TextViewLayout
    fileprivate let arguments: WithdrawArguments
    init(_ initialSize: NSSize, stableId: AnyHashable, balance: StarsAmount, arguments: WithdrawArguments) {
        self.arguments = arguments
        self.titleLayout = .init(.initialize(string: strings().fragmentStarWithdraw, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        let attr = NSMutableAttributedString()
        attr.append(string: strings().starPurchaseBalance("\(clown)\(balance.stringValue)"), color: theme.colors.text, font: .normal(.text))
        attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file), for: clown)
        
        self.balance = .init(attr)
        self.balance.measure(width: .greatestFiniteMagnitude)
        
        self.titleLayout.measure(width: initialSize.width - self.balance.layoutSize.width - 40)
        
        super.init(initialSize, height: 50, stableId: stableId)
    }
    
    override func viewClass() -> AnyClass {
        return WithdrawHeaderView.self
    }
}

private final class WithdrawHeaderView : GeneralRowView {
    private let title = InteractiveTextView()
    private let balance = InteractiveTextView()
    private let dismiss = ImageButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(title)
        addSubview(balance)
        addSubview(dismiss)
        
        dismiss.set(handler: { [weak self] _ in
            if let item = self?.item as? WithdrawHeaderItem {
                item.arguments.close()
            }
        }, for: .Click)
    }
    
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? WithdrawHeaderItem else {
            return
        }
        
        dismiss.set(image: theme.icons.modalClose, for: .Normal)
        dismiss.autohighlight = false
        dismiss.scaleOnClick = true
        dismiss.sizeToFit()
        
        
        
        title.set(text: item.titleLayout, context: item.arguments.context)
        balance.set(text: item.balance, context: item.arguments.context)
        
        needsLayout = true

    }
    
    override func layout() {
        super.layout()
        
        title.center()
        balance.centerY(x: frame.width - balance.frame.width - 20)
        dismiss.centerY(x: 20)
    }
}

private final class WithdrawInputItem : GeneralRowItem {
    let inputState: Updated_ChatTextInputState
    let arguments: WithdrawArguments
    let interactions: TextView_Interactions
    let balance: StarsAmount
    init(_ initialSize: NSSize, stableId: AnyHashable, balance: StarsAmount, inputState: Updated_ChatTextInputState, arguments: WithdrawArguments) {
        self.inputState = inputState
        self.arguments = arguments
        self.balance = balance
        self.interactions = arguments.interactions
        super.init(initialSize, stableId: stableId)
    }
    
    override var height: CGFloat {
        return 40 + 20 + 40
    }
    
    override func viewClass() -> AnyClass {
        return WithdrawInputView.self
    }
}


private final class WithdrawInputView : GeneralRowView {
    
    
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
        
        func update(_ item: WithdrawInputItem, animated: Bool) {
            let attr = NSMutableAttributedString()
            
            attr.append(string: strings().fragmentStarWithdrawInput("\(clown)\(item.inputState.inputText.string)") , color: theme.colors.underSelectedColor, font: .medium(.text))
            attr.insertEmbedded(.embedded(name: XTR_ICON, color: theme.colors.underSelectedColor, resize: false), for: clown)
            
            let layout = TextViewLayout(attr)
            layout.measure(width: item.width - 60)
            
            textView.set(text: layout, context: item.arguments.context)
            
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
    
    private final class LimitView : Control {
        private let iconView = InteractiveTextView()
        private let textView = InteractiveTextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(iconView)
            addSubview(textView)
            layer?.cornerRadius = 10
            scaleOnClick = true
            self.set(background: theme.colors.background, for: .Normal)
            
            textView.userInteractionEnabled = false
            iconView.userInteractionEnabled = false

        }
        
        func update(_ item: WithdrawInputItem, animated: Bool) {
            let attr = NSMutableAttributedString()
                        
            let min_withdraw = item.arguments.context.appConfiguration.getGeneralValue("stars_revenue_withdrawal_min", orElse: 1000)
            
            attr.append(string: strings().fragmentStarsMinWithdraw(Int(min_withdraw)), color: theme.colors.text, font: .medium(.text))
            let layout = TextViewLayout(attr)
            layout.measure(width: frame.width - 70)
            
            textView.set(text: layout, context: item.arguments.context)

            
            let iconAttr = NSMutableAttributedString()
            iconAttr.append(string: clown, color: theme.colors.text, font: .medium(.text))
            iconAttr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file), for: clown)
            
            let iconLayout = TextViewLayout(iconAttr)
            iconLayout.measure(width: frame.width - 70)

            iconView.set(text: iconLayout, context: item.arguments.context)

            
            needsLayout = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layout() {
            super.layout()
            iconView.centerY(x: 10)
            textView.centerY(x: iconView.frame.maxX + 10)
        }
    }
    
    private final class WithdrawInput : View {
        
        private weak var item: WithdrawInputItem?
        let inputView: UITextView = UITextView(frame: NSMakeRect(0, 0, 100, 40))
        private let starView = InteractiveTextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(starView)
            addSubview(inputView)
                        

            layer?.cornerRadius = 10
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(item: WithdrawInputItem, animated: Bool) {
            self.item = item
            self.backgroundColor = theme.colors.background
            
            let attr = NSMutableAttributedString()
            attr.append(string: clown)
            attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file), for: clown)
            
            let layout = TextViewLayout(attr)
            layout.measure(width: .greatestFiniteMagnitude)
            
            self.starView.set(text: layout, context: item.arguments.context)

            
            inputView.placeholder = strings().fragmentStarAmountPlaceholder
            
            inputView.context = item.arguments.context
            inputView.interactions.max_height = 500
            inputView.interactions.min_height = 13
            inputView.interactions.emojiPlayPolicy = .onceEnd
            inputView.interactions.canTransform = false
            
            item.interactions.min_height = 13
            item.interactions.max_height = 500
            item.interactions.emojiPlayPolicy = .onceEnd
            item.interactions.canTransform = false
            
            let value = Int64(item.inputState.string) ?? 0
            
            let min_withdraw = item.arguments.context.appConfiguration.getGeneralValue("stars_revenue_withdrawal_min", orElse: 1000)

            
            inputView.inputTheme = inputView.inputTheme.withUpdatedTextColor(value < min_withdraw ? theme.colors.redUI : theme.colors.text)
            
            
            item.interactions.filterEvent = { event in
                if let chars = event.characters {
                    return chars.trimmingCharacters(in: CharacterSet(charactersIn: "1234567890\u{7f}")).isEmpty
                } else {
                    return false
                }
            }

            self.inputView.set(item.interactions.presentation.textInputState())

            self.inputView.interactions = item.interactions
            
            item.interactions.inputDidUpdate = { [weak self] state in
                guard let `self` = self else {
                    return
                }
                self.set(state)
                self.inputDidUpdateLayout(animated: true)
            }
            
        }
        
        
        var textWidth: CGFloat {
            return frame.width - 20
        }
        
        func textViewSize() -> (NSSize, CGFloat) {
            let w = textWidth
            let height = inputView.height(for: w)
            return (NSMakeSize(w, min(max(height, inputView.min_height), inputView.max_height)), height)
        }
        
        private func inputDidUpdateLayout(animated: Bool) {
            self.updateLayout(size: frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
        }
        
        func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
            let (textSize, textHeight) = textViewSize()
            
            transition.updateFrame(view: starView, frame: starView.centerFrameY(x: 10))
            
            transition.updateFrame(view: inputView, frame: CGRect(origin: CGPoint(x: starView.frame.maxX + 10, y: 7), size: textSize))
            inputView.updateLayout(size: textSize, textHeight: textHeight, transition: transition)
        }
        
        private func set(_ state: Updated_ChatTextInputState) {
            guard let item else {
                return
            }
            item.arguments.updateState(state)
            
            item.redraw(animated: true)
        }
    }
    
    private let inputView = WithdrawInput(frame: NSMakeRect(0, 0, 40, 40))
    private var acceptView: AcceptView?
    private var limitView : LimitView?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(inputView)
    }
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? WithdrawInputItem else {
            return
        }
        
        self.inputView.update(item: item, animated: animated)
        
        let min_withdraw = item.arguments.context.appConfiguration.getGeneralValue("stars_revenue_withdrawal_min", orElse: 1000)

        let value = Int64(item.inputState.string) ?? 0
        if value < min_withdraw {
            if let acceptView {
                performSubviewRemoval(acceptView, animated: animated)
                self.acceptView = nil
            }
            
            let current: LimitView
            if let view = self.limitView {
                current = view
            } else {
                current = LimitView(frame: NSMakeRect(20, inputView.frame.maxY + 20, frame.width - 40, 40))
                self.limitView = current
                addSubview(current)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            current.update(item, animated: animated)
        } else {
            if let limitView {
                performSubviewRemoval(limitView, animated: animated)
                self.limitView = nil
            }
            let current: AcceptView
            if let view = self.acceptView {
                current = view
            } else {
                current = AcceptView(frame: NSMakeRect(20, inputView.frame.maxY + 20, frame.width - 40, 40))
                self.acceptView = current
                addSubview(current)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                
                current.set(handler: { [weak self] _ in
                    if let item = self?.item as? WithdrawInputItem {
                        item.arguments.withdraw()
                    }
                }, for: .Click)
            }
            current.update(item, animated: animated)
        }
        
        
        self.inputView.updateLayout(size: self.frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
    }
    
    override func shakeView() {
        inputView.shake(beep: true)
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        transition.updateFrame(view: inputView, frame: NSMakeRect(20, 0, size.width - 40,40))
        inputView.updateLayout(size: inputView.frame.size, transition: transition)
        
        if let acceptView {
            transition.updateFrame(view: acceptView, frame: NSMakeRect(20, inputView.frame.maxY + 20, frame.width - 40, 40))
        }
        if let limitView {
            transition.updateFrame(view: limitView, frame: NSMakeRect(20, inputView.frame.maxY + 20, frame.width - 40, 40))
        }
    }
    override var firstResponder: NSResponder? {
        return inputView.inputView.inputView
    }
}


private final class WithdrawArguments {
    let context: AccountContext
    let interactions: TextView_Interactions
    let updateState: (Updated_ChatTextInputState)->Void
    let withdraw:()->Void
    let close:()->Void
    init(context: AccountContext, interactions: TextView_Interactions, updateState: @escaping(Updated_ChatTextInputState)->Void, withdraw:@escaping()->Void, close:@escaping()->Void) {
        self.context = context
        self.interactions = interactions
        self.updateState = updateState
        self.withdraw = withdraw
        self.close = close
    }
}


private let _id_input = InputDataIdentifier("_id_input")

private func withdrawEntries(_ state: StarsState, arguments: WithdrawArguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return WithdrawHeaderItem(initialSize, stableId: stableId, balance: state.balance.stars, arguments: arguments)
    }))
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().fragmentStarWithdrawPlaceholder), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_input, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return WithdrawInputItem(initialSize, stableId: stableId, balance: state.balance.stars, inputState: state.inputState, arguments: arguments)
    }))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    return entries
}

private func withdrawStarBalance(context: AccountContext, state: StarsState, stateValue: Signal<StarsState, NoError>, updateState:@escaping((StarsState)->StarsState)->Void, callback:@escaping(Int64)->Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    
    var close:(()->Void)? = nil
    var getController:(()->InputDataController?)? = nil
    
    let initialState: Updated_ChatTextInputState = .init(inputText: .initialize(string: "\(state.balance.stars)"))
    
    let interactions = TextView_Interactions(presentation: initialState)
    
    updateState { current in
        var current = current
        current.inputState = initialState
        return current
    }
        
    let arguments = WithdrawArguments(context: context, interactions: interactions, updateState: { [weak interactions] value in
        
        let number = Int64(value.string) ?? 0
        
        var value = value
        if number > state.balance.stars.value {
            let string = state.balance.stars.stringValue
            value = .init(inputText: .initialize(string: string), selectionRange: string.length..<string.length)
            getController?()?.proccessValidation(.fail(.fields([_id_input : .shake])))
        }
        
        interactions?.update { _ in
            return value
        }
        updateState { current in
            var current = current
            current.inputState = value
            return current
        }
    }, withdraw: {
        _ = getController?()?.returnKeyAction()
    }, close: {
        close?()
    })
    
    let signal = stateValue |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: withdrawEntries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "")
    
    controller.validateData = { _ in
        if let value = Int64(interactions.presentation.string) {
            callback(value)
        }
        close?()
        return .none
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    
    let modalController = InputDataModalController(controller)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.close()
    }
    getController = { [weak controller] in
        return controller
    }
    
    
    return modalController
}

