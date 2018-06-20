//
//  NotificationSettingsViewController.swift
//  TelegramMac
//
//  Created by keepcoder on 15/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac

fileprivate enum NotificationSettingsEntry : Comparable, Identifiable {
    case notifications
    case messagePreview
    case notificationTone(String)
    case resetNotifications
    case resetText
    case whiteSpace(Int32,CGFloat)
    case searchField
    case badgeFilter(Bool)
    case peer(ChatListEntry)
    case searchPeer(Peer, Int32, PeerNotificationSettings?)
    var index:Int32 {
        switch self {
        case .notifications:
            return 1000
        case .messagePreview:
            return 2000
        case .badgeFilter:
            return 3000
        case .notificationTone:
            return 4000
        case .resetNotifications:
            return 5000
        case .resetText:
            return 6000
        case let .whiteSpace(index,_):
            return index
        case .searchField:
            return 7000
        case let .peer(entry):
            return INT32_MAX - entry.index.messageIndex.timestamp
        case let .searchPeer(_, index, _):
            return 8000 + index
        }
    }
    
    var stableId:AnyHashable {
        switch self {
        case let .peer(entry):
            switch entry {
            case let .HoleEntry(hole):
                return hole
            default:
                return entry.index
            }
        case let .searchPeer(peer,_,_):
            return peer.id
        default:
            return Int64(index)
        }
    }
}

fileprivate func <(lhs:NotificationSettingsEntry, rhs:NotificationSettingsEntry) -> Bool {
     return lhs.index < rhs.index
}

fileprivate func ==(lhs:NotificationSettingsEntry, rhs:NotificationSettingsEntry) -> Bool {
    switch lhs {
    case let .peer(lhsEntry):
        if case let .peer(rhsEntry) = rhs {
            return lhsEntry == rhsEntry
        }
    case let .badgeFilter(enabled):
        if case .badgeFilter(enabled) = rhs {
            return true
        } else {
            return false
        }
    case let .searchPeer(lhsPeer, lhsIndex, lhsNotificationSettings):
        if case let .searchPeer(rhsPeer, rhsIndex, rhsNotificationSettings) = rhs {
            
            if let lhsNotificationSettings = lhsNotificationSettings, let rhsNotificationSettings = rhsNotificationSettings {
                if !lhsNotificationSettings.isEqual(to: rhsNotificationSettings) {
                    return false
                }
            } else if (lhsNotificationSettings != nil) != (rhsNotificationSettings != nil) {
                return false
            }
            
            return lhsPeer.isEqual(rhsPeer) && lhsIndex == rhsIndex
        }
    case let .notificationTone(lhsTone):
        if case let .notificationTone(rhsTone) = rhs {
            return lhsTone == rhsTone
        }
        return false
    default:
        return lhs.stableId == rhs.stableId
    }
    return lhs.stableId == rhs.stableId
}

private func simpleEntries(_ settings:InAppNotificationSettings, filter: UnreadMessageCountsTotalItem) -> [NotificationSettingsEntry] {
    var simpleEntries:[NotificationSettingsEntry] = []
    simpleEntries.append(.whiteSpace(1,15))
    simpleEntries.append(.notifications)
    simpleEntries.append(.messagePreview)
    simpleEntries.append(.badgeFilter(filter == .raw))
    simpleEntries.append(.notificationTone(settings.tone))
    simpleEntries.append(.resetNotifications)
    simpleEntries.append(.resetText)
    simpleEntries.append(.whiteSpace(5001,40))
    simpleEntries.append(.searchField)
    return simpleEntries.reversed()
}

fileprivate struct NotificationsSettingsList {
    let list:[AppearanceWrapperEntry<NotificationSettingsEntry>]
    let settings:InAppNotificationSettings
}

struct NotificationSettingsInteractions {
    let resetAllNotifications:() -> Void
    let toggleMessagesPreview:() -> Void
    let toggleNotifications:() -> Void
    let notificationTone:(String) -> Void
    let toggleBadgeFilter:(Bool) -> Void
    let togglePeerId:(PeerId) -> Void
    let showToneOptions:() -> Void
}

