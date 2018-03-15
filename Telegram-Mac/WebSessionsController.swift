//
//  WebSessionsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit


private final class WebSessionArguments {
    let account: Account
    let logoutSession:(WebAuthorization)->Void
    let logoutAll:()->Void
    init(account: Account, logoutSession:@escaping(WebAuthorization)->Void, logoutAll:@escaping()->Void) {
        self.account = account
        self.logoutAll = logoutAll
        self.logoutSession = logoutSession
    }
}

private enum WebSessionEntryStableId : Hashable {
    static func ==(lhs: WebSessionEntryStableId, rhs: WebSessionEntryStableId) -> Bool {
        switch lhs {
        case let .sectionId(id):
            if case .sectionId(id) = rhs {
                return true
            } else {
                return false
            }
        case .logoutId:
            if case .logoutId = rhs {
                return true
            } else {
                return false
            }
        case .loadingId:
            if case .loadingId = rhs {
                return true
            } else {
                return false
            }
        case .descriptionId(let id):
            if case .descriptionId(id) = rhs {
                return true
            } else {
                return false
            }
        case .sessionId(let id):
            if case .sessionId(id) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    case logoutId
    case descriptionId(Int32)
    case sessionId(Int64)
    case loadingId
    case sectionId(Int32)
    var hashValue: Int {
        switch self {
        case let .sectionId(id):
            return Int(id)
        case .logoutId:
            return 0
        case .loadingId:
            return 1
        case let .sessionId(id):
            return Int(id)
        case let .descriptionId(id):
            return Int(id)
        }
    }
}

private enum WebSessionEntry : TableItemListNodeEntry {
    case logout(sectionId: Int32, index: Int32)
    case description(sectionId: Int32, index: Int32, text: String)
    case session(sectionId: Int32, index: Int32, authorization: WebAuthorization, peer: Peer)
    case sectionId(Int32)
    case loading
    
    var stableId:WebSessionEntryStableId {
        switch self {
        case let .sectionId(id):
            return .sectionId(id)
        case .logout:
            return .logoutId
        case .loading:
            return .loadingId
        case .description(_, let index, _):
            return .descriptionId(index)
        case .session(_, _, let authorization, _):
            return .sessionId(authorization.hash)
        }
    }
    
    var index: Int32 {
        switch self {
        case let .logout(sectionId, index):
            return (sectionId * 1000) + index
        case .loading:
            return 0
        case let .description(sectionId, index, _):
            return (sectionId * 1000) + index
        case let .session(sectionId, index, _, _):
            return (sectionId * 1000) + index
        case let .sectionId(sectionId):
            return (sectionId * 1000) + sectionId
        }
    }
    
    
    func item(_ arguments: WebSessionArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .sectionId:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        case let .description(_, _, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text)
        case .logout:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.webAuthorizationsLogoutAll, nameStyle: ControlStyle.init(font: .normal(.title), foregroundColor: theme.colors.redUI), type: .none, action: {
                arguments.logoutAll()
            })
        case .loading:
            return SearchEmptyRowItem(initialSize, stableId: stableId, isLoading: true)
        case let .session(_, _, authorization, peer):
            return WebAuthorizationRowItem(initialSize, stableId: stableId, account: arguments.account, authorization: authorization, peer: peer, logout: {
                arguments.logoutSession(authorization)
            })
        }
    }
}

private func ==(lhs: WebSessionEntry, rhs: WebSessionEntry) -> Bool {
    switch lhs {
    case .loading:
        if case .loading = rhs {
            return true
        } else {
            return false
        }
    case let .description(sectionId, index, text):
        if case .description(sectionId, index, text) = rhs {
            return true
        } else {
            return false
        }
    case let .logout(sectionId, index):
        if case .logout(sectionId, index) = rhs {
            return true
        } else {
            return false
        }
    case let .sectionId(sectionId):
        if case .sectionId(sectionId) = rhs {
            return true
        } else {
            return false
        }
    case let .session(lhsSectionId, lhsIndex, lhsAuthorization, lhsPeer):
        if case let .session(rhsSectionId, rhsIndex, rhsAuthorization, rhsPeer) = rhs {
            return lhsSectionId == rhsSectionId && lhsIndex == rhsIndex && lhsAuthorization == rhsAuthorization && lhsPeer.isEqual(rhsPeer)
        } else {
            return false
        }
    }
}
private func <(lhs: WebSessionEntry, rhs: WebSessionEntry) -> Bool {
    return lhs.index < rhs.index
}


private struct WebSessionsControllerState: Equatable {
    let removingSessionId: Int64?
    let removedSessions: Set<Int64>
    init() {
        self.removingSessionId = nil
        self.removedSessions = []
    }
    
    init(removingSessionId: Int64?, removedSessions: Set<Int64>) {
        self.removingSessionId = removingSessionId
        self.removedSessions = removedSessions
    }
    
    static func ==(lhs: WebSessionsControllerState, rhs: WebSessionsControllerState) -> Bool {
        if lhs.removingSessionId != rhs.removingSessionId {
            return false
        }
        if lhs.removedSessions != rhs.removedSessions {
            return false
        }
        
        return true
    }
    
    func withUpdatedRemovedSessionId(_ sessionId: Int64) -> WebSessionsControllerState {
        var sessions = self.removedSessions
        if sessions.contains(sessionId) {
            sessions.remove(sessionId)
        } else {
            sessions.insert(sessionId)
        }
        return WebSessionsControllerState(removingSessionId: removingSessionId, removedSessions: sessions)
    }
    
