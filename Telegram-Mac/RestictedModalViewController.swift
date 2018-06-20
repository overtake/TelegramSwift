//
//  RestictedModalViewController.swift
//  Telegram
//
//  Created by keepcoder on 08/06/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//


import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

private final class RestrictedControllerArguments {
    let account: Account
    let toggleRight: (TelegramChannelBannedRightsFlags, TelegramChannelBannedRightsFlags) -> Void
    let changeUntil:()->Void
    init(account: Account, toggleRight: @escaping (TelegramChannelBannedRightsFlags, TelegramChannelBannedRightsFlags) -> Void, changeUntil: @escaping () -> Void) {
        self.account = account
        self.toggleRight = toggleRight
        self.changeUntil = changeUntil
    }
}

private enum RestrictedEntryStableId: Hashable {
    case info
    case right(TelegramChannelBannedRightsFlags)
    case description(Int32)
    case section(Int32)
    case blockFor
    var hashValue: Int {
        switch self {
        case .info:
            return 0
        case .description(let index):
            return Int(index)
        case .section(let section):
            return Int(section)
        case let .right(flags):
            return flags.rawValue.hashValue
        case .blockFor:
            return 1
        }
    }
    
    static func ==(lhs: RestrictedEntryStableId, rhs: RestrictedEntryStableId) -> Bool {
        switch lhs {
        case .info:
            if case .info = rhs {
                return true
            } else {
                return false
            }
        case .blockFor:
            if case .blockFor = rhs {
                return true
            } else {
                return false
            }
        case let .right(flags):
            if case .right(flags) = rhs {
                return true
            } else {
                return false
            }
        case let .section(section):
            if case .section(section) = rhs {
                return true
            } else {
                return false
            }
        case .description(let text):
            if case .description(text) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

private enum RestrictedEntry: TableItemListNodeEntry {
    case info(Int32, Peer, TelegramUserPresence?)
    case rightItem(Int32, Int32, String, TelegramChannelBannedRightsFlags, TelegramChannelBannedRightsFlags, Bool, Bool)
    case description(Int32, Int32, String)
    case section(Int32)
    case blockFor(Int32, Int32, Int32)
    
    var stableId: RestrictedEntryStableId {
        switch self {
        case .info:
            return .info
        case .blockFor:
            return .blockFor
        case let .rightItem(_, _, _, right, _, _, _):
            return .right(right)
        case .description(_, let index, _):
            return .description(index)
        case .section(let sectionId):
            return .section(sectionId)
        }
    }
    
    static func ==(lhs: RestrictedEntry, rhs: RestrictedEntry) -> Bool {
        switch lhs {
        case let .info(lhsSectionId, lhsPeer, lhsPresence):
            if case let .info(rhsSectionId, rhsPeer, rhsPresence) = rhs {
                if lhsSectionId != rhsSectionId {
                    return false
                }
                if !arePeersEqual(lhsPeer, rhsPeer) {
                    return false
                }
                if lhsPresence != rhsPresence {
                    return false
                }
                
                return true
            } else {
                return false
            }
        case let .rightItem(lhsSectionId, lhsIndex, lhsText, lhsRight, lhsFlags, lhsValue, lhsEnabled):
            if case let .rightItem(rhsSectionId, rhsIndex, rhsText, rhsRight, rhsFlags, rhsValue, rhsEnabled) = rhs {
                if lhsSectionId != rhsSectionId {
                    return false
                }
                if lhsIndex != rhsIndex {
                    return false
                }
                if lhsText != rhsText {
                    return false
                }
                if lhsRight != rhsRight {
                    return false
                }
                if lhsFlags != rhsFlags {
                    return false
                }
                if lhsValue != rhsValue {
                    return false
                }
                if lhsEnabled != rhsEnabled {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .description(sectionId, index, text):
            if case .description(sectionId, index, text) = rhs{
                return true
            } else {
                return false
            }
        case let .section(sectionId):
            if case .section(sectionId) = rhs{
                return true
            } else {
                return false
            }
        case let .blockFor(sectionId, index, until):
            if case .blockFor(sectionId, index, until) = rhs{
                return true
            } else {
                return false
            }
        }
    }
    
    var index:Int32 {
        switch self {
        case .info(let sectionId, _, _):
            return (sectionId * 1000) + 0
        case .description(let sectionId, let index, _):
            return (sectionId * 1000) + index
        case .rightItem(let sectionId, let index, _, _, _, _, _):
            return (sectionId * 1000) + Int32(index) + 10
        case .section(let sectionId):
            return (sectionId + 1) * 1000 - sectionId
        case .blockFor(let sectionId, let index, _):
            return (sectionId * 1000) + index
        }
    }
    
    static func <(lhs: RestrictedEntry, rhs: RestrictedEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(_ arguments: RestrictedControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        case .info(_, let peer, let presence):
            var string:String = peer.isBot ? tr(L10n.presenceBot) : tr(L10n.peerStatusRecently)
            var color:NSColor = theme.colors.grayText
            
            if let presence = presence {
                let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                (string,_, color) = stringAndActivityForUserPresence(presence, relativeTo: Int32(timestamp))
            }
            return ShortPeerRowItem(initialSize, peer: peer, account: arguments.account, stableId: stableId, enabled: true, height: 60, photoSize: NSMakeSize(50, 50), statusStyle: ControlStyle(font: .normal(.title), foregroundColor: color), status: string, borderType: [], drawCustomSeparator: false, drawLastSeparator: false, inset: NSEdgeInsets(left: 25, right: 25), drawSeparatorIgnoringInset: false, action: {})
        case let .rightItem(_, _, name, right, flags, value, enabled):
            //ControlStyle(font: NSFont.)
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: name, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: enabled ? theme.colors.text : theme.colors.grayText), type: .switchable(value), action: {
                arguments.toggleRight(right, flags)
            }, enabled: enabled, switchAppearance: SwitchViewAppearance(backgroundColor: .white, stateOnColor: theme.colors.blueUI, stateOffColor: theme.colors.redUI, disabledColor: theme.colors.grayBackground, borderColor: .clear))
        case .description(_, _, let name):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: name)
        case .blockFor(_, _, let until):
            let text: String
            if until == 0 || until == .max {
                text = L10n.channelBanForever
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeZone = NSTimeZone.local
                formatter.timeStyle = .short
                text = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(until)))
            }
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.channelBlockUserBlockFor, type: .context(text), action: {
                arguments.changeUntil()
            })
        }
        //return TableRowItem(initialSize)
    }
}