fileprivate func prepareEntries(from:NotificationsSettingsList?, to:NotificationsSettingsList, account:Account, interactions:NotificationSettingsInteractions, searchInteractions:SearchInteractions, initialSize:NSSize, animated:Bool) -> Signal<TableEntriesTransition<NotificationsSettingsList>,Void> {
    
    return Signal {   subscriber in
        
        let (deleted,inserted, updated) =  proccessEntriesWithoutReverse(from?.list, right: to.list, { (entry) -> TableRowItem in
            
            switch entry.entry {
            case .notifications:
                return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: tr(L10n.notificationSettingsToggleNotifications), type: .switchable(to.settings.enabled), action: {
                    interactions.toggleNotifications()
                })
            case .messagePreview:
                return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: tr(L10n.notificationSettingsMessagesPreview), type: .switchable(to.settings.displayPreviews), action: {
                    interactions.toggleMessagesPreview()
                })
            case let .badgeFilter(enabled):
                return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: L10n.notificationSettingsIncludeMutedChats, type: .switchable(enabled), action: {
                    interactions.toggleBadgeFilter(!enabled)
                })
            case let .whiteSpace(_, height):
                return GeneralRowItem(initialSize, height: height, stableId: entry.stableId)
            case .notificationTone:
                return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: tr(L10n.notificationSettingsNotificationTone), type: .context(to.settings.tone.isEmpty ? tr(L10n.notificationSettingsToneDefault) : localizedString(to.settings.tone)), action: {
                    interactions.showToneOptions()
                })
            case .resetNotifications:
                return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: tr(L10n.notificationSettingsResetNotifications), type: .next, action: {
                    interactions.resetAllNotifications()
                })
            case .resetText:
                return GeneralTextRowItem(initialSize, stableId: entry.stableId, text: tr(L10n.notificationSettingsResetNotificationsText))
            case .searchField:
                return SearchRowItem(initialSize, stableId: entry.stableId, searchInteractions:searchInteractions)
            case let .peer(peerEntry):
                switch peerEntry {
                case  .HoleEntry:
                    return GeneralRowItem(initialSize, stableId:entry.stableId)
                case let .MessageEntry(_, _, _, notifySettings,_, renderedPeer, _):
                    if let peer = renderedPeer.chatMainPeer {
                        return ShortPeerRowItem(initialSize, peer: peer, account: account, height: 40, photoSize: NSMakeSize(30,30), inset: NSEdgeInsets(left:30,right:30), generalType:.switchable(!((notifySettings as? TelegramPeerNotificationSettings)?.isMuted ?? true)), action:{
                            interactions.togglePeerId(peer.id)
                        })
                    }
                    return GeneralRowItem(initialSize, stableId:entry.stableId)
                case .GroupReferenceEntry(_, _, _, _, _):
                    fatalError("feed not supported in notification settings")
                }
            case let .searchPeer(peer, _, notifySettings):
                return ShortPeerRowItem(initialSize, peer: peer, account: account, height: 40, photoSize: NSMakeSize(30,30), inset: NSEdgeInsets(left:30,right:30), generalType:.switchable(((notifySettings as? TelegramPeerNotificationSettings)?.isMuted ?? true)), action:{
                    interactions.togglePeerId(peer.id)
                })
                
            }
            
        })
        
        let transition = TableEntriesTransition<NotificationsSettingsList>(deleted: deleted, inserted: inserted, updated:updated, entries: to, animated:animated, state: animated ? .none(nil) : .saveVisible(.lower))
        subscriber.putNext(transition)
        subscriber.putCompletion()
        
        return EmptyDisposable
        } |> runOn(prepareQueue)
    
}


class NotificationSettingsViewController: TableViewController {
    private let request = Promise<ChatListIndexRequest>()
    private let disposable:MetaDisposable = MetaDisposable()
    private let notificationsDisposable:MetaDisposable = MetaDisposable()
    private var tones:[SPopoverItem] = []

