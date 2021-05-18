//
//  GroupCallPeerAvatarRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 09.03.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import SyncCore

final class GroupCallPeerAvatarRowItem : GeneralRowItem {
    fileprivate let account: Account
    fileprivate let peer: Peer
    fileprivate let nameLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, account: Account, peer: Peer, viewType: GeneralViewType, customTheme: GeneralRowItem.Theme) {
        self.account = account
        self.peer = peer
        self.nameLayout = TextViewLayout(.initialize(string: peer.displayTitle, color: customTheme.textColor, font: .medium(.title)))
        super.init(initialSize, stableId: stableId, viewType: viewType, customTheme: customTheme)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        nameLayout.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right)
        
        return true
    }
    
    override var height: CGFloat {
        return 180
    }
    
    override var hasBorder: Bool {
        return false
    }
    
    override func viewClass() -> AnyClass {
        return GroupCallPeerAvatarRowView.self
    }
}


private final class GroupCallPeerAvatarRowView: GeneralContainableRowView {
    private let imageView: TransformImageView = TransformImageView()
    private let nameView = TextView()
    private let shadowView = ShadowView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        
        
        shadowView.direction = .vertical(true)
        shadowView.shadowBackground = NSColor.black.withAlphaComponent(0.4)
        self.addSubview(shadowView)
        
        addSubview(nameView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? GeneralRowItem else {
            return
        }
        imageView.frame = containerView.bounds
        nameView.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left, imageView.frame.maxY - nameView.frame.height - item.viewType.innerInset.top))
        shadowView.frame = NSMakeRect(0, containerView.frame.height - 50, containerView.frame.width, 50)
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? GroupCallPeerAvatarRowItem else {
            return
        }
        
        nameView.update(item.nameLayout)
        
        let profileImageRepresentations:[TelegramMediaImageRepresentation]
        if let peer = item.peer as? TelegramChannel {
            profileImageRepresentations = peer.profileImageRepresentations
        } else if let peer = item.peer as? TelegramUser {
            profileImageRepresentations = peer.profileImageRepresentations
        } else if let peer = item.peer as? TelegramGroup {
            profileImageRepresentations = peer.profileImageRepresentations
        } else {
            profileImageRepresentations = []
        }
        
        let id = profileImageRepresentations.first?.resource.id.hashValue ?? Int(item.peer.id.toInt64())
        let media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: MediaId.Id(id)), representations: profileImageRepresentations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        
        layout()
        
        
        if let dimension = profileImageRepresentations.last?.dimensions.size {
            
            
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: dimension, boundingSize: NSMakeSize(item.blockWidth, item.height), intrinsicInsets: NSEdgeInsets())
            self.imageView.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: self.backingScaleFactor), clearInstantly: false)
            self.imageView.setSignal(chatMessagePhoto(account: item.account, imageReference: ImageMediaReference.standalone(media: media), peer: item.peer, scale: self.backingScaleFactor), clearInstantly: false, animate: true, cacheImage: { result in
                cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale)
            })
            self.imageView.set(arguments: arguments)
            
            if let reference = PeerReference(item.peer) {
                _ = fetchedMediaResource(mediaBox: item.account.postbox.mediaBox, reference: .avatar(peer: reference, resource: media.representations.last!.resource)).start()
            }
        } else {
            self.imageView.setSignal(signal: generateEmptyRoundAvatar(self.imageView.frame.size, font: .avatar(90.0), account: item.account, peer: item.peer) |> map { TransformImageResult($0, true) })
        }
    }
}
