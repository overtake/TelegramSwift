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
import DateUtils

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
    
    private let avatarAndText = Control()
    
    private var arguments: StoryArguments?
    private var groupId: PeerId?
    private var story: EngineStoryItem?
    
    private let shadowView = ShadowView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(shadowView)
        avatar.setFrameSize(NSMakeSize(28, 28))
        userContainer.addSubview(avatarAndText)
        avatarAndText.addSubview(avatar)
        avatarAndText.addSubview(dateView)
        avatarAndText.addSubview(textView)
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
        
        more.contextMenu = { [weak self] in
            
            let menu = ContextMenu(presentation: AppMenu.Presentation.current(storyTheme.colors))
            
            menu.addItem(ContextMenuItem("Share", handler: { [weak self] in
                if let story = self?.story {
                    self?.arguments?.share(story)
                }
            }, itemImage: MenuAnimation.menu_share.value))
            menu.addItem(ContextMenuItem("Hide", itemImage: MenuAnimation.menu_hide.value))

            menu.addItem(ContextSeparatorItem())
            menu.addItem(ContextMenuItem("Report", itemMode: .destruct, itemImage: MenuAnimation.menu_report.value))

            return menu
        }
        
        avatarAndText.scaleOnClick = true
        
        avatarAndText.set(handler: { [weak self] _ in
            if let groupId = self?.groupId {
                self?.arguments?.openPeerInfo(groupId)
            }
        }, for: .Click)
        
        avatar.userInteractionEnabled = false
        textView.userInteractionEnabled = false
        
    }
    
    func updateMuted(isMuted: Bool) {
        muted.set(image: isMuted ? muted_image : unmuted_image, for: .Normal)
    }
    
    func update(context: AccountContext, arguments: StoryArguments, groupId: PeerId, peer: Peer?, story: EngineStoryItem, animated: Bool) {
        guard let peer = peer else {
            return
        }
        self.story = story
        self.groupId = groupId
        self.arguments = arguments
        avatar.setPeer(account: context.account, peer: peer)
        

        
        let date = NSMutableAttributedString()
        date.append(string: " \(strings().bullet) ", color: NSColor.white.withAlphaComponent(0.8), font: .medium(.short))
        date.append(string: DateUtils.string(forRelativeLastSeen: story.timestamp), color: NSColor.white.withAlphaComponent(0.8), font: .medium(.short))

        let dateLayout = TextViewLayout(date)
        dateLayout.measure(width: .greatestFiniteMagnitude)

        
        muted.set(image: arguments.interaction.presentation.isMuted ? muted_image : unmuted_image, for: .Normal)
        muted.isHidden = !arguments.interaction.canBeMuted(story)
        more.isHidden = context.peerId == groupId

        
        let authorWidth = frame.width - dateLayout.layoutSize.width - more.frame.width - muted.frame.width - avatar.frame.width - 10 - (muted.isHidden ? 0 : 12) - (more.isHidden ? 0 : 12)
        
        let authorName = NSMutableAttributedString()
        authorName.append(string: context.peerId == groupId ? "My Story" : peer.compactDisplayTitle, color: .white, font: .medium(.title))

        
        var authorLayout = TextViewLayout(authorName, maximumNumberOfLines: 1, truncationType: .middle)
        authorLayout.measure(width: authorWidth)
        
        textView.update(authorLayout)
        dateView.update(dateLayout)
        
        
        avatarAndText.setFrameSize(NSMakeSize(textView.frame.width + dateView.frame.width + avatar.frame.width + 8, avatar.frame.height))
        
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        
        self.updateLayout(size: frame.size, transition: transition)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: shadowView, frame: NSMakeRect(0, 0, size.width, 74))
        transition.updateFrame(view: userContainer, frame: NSMakeRect(0, 0, size.width, 56))
        
        transition.updateFrame(view: avatarAndText, frame: avatarAndText.centerFrameY(x: 14))
        
        transition.updateFrame(view: avatar, frame: avatar.centerFrameY(x: 0))
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