    private let search:ValuePromise<SearchState> = ValuePromise(ignoreRepeated: true)
    
    override var removeAfterDisapper:Bool {
        return true
    }
    

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let previous:Atomic<NotificationsSettingsList?> = Atomic(value: nil)
        let initialSize = self.atomicSize
        let account = self.account
        
        
        search.set(SearchState(state: .None, request: nil))
        
        
        let searchInteractions = SearchInteractions({ [weak self] state in
            self?.search.set(state)
        }, { [weak self] state in
            self?.search.set(state)
        })
        
        let interactions = NotificationSettingsInteractions(resetAllNotifications: { [weak self] in
            if let window = self?.window , let account = self?.account {
                confirm(for: window, header: tr(L10n.notificationSettingsConfirmReset), information: tr(L10n.chatConfirmActionUndonable), successHandler: { _ in
                    _ = resetPeerNotificationSettings(network: account.network).start()
                })
            }
            }, toggleMessagesPreview: {
                _ = updateInAppNotificationSettingsInteractively(postbox: account.postbox, {$0.withUpdatedDisplayPreviews(!$0.displayPreviews)}).start()
        }, toggleNotifications: {
            _ = updateInAppNotificationSettingsInteractively(postbox: account.postbox, {$0.withUpdatedEnables(!$0.enabled)}).start()
        }, notificationTone: { (tone) in
            
        }, toggleBadgeFilter: { enable in
            FastSettings.toggleBadgeFilter(!enable)
            account.context.badgeFilter.set(!enable ? .filtered : .raw)
        }, togglePeerId: { [weak self] peerId in
            self?.notificationsDisposable.set(togglePeerMuted(account: account, peerId: peerId).start())
        }, showToneOptions: { [weak self] in
            self?.showToneOptions()
        });
        
        let tones = ObjcUtils.notificationTones("Default")
        for tone in tones {
            self.tones.append(SPopoverItem(localizedString(tone), {
                _ = NSSound(named: NSSound.Name(rawValue: tone))?.play()
                _ = updateInAppNotificationSettingsInteractively(postbox: account.postbox, {$0.withUpdatedTone(tone)}).start()
            }))
        }
        
        let first = Atomic(value:true)