private enum RestrictUntil : Int32 {
    case day = 86400
    case week = 604800
    case month = 2592000
    case forever = 0
}

private struct RestrictedControllerState: Equatable {
    let updatedFlags: TelegramChannelBannedRightsFlags?
    let until: Int32
    
    init(updatedFlags: TelegramChannelBannedRightsFlags? = nil, until: Int32 = 0) {
        self.updatedFlags = updatedFlags
        self.until = until
    }
    
    static func ==(lhs: RestrictedControllerState, rhs: RestrictedControllerState) -> Bool {
        if lhs.updatedFlags != rhs.updatedFlags {
            return false
        }
        if lhs.until != rhs.until {
            return false
        }
        return true
    }
    
    func withUpdatedUpdatedFlags(_ updatedFlags: TelegramChannelBannedRightsFlags?) -> RestrictedControllerState {
        return RestrictedControllerState(updatedFlags: updatedFlags, until: self.until)
    }
    
    func withUpdatedUntil(_ until: Int32) -> RestrictedControllerState {
        return RestrictedControllerState(updatedFlags: self.updatedFlags, until: until)
    }
}

private func banRightDependencies(_ right: TelegramChannelBannedRightsFlags) -> [TelegramChannelBannedRightsFlags] {
    
    if right.contains(.banReadMessages) {
        return [.banSendMessages, .banSendMedia, .banSendStickers, .banSendGifs, .banEmbedLinks]
    } else if right.contains(.banSendMessages) {
        return [.banSendMedia, .banSendStickers, .banSendGifs, .banEmbedLinks]
    } else if right.contains(.banSendMedia) {
        return [.banSendStickers, .banSendGifs, .banEmbedLinks]
    } else if right.contains(.banSendStickers) {
        return [.banSendGifs]
    }
    
    return []
}

