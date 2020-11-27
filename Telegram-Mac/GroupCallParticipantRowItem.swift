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
    fileprivate let data: PeerGroupCallData
    private let _contextMenu: ()->Signal<[ContextMenuItem], NoError>
    
    fileprivate let titleLayout: TextViewLayout
    fileprivate let statusLayout: TextViewLayout
    fileprivate let account: Account
    fileprivate let isLastItem: Bool
    fileprivate let state: PresentationGroupCallState
    fileprivate let isInvited: Bool
    fileprivate let invite:(PeerId)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, account: Account, state: PresentationGroupCallState, data: PeerGroupCallData, isInvited: Bool, isLastItem: Bool, action: @escaping()->Void, invite:@escaping(PeerId)->Void, contextMenu:@escaping()->Signal<[ContextMenuItem], NoError>) {
        self.data = data
        self.account = account
        self.invite = invite
        self._contextMenu = contextMenu
        self.isInvited = isInvited
        self.state = state
        self.titleLayout = TextViewLayout(.initialize(string: data.peer.displayTitle, color: (data.state != nil || data.audioLevel != nil ? .white : GroupCallTheme.grayStatusColor), font: .medium(.text)), maximumNumberOfLines: 1)
        self.isLastItem = isLastItem
        var string:String = L10n.peerStatusRecently
        var color:NSColor = GroupCallTheme.grayStatusColor
        if let presence = data.presence {
            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
            (string, _, _) = stringAndActivityForUserPresence(presence, timeDifference: 0, relativeTo: Int32(timestamp))
        }
        if let _ = data.state {
            if data.isSpeaking {
                string = L10n.voiceChatSpeaking
                color = GroupCallTheme.greenStatusColor
            } else {
                string = L10n.voiceChatListening
                color = GroupCallTheme.blueStatusColor
            }
        }
        self.statusLayout = TextViewLayout(.initialize(string: string, color: color, font: .normal(.short)), maximumNumberOfLines: 1)
        super.init(initialSize, height: 48, stableId: stableId, type: .none, viewType: .legacy, action: action, inset: NSEdgeInsetsMake(0, 12, 0, 12), enabled: true)
    }
    
    var isActivePeer: Bool {
        return data.state != nil
    }
    
    var peer: Peer {
        return data.peer
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
    private let button = ImageButton()
    private let separator: View = View()
    private let playbackAudioLevelView: VoiceBlobView
    required init(frame frameRect: NSRect) {
        playbackAudioLevelView = VoiceBlobView(
            frame: NSMakeRect(0, 0, 55, 55),
            maxLevel: 0.3,
            smallBlobRange: (0, 0),
            mediumBlobRange: (0.7, 0.8),
            bigBlobRange: (0.8, 0.9)
        )

        super.init(frame: frameRect)
        photoView.setFrameSize(NSMakeSize(35, 35))
        addSubview(playbackAudioLevelView)
        addSubview(photoView)
        addSubview(titleView)
        addSubview(separator)
        addSubview(button)
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false

        button.animates = true

        button.autohighlight = true
        button.set(handler: { [weak self] _ in
            guard let item = self?.item as? GroupCallParticipantRowItem else {
                return
            }
            item.invite(item.peer.id)
        }, for: .SingleClick)
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
        button.centerY(x: frame.width - 12 - control.frame.width)

        playbackAudioLevelView.centerY(x: 2, addition: 1)
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

        if item.isActivePeer {
            if item.data.isSpeaking {
                button.set(image: GroupCallTheme.small_speaking, for: .Normal)
            } else {
                if let muteState = item.data.state?.muteState {
                    button.set(image: GroupCallTheme.small_mute, for: .Normal)
                } else {
                    button.set(image: GroupCallTheme.small_unmute, for: .Normal)
                }
            }
        } else {
            if item.isInvited {
                button.set(image: GroupCallTheme.invitedIcon, for: .Normal)
                button.userInteractionEnabled = false
            } else {
                button.set(image: GroupCallTheme.inviteIcon, for: .Normal)
                button.userInteractionEnabled = true
            }
        }

        playbackAudioLevelView.setColor(GroupCallTheme.speakActiveColor)

        if item.data.isSpeaking {
            playbackAudioLevelView.startAnimating()
        } else {
            playbackAudioLevelView.stopAnimating()
        }
        playbackAudioLevelView.change(opacity: item.data.isSpeaking ? 1 : 0, animated: animated)

        playbackAudioLevelView.updateLevel(CGFloat(item.data.audioLevel ?? 0))

        button.sizeToFit(.zero, NSMakeSize(24, 24), thatFit: true)


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
        needsLayout = true
        
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