        let list:Signal<TableEntriesTransition<NotificationsSettingsList>,Void> = (combineLatest(request.get() |> distinctUntilChanged, search.get() |> distinctUntilChanged) |> mapToSignal { (location, search) -> Signal<TableEntriesTransition<NotificationsSettingsList>,Void> in
            
            var signal:Signal<ChatListView,Void>
            
            
            let mappedEntries:Signal<[NotificationSettingsEntry],Void>
            
            if search.request.isEmpty || search.state == .None {
                
                switch(location) {
                case let .Initial(count, _):
                    signal = account.viewTracker.tailChatListView(groupId: nil, count: count) |> map {$0.0}
                case let .Index(index, _):
                    signal = account.viewTracker.aroundChatListView(groupId: nil, index: index, count: 100) |> map {$0.0}
                }
                
                mappedEntries = signal |> map { value -> [NotificationSettingsEntry] in
                    var ids:[PeerId:PeerId] = [:]
                    
                    return value.entries.filter({ index -> Bool in
                        switch index {
                        case  .HoleEntry:
                            return false
                        case let .MessageEntry(_, _, _, _,_, renderedPeer, _):
                            let first = ids[renderedPeer.peerId] == nil && renderedPeer.peerId.namespace != Namespaces.Peer.SecretChat
                            ids[renderedPeer.peerId] = renderedPeer.peerId
                            return first
                        case .GroupReferenceEntry(_, _, _, _, _):
                           return false
                        }
                        
                    }).map { peer -> NotificationSettingsEntry in
                        return .peer(peer)
                    }
                } |> mapToQueue { list in return .single(list)}
                
                
            } else {
                
                
                var ids:[PeerId:Peer] = [:]
                let foundLocalPeers = combineLatest(account.postbox.searchPeers(query: search.request.lowercased(), groupId: nil) |> map {$0.compactMap({$0.chatMainPeer}).filter({!($0 is TelegramSecretChat)})},account.postbox.searchContacts(query: search.request.lowercased()))
                    |> map { (peers, contacts) -> [Peer] in
                        return (peers + contacts).filter({ (peer) -> Bool in
                            let first = ids[peer.id] == nil
                            ids[peer.id] = peer
                            return first
                        })
                }
                
                mappedEntries = foundLocalPeers |> mapToSignal { peers -> Signal<[NotificationSettingsEntry], Void> in
                    
                    return combineLatest(peers.map { peer -> Signal<TelegramPeerNotificationSettings?, Void> in
                        
                        return account.postbox.transaction { transaction -> TelegramPeerNotificationSettings? in
                            return transaction.getPeerNotificationSettings(peer.id) as? TelegramPeerNotificationSettings
                        }
                        
                    }) |> map { (settings) -> [NotificationSettingsEntry] in
                        var entries:[NotificationSettingsEntry] = []
                        for i in 0 ..< peers.count {
                            entries.append(.searchPeer(peers[i], Int32(i) + 1, settings[i]))
                        }
                        return entries
                    }
                }
            }
            
            return combineLatest(mappedEntries |> deliverOnPrepareQueue, account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.inAppNotificationSettings]) |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue, account.context.badgeFilter.get() |> deliverOnPrepareQueue) |> map { value, settings, appearance, filter -> NotificationsSettingsList in
                
                let inAppSettings: InAppNotificationSettings
                if let settings = settings.values[ApplicationSpecificPreferencesKeys.inAppNotificationSettings] as? InAppNotificationSettings {
                    inAppSettings = settings
                } else {
                    inAppSettings = InAppNotificationSettings.defaultSettings
                }
                return NotificationsSettingsList(list: (simpleEntries(inAppSettings, filter: filter) + value).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}.sorted(by: <), settings: inAppSettings)
            } |> mapToQueue { value -> Signal<TableEntriesTransition<NotificationsSettingsList>, Void> in
                return prepareEntries(from: previous.modify {$0}, to: value, account: account, interactions:interactions, searchInteractions: searchInteractions, initialSize: initialSize.modify({$0}), animated: !first.swap(false))
            }

        })
        |> deliverOnMainQueue
        
        
        
        
        let apply = list |> mapToSignal { [weak self] transition -> Signal<Void,NoError> in
            
            self?.readyOnce()
            
            self?.genericView.resetScrollNotifies()
            _ = previous.swap(transition.entries)
            self?.genericView.merge(with: transition)
            self?.searchView?.searchInteractions = searchInteractions
            return .complete()
            
        }
        
        disposable.set(apply.start())
        
        request.set(.single(.Initial(100, nil)))
        
    }
    
    
    func showToneOptions() {
        if let view = (genericView.viewNecessary(at: 4) as? GeneralInteractedRowView)?.textView {
            showPopover(for: view, with: SPopoverViewController(items: tones), edge: .minX, inset: NSMakePoint(0,-30))
        }

    }
    
    override var canBecomeResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool? {
        return false
    }
    
    override func firstResponder() -> NSResponder? {
        if let item = genericView.item(stableId: NotificationSettingsEntry.searchField.stableId), let view = genericView.viewNecessary(at: item.index) as? SearchRowView {
            return view.searchView.input
        }
        return nil
    }
    

    var searchView:SearchView? {
        if let item = genericView.item(stableId: NotificationSettingsEntry.searchField.stableId), let view = genericView.viewNecessary(at: item.index) as? SearchRowView {
            return view.searchView
        }
        return nil
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        if let item = genericView.item(stableId: NotificationSettingsEntry.searchField.stableId), let view = genericView.viewNecessary(at: item.index) as? SearchRowView {
            if view.searchView.state == .Focus {
                return view.searchView.changeResponder() ? .invoked : .rejected
            }
        }
        return .rejected
    }

    deinit {
        disposable.dispose()
        notificationsDisposable.dispose()
    }
    
}