private func unbanRightDependencies(_ right: TelegramChannelBannedRightsFlags) -> [TelegramChannelBannedRightsFlags] {
    
    if right.contains(.banReadMessages) {
        return []
    } else if right.contains(.banSendMessages) {
        return [.banReadMessages]
    } else if right.contains(.banSendMedia) {
        return [.banSendMessages, .banReadMessages]
    } else if right.contains(.banSendStickers) {
        return [.banSendMessages, .banReadMessages, .banSendMedia, .banSendGifs]
    } else if right.contains(.banEmbedLinks) {
        return [.banSendMessages, .banReadMessages, .banSendMedia]
    }
    
    return []
}


private func RestrictedEntries(state: RestrictedControllerState, participant: RenderedChannelParticipant, view: PeerView) -> [RestrictedEntry] {
    var index:Int32 = 0
    var sectionId:Int32 = 1
    var entries:[RestrictedEntry] = []
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    entries.append(.info(sectionId, participant.peer, participant.presences[participant.peer.id] as? TelegramUserPresence))
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    entries.append(.description(sectionId, index, tr(L10n.channelUserRestriction)))
    index += 1
    
    if let peer = peerViewMainPeer(view) as? TelegramChannel {
        switch participant.participant {
        case .member(_, _, _, let banInfo):
            
            if let banInfo = banInfo {
                let restrictions:[(TelegramChannelBannedRightsFlags,String)] = [(.banReadMessages, tr(L10n.channelBlockUserCanReadMessages)), (.banSendMessages, tr(L10n.channelBlockUserCanSendMessages)), (.banSendMedia, tr(L10n.channelBlockUserCanSendMedia)), ([.banSendStickers], tr(L10n.channelBlockUserCanSendStickers)), (.banEmbedLinks, tr(L10n.channelBlockUserCanEmbedLinks))]
                let currentRightsFlags: TelegramChannelBannedRightsFlags
                if let updatedFlags = state.updatedFlags {
                    currentRightsFlags = updatedFlags
                } else {
                    currentRightsFlags = banInfo.rights.flags
                }
                
                for restriction in restrictions {
                    entries.append(.rightItem(sectionId, index, restriction.1, restriction.0, currentRightsFlags, !currentRightsFlags.contains(restriction.0) && !currentRightsFlags.contains(.banReadMessages), peer.hasAdminRights(.canBanUsers)))
                    index += 1
                }
            }
        default:
            break
        }
    }
    
    
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    entries.append(.blockFor(sectionId, index, state.until))
    index += 1
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    return entries
}

