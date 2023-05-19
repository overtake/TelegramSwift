//
//  DeleteSupergroupMessagesModalController.swift
//  Telegram
//
//  Created by keepcoder on 11/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import Postbox
import SwiftSignalKit


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
    private let context:AccountContext
    private let memberId:PeerId
    private var options:DeleteSupergroupMessagesSet = DeleteSupergroupMessagesSet(.deleteMessages)
    private let onComplete:()->Void
    private let peerViewDisposable = MetaDisposable()
    init(context: AccountContext, messageIds:[MessageId], peerId:PeerId, memberId: PeerId, onComplete: @escaping() -> Void) {
        self.context = context
        self.messageIds = messageIds
        self.peerId = peerId
        self.memberId = memberId
        self.onComplete = onComplete
        super.init(frame: NSMakeRect(0, 0, 350, 260))
        bar = .init(height: 0)
    }
    
    
    deinit {
        peerViewDisposable.dispose()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let initialSize = atomicSize.modify({$0})
        
        let update: Promise<Void> = Promise(Void())
        
        peerViewDisposable.set(combineLatest(context.account.viewTracker.peerView( peerId) |> take(1) |> deliverOnMainQueue, update.get()).start(next: { [weak self] peerView, _ in
            if let strongSelf = self, let peer = peerViewMainPeer(peerView) as? TelegramChannel {
                
                _ = strongSelf.genericView.removeAll()
                
                _ = strongSelf.genericView.addItem(item: GeneralRowItem(initialSize, height: 20, stableId: 0))
                
                _ = strongSelf.genericView.addItem(item: GeneralInteractedRowItem(initialSize, stableId: 1, name: strings().supergroupDeleteRestrictionDeleteMessage, type: .selectable(strongSelf.options.contains(.deleteMessages)), action: { [weak strongSelf] in
                    if let strongSelf = strongSelf {
                        if !strongSelf.options.isEmpty {
                            strongSelf.options.remove(.deleteMessages)
                        }
                        update.set(.single(Void()))
                    }
                }))
                
                if peer.hasPermission(.banMembers) {
                    _ = strongSelf.genericView.addItem(item: GeneralInteractedRowItem(initialSize, stableId: 2, name: strings().supergroupDeleteRestrictionBanUser, type: .selectable(strongSelf.options.contains(.banUser)), action: { [weak strongSelf] in
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
               
                _ = strongSelf.genericView.addItem(item: GeneralInteractedRowItem(initialSize, stableId: 3, name: strings().supergroupDeleteRestrictionReportSpam, type: .selectable(strongSelf.options.contains(.reportSpam)), action: { [weak strongSelf] in
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
                
                _ = strongSelf.genericView.addItem(item: GeneralInteractedRowItem(initialSize, stableId: 4, name: strings().supergroupDeleteRestrictionDeleteAllMessages, type: .selectable(strongSelf.options.contains(.deleteAllMessages)), action: { [weak strongSelf] in
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
        var signals:[Signal<Void, NoError>] = [context.engine.messages.deleteMessagesInteractively(messageIds: messageIds, type: .forEveryone)]
        if options.contains(.banUser) {
            
            signals.append(context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(peerId: peerId, memberId: memberId, bannedRights: TelegramChatBannedRights(flags: [.banReadMessages], untilDate: Int32.max)))
        }
        if options.contains(.reportSpam) {
            signals.append(context.engine.peers.reportPeerMessages(messageIds: messageIds, reason: .spam, message: ""))
        }
        if options.contains(.deleteAllMessages) {
            signals.append(context.engine.messages.clearAuthorHistory(peerId: peerId, memberId: memberId))
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
        return ModalInteractions(acceptTitle: strings().modalOK, accept: { [weak self] in
            self?.perform()
        }, cancelTitle: strings().modalCancel, drawBorder: true, height: 40)
    }
    
    
    
}
