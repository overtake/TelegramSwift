//
//  DiscussionSetModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/05/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac


private final class DiscussionSetView : View {
    private let channelPhoto: AvatarControl = AvatarControl(font: .avatar(22))
    private let groupPhoto: AvatarControl = AvatarControl(font: .avatar(22))
    private let photoContainer: View = View()
    private let textView: TextView = TextView()
    private let maskView: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(photoContainer)
        channelPhoto.setFrameSize(NSMakeSize(60, 60))
        groupPhoto.setFrameSize(NSMakeSize(60, 60))
        maskView.setFrameSize(NSMakeSize(64, 64))
        maskView.layer?.cornerRadius = maskView.frame.height / 2
        maskView.layer?.borderWidth = (maskView.frame.width - groupPhoto.frame.width) / 2
        maskView.layer?.borderColor = theme.colors.background.cgColor
        photoContainer.addSubview(channelPhoto)
        photoContainer.addSubview(groupPhoto)
        photoContainer.addSubview(maskView)
        
        photoContainer.setFrameSize(NSMakeSize(groupPhoto.frame.width + channelPhoto.frame.width - 10, maskView.frame.height))
        textView.isSelectable = false
        textView.userInteractionEnabled = false
        addSubview(textView)
    }
    
    override func layout() {
        super.layout()
        
        photoContainer.centerX(y: 20)
        groupPhoto.centerY(x: 2)
        channelPhoto.centerY(x: channelPhoto.frame.maxX - 10)
        textView.centerX(y: photoContainer.frame.maxY + 20)
    }
    
    func update(context: AccountContext, channel: Peer, group: Peer) -> NSSize {
        channelPhoto.setPeer(account: context.account, peer: channel)
        groupPhoto.setPeer(account: context.account, peer: group)
        
        let attributedString = NSMutableAttributedString()
        if channel.addressName == nil {
            _ = attributedString.append(string: L10n.discussionSetModalTextPrivate(group.displayTitle, channel.displayTitle), color: theme.colors.text, font: .normal(.text))
        } else {
            _ = attributedString.append(string: L10n.discussionSetModalTextPublic(group.displayTitle, channel.displayTitle), color: theme.colors.text, font: .normal(.text))
        }
        attributedString.detectBoldColorInString(with: .medium(.text))
        
        let layout = TextViewLayout(attributedString, alignment: .center)
        layout.measure(width: 300 - 40)
        
        textView.update(layout)
        
        return NSMakeSize(300, textView.frame.height + photoContainer.frame.height + 20 + 20 + 20)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class DiscussionSetModalController: ModalViewController {

    private let context: AccountContext
    private let channel: Peer
    private let group:Peer
    private let accept:()->Void
    init(context: AccountContext, channel: Peer, group:Peer, accept:@escaping()->Void) {
        self.context = context
        self.channel = channel
        self.group = group
        self.accept = accept
        super.init(frame: NSMakeRect(0, 0, 300, 300))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let size = genericView.update(context: self.context, channel: self.channel, group: self.group)
        modal?.resize(with: size, animated: false)
        readyOnce()
    }
    
    private var genericView:DiscussionSetView {
        return self.view as! DiscussionSetView
    }
    
    override func viewClass() -> AnyClass {
        return DiscussionSetView.self
    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: L10n.discussionSetModalOK, accept: { [weak self] in
            self?.close()
            self?.accept()
        }, cancelTitle: L10n.modalCancel, drawBorder: false, height: 50)
    }
}
