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
    var peer: PeerEquatable?
    var state:PeerInvitationImportersState?
    var adding:Set<PeerId> = Set()
    var added:Set<PeerId> = Set()
    var dismissing:Set<PeerId> = Set()
    var dismissed:Set<PeerId> = Set()
    
    var searchState: SearchState?
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
   
    
    
    
    if let peer = state.peer?.peer {
        
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
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: nil, comparable: nil, item: { initialSize, stableId in
            
            
            
            let text: String = L10n.requestJoinListDescription
            
            let attr = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.listGrayText), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.listGrayText), link: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.accent), linkAttribute: { contents in
                return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents,  {_ in
                    arguments.openInviteLinks()
                }))
            }))
            
            return AnimtedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.invitations, text: attr)
        }))
        index += 1
        
       
        let isChannel = peer.isChannel
        
        if let importerState = state.state {
            
            let importers = importerState.importers.filter { $0.approvedBy == nil }.filter { value in
                if let search = state.searchState {
                    if !search.request.isEmpty {
                        return value.peer.peer?.displayTitle.lowercased().components(separatedBy: " ").filter {
                            $0.hasPrefix(search.request.lowercased())
                        }.isEmpty == false
                    } else {
                        return true
                    }
                } else {
                    return true
                }
            }
            

            if !importers.isEmpty {
                entries.append(.sectionId(sectionId, type: .normal))
                sectionId += 1


                entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.requestJoinListListHeaderCountable(importers.count)), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
                
                
                for (i, importer) in importers.enumerated() {
                    
                    let data: PeerRequestChatJoinData = .init(peer: PeerEquatable(importer.peer.peer!), about: nil, timeInterval: TimeInterval(importer.date), added: state.added.contains(importer.peer.peerId), adding: state.adding.contains(importer.peer.peerId), dismissing: state.dismissing.contains(importer.peer.peerId), dismissed: state.dismissed.contains(importer.peer.peerId))
                    
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("peer_id_\(importer.peer.peerId)"), equatable: .init(data), comparable: nil, item: { initialSize, stableId in
                        return PeerRequestJoinRowItem(initialSize, stableId: stableId, context: arguments.context, isChannel: isChannel, data: data, add: arguments.add, dismiss: arguments.dismiss, openInfo: arguments.openInfo, viewType: bestGeneralViewType(importers, for: i))
                    }))
                    index += 1
                }

            }
        }
        
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func RequestJoinMemberListController(context: AccountContext, peerId: PeerId, manager: PeerInvitationImportersContext, openInviteLinks: @escaping()->Void) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State(peer: nil, state: nil, adding: Set(), added: Set(), dismissing: Set(), dismissed: Set(), searchState: SearchState(state: .None, request: nil))
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
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
            text = L10n.requestJoinListTooltipApprovedChannel(peer?.peer.peer?.displayTitle ?? "")
        } else {
            text = L10n.requestJoinListTooltipApprovedGroup(peer?.peer.peer?.displayTitle ?? "")
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
        context.sharedContext.bindings.rootNavigation().push(PeerInfoController(context: context, peerId: peerId))
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

    
    let searchValue:Atomic<TableSearchViewState> = Atomic(value: .none({ searchState in
        updateState { current in
            var current = current
            current.searchState = searchState
            return current
        }
    }))
    let searchPromise: ValuePromise<TableSearchViewState> = ValuePromise(.none({ searchState in
        updateState { current in
            var current = current
            current.searchState = searchState
            return current
        }
    }), ignoreRepeated: true)
    let updateSearchValue:((TableSearchViewState)->TableSearchViewState)->Void = { f in
        searchPromise.set(searchValue.modify(f))
    }
    
    
    let searchData = TableSearchVisibleData(cancelImage: theme.icons.chatSearchCancel, cancel: {
        updateSearchValue { _ in
            return .none({ searchState in
                updateState { current in
                    var current = current
                    current.searchState = searchState
                    return current
                }
            })
        }
    }, updateState: { searchState in
        updateState { current in
            var current = current
            current.searchState = searchState
            return current
        }
    })
    
    let signal = combineLatest(statePromise.get(), searchPromise.get()) |> deliverOnPrepareQueue |> map { state, searchData in
        return InputDataSignalValue(entries: entries(state, arguments: arguments), searchState: searchData)
    }
    
    var updateBarIsHidden:((Bool)->Void)? = nil

    
    let controller = InputDataController(dataSignal: signal, title: "Members Requests", removeAfterDisappear: false, customRightButton: { controller in
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
        updateBarIsHidden = { [weak bar] isHidden in
            bar?.button.alphaValue = isHidden ? 0 : 1
        }

        return bar
    })
    
    controller.onDeinit = {
        actionsDisposable.dispose()
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
