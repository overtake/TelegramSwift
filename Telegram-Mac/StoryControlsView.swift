//
//  StoryControlsView.swift
//  Telegram
//
//  Created by Mike Renoir on 27.04.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit

private let more_image = NSImage(named: "Icon_StoryMore")!.precomposed(NSColor.white)
private let muted_image = NSImage(named: "Icon_StoryMute")!.precomposed(NSColor.white)
private let unmuted_image = NSImage(named: "Icon_StoryUnmute")!.precomposed(NSColor.white)


final class StoryControlsView : Control {
    private let avatar = AvatarControl(font: .avatar(13))
    private let textView = TextView()
    private let dateView = TextView()
    private let userContainer = View()
    private let more = ImageButton()
    private let muted = ImageButton()
    
    private var arguments: StoryArguments?
    private var groupId: PeerId?
    
    private let shadowView = ShadowView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(shadowView)
        avatar.setFrameSize(NSMakeSize(28, 28))
        userContainer.addSubview(avatar)
        userContainer.addSubview(dateView)
        userContainer.addSubview(textView)
        userContainer.addSubview(more)
        userContainer.addSubview(muted)
        addSubview(userContainer)
        shadowView.direction = .vertical(false)
        shadowView.shadowBackground = NSColor.black.withAlphaComponent(0.5)
        textView.userInteractionEnabled = true

        textView.isSelectable = false
        dateView.isSelectable = false
        
        more.scaleOnClick = true
        more.autohighlight = false
        
        muted.scaleOnClick = true
        muted.autohighlight = false

        
        more.set(image: more_image, for: .Normal)
        more.sizeToFit(.zero, NSMakeSize(24, 24), thatFit: true)
        
        muted.set(image: muted_image, for: .Normal)
        muted.sizeToFit(.zero, NSMakeSize(24, 24), thatFit: true)

        muted.set(handler: { [weak self] _ in
            self?.arguments?.interaction.toggleMuted()
        }, for: .Click)
        
        more.contextMenu = {
            
            let menu = ContextMenu(presentation: AppMenu.Presentation.current(storyTheme.colors))
            
            menu.addItem(ContextMenuItem("Share", itemImage: MenuAnimation.menu_share.value))
            menu.addItem(ContextMenuItem("Hide", itemImage: MenuAnimation.menu_hide.value))

            menu.addItem(ContextSeparatorItem())
            menu.addItem(ContextMenuItem("Report", itemMode: .destruct, itemImage: MenuAnimation.menu_report.value))

            return menu
        }
        
        avatar.set(handler: { [weak self] _ in
            if let groupId = self?.groupId {
                self?.arguments?.openPeerInfo(groupId)
            }
        }, for: .Click)
        
        textView.set(handler: { [weak self] _ in
            if let groupId = self?.groupId {
                self?.arguments?.openPeerInfo(groupId)
            }
        }, for: .Click)

    }
    
    func updateMuted(isMuted: Bool) {
        muted.set(image: isMuted ? muted_image : unmuted_image, for: .Normal)
    }
    
    func update(context: AccountContext, arguments: StoryArguments, groupId: PeerId, story: Message, animated: Bool) {
        guard let peer = story.author else {
            return
        }
        self.groupId = groupId
        self.arguments = arguments
        avatar.setPeer(account: context.account, peer: peer)
        
        let authorName = NSMutableAttributedString()
        
        authorName.append(string: context.peerId == groupId ? "My Story" : peer.displayTitle, color: .white, font: .medium(.title))
        
        let date = NSMutableAttributedString()

        date.append(string: " \(strings().bullet) ", color: NSColor.white.withAlphaComponent(0.8), font: .medium(.short))
        date.append(string: "24m ago", color: NSColor.white.withAlphaComponent(0.8), font: .medium(.short))
        
        
        let dateLayout = TextViewLayout(date)
        dateLayout.measure(width: .greatestFiniteMagnitude)

        
        let authorLayout = TextViewLayout(authorName, maximumNumberOfLines: 1)
        authorLayout.measure(width: frame.width - dateLayout.layoutSize.width - more.frame.width - muted.frame.width - avatar.frame.width - 20)
        
        textView.update(authorLayout)
        dateView.update(dateLayout)
        
        muted.set(image: arguments.interaction.presentation.isMuted ? muted_image : unmuted_image, for: .Normal)
        muted.isHidden = !arguments.interaction.canBeMuted(story)
        more.isHidden = context.peerId == groupId

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: shadowView, frame: NSMakeRect(0, 0, size.width, 74))
        transition.updateFrame(view: userContainer, frame: NSMakeRect(0, 0, size.width, 56))
        
        transition.updateFrame(view: avatar, frame: avatar.centerFrameY(x: 14))
        transition.updateFrame(view: textView, frame: textView.centerFrameY(x: avatar.frame.maxX + 8))
        transition.updateFrame(view: dateView, frame: dateView.centerFrameY(x: textView.frame.maxX))

        transition.updateFrame(view: more, frame: more.centerFrameY(x: size.width - more.frame.width - 5))
        transition.updateFrame(view: muted, frame: more.centerFrameY(x: (more.isHidden ? size.width : more.frame.minX) - muted.frame.width - 5))

    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: frame.size, transition: .immediate)
    }
}
