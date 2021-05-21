//
//  GroupCallContextMenuHeader.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 20.05.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit

final class GroupCallContextMenuHeaderView : View {
    private let imageView: TransformImageView
    private let nameView = TextView()
    private var descView: TextView?
    required init(frame frameRect: NSRect) {
        imageView = TransformImageView(frame: frameRect.size.bounds.insetBy(dx: 5, dy: 0))
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(nameView)
        imageView.layer?.cornerRadius = 4
    }
    
    override func layout() {
        super.layout()
        imageView.frame = NSMakeSize(frame.width, 200).bounds.insetBy(dx: 5, dy: 0)
        nameView.setFrameOrigin(NSMakePoint(14, imageView.frame.maxY + 5))
        descView?.setFrameOrigin(NSMakePoint(14, nameView.frame.maxY + 3))
    }
    
    func setPeer(_ peer: Peer, about: String?, account: Account) {
        
        let name = TextViewLayout(.initialize(string: peer.displayTitle, color: GroupCallTheme.customTheme.textColor, font: .medium(.text)), maximumNumberOfLines: 2)
        name.measure(width: frame.width - 28)
        
        nameView.update(name)
        
        if let about = about {
            self.descView = TextView()
            addSubview(self.descView!)
            let desc = TextViewLayout(.initialize(string: about, color: GroupCallTheme.customTheme.grayTextColor, font: .normal(.text)))
            desc.measure(width: frame.width - 28)
            self.descView?.update(desc)

        } else {
            self.descView?.removeFromSuperview()
            self.descView = nil
        }
        
        let profileImageRepresentations:[TelegramMediaImageRepresentation]
        if let peer = peer as? TelegramChannel {
            profileImageRepresentations = peer.profileImageRepresentations
        } else if let peer = peer as? TelegramUser {
            profileImageRepresentations = peer.profileImageRepresentations
        } else if let peer = peer as? TelegramGroup {
            profileImageRepresentations = peer.profileImageRepresentations
        } else {
            profileImageRepresentations = []
        }
        
        let id = profileImageRepresentations.first?.resource.id.hashValue ?? Int(peer.id.toInt64())
        let media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: MediaId.Id(id)), representations: profileImageRepresentations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                
        
        if let dimension = profileImageRepresentations.last?.dimensions.size {
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: dimension, boundingSize: frame.size, intrinsicInsets: NSEdgeInsets())
            self.imageView.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: self.backingScaleFactor), clearInstantly: false)
            self.imageView.setSignal(chatMessagePhoto(account: account, imageReference: ImageMediaReference.standalone(media: media), peer: peer, scale: self.backingScaleFactor), clearInstantly: false, animate: true, cacheImage: { result in
                cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale)
            })
            self.imageView.set(arguments: arguments)
            
            if let reference = PeerReference(peer) {
                _ = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: .avatar(peer: reference, resource: media.representations.last!.resource)).start()
            }
        } else {
            self.imageView.setSignal(signal: generateEmptyRoundAvatar(self.imageView.frame.size, font: .avatar(90.0), account: account, peer: peer) |> map { TransformImageResult($0, true) })
        }
        
        setFrameSize(NSMakeSize(frame.width, 200 + name.layoutSize.height + 10 + (descView != nil ? descView!.frame.height + 3 : 0)))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
