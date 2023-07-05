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
private let cant_unmute = NSImage(named: "Icon_StoryMute")!.precomposed(NSColor.white.withAlphaComponent(0.75))


private let unmuted_image = NSImage(named: "Icon_StoryUnmute")!.precomposed(NSColor.white)


final class StoryControlsView : Control {
    private let avatar = AvatarControl(font: .avatar(13))
    private let textView = TextView()
    private let dateView = TextView()
    private let userContainer = View()
    private let more = ImageButton()
    private let muted = ImageButton()
    private let closeFriends = ImageButton()

    private let avatarAndText = Control()
    
    private var arguments: StoryArguments?
    private var groupId: PeerId?
    private var story: StoryContentItem?
    
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
        userContainer.addSubview(closeFriends)
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

        closeFriends.scaleOnClick = true
        closeFriends.autohighlight = false
        
        more.set(image: more_image, for: .Normal)
        more.sizeToFit(.zero, NSMakeSize(24, 24), thatFit: true)
        
        muted.set(image: muted_image, for: .Normal)
        muted.sizeToFit(.zero, NSMakeSize(24, 24), thatFit: true)
        
        
        closeFriends.set(image: NSImage(named: "Icon_StoryCloseFriends")!.precomposed(), for: .Normal)
        closeFriends.sizeToFit(.zero, NSMakeSize(24, 24), thatFit: true)

        muted.set(handler: { [weak self] _ in
            if self?.hasNoSound == true {
                self?.arguments?.showTooltipText("This video has no sound", MenuAnimation.menu_speaker_muted)
            } else {
                self?.arguments?.interaction.toggleMuted()
            }
        }, for: .Click)
        
        more.contextMenu = { [weak self] in
            
            let menu = ContextMenu(presentation: AppMenu.Presentation.current(storyTheme.colors))
            if let story = self?.story, let peer = story.peer, let peerId = story.peerId {
                if peer._asPeer().storyArchived {
                    menu.addItem(ContextMenuItem("Unhide \(peer._asPeer().compactDisplayTitle)", handler: { [weak self] in
                        self?.arguments?.toggleHide(peer._asPeer(), false)
                    }, itemImage: MenuAnimation.menu_show_message.value))

                } else {
                    menu.addItem(ContextMenuItem("Hide \(peer._asPeer().compactDisplayTitle)", handler: {
                        self?.arguments?.toggleHide(peer._asPeer(), true)
                    }, itemImage: MenuAnimation.menu_move_to_contacts.value))
                }

                let report = ContextMenuItem("Report", itemImage: MenuAnimation.menu_report.value)
                
                let submenu = ContextMenu()
                            
                let options:[ReportReason] = [.spam, .violence, .porno, .childAbuse, .copyright, .personalDetails, .illegalDrugs]
                let animation:[LocalAnimatedSticker] = [.menu_delete, .menu_violence, .menu_pornography, .menu_restrict, .menu_copyright, .menu_open_profile, .menu_drugs]
                
                for i in 0 ..< options.count {
                    submenu.addItem(ContextMenuItem(options[i].title, handler: { [weak self] in
                        self?.arguments?.report(peerId, story.storyItem.id, options[i])
                    }, itemImage: animation[i].value))
                }
                report.submenu = submenu
                menu.addItem(report)
            }
            

            return menu
        }
        
        avatarAndText.scaleOnClick = true
        
        avatarAndText.set(handler: { [weak self] control in
            if let groupId = self?.groupId {
                self?.arguments?.openPeerInfo(groupId, control)
            }
        }, for: .Click)
        
        avatar.userInteractionEnabled = false
        textView.userInteractionEnabled = false
     
        closeFriends.set(handler: { [weak self] control in
            if let peer = self?.story?.peer {
                self?.arguments?.showFriendsTooltip(control, peer._asPeer())
            }
        }, for: .Click)
        
    }
    
    var hasNoSound: Bool {
        guard let story = self.story, let arguments = self.arguments else {
            return false
        }
        return arguments.interaction.hasNoSound(story.storyItem)
    }
    
    func updateMuted(isMuted: Bool) {
        guard let story = self.story, let arguments = self.arguments else {
            return
        }
        if arguments.interaction.hasNoSound(story.storyItem) {
            muted.set(image: cant_unmute, for: .Normal)
        } else {
            muted.set(image: isMuted ? muted_image : unmuted_image, for: .Normal)
        }
    }
    
    func update(context: AccountContext, arguments: StoryArguments, groupId: PeerId, peer: Peer?, story: StoryContentItem, animated: Bool) {
        guard let peer = peer else {
            return
        }
        self.story = story
        self.groupId = groupId
        self.arguments = arguments
        avatar.setPeer(account: context.account, peer: peer)
        
        closeFriends.isHidden = !story.storyItem.isCloseFriends
        
        let date = NSMutableAttributedString()
        date.append(string: " \(strings().bullet) ", color: NSColor.white.withAlphaComponent(0.8), font: .medium(.short))
        date.append(string: DateUtils.string(forRelativeLastSeen: story.storyItem.timestamp), color: NSColor.white.withAlphaComponent(0.8), font: .medium(.short))

        let dateLayout = TextViewLayout(date, maximumNumberOfLines: 1)
        dateLayout.measure(width: frame.width / 2)

        if hasNoSound {
            muted.set(image: cant_unmute, for: .Normal)
        } else {
            muted.set(image: arguments.interaction.presentation.isMuted ? muted_image : unmuted_image, for: .Normal)
        }
        muted.isHidden = !arguments.interaction.canBeMuted(story.storyItem)
        more.isHidden = context.peerId == groupId
        closeFriends.isHidden = !story.storyItem.isCloseFriends
        
        let authorWidth = frame.width - dateLayout.layoutSize.width - more.frame.width - muted.frame.width - avatar.frame.width - 10 - (muted.isHidden ? 0 : 12) - (more.isHidden ? 0 : 12) - (closeFriends.isHidden ? 0 : 12)
        
        let authorName = NSMutableAttributedString()
        authorName.append(string: context.peerId == groupId ? "My Story" : peer.compactDisplayTitle, color: .white, font: .medium(.title))

        
        let authorLayout = TextViewLayout(authorName, maximumNumberOfLines: 1, truncationType: .middle)
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

        var controlX = size.width
        
        if !more.isHidden {
            controlX -= (more.frame.width + 5)
            transition.updateFrame(view: more, frame: more.centerFrameY(x: controlX))
        }
        
        if !closeFriends.isHidden {
            controlX -= (closeFriends.frame.width + 5)
            transition.updateFrame(view: closeFriends, frame: closeFriends.centerFrameY(x: controlX))
        }
        if !muted.isHidden {
            controlX -= (muted.frame.width + 5)
            transition.updateFrame(view: muted, frame: muted.centerFrameY(x: controlX))
        }
    }
    
    override func layout() {
        super.layout()
        
        dateView.resize(frame.width / 2)

        let width = frame.width - dateView.frame.width - more.frame.width - muted.frame.width - avatar.frame.width - 10 - (muted.isHidden ? 0 : 12) - (more.isHidden ? 0 : 12)
        
        self.textView.resize(width)

        self.updateLayout(size: frame.size, transition: .immediate)
    }
}
