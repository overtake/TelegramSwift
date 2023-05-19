//
//  RequestJoinMemberListController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01.10.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private final class Arguments {
    let context: AccountContext
    let add:(PeerId)->Void
    let dismiss:(PeerId)->Void
    let openInfo:(PeerId)->Void
    let openInviteLinks:()->Void
    init(context: AccountContext, add:@escaping(PeerId)->Void, dismiss:@escaping(PeerId)->Void, openInfo:@escaping(PeerId)->Void, openInviteLinks:@escaping()->Void) {
        self.context = context
        self.add = add
        self.dismiss = dismiss
        self.openInfo = openInfo
        self.openInviteLinks = openInviteLinks
    }
}

struct PeerRequestChatJoinData : Equatable {
    let peer: PeerEquatable
    let about: String?
    let timeInterval: TimeInterval
    let added: Bool
    let adding: Bool
    let dismissing: Bool
    let dismissed: Bool
}

private struct State : Equatable {
    
    struct SearchResult : Equatable {
        var isLoading: Bool
        var result: PeerInvitationImportersState?
    }
    
    var peer: PeerEquatable?
    var state:PeerInvitationImportersState?
    var added:Set<PeerId> = Set()
    var dismissed:Set<PeerId> = Set()
    
    var searchState: SearchState?
    
    var empty: Bool {
        if let state = state {
            return state.importers.isEmpty
        }
        return true
    }
    
    var searchResult: SearchResult?
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
        
    if let peer = state.peer?.peer {
        if !state.empty {
            if let searchState = state.searchState {
                switch searchState.state {
                case .Focus:
                    entries.append(.sectionId(sectionId, type: .customModern(80)))
                    sectionId += 1
                default:
                    entries.append(.sectionId(sectionId, type: .normal))
                    sectionId += 1
                }
                
            } else {
                entries.append(.sectionId(sectionId, type: .normal))
                sectionId += 1
            }
            
            if state.searchResult == nil {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: nil, comparable: nil, item: { initialSize, stableId in
                    
                    
                    
                    let text: String = strings().requestJoinListDescription
                    
                    let attr = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.listGrayText), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.listGrayText), link: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.accent), linkAttribute: { contents in
                        return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents,  {_ in
                            arguments.openInviteLinks()
                        }))
                    }))
                    
                    return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.request_join_link, text: attr)
                }))
                index += 1
            }
            
         
            
           
            let isChannel = peer.isChannel
            
            
            
            let effectiveImporterState: PeerInvitationImportersState?
            if let searchResult = state.searchResult {
                effectiveImporterState = searchResult.result
                
                if searchResult.isLoading {
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("searching"), equatable: nil, comparable: nil, item: { initialSize, stableId in
                        return GeneralLoadingRowItem(initialSize, stableId: stableId, viewType: .singleItem)
                    }))
                    index += 1
                } else if let result = searchResult.result, result.count == 0, let request = state.searchState?.request {
                    
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("dynamic_top"), equatable: nil, comparable: nil, item: { initialSize, stableId in
                        return DynamicHeightRowItem(initialSize, stableId: stableId, side: .top)
                    }))
                    index += 1
                    
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("empty_header"), equatable: nil, comparable: nil, item: { initialSize, stableId in
                        
                        
                        let text: String = strings().requestJoinListSearchEmpty(request)
                        
                        let attr = NSMutableAttributedString()
                        _ = attr.append(string: strings().requestJoinListSearchEmptyHeader, color: theme.colors.text, font: .medium(.header))
                        _ = attr.append(string: "\n", color: theme.colors.grayText, font: .normal(.title))
                        _ = attr.append(string: text, color: theme.colors.grayText, font: .normal(.title))
                        attr.detectBoldColorInString(with: .medium(.title))
                        
                        return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.zoom, text: attr)
                    }))
                    index += 1
                    
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("dynamic_bottom"), equatable: nil, comparable: nil, item: { initialSize, stableId in
                        return DynamicHeightRowItem(initialSize, stableId: stableId, side: .bottom)
                    }))
                    index += 1
