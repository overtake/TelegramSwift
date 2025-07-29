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

private let more_image = NSImage(resource: .iconStoryMore).precomposed(NSColor.white)
private let muted_image = NSImage(resource: .iconStoryMute).precomposed(NSColor.white)
private let cant_unmute = NSImage(resource: .iconStoryMute).precomposed(NSColor.white.withAlphaComponent(0.75))


private let unmuted_image = NSImage(resource: .iconStoryUnmute).precomposed(NSColor.white)

private let privacy_close_friends = NSImage(resource: .iconStoryCloseFriends).precomposed()
private let privacy_contacts = NSImage(resource: .iconStoryContacts).precomposed()
private let privacy_selected_contacts = NSImage(resource: .iconStorySelectedContacts).precomposed()
private let forward_repost = NSImage(resource: .iconStoryViewRepost).precomposed(NSColor.white)


private final class RepostView : View {
    private let imageView = ImageView()
    private var avatarView: AvatarControl?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        self.imageView.image = forward_repost
        self.imageView.sizeToFit()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(forwardInfo: EngineStoryItem.ForwardInfo, context: AccountContext, animated: Bool) {
        switch forwardInfo {
        case let .known(peer, _, _):
            let current: AvatarControl
            if let view = self.avatarView {
                current = view
            } else {
                current = AvatarControl(font: .avatar(4))
                current.setFrameSize(NSMakeSize(12, 12))
                self.avatarView = current
                addSubview(current)
            }
            current.setPeer(account: context.account, peer: peer._asPeer())
        default:
            if let view = avatarView {
                performSubviewRemoval(view, animated: animated)
                self.avatarView = nil
            }
        }
        
        let size = NSMakeSize(avatarView != nil ? 27 : 12, 16)
        
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        self.setFrameSize(size)
        self.updateLayout(size: size, transition: transition)
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: imageView, frame: self.imageView.centerFrameY(x: 0))
        if let avatar = avatarView {
            transition.updateFrame(view: avatar, frame: avatar.centerFrameY(x: self.imageView.frame.maxX + 3))
        }
    }
}

private final class AuthorView : View {
    private let avatarView: AvatarControl = AvatarControl(font: .avatar(4))
    private let nameView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        avatarView.setFrameSize(NSMakeSize(12, 12))
        addSubview(avatarView)
        addSubview(nameView)
        
        avatarView.userInteractionEnabled = false
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(peer: EnginePeer, context: AccountContext, animated: Bool) {
        avatarView.setPeer(account: context.account, peer: peer._asPeer())

        
        let layout = TextViewLayout(.initialize(string: peer._asPeer().compactDisplayTitle, color: NSColor.white.withAlphaComponent(0.8), font: .medium(.small)))
        layout.measure(width: 100)
        
        self.nameView.update(layout)
        
        let size = NSMakeSize(avatarView.frame.width + 3 + self.nameView.frame.width, 16)
        
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        self.setFrameSize(size)
        self.updateLayout(size: size, transition: transition)
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: avatarView, frame: avatarView.centerFrameY(x: 0))
        transition.updateFrame(view: nameView, frame: self.nameView.centerFrameY(x: avatarView.frame.maxX + 3))
    }
}

final class StoryControlsView : Control {
    private let avatar = AvatarControl(font: .avatar(13))
    private let textView = TextView()
    private let dateContainer = Control()
    private let dateView = TextView()
    private let userContainer = View()
    private let more = ImageButton()
    private let muted = ImageButton()
    private let privacy = ImageButton()

    private let avatarAndText = Control()
    
    private var arguments: StoryArguments?
    private var groupId: PeerId?
    private var story: StoryContentItem?
    
    private let shadowView = ShadowView()
    
    private var repostView: RepostView?
    private var authorView: AuthorView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(shadowView)
        avatar.setFrameSize(NSMakeSize(32, 32))
        userContainer.addSubview(avatarAndText)
        avatarAndText.addSubview(avatar)
        dateContainer.addSubview(dateView)
        avatarAndText.addSubview(dateContainer)
        avatarAndText.addSubview(textView)
        userContainer.addSubview(more)
        userContainer.addSubview(privacy)
        userContainer.addSubview(muted)
        
        avatarAndText.layer?.masksToBounds = false
        

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

        privacy.scaleOnClick = true
        privacy.autohighlight = false
        
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
        
