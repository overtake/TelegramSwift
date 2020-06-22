//
//  GroupsStatsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19/06/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import SyncCore
import GraphCore

private func statsEntries(_ state: GroupStatsContextState, uiState: UIStatsState, peers: [PeerId : Peer]?, updateIsLoading: @escaping(InputDataIdentifier, Bool)->Void, context: GroupStatsContext, accountContext: AccountContext, openPeerInfo: @escaping(PeerId)->Void, detailedDisposable: DisposableDict<InputDataIdentifier>) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    
    if state.stats == nil {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("loading"), equatable: nil, item: { initialSize, stableId in
            return StatisticsLoadingRowItem(initialSize, stableId: stableId, context: accountContext, text: L10n.channelStatsLoading)
        }))
    } else if let stats = state.stats  {
        
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.statsGroupOverview), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        var overviewItems:[ChannelOverviewItem] = []
        
        if stats.members.current > 0 {
            overviewItems.append(ChannelOverviewItem(title: L10n.statsGroupMembers, value: stats.members.attributedString))
        }
        if stats.messages.current != 0 {
            overviewItems.append(ChannelOverviewItem(title: L10n.statsGroupMessages, value: stats.messages.attributedString))
        }
        if stats.viewers.current > 0 {
            overviewItems.append(ChannelOverviewItem(title: L10n.statsGroupViewers, value: stats.viewers.attributedString))
        }
        if stats.posters.current > 0 {
            overviewItems.append(ChannelOverviewItem(title: L10n.statsGroupPosters, value: stats.posters.attributedString))
        }
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("overview"), equatable: InputDataEquatable(overviewItems), item: { initialSize, stableId in
            return ChannelOverviewStatsRowItem(initialSize, stableId: stableId, items: overviewItems, viewType: .singleItem)
        }))
        index += 1
        
        
        struct Graph {
            let graph: StatsGraph
            let title: String
            let identifier: InputDataIdentifier
            let type: ChartItemType
            let load:(InputDataIdentifier)->Void
        }
        
        var graphs: [Graph] = []
        
        if !stats.growthGraph.isEmpty {
            graphs.append(Graph(graph: stats.growthGraph, title: L10n.statsGroupGrowthTitle, identifier: InputDataIdentifier("growthGraph"), type: .lines, load: { identifier in
                context.loadGrowthGraph()
                updateIsLoading(identifier, true)
            }))
        }
        
        if !stats.membersGraph.isEmpty {
            graphs.append(Graph(graph: stats.membersGraph, title: L10n.statsGroupMembersTitle, identifier: InputDataIdentifier("membersGraph"), type: .lines, load: { identifier in
                context.loadMembersGraph()
                updateIsLoading(identifier, true)
            }))
        }
        
        if !stats.newMembersBySourceGraph.isEmpty {
            graphs.append(Graph(graph: stats.newMembersBySourceGraph, title: L10n.statsGroupNewMembersBySourceTitle, identifier: InputDataIdentifier("newMembersBySourceGraph"), type: .bars, load: { identifier in
                context.loadNewMembersBySourceGraph()
                updateIsLoading(identifier, true)
            }))
        }
        
        if !stats.languagesGraph.isEmpty {
            graphs.append(Graph(graph: stats.languagesGraph, title: L10n.statsGroupLanguagesTitle, identifier: InputDataIdentifier("languagesGraph"), type: .pie, load: { identifier in
                context.loadLanguagesGraph()
                updateIsLoading(identifier, true)
            }))
        }
        
        if !stats.messagesGraph.isEmpty {
            graphs.append(Graph(graph: stats.messagesGraph, title: L10n.statsGroupMessagesTitle, identifier: InputDataIdentifier("messagesGraph"), type: .bars, load: { identifier in
                context.loadMessagesGraph()
                updateIsLoading(identifier, true)
            }))
        }
        
        if !stats.actionsGraph.isEmpty {
            graphs.append(Graph(graph: stats.actionsGraph, title: L10n.statsGroupActionsTitle, identifier: InputDataIdentifier("actionsGraph"), type: .lines, load: { identifier in
                context.loadActionsGraph()
                updateIsLoading(identifier, true)
            }))
        }
       
        
        if !stats.topHoursGraph.isEmpty {
            graphs.append(Graph(graph: stats.topHoursGraph, title: L10n.statsGroupTopHoursTitle, identifier: InputDataIdentifier("topHoursGraph"), type: .hourlyStep, load: { identifier in
                context.loadTopHoursGraph()
                updateIsLoading(identifier, true)
            }))
        }
      
        if !stats.topWeekdaysGraph.isEmpty {
            graphs.append(Graph(graph: stats.topWeekdaysGraph, title: L10n.statsGroupTopWeekdaysTitle, identifier: InputDataIdentifier("topWeekdaysGraph"), type: .area, load: { identifier in
                context.loadTopWeekdaysGraph()
                updateIsLoading(identifier, true)
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
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), item: { initialSize, stableId in
                        return StatisticRowItem(initialSize, stableId: stableId, context: accountContext, collection: collection, viewType: .singleItem, type: graph.type, getDetailsData: { date, completion in
                            detailedDisposable.set(context.loadDetailedGraph(graph.graph, x: Int64(date.timeIntervalSince1970) * 1000).start(next: { graph in
                                if let graph = graph, case let .Loaded(_, data) = graph {
                                    completion(data)
                                }
                            }), forKey: graph.identifier)
                        })
                    }))
                }, failure: { error in
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), item: { initialSize, stableId in
                        return StatisticLoadingRowItem(initialSize, stableId: stableId, error: error.localizedDescription)
                    }))
                })
                
                updateIsLoading(graph.identifier, false)
                
                index += 1
            case .OnDemand:
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), item: { initialSize, stableId in
                    return StatisticLoadingRowItem(initialSize, stableId: stableId, error: nil)
                }))
                index += 1
                if !uiState.loading.contains(graph.identifier) {
                    graph.load(graph.identifier)
                }
            case let .Failed(error):
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), item: { initialSize, stableId in
                    return StatisticLoadingRowItem(initialSize, stableId: stableId, error: error)
                }))
                index += 1
                updateIsLoading(graph.identifier, false)
            case .Empty:
                break
            }
        }
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        var addNextSection: Bool = false
        
        
        let dates = "\(dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(stats.period.minDate)))) – \(dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(stats.period.maxDate))))"
        
        if let peers = peers {
            let topPosters = stats.topPosters.filter { $0.messageCount > 0 && peers[$0.peerId] != nil && !peers[$0.peerId]!.rawDisplayTitle.isEmpty }
            if !topPosters.isEmpty {
                entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.statsGroupTopPostersTitle), data: .init(color: theme.colors.listGrayText, detectBold: false, viewType: .textTopItem, rightItem: InputDataGeneralTextRightData(isLoading: false, text: .initialize(string: dates, color: theme.colors.listGrayText, font: .normal(12))))))
                index += 1
                for (i, topPoster) in topPosters.enumerated() {
                    if let peer = peers[topPoster.peerId], topPoster.messageCount > 0 {
                        var textComponents: [String] = []
                        if topPoster.messageCount > 0 {
                            textComponents.append(L10n.statsGroupTopPosterMessagesCountable(Int(topPoster.messageCount)))
                            if topPoster.averageChars > 0 {
                                textComponents.append(L10n.statsGroupTopPosterCharsCountable(Int(topPoster.averageChars)))
                            }
                        }
                        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier.init("top_posters_\(peer.id)"), equatable: nil, item: { initialSize, stableId in
                            return ShortPeerRowItem(initialSize, peer: peer, account: accountContext.account, stableId: stableId, enabled: true, height: 56, photoSize: NSMakeSize(36, 36), status: textComponents.joined(separator: ", "), inset: NSEdgeInsets(left: 30, right: 30), viewType: bestGeneralViewType(topPosters, for: i), action: {
                                openPeerInfo(peer.id)
                            })
                        }))
                        index += 1
                    }
                }
                addNextSection = true
            }
            
            let topAdmins = stats.topAdmins.filter {
                return peers[$0.peerId] != nil && ($0.deletedCount + $0.kickedCount + $0.bannedCount) > 0 && !peers[$0.peerId]!.rawDisplayTitle.isEmpty
            }
            
            if !topAdmins.isEmpty {
                if addNextSection {
                    entries.append(.sectionId(sectionId, type: .normal))
                    sectionId += 1
                }
                entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.statsGroupTopAdminsTitle), data: .init(color: theme.colors.listGrayText, detectBold: false, viewType: .textTopItem, rightItem: InputDataGeneralTextRightData(isLoading: false, text: .initialize(string: dates, color: theme.colors.listGrayText, font: .normal(12))))))
                index += 1
                
                for (i, topAdmin) in topAdmins.enumerated() {
                    if let peer = peers[topAdmin.peerId] {
                        
                        var textComponents: [String] = []
                        if topAdmin.deletedCount > 0 {
                            textComponents.append(L10n.statsGroupTopAdminDeletionsCountable(Int(topAdmin.deletedCount)))
                        }
                        if topAdmin.kickedCount > 0 {
                            textComponents.append(L10n.statsGroupTopAdminKicksCountable(Int(topAdmin.kickedCount)))
                        }
                        if topAdmin.bannedCount > 0 {
                            textComponents.append(L10n.statsGroupTopAdminBansCountable(Int(topAdmin.bannedCount)))
                        }
                        
                        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier.init("top_admin_\(peer.id)"), equatable: nil, item: { initialSize, stableId in
                            return ShortPeerRowItem(initialSize, peer: peer, account: accountContext.account, stableId: stableId, enabled: true, height: 56, photoSize: NSMakeSize(36, 36), status: textComponents.joined(separator: ", "), inset: NSEdgeInsets(left: 30, right: 30), viewType: bestGeneralViewType(topAdmins, for: i), action: {
                                openPeerInfo(peer.id)
                            })
                        }))
                        index += 1
                    }
                }
            } else {
                entries.append(.sectionId(sectionId, type: .normal))
                sectionId += 1
                addNextSection = false
            }
            
            
            let topInviters = stats.topInviters.filter {
                return peers[$0.peerId] != nil && $0.inviteCount > 0 && !peers[$0.peerId]!.rawDisplayTitle.isEmpty
            }
            
            if !topInviters.isEmpty {
                if addNextSection {
                    entries.append(.sectionId(sectionId, type: .normal))
                    sectionId += 1
                }
                
                entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.statsGroupTopInvitersTitle), data: .init(color: theme.colors.listGrayText, detectBold: false, viewType: .textTopItem, rightItem: InputDataGeneralTextRightData(isLoading: false, text: .initialize(string: dates, color: theme.colors.listGrayText, font: .normal(12))))))
                index += 1
                
                for (i, topInviter) in topInviters.enumerated() {
                    if let peer = peers[topInviter.peerId] {
                        
                        var textComponents: [String] = []
                        textComponents.append(L10n.statsGroupTopInviterInvitesCountable(Int(topInviter.inviteCount)))
                        
                        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("top_inviter_\(peer.id)"), equatable: nil, item: { initialSize, stableId in
                            return ShortPeerRowItem(initialSize, peer: peer, account: accountContext.account, stableId: stableId, enabled: true, height: 56, photoSize: NSMakeSize(36, 36), status: textComponents.joined(separator: ", "), inset: NSEdgeInsets(left: 30, right: 30), viewType: bestGeneralViewType(topInviters, for: i), action: {
                                openPeerInfo(peer.id)
                            })
                        }))
                        index += 1
                    }
                }
            } else {
                entries.append(.sectionId(sectionId, type: .normal))
                sectionId += 1
                addNextSection = false
            }
        }
        if addNextSection {
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
        }
    }
    
    
    return entries
}