//
//                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("search_empty"), equatable: nil, comparable: nil, item: { initialSize, stableId in
//                        return GeneralBlockTextRowItem.init(initialSize, stableId: stableId, viewType: .singleItem, text: strings().requestJoinListSearchEmpty(request), font: .normal(.text), color: theme.colors.text, header: .init(text: strings().requestJoinListSearchEmptyHeader, icon: nil))
//                    }))
//                    index += 1
                }
               
                
            } else {
                effectiveImporterState = state.state
            }
            if let importerState = effectiveImporterState {
                
                let importers = importerState.importers.filter { $0.approvedBy == nil && !state.added.contains($0.peer.peerId) && !state.dismissed.contains($0.peer.peerId) }
                

                if !importers.isEmpty {
                   

                    if state.searchResult == nil {
                        entries.append(.sectionId(sectionId, type: .normal))
                        sectionId += 1
                        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().requestJoinListListHeaderCountable(importers.count)), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
                        index += 1
                    }
                    for (i, importer) in importers.enumerated() {
                        
                        let data: PeerRequestChatJoinData = .init(peer: PeerEquatable(importer.peer.peer!), about: importer.about, timeInterval: TimeInterval(importer.date), added: state.added.contains(importer.peer.peerId), adding: false, dismissing: false, dismissed: state.dismissed.contains(importer.peer.peerId))
                        
                        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("peer_id_\(importer.peer.peerId)"), equatable: .init(data), comparable: nil, item: { initialSize, stableId in
                            return PeerRequestJoinRowItem(initialSize, stableId: stableId, context: arguments.context, isChannel: isChannel, data: data, add: arguments.add, dismiss: arguments.dismiss, openInfo: arguments.openInfo, viewType: bestGeneralViewType(importers, for: i))
                        }))
                        index += 1
                    }

                }
            }
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
        } else if let _ = state.state {
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("dynamic_top"), equatable: nil, comparable: nil, item: { initialSize, stableId in
                return DynamicHeightRowItem(initialSize, stableId: stableId, side: .top)
            }))
            index += 1
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("center"), equatable: nil, comparable: nil, item: { initialSize, stableId in
                
                let attr = NSMutableAttributedString()
                _ = attr.append(string: strings().requestJoinListEmpty1, color: theme.colors.text, font: .medium(.header))
                _ = attr.append(string: "\n", color: theme.colors.text, font: .medium(.header))
                _ = attr.append(string: peer.isChannel ? strings().requestJoinListEmpty2Channel : strings().requestJoinListEmpty2Group, color: theme.colors.listGrayText, font: .normal(.text))

                
                return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.thumbsup, text: attr)
            }))
            index += 1
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("dynamic_bottom"), equatable: nil, comparable: nil, item: { initialSize, stableId in
                return DynamicHeightRowItem(initialSize, stableId: stableId, side: .bottom)
            }))
            index += 1
        } else {
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("dynamic_top"), equatable: nil, comparable: nil, item: { initialSize, stableId in
                return DynamicHeightRowItem(initialSize, stableId: stableId, side: .top)
            }))
            index += 1
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("progress"), equatable: nil, comparable: nil, item: { initialSize, stableId in
                return LoadingTableItem(initialSize, height: 100, stableId: stableId)
            }))
            index += 1
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("dynamic_bottom"), equatable: nil, comparable: nil, item: { initialSize, stableId in
                return DynamicHeightRowItem(initialSize, stableId: stableId, side: .bottom)
            }))
            index += 1
        }
       
    }
    

    
    return entries
}

