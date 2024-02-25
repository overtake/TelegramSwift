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

import GraphCore

private func statsEntries(_ state: GroupStatsContextState, uiState: UIStatsState, peers: [PeerId : Peer]?, updateIsLoading: @escaping(InputDataIdentifier, Bool)->Void, revealSection: @escaping(UIStatsState.RevealSection)->Void, context: GroupStatsContext, accountContext: AccountContext, openPeerInfo: @escaping(PeerId)->Void, detailedDisposable: DisposableDict<InputDataIdentifier>) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    
    if state.stats == nil {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("loading"), equatable: nil, comparable: nil, item: { initialSize, stableId in
            return StatisticsLoadingRowItem(initialSize, stableId: stableId, context: accountContext, text: strings().channelStatsLoading)
        }))
    } else if let stats = state.stats  {
        
        let dates = "\(dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(stats.period.minDate)))) – \(dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(stats.period.maxDate))))"

        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().statsGroupOverview), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem, rightItem: InputDataGeneralTextRightData(isLoading: false, text: .initialize(string: dates, color: theme.colors.listGrayText, font: .normal(12))))))
        index += 1
        
        var overviewItems:[ChannelOverviewItem] = []
        
        if stats.members.current > 0 {
            overviewItems.append(ChannelOverviewItem(title: strings().statsGroupMembers, value: stats.members.attributedString))
        }
        if stats.messages.current != 0 {
            overviewItems.append(ChannelOverviewItem(title: strings().statsGroupMessages, value: stats.messages.attributedString))
        }
        if stats.viewers.current > 0 {
            overviewItems.append(ChannelOverviewItem(title: strings().statsGroupViewers, value: stats.viewers.attributedString))
        }
        if stats.posters.current > 0 {
            overviewItems.append(ChannelOverviewItem(title: strings().statsGroupPosters, value: stats.posters.attributedString))
        }
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("overview"), equatable: InputDataEquatable(overviewItems), comparable: nil, item: { initialSize, stableId in
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
            graphs.append(Graph(graph: stats.growthGraph, title: strings().statsGroupGrowthTitle, identifier: InputDataIdentifier("growthGraph"), type: .lines, load: { identifier in
                context.loadGrowthGraph()
                updateIsLoading(identifier, true)
            }))
        }
        
        if !stats.membersGraph.isEmpty {
            graphs.append(Graph(graph: stats.membersGraph, title: strings().statsGroupMembersTitle, identifier: InputDataIdentifier("membersGraph"), type: .lines, load: { identifier in
                context.loadMembersGraph()
                updateIsLoading(identifier, true)
            }))
        }
        
        if !stats.newMembersBySourceGraph.isEmpty {
            graphs.append(Graph(graph: stats.newMembersBySourceGraph, title: strings().statsGroupNewMembersBySourceTitle, identifier: InputDataIdentifier("newMembersBySourceGraph"), type: .bars, load: { identifier in
                context.loadNewMembersBySourceGraph()
                updateIsLoading(identifier, true)
            }))
        }
        
        if !stats.languagesGraph.isEmpty {
            graphs.append(Graph(graph: stats.languagesGraph, title: strings().statsGroupLanguagesTitle, identifier: InputDataIdentifier("languagesGraph"), type: .pie, load: { identifier in
                context.loadLanguagesGraph()
                updateIsLoading(identifier, true)
            }))
        }
        
        if !stats.messagesGraph.isEmpty {
            graphs.append(Graph(graph: stats.messagesGraph, title: strings().statsGroupMessagesTitle, identifier: InputDataIdentifier("messagesGraph"), type: .bars, load: { identifier in
                context.loadMessagesGraph()
                updateIsLoading(identifier, true)
            }))
        }
        
        if !stats.actionsGraph.isEmpty {
            graphs.append(Graph(graph: stats.actionsGraph, title: strings().statsGroupActionsTitle, identifier: InputDataIdentifier("actionsGraph"), type: .lines, load: { identifier in
                context.loadActionsGraph()
                updateIsLoading(identifier, true)
            }))
        }
       
        
        if !stats.topHoursGraph.isEmpty {
            graphs.append(Graph(graph: stats.topHoursGraph, title: strings().statsGroupTopHoursTitle, identifier: InputDataIdentifier("topHoursGraph"), type: .hourlyStep, load: { identifier in
                context.loadTopHoursGraph()
                updateIsLoading(identifier, true)
            }))
        }
      
        if !stats.topWeekdaysGraph.isEmpty {
            graphs.append(Graph(graph: stats.topWeekdaysGraph, title: strings().statsGroupTopWeekdaysTitle, identifier: InputDataIdentifier("topWeekdaysGraph"), type: .area, load: { identifier in
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
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), comparable: nil, item: { initialSize, stableId in
                        return StatisticRowItem(initialSize, stableId: stableId, context: accountContext, collection: collection, viewType: .singleItem, type: graph.type, getDetailsData: { date, completion in
                            detailedDisposable.set(context.loadDetailedGraph(graph.graph, x: Int64(date.timeIntervalSince1970) * 1000).start(next: { graph in
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
                
                updateIsLoading(graph.identifier, false)
                
                index += 1
            case .OnDemand:
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), comparable: nil, item: { initialSize, stableId in
                    return StatisticLoadingRowItem(initialSize, stableId: stableId, error: nil)
                }))
                index += 1
                if !uiState.loading.contains(graph.identifier) {
                    graph.load(graph.identifier)
                }
            case let .Failed(error):
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), comparable: nil, item: { initialSize, stableId in
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
        
        
        
        if let peers = peers {
            var topPosters = stats.topPosters.filter { $0.messageCount > 0 && peers[$0.peerId] != nil && !peers[$0.peerId]!.rawDisplayTitle.isEmpty }
            if !topPosters.isEmpty {
                entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().statsGroupTopPostersTitle), data: .init(color: theme.colors.listGrayText, detectBold: false, viewType: .textTopItem, rightItem: InputDataGeneralTextRightData(isLoading: false, text: .initialize(string: dates, color: theme.colors.listGrayText, font: .normal(12))))))
                index += 1
                
                let needReveal = !uiState.revealed.contains(.topPosters) && topPosters.count > 10
                let toRevealCount = topPosters.count - 10
                if needReveal {
                    topPosters = Array(topPosters.prefix(10))
                }
                
                for (i, topPoster) in topPosters.enumerated() {
                    if let peer = peers[topPoster.peerId], topPoster.messageCount > 0 {
                        var textComponents: [String] = []
                        if topPoster.messageCount > 0 {
                            textComponents.append(strings().statsGroupTopPosterMessagesCountable(Int(topPoster.messageCount)))
                            if topPoster.averageChars > 0 {
                                textComponents.append(strings().statsGroupTopPosterCharsCountable(Int(topPoster.averageChars)))
                            }
                        }
                        
                        var viewType = bestGeneralViewType(topPosters, for: i)
                        
                        if topPoster == topPosters.last, needReveal {
                            viewType = .innerItem
                        }
                        
                        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("top_posters_\(peer.id)"), equatable: nil, comparable: nil, item: { initialSize, stableId in
                            return ShortPeerRowItem(initialSize, peer: peer, account: accountContext.account, context: accountContext, stableId: stableId, enabled: true, height: 56, photoSize: NSMakeSize(36, 36), status: textComponents.joined(separator: ", "), inset: NSEdgeInsets(left: 20, right: 20), viewType: viewType, action: {
                                openPeerInfo(peer.id)
                            })
                        }))
                        index += 1
                    }
                }
                
                if needReveal {
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: UIStatsState.RevealSection.topPosters.id, equatable: nil, comparable: nil, item: { initialSize, stableId in
                        return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().statsShowMoreCountable(toRevealCount), nameStyle: blueActionButton, type: .none, viewType: .lastItem, action: {
                            
                            revealSection(UIStatsState.RevealSection.topPosters)
                            
                        }, thumb: GeneralThumbAdditional(thumb: theme.icons.chatSearchUp, textInset: 52, thumbInset: 4))
                    }))
                    index += 1
                }
                
                addNextSection = true
            }
            
            var topAdmins = stats.topAdmins.filter {
                return peers[$0.peerId] != nil && ($0.deletedCount + $0.kickedCount + $0.bannedCount) > 0 && !peers[$0.peerId]!.rawDisplayTitle.isEmpty
            }
            
            if !topAdmins.isEmpty {
                if addNextSection {
                    entries.append(.sectionId(sectionId, type: .normal))
                    sectionId += 1
                }
                entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().statsGroupTopAdminsTitle), data: .init(color: theme.colors.listGrayText, detectBold: false, viewType: .textTopItem, rightItem: InputDataGeneralTextRightData(isLoading: false, text: .initialize(string: dates, color: theme.colors.listGrayText, font: .normal(12))))))
                index += 1
                
                let needReveal = !uiState.revealed.contains(.topAdmins) && topAdmins.count > 10
                let toRevealCount = topAdmins.count - 10
                if needReveal {
                    topAdmins = Array(topAdmins.prefix(10))
                }
                
                for (i, topAdmin) in topAdmins.enumerated() {
                    if let peer = peers[topAdmin.peerId] {
                        
                        var textComponents: [String] = []
                        if topAdmin.deletedCount > 0 {
                            textComponents.append(strings().statsGroupTopAdminDeletionsCountable(Int(topAdmin.deletedCount)))
                        }
                        if topAdmin.kickedCount > 0 {
                            textComponents.append(strings().statsGroupTopAdminKicksCountable(Int(topAdmin.kickedCount)))
                        }
                        if topAdmin.bannedCount > 0 {
                            textComponents.append(strings().statsGroupTopAdminBansCountable(Int(topAdmin.bannedCount)))
                        }
                        
                        var viewType = bestGeneralViewType(topAdmins, for: i)
                        
                        if topAdmin == topAdmins.last, needReveal {
                            viewType = .innerItem
                        }
                        
                        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier.init("top_admin_\(peer.id)"), equatable: nil, comparable: nil, item: { initialSize, stableId in
                            return ShortPeerRowItem(initialSize, peer: peer, account: accountContext.account, context: accountContext, stableId: stableId, enabled: true, height: 56, photoSize: NSMakeSize(36, 36), status: textComponents.joined(separator: ", "), inset: NSEdgeInsets(left: 20, right: 20), viewType: viewType, action: {
                                openPeerInfo(peer.id)
                            })
                        }))
                        index += 1
                    }
                }
                
                
                if needReveal {
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: UIStatsState.RevealSection.topAdmins.id, equatable: nil, comparable: nil, item: { initialSize, stableId in
                        return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().statsShowMoreCountable(toRevealCount), nameStyle: blueActionButton, type: .none, viewType: .lastItem, action: {
                            
                            revealSection(UIStatsState.RevealSection.topAdmins)
                            
                        }, thumb: GeneralThumbAdditional(thumb: theme.icons.chatSearchUp, textInset: 52, thumbInset: 4))
                    }))
                    index += 1
                }
                
                
            } else {
                entries.append(.sectionId(sectionId, type: .normal))
                sectionId += 1
                addNextSection = false
            }
            
            
            var topInviters = stats.topInviters.filter {
                return peers[$0.peerId] != nil && $0.inviteCount > 0 && !peers[$0.peerId]!.rawDisplayTitle.isEmpty
            }
            
            if !topInviters.isEmpty {
                if addNextSection {
                    entries.append(.sectionId(sectionId, type: .normal))
                    sectionId += 1
                }
                
                entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().statsGroupTopInvitersTitle), data: .init(color: theme.colors.listGrayText, detectBold: false, viewType: .textTopItem, rightItem: InputDataGeneralTextRightData(isLoading: false, text: .initialize(string: dates, color: theme.colors.listGrayText, font: .normal(12))))))
                index += 1
                
                
                let needReveal = !uiState.revealed.contains(.topInviters) && topInviters.count > 10
                let toRevealCount = topInviters.count - 10
                if needReveal {
                    topInviters = Array(topInviters.prefix(10))
                }
                
                
                for (i, topInviter) in topInviters.enumerated() {
                    if let peer = peers[topInviter.peerId] {
                        
                        var textComponents: [String] = []
                        textComponents.append(strings().statsGroupTopInviterInvitesCountable(Int(topInviter.inviteCount)))
                        
                        var viewType = bestGeneralViewType(topPosters, for: i)
                        
                        if topInviter == topInviters.last, needReveal {
                            viewType = .innerItem
                        }
                        
                        
                        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("top_inviter_\(peer.id)"), equatable: nil, comparable: nil, item: { initialSize, stableId in
                            return ShortPeerRowItem(initialSize, peer: peer, account: accountContext.account, context: accountContext, stableId: stableId, enabled: true, height: 56, photoSize: NSMakeSize(36, 36), status: textComponents.joined(separator: ", "), inset: NSEdgeInsets(left: 20, right: 20), viewType: viewType, action: {
                                openPeerInfo(peer.id)
                            })
                        }))
                        index += 1
                    }
                }
                
                if needReveal {
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: UIStatsState.RevealSection.topInviters.id, equatable: nil, comparable: nil, item: { initialSize, stableId in
                        return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().statsShowMoreCountable(toRevealCount), nameStyle: blueActionButton, type: .none, viewType: .lastItem, action: {
                            
                            revealSection(UIStatsState.RevealSection.topInviters)
                            
                        }, thumb: GeneralThumbAdditional(thumb: theme.icons.chatSearchUp, textInset: 52, thumbInset: 4))
                    }))
                    index += 1
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


func GroupStatsViewController(_ context: AccountContext, peerId: PeerId) -> ViewController {
    
    let initialState = UIStatsState(loading: [])
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((UIStatsState) -> UIStatsState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let openPeerInfo:(PeerId)->Void = { peerId in
        PeerInfoController.push(navigation: context.bindings.rootNavigation(), context: context, peerId: peerId)
    }
    
    let statsContext = GroupStatsContext(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.peerId, peerId: peerId)

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
        }, revealSection: { section in
            updateState {
                $0.withRevealedSection(section)
            }
        }, context: statsContext, accountContext: context, openPeerInfo: openPeerInfo, detailedDisposable: detailedDisposable)
    } |> map {
        return InputDataSignalValue(entries: $0)
    }
    
    
    let controller = InputDataController(dataSignal: signal, title: strings().groupStatsTitle, removeAfterDisappear: false, hasDone: false)
    
    controller.contextObject = statsContext
    controller.didLoad = { controller, _ in
        controller.tableView.alwaysOpenRowsOnMouseUp = true
        controller.tableView.needUpdateVisibleAfterScroll = true
    }
    
    controller.onDeinit = {
        detailedDisposable.dispose()
    }
    
    return controller
}