fileprivate func prepareTransition(left:[RestrictedEntry], right: [RestrictedEntry], initialSize:NSSize, arguments:RestrictedControllerArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

class RestrictedModalViewController: TableModalViewController {
    private let participant:RenderedChannelParticipant
    private let account:Account
    private let disposable = MetaDisposable()
    private let peerId:PeerId
    private let stateValue:Atomic<RestrictedControllerState> = Atomic(value: RestrictedControllerState())
    private let unban: Bool
    private let updated:(TelegramChannelBannedRights)->Void
    init(account:Account, peerId:PeerId, participant:RenderedChannelParticipant, unban: Bool, updated: @escaping(TelegramChannelBannedRights)->Void) {
        self.participant = participant
        self.account = account
        self.unban = unban
        self.updated = updated
        self.peerId = peerId
        super.init(frame: NSMakeRect(0, 0, 300, 360))
        bar = .init(height : 0)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let participant = self.participant
        let unban = self.unban
        let stateValue = self.stateValue
        let statePromise = ValuePromise(RestrictedControllerState(), ignoreRepeated: true)
        let updateState: ((RestrictedControllerState) -> RestrictedControllerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }

        updateState { current in
            switch participant.participant {
            case let .member(_, _, _, banInfo):
                if let banInfo = banInfo {
                    return current.withUpdatedUpdatedFlags(banInfo.rights.flags).withUpdatedUntil(banInfo.rights.untilDate)
                }
            default:
                break
            }
            return current
        }
        
        let arguments = RestrictedControllerArguments(account: account, toggleRight: { right, flags in
            updateState { current in
                var updated = flags
                
                let banDepencies = banRightDependencies(right)
                let unbanDepencies = unbanRightDependencies(right)
                
                if flags == .banReadMessages {
                    updated = []
                    
                    for depend in banDepencies {
                        updated.insert(depend)
                    }
                } else {
                    if flags.contains(right) {
                        updated.remove(right)
                        for depend in unbanDepencies {
                            if updated.contains(depend) {
                                updated.remove(depend)
                            }
                        }
                    } else {
                        updated.insert(right)
                        for depend in banDepencies {
                            if !updated.contains(depend) {
                                updated.insert(depend)
                            }
                        }
                    }
                }
                
                
                return current.withUpdatedUpdatedFlags(updated)
            }
        }, changeUntil: { [weak self] in
            if let strongSelf = self {
                if let index = strongSelf.genericView.index(hash: RestrictedEntryStableId.blockFor) {
                    if let view = (strongSelf.genericView.viewNecessary(at: index) as? GeneralInteractedRowView)?.textView {
                        var items:[SPopoverItem] = []
                        items.append(SPopoverItem(tr(L10n.timerDaysCountable(1)), {
                            updateState {
                                $0.withUpdatedUntil(Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970 + 24 * 60 * 60))
                            }
                        }))
                        items.append(SPopoverItem(tr(L10n.timerWeeksCountable(1)), {
                            updateState {
                                $0.withUpdatedUntil(Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970 + 7 * 24 * 60 * 60))
                            }
                        }))
                        items.append(SPopoverItem(tr(L10n.timerMonthsCountable(1)), {
                            updateState {
                                $0.withUpdatedUntil(Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970 + 30 * 24 * 60 * 60))
                            }
                        }))
                        items.append(SPopoverItem(tr(L10n.channelBanForever), {
                            updateState {
                                $0.withUpdatedUntil(0)
                            }
                        }))
                        showPopover(for: view, with: SPopoverViewController(items: items), edge: .maxX, inset: NSMakePoint(view.frame.width,-10))
                    }
                }
            }
            
        })
        
        
        
        
        let previous:Atomic<[RestrictedEntry]> = Atomic(value: [])
        let initialSize = self.atomicSize
        
        let signal:Signal<(TableUpdateTransition, PeerView), Void> = combineLatest(statePromise.get(), account.viewTracker.peerView(peerId)) |> deliverOn(prepareQueue) |> map { state, view in
            return (RestrictedEntries(state: state, participant: participant, view: view), view)
        } |> map { entries, view in
            return (prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments), view)
        } |> deliverOnMainQueue
        let animated:Atomic<Bool> = Atomic(value: false)
        disposable.set(signal.start(next: { [weak self] transition, view in
            self?.genericView.merge(with: transition)
            self?.updateSize(animated.swap(true))
            self?.readyOnce()
            self?.modal?.interactions?.updateDone({ button in
                if let peer = peerViewMainPeer(view) as? TelegramChannel {
                    button.isEnabled = peer.hasAdminRights(.canBanUsers)
                }
            })
            self?.modal?.interactions?.updateCancel({ button in
                if unban {
                    button.set(text: tr(L10n.channelBlacklistUnban), for: .Normal)
                    button.set(color: theme.colors.redUI, for: .Normal)
                } else {
                    button.set(text: "", for: .Normal)
                }
            })
        }))
        
        
    }
    
    deinit {
        disposable.dispose()
    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: tr(L10n.modalOK), accept: { [weak self] in
            if let strongSelf = self {
                strongSelf.close()
                switch strongSelf.participant.participant {
                case let .member(_, _, _, banInfo):
                    if let banInfo = banInfo {
                        let state = strongSelf.stateValue.modify({$0})
                        let flags = state.updatedFlags ?? banInfo.rights.flags
                        strongSelf.updated(TelegramChannelBannedRights(flags: flags, untilDate: state.until))
                    }
                default:
                    break
                }
                
            }
        }, cancelTitle: tr(L10n.modalCancel), cancel: { [weak self] in
            self?.close()
            self?.updated(TelegramChannelBannedRights(flags: [], untilDate: 0))
        }, drawBorder: true, height: 40)
    }
    
}