        muted.contextMenu = { [weak self] in
            let menu = ContextMenu()
            menu.name = "volume"
            menu.addItem(SliderContextMenuItem(volume: CGFloat(FastSettings.volumeStoryRate), minValue: 0, maxValue: 1.0, midValue: 0.5, drawable: MenuAnimation.menu_speaker, drawable_muted: MenuAnimation.menu_speaker_muted, { value, _ in
                self?.arguments?.interaction.setVolume(Float(value))
            }))
            return menu
        }
        
        more.contextMenu = { [weak self] in
            if let story = self?.story, let arguments = self?.arguments {
                return arguments.storyContextMenu(story)
            }
            return nil
        }
        
        avatarAndText.scaleOnClick = true
        
        avatarAndText.set(handler: { [weak self] control in
            if let groupId = self?.story?.peer?.id {
                self?.arguments?.openPeerInfo(groupId, control)
            }
        }, for: .Click)
        
        avatar.userInteractionEnabled = false
        textView.userInteractionEnabled = false
     
        privacy.set(handler: { [weak self] control in
            if let story = self?.story {
                if story.peerId != self?.arguments?.context.peerId {
                    self?.arguments?.showFriendsTooltip(control, story)
                } else {
                    self?.arguments?.setupPrivacy(story)
                }
            }
        }, for: .Click)
        
    }
    
    var hasNoSound: Bool {
        guard let story = self.story, let arguments = self.arguments else {
            return false
        }
        return arguments.interaction.hasNoSound(story.storyItem)
    }
    
    func updateMuted(isMuted: Bool, volume: Float) {
        guard let story = self.story, let arguments = self.arguments else {
            return
        }
        if arguments.interaction.hasNoSound(story.storyItem) {
            muted.set(image: cant_unmute, for: .Normal)
        } else {
            muted.set(image: isMuted || volume == 0 ? muted_image : unmuted_image, for: .Normal)
        }
    }
    
    func update(context: AccountContext, arguments: StoryArguments, groupId: PeerId, peer: Peer?, slice: StoryContentContextState.FocusedSlice, story: StoryContentItem, animated: Bool) {
        guard let peer = peer else {
            return
        }
        self.story = story
        self.groupId = groupId
        self.arguments = arguments
        avatar.setPeer(account: context.account, peer: story.itemPeer?._asPeer() ?? peer)
        
        privacy.isHidden = !story.storyItem.isCloseFriends && !story.storyItem.isSelectedContacts && !story.storyItem.isContacts
        
        if story.storyItem.isCloseFriends {
            privacy.set(image: privacy_close_friends, for: .Normal)
        } else if story.storyItem.isSelectedContacts {
            privacy.set(image: privacy_selected_contacts, for: .Normal)
        } else if story.storyItem.isContacts {
            privacy.set(image: privacy_contacts, for: .Normal)
        }
        privacy.sizeToFit(.zero, NSMakeSize(24, 24), thatFit: true)

        
        
        let date = NSMutableAttributedString()
        let color = NSColor.white.withAlphaComponent(0.8)
        if let forwardInfo = story.storyItem.forwardInfo {
            let peerId: PeerId?
            switch forwardInfo {
            case let .known(peer, _, _):
                date.append(string: peer._asPeer().compactDisplayTitle, color: NSColor.white, font: .medium(.small))
                date.append(string: " \(strings().bullet) ", color: color, font: .medium(.small))
                peerId = peer.id
            case let .unknown(name, _):
                date.append(string: name, color: NSColor.white, font: .medium(.small))
                date.append(string: " \(strings().bullet) ", color: color, font: .medium(.small))
                peerId = nil
            }
            let current: RepostView
            var isNew = false
            if let view = self.repostView {
                current = view
            } else {
                current = RepostView(frame: .zero)
                self.repostView = current
                dateContainer.addSubview(current)
                isNew = true
            }
            current.set(forwardInfo: forwardInfo, context: context, animated: animated)
            if isNew {
                current.centerY(x: 0)
            }
            if let peerId = peerId {
                dateContainer.removeAllHandlers()
                dateContainer.set(handler: { [weak arguments] _ in
                    arguments?.openChat(peerId, nil, nil)
                }, for: .Click)
            } else {
                dateContainer.removeAllHandlers()
            }
        } else if let view = repostView {
            performSubviewRemoval(view, animated: animated)
            self.repostView = nil
        }
        
        if let author = story.storyItem.author {
            
            date.append(string: "\(strings().bullet) ", color: color, font: .medium(.small))
            
            let current: AuthorView
            var isNew = false
            if let view = self.authorView {
                current = view
            } else {
                current = AuthorView(frame: .zero)
                self.authorView = current
                dateContainer.addSubview(current)
                isNew = true
            }
            current.set(peer: author, context: context, animated: animated)
            if isNew {
                current.centerY(x: 0)
            }
            dateContainer.removeAllHandlers()
            dateContainer.set(handler: { [weak arguments] _ in
                arguments?.openChat(author.id, nil, nil)
            }, for: .Click)
            
        } else if let view = authorView {
            performSubviewRemoval(view, animated: animated)
            self.authorView = nil
        }
        
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
            muted.set(image: arguments.interaction.presentation.isMuted || arguments.interaction.presentation.volume == 0 ? muted_image : unmuted_image, for: .Normal)
        }
        muted.isHidden = !arguments.interaction.canBeMuted(story.storyItem)
        more.isHidden = context.peerId == groupId || peer.isBot

        
        let textWidth = frame.width - 24 - avatar.frame.width - 20 - (muted.isHidden ? 0 : 20) - (more.isHidden ? 0 : 20) - (privacy.isHidden ? 0 : 20) - (repostView != nil ? repostView!.frame.width + 3 : 0) - (authorView != nil ? authorView!.frame.width + 3 : 0)


        let dateLayout = TextViewLayout(date, maximumNumberOfLines: 1)
        dateLayout.measure(width: textWidth)

               
        dateContainer.isHidden = peer.isBot == true
        
        dateContainer.userInteractionEnabled = self.repostView != nil || self.authorView != nil
        dateContainer.scaleOnClick = true
        dateView.userInteractionEnabled = false
        
        
        
        let authorName = NSMutableAttributedString()
        if let itemPeer = story.itemPeer {
            authorName.append(string: itemPeer._asPeer().displayTitle, color: .white, font: .medium(.title))
        } else {
            authorName.append(string: context.peerId == groupId ? strings().storyControlsYourStory : peer.displayTitle, color: .white, font: .medium(.title))
        }
        
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
        if dateContainer.isHidden {
            transition.updateFrame(view: textView, frame: textView.centerFrameY(x: avatar.frame.maxX + 10))
        } else {
            transition.updateFrame(view: textView, frame: CGRect(origin: NSMakePoint(avatar.frame.maxX + 10, avatar.frame.minY), size: textView.frame.size))
        }
        
        
        
        var dateContainerSize: NSSize = dateView.frame.size
        if let repostView = self.repostView {
            dateContainerSize.width += repostView.frame.width + 3
            transition.updateFrame(view: repostView, frame: repostView.centerFrameY(x: 0))
            repostView.updateLayout(size: repostView.frame.size, transition: transition)
        }
        
        if let authorView = self.authorView {
            dateContainerSize.width += authorView.frame.width + 3
            transition.updateFrame(view: authorView, frame: authorView.centerFrameY(x: 0))
            authorView.updateLayout(size: authorView.frame.size, transition: transition)
        }
        
        transition.updateFrame(view: dateContainer, frame: CGRect(origin: NSMakePoint(avatar.frame.maxX + 10, avatar.frame.maxY - dateView.frame.height), size: dateContainerSize))
        
        
        if let view = repostView {
            transition.updateFrame(view: dateView, frame: dateView.centerFrameY(x: view.frame.maxX + 3))
        } else if let view = authorView {
            transition.updateFrame(view: dateView, frame: dateView.centerFrameY(x: view.frame.maxX + 3))
        } else {
            transition.updateFrame(view: dateView, frame: dateView.centerFrameY(x: 0))
        }

        var controlX = size.width
        
        if !more.isHidden {
            controlX -= (more.frame.width + 5)
            transition.updateFrame(view: more, frame: more.centerFrameY(x: controlX))
        }
        
        if !privacy.isHidden {
            controlX -= (privacy.frame.width + 5)
            transition.updateFrame(view: privacy, frame: privacy.centerFrameY(x: controlX))
        }
        if !muted.isHidden {
            controlX -= (muted.frame.width + 5)
            transition.updateFrame(view: muted, frame: muted.centerFrameY(x: controlX))
        }
    }
    
    override func layout() {
        super.layout()
        

        let width = frame.width - 24 - avatar.frame.width - 20 - (muted.isHidden ? 0 : 20) - (more.isHidden ? 0 : 20) - (privacy.isHidden ? 0 : 20)
        
        self.textView.resize(width)
        self.dateView.resize(width)

        self.updateLayout(size: frame.size, transition: .immediate)
    }
}
