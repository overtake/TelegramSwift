//
//  DeleteSupergroupMessagesModalController.swift
//  Telegram
//
//  Created by keepcoder on 11/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac


struct DeleteSupergroupMessagesSet : OptionSet {
    
    var rawValue: UInt32
    
    init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    init() {
        self.rawValue = 0
    }
    
    public init(_ flags: DeleteSupergroupMessagesSet) {
        var rawValue: UInt32 = 0
        
        if flags.contains(DeleteSupergroupMessagesSet.deleteMessages) {
            rawValue |= DeleteSupergroupMessagesSet.deleteMessages.rawValue
        }
        
        if flags.contains(DeleteSupergroupMessagesSet.banUser) {
            rawValue |= DeleteSupergroupMessagesSet.banUser.rawValue
        }
        
        if flags.contains(DeleteSupergroupMessagesSet.reportSpam) {
            rawValue |= DeleteSupergroupMessagesSet.reportSpam.rawValue
        }
        
        if flags.contains(DeleteSupergroupMessagesSet.deleteAllMessages) {
            rawValue |= DeleteSupergroupMessagesSet.deleteAllMessages.rawValue
        }
        
        self.rawValue = rawValue
    }

    
    static let deleteMessages = DeleteSupergroupMessagesSet(rawValue: 1)
    static let banUser = DeleteSupergroupMessagesSet(rawValue: 2)
    static let reportSpam = DeleteSupergroupMessagesSet(rawValue: 4)
    static let deleteAllMessages = DeleteSupergroupMessagesSet(rawValue: 8)
}

class DeleteSupergroupMessagesModalController: TableModalViewController {
    private let peerId:PeerId
    private let messageIds:[MessageId]
    private let account:Account
    private let memberId:PeerId
    private var options:DeleteSupergroupMessagesSet = DeleteSupergroupMessagesSet(.deleteMessages)
    private let onComplete:()->Void
    private let peerViewDisposable = MetaDisposable()
    init(account:Account, messageIds:[MessageId], peerId:PeerId, memberId: PeerId, onComplete: @escaping() -> Void) {
        self.account = account
        self.messageIds = messageIds
        self.peerId = peerId
        self.memberId = memberId
        self.onComplete = onComplete
        super.init(frame: NSMakeRect(0, 0, 280, 260))
        bar = .init(height: 0)
    }
    
    
    deinit {
        peerViewDisposable.dispose()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let initialSize = atomicSize.modify({$0})
        
        let update: Promise<Void> = Promise(Void())
        
        peerViewDisposable.set(combineLatest(account.viewTracker.peerView( peerId) |> take(1) |> deliverOnMainQueue, update.get()).start(next: { [weak self] peerView, _ in
            if let strongSelf = self, let peer = peerViewMainPeer(peerView) as? TelegramChannel {
                
                _ = strongSelf.genericView.removeAll()
                
                _ = strongSelf.genericView.addItem(item: GeneralRowItem(initialSize, height: 20, stableId: 0))
                
                _ = strongSelf.genericView.addItem(item: GeneralInteractedRowItem(initialSize, stableId: 1, name: tr(L10n.supergroupDeleteRestrictionDeleteMessage), type: .selectable(strongSelf.options.contains(.deleteMessages)), action: { [weak strongSelf] in
                    if let strongSelf = strongSelf {
                        if !strongSelf.options.isEmpty {
                            strongSelf.options.remove(.deleteMessages)
                        }
                        update.set(.single(Void()))
                    }
                }))
                
                if peer.hasAdminRights(.canBanUsers) {
                    _ = strongSelf.genericView.addItem(item: GeneralInteractedRowItem(initialSize, stableId: 2, name: tr(L10n.supergroupDeleteRestrictionBanUser), type: .selectable(strongSelf.options.contains(.banUser)), action: { [weak strongSelf] in
                        if let strongSelf = strongSelf {
                            if strongSelf.options.contains(.banUser) {
                                strongSelf.options.remove(.banUser)
                                if strongSelf.options.isEmpty {
                                    strongSelf.options.insert(.deleteMessages)
                                }
                            } else {
                                strongSelf.options.insert(.banUser)
                            }
                            update.set(.single(Void()))
                        }
                    }))
                }
               
                _ = strongSelf.genericView.addItem(item: GeneralInteractedRowItem(initialSize, stableId: 3, name: tr(L10n.supergroupDeleteRestrictionReportSpam), type: .selectable(strongSelf.options.contains(.reportSpam)), action: { [weak strongSelf] in
                    if let strongSelf = strongSelf {
                        if strongSelf.options.contains(.reportSpam) {
                            strongSelf.options.remove(.reportSpam)
                            if strongSelf.options.isEmpty {
                                strongSelf.options.insert(.deleteMessages)
                            }
                        } else {
                            strongSelf.options.insert(.reportSpam)
                        }
                        strongSelf.genericView.reloadData()
                        update.set(.single(Void()))
                    }
                }))
                
                _ = strongSelf.genericView.addItem(item: GeneralInteractedRowItem(initialSize, stableId: 4, name: tr(L10n.supergroupDeleteRestrictionDeleteAllMessages), type: .selectable(strongSelf.options.contains(.deleteAllMessages)), action: { [weak strongSelf] in
                    if let strongSelf = strongSelf {
                        if strongSelf.options.contains(.deleteAllMessages) {
                            strongSelf.options.remove(.deleteAllMessages)
                            if strongSelf.options.isEmpty {
                                strongSelf.options.insert(.deleteMessages)
                            }
                        } else {
                            strongSelf.options.insert(.deleteAllMessages)
                        }
                        strongSelf.genericView.reloadData()
                        update.set(.single(Void()))
                    }
                }))
                
                _ = strongSelf.genericView.addItem(item: GeneralRowItem(initialSize, height: 20, stableId: 5))
                strongSelf.updateSize(false)
                strongSelf.readyOnce()
            }
        }))
    }
    
    private func perform() {
        var signals:[Signal<Void, Void>] = [deleteMessagesInteractively(postbox: account.postbox, messageIds: messageIds, type: .forEveryone)]
        if options.contains(.banUser) {
            signals.append(removePeerMember(account: account, peerId: peerId, memberId: memberId))
        }
        if options.contains(.reportSpam) {
            signals.append(reportSupergroupPeer(account: account, peerId: memberId, memberId: memberId, messageIds: messageIds))
        }
        if options.contains(.deleteAllMessages) {
            signals.append(clearAuthorHistory(account: account, peerId: peerId, memberId: memberId))
        }
        _ = combineLatest(signals).start()
        onComplete()
        close()
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        perform()
        close()
        return .invoked
    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: tr(L10n.modalOK), accept: { [weak self] in
            self?.perform()
        }, cancelTitle: tr(L10n.modalCancel), drawBorder: true, height: 40)
    }
    
    
    
}