    func withUpdatedRemovingSessionId(_ removingSessionId: Int64?) -> WebSessionsControllerState {
        return WebSessionsControllerState(removingSessionId: removingSessionId, removedSessions: self.removedSessions)
    }
    
    func newState(from value: ([WebAuthorization], [PeerId : Peer])?) -> ([WebAuthorization], [PeerId : Peer])? {
        if let value = value {
            return (value.0.filter({!removedSessions.contains($0.hash)}), value.1)
        }
        return nil
    }
    
}

private func prepareSessions(left:[AppearanceWrapperEntry<WebSessionEntry>], right: [AppearanceWrapperEntry<WebSessionEntry>], arguments: WebSessionArguments, initialSize: NSSize) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

private func webAuthorizationEntries(authorizations: [WebAuthorization]?, peers:[PeerId : Peer], state: WebSessionsControllerState) -> [WebSessionEntry] {
    var entries: [WebSessionEntry] = []
    
    if let authorizations = authorizations {
        var sectionId:Int32 = 0
        entries.append(.sectionId(sectionId))
        sectionId += 1
        
        var index: Int32 = 1
        
        
        entries.append(.logout(sectionId: sectionId, index: index))
        index += 1
        
        entries.append(.description(sectionId: sectionId, index: index, text: L10n.webAuthorizationsLogoutAllDescription))
        index += 1
        
        entries.append(.sectionId(sectionId))
        sectionId += 1
        
        
        let authorizations = authorizations.filter {!state.removedSessions.contains($0.hash)}
        
        if authorizations.count > 0 {
            entries.append(.description(sectionId: sectionId, index: index, text: L10n.webAuthorizationsLoggedInDescrpiption))
            index += 1
        }
        
        for auth in authorizations {
            if let peer = peers[auth.botId] {
                entries.append(.session(sectionId: sectionId, index: index, authorization: auth, peer: peer))
                index += 1
            }
        }
    } else {
        entries.append(.loading)
    }
    
    
    return entries
}

class WebSessionsController: TableViewController {

    private let disposable = MetaDisposable()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let actionsDisposable = MetaDisposable()
        
        let state = Atomic(value: WebSessionsControllerState())
        
       
        
        let stateValue = ValuePromise(WebSessionsControllerState(), ignoreRepeated: true)
        
        let updateState:((WebSessionsControllerState)->WebSessionsControllerState)->Void = { f -> Void in
            stateValue.set(state.modify(f))
        }
        
        let network = self.account.network
        
        let arguments = WebSessionArguments(account: account, logoutSession: { session in
            confirm(for: mainWindow, information: L10n.webAuthorizationsConfirmRevoke, successHandler: { result in
                updateState { state in
                    return state.withUpdatedRemovingSessionId(session.hash)
                }
                
                _ = showModalProgress(signal: terminateWebSession(network: network, hash: session.hash), for: mainWindow).start(next: { value in
                    updateState { state in
                        return state.withUpdatedRemovedSessionId(session.hash).withUpdatedRemovingSessionId(nil)
                    }
                })
            })
            
        }, logoutAll: { [weak self] in
            confirm(for: mainWindow, information: L10n.webAuthorizationsConfirmRevokeAll, successHandler: { result in
                self?.updated(nil)
                self?.navigationController?.back()
                _ = showModalProgress(signal: terminateAllWebSessions(network: network), for: mainWindow).start()
            })
           
        })
        let initialSize = self.atomicSize
        
        let previous: Atomic<[AppearanceWrapperEntry<WebSessionEntry>]> = Atomic(value: [])
        
        let signal = combineLatest((Signal<([WebAuthorization], [PeerId: Peer])?, Void>.single(defaultValue) |> deliverOnPrepareQueue |> then (webSessions(network: account.network) |> map {Optional($0)} |> deliverOnPrepareQueue)), appearanceSignal |> deliverOnPrepareQueue, stateValue.get() |> deliverOnPrepareQueue) |> map { values, appearance, state -> (TableUpdateTransition, ([WebAuthorization], [PeerId: Peer])?, WebSessionsControllerState) in
            let entries = webAuthorizationEntries(authorizations: values?.0, peers: values?.1 ?? [:], state: state).map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
            return (prepareSessions(left: previous.swap(entries), right: entries, arguments: arguments, initialSize: initialSize.modify{$0}), values, state)
            
        } |> deliverOnMainQueue |> afterDisposed {
            actionsDisposable.dispose()
        }
        
        disposable.set(signal.start(next: { [weak self] transition, values, state in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
            
            let newValue = state.newState(from: values)
            self?.updated(newValue)
            
            if newValue == nil || newValue?.0.isEmpty == true {
                self?.navigationController?.back()
            }
        }))
        
    }
    
    deinit {
        disposable.dispose()
    }
    
    private let defaultValue: ([WebAuthorization], [PeerId : Peer])?
    private let updated: (([WebAuthorization], [PeerId : Peer])?) -> Void
    init(_ account: Account, _ result: ([WebAuthorization], [PeerId : Peer])?, updated: @escaping(([WebAuthorization], [PeerId : Peer])?) -> Void) {
        self.defaultValue = result
        self.updated = updated
        super.init(account)
        
    }
    
}
