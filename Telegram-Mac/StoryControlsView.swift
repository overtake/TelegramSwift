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

private let privacy_close_friends = NSImage(named: "Icon_StoryCloseFriends")!.precomposed()
private let privacy_contacts = NSImage(named: "Icon_Story_Contacts")!.precomposed()
private let privacy_selected_contacts = NSImage(named: "Icon_Story_Selected_Contacts")!.precomposed()

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
        avatar.setFrameSize(NSMakeSize(32, 32))
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
        
        
        muted.set(handler: { [weak self] _ in
            if self?.hasNoSound == true {
                self?.arguments?.showTooltipText(strings().storyControlsVideoNoSound, MenuAnimation.menu_speaker_muted)
            } else {
                self?.arguments?.interaction.toggleMuted()
            }
        }, for: .Click)
        
        more.contextMenu = { [weak self] in
            if let story = self?.story, let arguments = self?.arguments {
                return arguments.storyContextMenu(story)
            }
            return nil
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
            if let story = self?.story {
                self?.arguments?.showFriendsTooltip(control, story)
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
    
    func update(context: AccountContext, arguments: StoryArguments, groupId: PeerId, peer: Peer?, slice: StoryContentContextState.FocusedSlice, story: StoryContentItem, animated: Bool) {
        guard let peer = peer else {
            return
        }
        self.story = story
        self.groupId = groupId
        self.arguments = arguments
        avatar.setPeer(account: context.account, peer: peer)
        
        closeFriends.isHidden = !story.storyItem.isCloseFriends && !story.storyItem.isSelectedContacts && !story.storyItem.isContacts
        
        if story.storyItem.isCloseFriends {
            closeFriends.set(image: privacy_close_friends, for: .Normal)
        } else if story.storyItem.isSelectedContacts {
            closeFriends.set(image: privacy_selected_contacts, for: .Normal)
        } else if story.storyItem.isContacts {
            closeFriends.set(image: privacy_contacts, for: .Normal)
        }
        closeFriends.sizeToFit(.zero, NSMakeSize(24, 24), thatFit: true)

        
        
        let date = NSMutableAttributedString()
        let color = NSColor.white.withAlphaComponent(0.8)
        if story.storyItem.expirationTimestamp < context.timestamp {
            date.append(string: stringForFullDate(timestamp: story.storyItem.timestamp), color: color, font: .medium(.small))
        } else {
            date.append(string: DateUtils.string(forRelativeLastSeen: story.storyItem.timestamp), color: color, font: .medium(.small))
        }
        if story.storyItem.isEdited {
            date.append(string: " \(strings().bullet) ", color: color, font: .medium(.small))
            date.append(string: strings().storyControlsEdited, color: color, font: .medium(.short))
        }
        
        if hasNoSound {
            muted.set(image: cant_unmute, for: .Normal)
        } else {
            muted.set(image: arguments.interaction.presentation.isMuted ? muted_image : unmuted_image, for: .Normal)
        }
        muted.isHidden = !arguments.interaction.canBeMuted(story.storyItem)
        more.isHidden = context.peerId == groupId

        
        let textWidth = frame.width - 24 - avatar.frame.width - 20 - (muted.isHidden ? 0 : 20) - (more.isHidden ? 0 : 20) - (closeFriends.isHidden ? 0 : 20)


        let dateLayout = TextViewLayout(date, maximumNumberOfLines: 1)
        dateLayout.measure(width: textWidth)

               

        let authorName = NSMutableAttributedString()
        authorName.append(string: context.peerId == groupId ? strings().storyControlsYourStory : peer.displayTitle, color: .white, font: .medium(.title))
        
        if story.dayCounters != nil, let position = story.position {
            authorName.append(string: " \(strings().bullet) \(position + 1)/\(slice.totalCount)", color: color, font: .normal(.small))
        }

        let authorLayout = TextViewLayout(authorName, maximumNumberOfLines: 1, truncationType: .middle)
        authorLayout.measure(width: textWidth)
        
        textView.update(authorLayout)
        dateView.update(dateLayout)
        
        avatarAndText.setFrameSize(NSMakeSize(textView.frame.width + dateView.frame.width + avatar.frame.width + 10, avatar.frame.height))
        
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
        transition.updateFrame(view: userContainer, frame: NSMakeRect(0, 4, size.width, 56))
        
        transition.updateFrame(view: avatarAndText, frame: avatarAndText.centerFrameY(x: 12))
        
        transition.updateFrame(view: avatar, frame: avatar.centerFrameY(x: 0))
        transition.updateFrame(view: textView, frame: CGRect(origin: NSMakePoint(avatar.frame.maxX + 10, avatar.frame.minY), size: textView.frame.size))
        transition.updateFrame(view: dateView, frame: CGRect(origin: NSMakePoint(avatar.frame.maxX + 10, avatar.frame.maxY - dateView.frame.height), size: dateView.frame.size))

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
        

        let width = frame.width - 24 - avatar.frame.width - 20 - (muted.isHidden ? 0 : 20) - (more.isHidden ? 0 : 20) - (closeFriends.isHidden ? 0 : 20)
        
        self.textView.resize(width)
        self.dateView.resize(width)

        self.updateLayout(size: frame.size, transition: .immediate)
    }
}
