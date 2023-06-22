//
//  EditBotUsernameController.swift
//  Telegram
//
//  Created by Mike Renoir on 31.03.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox


private let _id_username = InputDataIdentifier("_id_username")
private func _id_external(_ username: TelegramPeerUsername) -> InputDataIdentifier {
    return .init("_id_external_\(username.username)")
}
private final class Arguments {
    let context: AccountContext
    let activate:(TelegramPeerUsername)->Void
    init(context: AccountContext, activate:@escaping(TelegramPeerUsername)->Void) {
        self.context = context
        self.activate = activate
    }
}

private struct State : Equatable {
    struct Usernames: Equatable {
        var username: String
        var usernames: [TelegramPeerUsername]
    }
    var usernames: Usernames
    var state: AddressNameAvailabilityState
    
    var isEnabled: Bool {
        switch state {
        case .success:
            return true
        case let .none(username):
            return username != self.usernames.username
        default:
            return false
        }
    }
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    

    entries.append(.desc(sectionId: sectionId, index: 0, text: .plain(strings().botUsernameHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    
    entries.append(.general(sectionId: sectionId, index: 1, value: .none, error: nil, identifier: _id_username, data: .init(name: state.state.username ?? "", color: theme.colors.text, viewType: .singleItem, enabled: false)))
    
    
    entries.append(.desc(sectionId: sectionId, index: 2, text: .markdown(strings().botUsernameInfo, linkHandler: { _ in
        execute(inapp: .external(link: "https://fragment.com", false))
    }), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    if !state.usernames.usernames.isEmpty {
        entries.append(.desc(sectionId: sectionId, index: 4, text: .plain(strings().botUsernameListTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        
        
        var index: Int32 = 5
        
        struct Tuple : Equatable {
            let username: TelegramPeerUsername
            let viewType: GeneralViewType
        }
        
        for (i, username) in state.usernames.usernames.enumerated() {
            let tuple = Tuple(username: username, viewType: bestGeneralViewType(state.usernames.usernames, for: i))
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_external(username), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
                return ExternalUsernameRowItem(initialSize, stableId: stableId, username: tuple.username, viewType: tuple.viewType, activate: {
                    arguments.activate(tuple.username)
                })
            }))
            index += 1
        }
        index += 1
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().botUsernameListInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    }
    
    return entries
}

func EditBotUsernameController(context: AccountContext, peerId: PeerId) -> InputDataController {

    let actionsDisposable = DisposableSet()
    let availabilityDisposable = MetaDisposable()
    actionsDisposable.add(availabilityDisposable)
    let initialState = State(usernames: .init(username: "", usernames: []), state: .none(username: nil))
    
    let statePromise = ValuePromise<State>(ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let nextTransactionNonAnimated = Atomic(value: false)

    let arguments = Arguments(context: context, activate: { username in
        
        guard !username.flags.contains(.isEditable) else {
            return
        }
        
        let value = !username.flags.contains(.isActive)
        var updatedFlags: TelegramPeerUsername.Flags = username.flags
        if value {
            updatedFlags.insert(.isActive)
        } else {
            updatedFlags.remove(.isActive)
        }
        let title: String = value ? strings().botUsernameActivateTitle : strings().botUsernameDeactivateTitle
        let info: String = value ? strings().botUsernameActivateInfo : strings().botUsernameDeactivateInfo
        let ok: String = value ? strings().botUsernameActivateOk : strings().botUsernameDeactivateOk
        
        confirm(for: context.window, header: title, information: info, okTitle: ok, successHandler: { _ in
            _ = context.engine.peers.toggleAddressNameActive(domain: .bot(peerId), name: username.username, active: value).start()
            
            updateState { current in
                var current = current
                
                let index = current.usernames.usernames.firstIndex(where: { $0.username == username.username })
                if let index = index {
                    current.usernames.usernames[index] = .init(flags: updatedFlags, username: username.username)
                }
                return current
            }
        })
    })
    
    let view = context.account.viewTracker.peerView(peerId) |> deliverOnMainQueue |> mapToSignal { peerView -> Signal<State.Usernames, NoError> in
        if let peer = peerView.peers[peerId] {
            return .single(.init(username: peer.username ?? "", usernames: peer.usernames))
        }
        return .complete()
    }
    actionsDisposable.add(view.start(next: { usernames in
        updateState { current in
            var current = current
            current.usernames = usernames
            current.state = .none(username: usernames.username)
            return current
        }
    }))
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments), animated: !nextTransactionNonAnimated.swap(false))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().botUsernameTitle)
    
    
    controller.updateDoneValue = { data in
        return { f in
            f(.enabled(strings().navigationDone))
        }
    }
    
    controller.validateData = { data in
        
        let state = stateValue.with { $0.state }
        
        switch state {
        case .success, .none:
            return .fail(.doSomething(next: { f in
                _ = context.engine.peers.updateAddressName(domain: .bot(peerId), name: state.username).start()
                f(.success(.navigationBack))
            }))
        default:
            return .fail(.none)
        }
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.afterTransaction = { controller in
        var range: NSRange = NSMakeRange(NSNotFound, 0)
        
        controller.tableView.enumerateItems(with: { item in
            if let item = item as? ExternalUsernameRowItem {
                if item.username.flags.contains(.isActive) {
                    if range.location == NSNotFound {
                        range.location = item.index
                    }
                    range.length += 1
                } else {
                    return false
                }
            }
            return true
        })
        
        if range.location != NSNotFound {
            controller.tableView.resortController = .init(resortRange: range, start: { _ in
                
            }, resort: { _ in }, complete: { from, to in
                let fromValue = from - range.location
                let toValue = to - range.location
                var names = stateValue.with { $0.usernames.usernames }
                names.move(at: fromValue, to: toValue)
                _ = nextTransactionNonAnimated.swap(true)
                updateState { current in
                    var current = current
                    current.usernames.usernames = names
                    return current
                }
                actionsDisposable.add(context.engine.peers.reorderAddressNames(domain: .bot(peerId), names: names).start())
            })
        } else {
            controller.tableView.resortController = nil
        }
    }
    return controller
}
