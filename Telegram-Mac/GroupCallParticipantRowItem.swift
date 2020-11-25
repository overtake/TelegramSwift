//
//  GroupCallParticipantRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/11/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import SyncCore
import Postbox
import TelegramCore

final class GroupCallParticipantRowItem : GeneralRowItem {
    private let participant: RenderedChannelParticipant
    private let state: PresentationGroupCallMemberState?
    private let audioLevel: Float?
    private let _contextMenu: ()->Signal<[ContextMenuItem], NoError>
    
    fileprivate let titleLayout: TextViewLayout
    fileprivate let statusLayout: TextViewLayout
    fileprivate let account: Account
    fileprivate let isLastItem: Bool
    init(_ initialSize: NSSize, stableId: AnyHashable, account: Account, participant: RenderedChannelParticipant, state: PresentationGroupCallMemberState?, audioLevel: Float?, isLastItem: Bool, action: @escaping()->Void, contextMenu:@escaping()->Signal<[ContextMenuItem], NoError>) {
        self.participant = participant
        self.state = state
        self.audioLevel = audioLevel
        self.account = account
        self._contextMenu = contextMenu
        self.titleLayout = TextViewLayout(.initialize(string: participant.peer.displayTitle, color: (state != nil || audioLevel != nil ? .white : GroupCallTheme.grayStatusColor), font: .medium(.text)), maximumNumberOfLines: 1)
        self.isLastItem = isLastItem
        var string:String = L10n.peerStatusRecently
        var color:NSColor = GroupCallTheme.grayStatusColor
        if let presence = participant.presences[participant.peer.id] as? TelegramUserPresence {
            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
            (string, _, _) = stringAndActivityForUserPresence(presence, timeDifference: 0, relativeTo: Int32(timestamp))
        }
        if let state = state {
            if state.isSpeaking || audioLevel != nil {
                string = "speaking"
                color = GroupCallTheme.greenStatusColor
            } else {
                string = "listening"
                color = GroupCallTheme.blueStatusColor
            }
        }
        self.statusLayout = TextViewLayout(.initialize(string: string, color: color, font: .normal(.short)), maximumNumberOfLines: 1)
        super.init(initialSize, height: 48, stableId: stableId, type: .none, viewType: .legacy, action: action, inset: NSEdgeInsetsMake(0, 12, 0, 12), enabled: true)
    }
    
    var isActivePeer: Bool {
        return state != nil || audioLevel != nil
    }
    
    var peer: Peer {
        return self.participant.peer
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        titleLayout.measure(width: width - 40 - inset.left - inset.left - inset.right - 24 - inset.right)
        statusLayout.measure(width: width - 40 - inset.left - inset.left - inset.right - 24 - inset.right)

        return true
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        return _contextMenu()
    }
    
    override func viewClass() -> AnyClass {
        return GroupCallParticipantRowView.self
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
}


private final class GroupCallParticipantRowView : TableRowView {
    private let photoView: AvatarControl = AvatarControl(font: .avatar(15))
    private let titleView: TextView = TextView()
    private var statusView: TextView?
    private let control: LAnimationButton = LAnimationButton(animation: "group_call_member_mute", size: NSMakeSize(24, 24))
    private let separator: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        photoView.setFrameSize(NSMakeSize(35, 35))
        addSubview(photoView)
        addSubview(titleView)
        addSubview(control)
        addSubview(separator)
        addSubview(control)
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? GroupCallParticipantRowItem else {
            return
        }
        photoView.centerY(x: item.inset.left)
        titleView.setFrameOrigin(NSMakePoint(photoView.frame.maxX + item.inset.left, 6))
        if let statusView = statusView {
            statusView.setFrameOrigin(NSMakePoint(photoView.frame.maxX + item.inset.left, frame.height - statusView.frame.height - 6))
        }
        if item.isLastItem {
            separator.frame = NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize)
        } else {
            separator.frame = NSMakeRect(titleView.frame.minX, frame.height - .borderSize, frame.width - titleView.frame.minX, .borderSize)
        }
        control.centerY(x: frame.width - 12 - control.frame.width)
    }
    
    override func updateColors() {
        super.updateColors()
        self.titleView.backgroundColor = backdorColor
        self.statusView?.backgroundColor = backdorColor
        self.separator.backgroundColor = GroupCallTheme.memberSeparatorColor
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? GroupCallParticipantRowItem else {
            return
        }
        titleView.update(item.titleLayout)
        photoView.setPeer(account: item.account, peer: item.peer, message: nil)
        
        photoView._change(opacity: item.isActivePeer ? 1.0 : 0.5, animated: animated)
        
        if statusView?.layout != item.statusLayout {
            if let statusView = statusView {
                if animated {
                    statusView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak statusView] _ in
                        statusView?.removeFromSuperview()
                    })
                    statusView.layer?.animateScaleSpring(from: 1, to: 0.2, duration: 0.2)
                } else {
                    statusView.removeFromSuperview()
                }
            }
            let statusView = TextView()
            statusView.userInteractionEnabled = false
            statusView.isSelectable = false
            statusView.update(item.statusLayout)
            addSubview(statusView)
            statusView.setFrameOrigin(NSMakePoint(photoView.frame.maxX + item.inset.left, frame.height - statusView.frame.height - 6))
            
            statusView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            statusView.layer?.animateScaleSpring(from: 0.2, to: 1, duration: 0.2)
            
            self.statusView = statusView
        }
        
        statusView?.update(item.statusLayout)

        
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    override var backdorColor: NSColor {
        return GroupCallTheme.membersColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