func RequestJoinMemberListController(context: AccountContext, peerId: PeerId, manager: PeerInvitationImportersContext, openInviteLinks: @escaping()->Void) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State(peer: nil, state: nil, added: Set(), dismissed: Set(), searchState: SearchState(state: .None, request: nil))
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let searchStatePromise = ValuePromise(SearchState(state: .None, request: nil), ignoreRepeated: true)
    let searchStateValue = Atomic(value: SearchState(state: .None, request: nil))
    let updateSearchState: ((SearchState) -> SearchState) -> Void = { f in
        searchStatePromise.set(searchStateValue.modify (f))
    }

    
    
    var getController:(()->InputDataController?)? = nil

    let arguments = Arguments(context: context, add: { [weak manager] userId in
        updateState { current in
            var current = current
            current.added.insert(userId)
            return current
        }
        
        let attr = NSMutableAttributedString()
        
        let text: String
        let isChannel = stateValue.with { $0.peer?.peer.isChannel == true }
        let peer = stateValue.with { $0.state?.importers.first(where: { $0.peer.peerId == userId })}
        if isChannel {
            text = strings().requestJoinListTooltipApprovedChannel(peer?.peer.peer?.displayTitle ?? "")
        } else {
            text = strings().requestJoinListTooltipApprovedGroup(peer?.peer.peer?.displayTitle ?? "")
        }
        
        _ = attr.append(string: text, color: theme.colors.text, font: .normal(.text))
        attr.detectBoldColorInString(with: .medium(.text))
        getController?()?.show(toaster: ControllerToaster(text: attr))
        
        manager?.update(userId, action: .approve)

    }, dismiss: { [weak manager] userId in
        updateState { current in
            var current = current
            current.added.insert(userId)
            return current
        }
        manager?.update(userId, action: .deny)
    }, openInfo: { peerId in
        context.bindings.rootNavigation().push(PeerInfoController(context: context, peerId: peerId))
    }, openInviteLinks: openInviteLinks)
    
    let peerSignal = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
    
    actionsDisposable.add(peerSignal.start(next: { peer in
        updateState { current in
            var current = current
            if let peer = peer?._asPeer() {
                current.peer = .init(peer)
            } else {
                current.peer = nil
            }
            return current
        }
    }))
    
    actionsDisposable.add(manager.state.start(next: { state in
        updateState { current in
            var current = current
            current.state = state
            return current
        }
    }))

    var searchManager: PeerInvitationImportersContext?
    let searchResultDisposable = MetaDisposable()
    
    actionsDisposable.add(searchStatePromise.get().start(next: { state in
        
        let result: State.SearchResult?
        if !state.request.isEmpty {
            result = .init(isLoading: true, result: nil)
        } else {
            result = nil
        }
        updateState { current in
            var current = current
            current.searchState = state
            current.searchResult = result
            return current
        }
        if result != nil {
            let manager = context.engine.peers.peerInvitationImporters(peerId: peerId, subject: .requests(query: state.request))
            manager.loadMore()
            searchManager = manager
            searchResultDisposable.set(manager.state.start(next: { state in
                updateState { current in
                    var current = current
                    if !state.isLoadingMore {
                        current.searchResult = .init(isLoading: false, result: state)
                    }
                    return current
                }
            }))
        } else {
            searchManager = nil
            searchResultDisposable.set(nil)
        }
        
    }))

    
    let searchValue:Atomic<TableSearchViewState> = Atomic(value: .none({ searchState in
        updateSearchState { _ in
            return searchState
        }
    }))
    let searchPromise: ValuePromise<TableSearchViewState> = ValuePromise(.none({ searchState in
        updateSearchState { _ in
            return searchState
        }
    }), ignoreRepeated: true)
    let updateSearchValue:((TableSearchViewState)->TableSearchViewState)->Void = { f in
        searchPromise.set(searchValue.modify(f))
    }
    
    
    let searchData = TableSearchVisibleData(cancelImage: theme.icons.chatSearchCancel, cancel: {
        updateSearchValue { _ in
            return .none({ searchState in
                updateSearchState { _ in
                    return searchState
                }
            })
        }
    }, updateState: { searchState in
        updateSearchState { _ in
            return searchState
        }
    })
    
    
    
    let signal = combineLatest(statePromise.get(), searchPromise.get()) |> deliverOnPrepareQueue |> map { state, searchData in
        return InputDataSignalValue(entries: entries(state, arguments: arguments), searchState: searchData)
    }
    
    var updateBarIsHidden:((Bool)->Void)? = nil

    
    let controller = InputDataController(dataSignal: signal, title: strings().requestJoinListTitle, removeAfterDisappear: false, customRightButton: { controller in
        let bar = ImageBarView(controller: controller, theme.icons.chatSearch)
        bar.button.set(handler: { _ in
            updateSearchValue { current in
                switch current {
                case .none:
                    return .visible(searchData)
                case .visible:
                    return .none({ searchState in
                        updateState { current in
                            var current = current
                            current.searchState = searchState
                            return current
                        }
                    })
                }
            }
        }, for: .Click)
        bar.button.autohighlight = false
        bar.button.scaleOnClick = true
        updateBarIsHidden = { [weak bar] isHidden in
            bar?.button.alphaValue = isHidden ? 0 : 1
        }

        return bar
    })
    
    controller.onDeinit = {
        actionsDisposable.dispose()
        searchResultDisposable.dispose()
        searchManager = nil
    }
    
    controller.searchKeyInvocation = {
        updateSearchValue { current in
            switch current {
            case .none:
                return .visible(searchData)
            case .visible:
                return .none({ searchState in
                    updateState { current in
                        var current = current
                        current.searchState = searchState
                        return current
                    }
                })
            }
        }
        return .invoked
    }
    
    
    controller.didLoaded = { [weak manager] controller, _ in
        controller.tableView.setScrollHandler { position in
            switch position.direction {
            case .bottom:
                manager?.loadMore()
            default:
                break
            }
        }
    }
    
    controller.afterTransaction = { controller in
        updateBarIsHidden?(stateValue.with { $0.state?.importers.filter { $0.approvedBy == nil}.count == 0 })
    }
    getController = { [weak controller] in
        return controller
    }
    


    return controller
    
}
