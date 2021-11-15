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
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, photo: TelegramMediaImageRepresentation?, title: String, about: String?, participantsCount: Int, isChannelOrMegagroup: Bool, viewType: GeneralViewType) {
        self.context = context
        self.photo = photo
        
        self.titleLayout = TextViewLayout(.initialize(string: title, color: theme.colors.text, font: .medium(.header)), maximumNumberOfLines: 1, truncationType: .middle)
        
        
        self.peer = TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(0)), title: title, photo: [photo].compactMap { $0 }, participantCount: 0, role: .member, membership: .Left, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)

        
        let countText: String
        if isChannelOrMegagroup {
            countText = strings().peerStatusSubscribersCountable(participantsCount).replacingOccurrences(of: "\(participantsCount)", with: participantsCount.formattedWithSeparator)
        } else {
            countText = strings().peerStatusMemberCountable(participantsCount).replacingOccurrences(of: "\(participantsCount)", with: participantsCount.formattedWithSeparator)
        }
        
        self.statusLayout = TextViewLayout(.initialize(string: countText, color: theme.colors.grayText, font: .normal(.text)), alignment: .center)

        if let about = about {
            self.aboutLayout = TextViewLayout(.initialize(string: about, color: theme.colors.text, font: .normal(.text)), alignment: .center)
        } else {
            self.aboutLayout = nil
        }

        
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override var height: CGFloat {
        let top = self.viewType.innerInset.top
        
        var height = top + 80 + top + self.titleLayout.layoutSize.height + self.statusLayout.layoutSize.height + top
        if let about = aboutLayout {
            height += top + about.layoutSize.height
        }
        
        return height
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.titleLayout.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right)
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
    
    override func layout() {
        super.layout()
        
        guard let item = item as? GeneralRowItem else {
            return
        }
        let top = item.viewType.innerInset.top
        avatar.centerX(y: top)
        titleView.centerX(y: avatar.frame.maxY + top)
        statusView.centerX(y: titleView.frame.maxY)
        aboutView.centerX(y: statusView.frame.maxY + top)
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
        needsLayout = true
    }
}
