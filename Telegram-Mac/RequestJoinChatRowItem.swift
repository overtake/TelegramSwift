//
//  RequestJoinChatRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01.10.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import TelegramCore


final class RequestJoinChatRowItem : GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let titleLayout: TextViewLayout
    fileprivate let statusLayout: TextViewLayout
    fileprivate let aboutLayout: TextViewLayout?
    
    fileprivate let photo: TelegramMediaImageRepresentation?
    fileprivate let peer: Peer
    fileprivate let flags: ExternalJoiningChatState.Invite.Flags
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, photo: TelegramMediaImageRepresentation?, title: String, about: String?, participantsCount: Int, flags: ExternalJoiningChatState.Invite.Flags, isChannelOrMegagroup: Bool, viewType: GeneralViewType) {
        self.context = context
        self.photo = photo
        self.flags = flags
        self.titleLayout = TextViewLayout(.initialize(string: title, color: theme.colors.text, font: .medium(.header)), maximumNumberOfLines: 1, truncationType: .middle)
        
        
        self.peer = TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(0)), title: title, photo: [photo].compactMap { $0 }, participantCount: 0, role: .member, membership: .Left, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)

        
        let countText: String
        if isChannelOrMegagroup {
            countText = strings().peerStatusSubscribersCountable(participantsCount).replacingOccurrences(of: "\(participantsCount)", with: participantsCount.formattedWithSeparator)
        } else {
            countText = strings().peerStatusMemberCountable(participantsCount).replacingOccurrences(of: "\(participantsCount)", with: participantsCount.formattedWithSeparator)
        }
        
        self.statusLayout = TextViewLayout(.initialize(string: countText, color: theme.colors.listGrayText, font: .normal(.text)), alignment: .center)

        if let about = about {
            self.aboutLayout = TextViewLayout(.initialize(string: about, color: theme.colors.text, font: .normal(.text)), alignment: .center)
        } else {
            self.aboutLayout = nil
        }

        
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override var height: CGFloat {
        let top = self.viewType.innerInset.top
        
        var height = 80 + self.titleLayout.layoutSize.height + self.statusLayout.layoutSize.height
        if let about = aboutLayout {
            height += top + about.layoutSize.height
        }
        
        return height + self.viewType.innerInset.top
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        let hasStatus = flags.isVerified || flags.isFake || flags.isScam
        
        self.titleLayout.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right - (hasStatus ? 30 : 0))
        self.statusLayout.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right)
        self.aboutLayout?.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right)

        return true
    }
    
    override func viewClass() -> AnyClass {
        return RequestJoinChatRowView.self
    }
}


private final class RequestJoinChatRowView : GeneralContainableRowView {
    private let avatar: AvatarControl = AvatarControl(font: .avatar(30))
    private let titleView = TextView()
    private let statusView = TextView()
    private let aboutView = TextView()
    private var statusImage: ImageView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.avatar.setFrameSize(NSMakeSize(80, 80))
        addSubview(self.avatar)
        addSubview(titleView)
        addSubview(statusView)
        addSubview(aboutView)
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        statusView.userInteractionEnabled = false
        statusView.isSelectable = false
        aboutView.userInteractionEnabled = false
        aboutView.isSelectable = false
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? GeneralRowItem else {
            return
        }
        let top = item.viewType.innerInset.top
        avatar.centerX(y: 0)
        titleView.centerX(y: avatar.frame.maxY + top, addition: statusImage != nil ? -(statusImage!.frame.width / 2 + 5) : 0)
        statusView.centerX(y: titleView.frame.maxY)
        aboutView.centerX(y: statusView.frame.maxY + top)
        
        if let statusImage = self.statusImage {
            statusImage.setFrameOrigin(NSMakePoint(titleView.frame.maxX + 5, titleView.frame.minY))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? RequestJoinChatRowItem else {
            return
        }
        self.avatar.setPeer(account: item.context.account, peer: item.peer)
        self.titleView.update(item.titleLayout)
        self.statusView.update(item.statusLayout)
        self.aboutView.update(item.aboutLayout)
        
        if item.flags.isVerified || item.flags.isScam || item.flags.isFake {
            let current: ImageView
            if let view = self.statusImage {
                current = view
            } else {
                current = ImageView()
                self.statusImage = current
                addSubview(current)
            }
            if item.flags.isScam {
                current.image = theme.icons.scam
            } else if item.flags.isFake {
                current.image = theme.icons.fake
            } else if item.flags.isVerified {
                current.image = theme.icons.verifyDialog
            }
            current.sizeToFit()
        }
        
        needsLayout = true
    }
}