func GroupStatsViewController(_ context: AccountContext, peerId: PeerId, datacenterId: Int32) -> ViewController {
    
    let initialState = UIStatsState(loading: [])
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((UIStatsState) -> UIStatsState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let openPeerInfo:(PeerId)->Void = { peerId in
        return context.sharedContext.bindings.rootNavigation().push(PeerInfoController(context: context, peerId: peerId))
    }
    
    let statsContext = GroupStatsContext(postbox: context.account.postbox, network: context.account.network, datacenterId: datacenterId, peerId: peerId)

    let peersPromise = Promise<[PeerId: Peer]?>(nil)
    
    peersPromise.set(.single(nil) |> then(statsContext.state |> map(Optional.init)
        |> map { stats -> [PeerId]? in
            guard let stats = stats?.stats else {
                return nil
            }
            var peerIds = Set<PeerId>()
            peerIds.formUnion(stats.topPosters.map { $0.peerId })
            peerIds.formUnion(stats.topAdmins.map { $0.peerId })
            peerIds.formUnion(stats.topInviters.map { $0.peerId })
            return Array(peerIds)
        }
        |> mapToSignal { peerIds -> Signal<[PeerId: Peer]?, NoError> in
            return context.account.postbox.transaction { transaction -> [PeerId: Peer]? in
                var peers: [PeerId: Peer] = [:]
                if let peerIds = peerIds {
                    for peerId in peerIds {
                        if let peer = transaction.getPeer(peerId) {
                            peers[peerId] = peer
                        }
                    }
                }
                return peers
            }
        }))
    
    let detailedDisposable = DisposableDict<InputDataIdentifier>()
    
    let signal = combineLatest(queue: prepareQueue, statePromise.get(), statsContext.state, peersPromise.get()) |> map { uiState, state, peers in
        return statsEntries(state, uiState: uiState, peers: peers, updateIsLoading: { identifier, isLoading in
            updateState { state in
                if isLoading {
                    return state.withAddedLoading(identifier)
                } else {
                    return state.withRemovedLoading(identifier)
                }
            }
        }, context: statsContext, accountContext: context, openPeerInfo: openPeerInfo, detailedDisposable: detailedDisposable)
    } |> map {
        return InputDataSignalValue(entries: $0)
    }
    
    
    let controller = InputDataController(dataSignal: signal, title: L10n.channelStatsTitle, removeAfterDisappear: false, hasDone: false)
    
    controller.contextOject = statsContext
    controller.didLoaded = { controller, _ in
        controller.tableView.alwaysOpenRowsOnMouseUp = true
        controller.tableView.needUpdateVisibleAfterScroll = true
    }
    
    controller.onDeinit = {
        detailedDisposable.dispose()
    }
    
    return controller
}
