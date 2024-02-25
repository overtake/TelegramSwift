//
//  GroupCallParticipantRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/11/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import ColorPalette
import Postbox
import TelegramCore
import AppKit

private var fakeIcon: CGImage {
    generateFakeIconReversed(foregroundColor: GroupCallTheme.customTheme.redColor, backgroundColor: GroupCallTheme.customTheme.backgroundColor)
}
private var scamIcon: CGImage {
    generateScamIconReversed(foregroundColor: GroupCallTheme.customTheme.redColor, backgroundColor: GroupCallTheme.customTheme.backgroundColor)
}
private var verifyIcon: CGImage {
    NSImage(named: "Icon_VerifyDialog")!.precomposed(GroupCallTheme.customTheme.accentColor)
}
private var premiumIcon: CGImage {
    NSImage(named: "Icon_Peer_Premium")!.precomposed(GroupCallTheme.customTheme.accentColor)
}

final class GroupCallParticipantRowItem : GeneralRowItem {
    let data: PeerGroupCallData
    private let _contextMenu: ()->Signal<[ContextMenuItem], NoError>
    
    fileprivate private(set) var titleLayout: TextViewLayout!
    fileprivate let statusLayout: TextViewLayout
    fileprivate let account: Account
    fileprivate let isLastItem: Bool
    fileprivate let isInvited: Bool
    fileprivate let drawLine: Bool
    fileprivate let invite:(PeerId)->Void
    fileprivate let canManageCall:Bool
    fileprivate let takeVideo:(PeerId, VideoSourceMacMode?, GroupCallUIState.ActiveVideo.Mode)->NSView?
    fileprivate let volume: TextViewLayout?
    fileprivate let audioLevel:(PeerId)->Signal<Float?, NoError>?
    fileprivate private(set) var buttonImage: (CGImage, CGImage?)? = nil
    fileprivate let baseEndpoint: String?
    fileprivate let focusVideo:(String?)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, account: Account, data: PeerGroupCallData, baseEndpoint: String?, canManageCall: Bool, isInvited: Bool, isLastItem: Bool, drawLine: Bool, viewType: GeneralViewType, action: @escaping()->Void, invite:@escaping(PeerId)->Void, contextMenu:@escaping()->Signal<[ContextMenuItem], NoError>, takeVideo:@escaping(PeerId, VideoSourceMacMode?, GroupCallUIState.ActiveVideo.Mode)->NSView?, audioLevel:@escaping(PeerId)->Signal<Float?, NoError>?, focusVideo: @escaping(String?)->Void) {
        self.data = data
        self.audioLevel = audioLevel
        self.account = account
        self.canManageCall = canManageCall
        self.invite = invite
        self.focusVideo = focusVideo
        self._contextMenu = contextMenu
        self.isInvited = isInvited
        self.drawLine = drawLine
        self.takeVideo = takeVideo
        self.baseEndpoint = baseEndpoint
        self.isLastItem = isLastItem
        let (string, color) = data.status
        
        if let volume = data.unsyncVolume ?? data.state?.volume, volume != 10000 {
            if let muteState = data.state?.muteState, !muteState.canUnmute || muteState.mutedByYou {
                self.volume = nil
            } else {
                if data.isSpeaking {
                    var volumeColor: NSColor
                    if volume == 0 {
                        volumeColor = GroupCallTheme.grayStatusColor
                    } else {
                        volumeColor = color
                    }
                    self.volume = TextViewLayout(.initialize(string: "\(Int(Float(volume) / 10000 * 100))%", color: volumeColor, font: .normal(.short)))
                } else {
                    self.volume = nil
                }
            }
        } else {
            self.volume = nil
        }
        

        self.statusLayout = TextViewLayout(.initialize(string: string, color: color, font: .normal(.short)), maximumNumberOfLines: 1)
        super.init(initialSize, height: 0, stableId: stableId, type: .none, viewType: viewType, action: action, inset: .init(), enabled: true)
        
        
        if isActivePeer {
            if data.isSpeaking {
                self.buttonImage = (GroupCallTheme.small_speaking, GroupCallTheme.small_speaking_active)
            } else {
                if let muteState = data.state?.muteState {
                    if !muteState.canUnmute && data.isRaisedHand {
                        self.buttonImage = (GroupCallTheme.small_raised_hand, GroupCallTheme.small_raised_hand_active)
                    } else if muteState.canUnmute && !muteState.mutedByYou {
                        self.buttonImage = (GroupCallTheme.small_muted, GroupCallTheme.small_muted_active)
                    } else {
                        self.buttonImage = (GroupCallTheme.small_muted_locked, GroupCallTheme.small_muted_locked_active)
                    }
                } else if data.state == nil {
                    self.buttonImage = (GroupCallTheme.small_muted, GroupCallTheme.small_muted_active)
                } else {
                    self.buttonImage = (GroupCallTheme.small_unmuted, GroupCallTheme.small_unmuted_active)
                }
            }
        } else {
            if isInvited {
                self.buttonImage = (GroupCallTheme.invitedIcon, nil)
            } else {
                self.buttonImage = (GroupCallTheme.inviteIcon, nil)
            }
        }


    }
    
    override var viewType: GeneralViewType {
        return isVertical ? .singleItem : super.viewType
    }
    
    override var height: CGFloat {
        return isVertical ? 120 : 48
    }
    
    override var menuPresentation: AppMenu.Presentation {
        return .current(darkAppearance.colors)
    }
    
    override var isLegacyMenu: Bool {
        return false
    }
    
    override var inset: NSEdgeInsets {
        let insets: NSEdgeInsets
        if isVertical {
            insets = NSEdgeInsetsMake(0, 0, 5, 0)
        } else {
            insets = NSEdgeInsetsMake(0, 0, 0, 0)
        }
        return insets
    }
    
    override var width: CGFloat {
        return super.width
    }
    
    var isVertical: Bool {
        return data.isVertical
    }
    
    
    var itemInset: NSEdgeInsets {
        return NSEdgeInsetsMake(0, 12, 0, 12)
    }
    
    var isActivePeer: Bool {
        return data.state != nil || data.peer.id == data.accountPeerId
    }
    
    var peer: Peer {
        return data.peer
    }
    
    func takeCurrentVideo() -> NSView? {
        var mode: VideoSourceMacMode? = nil
        if let baseEndpoint = self.baseEndpoint {
            if self.data.videoEndpoint == baseEndpoint {
                mode = .video
            }
            if self.data.presentationEndpoint == baseEndpoint {
                mode = .screencast
            }
        }
        let videoView = isVertical ? self.takeVideo(peer.id, mode, .list) : nil

        return videoView
    }
    
    var supplementIcon: (CGImage, NSSize)? {
        
        let isScam: Bool = peer.isScam
        let isFake: Bool = peer.isFake
        let verified: Bool = peer.isVerified
        let isPremium: Bool = peer.isPremium

        if isScam {
            return (scamIcon, .zero)
        } else if isFake {
            return (fakeIcon, .zero)
        } else if verified {
            return (verifyIcon, .zero)
        } else if isPremium {
            return (premiumIcon, .zero)
        } else {
            return nil
        }
    }
    
    override var hasBorder: Bool {
        return false
    }
    override var instantlyResize: Bool {
        return true
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
                
        
        self.volume?.measure(width: .greatestFiniteMagnitude)
        var inset: CGFloat = 0
        if let volume = self.volume {
            inset = volume.layoutSize.width + 25
        } else {
            for image in statusImage {
                inset += image.backingSize.width + 3
            }
        }

        
        
        if isVertical {
            self.titleLayout = TextViewLayout(.initialize(string: data.peer.compactDisplayTitle, color: NSColor.white.withAlphaComponent(0.8), font: .normal(.text)), maximumNumberOfLines: 1)
        } else {
            self.titleLayout = TextViewLayout(.initialize(string: data.peer.displayTitle, color: (data.state != nil ? .white : GroupCallTheme.grayStatusColor), font: .medium(.text)), maximumNumberOfLines: 1)
        }
        
        let addition: CGFloat
        if let size = PremiumStatusControl.controlSize(peer, false) {
            addition = size.width + 5
        } else {
            addition = 0
        }
        
        if isVertical {
            titleLayout.measure(width: GroupCallTheme.smallTableWidth - 16 - 10 - addition)
        } else {
            let width = (data.isFullscreen && data.videoMode) ? GroupCallTheme.tileTableWidth - 20 : width - 20
            titleLayout.measure(width: width - itemInset.left - itemInset.left - itemInset.right - (data.videoMode ? 0 : 28) - itemInset.right - addition)
            statusLayout.measure(width: width - itemInset.left - itemInset.left - itemInset.right - (data.videoMode ? 0 : 28) - itemInset.right - inset)
        }
        
        return true
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        return _contextMenu()
    }
    
    override func viewClass() -> AnyClass {
        return GroupCallParticipantRowView.self
    }
    
    override var identifier: String {
        return isVertical ? "vertical_group_call_item" : super.identifier
    }
    
    var statusImage: [CGImage] {
        let hasVideo = data.hasVideo
        
        var images:[CGImage] = []
        
        if hasVideo || volume != nil || data.videoMode, let state = data.state {
            
            if data.videoMode {
                if let muteState = state.muteState {
                    if muteState.mutedByYou || !muteState.canUnmute {
                        images.append(GroupCallTheme.video_status_muted_red)
                    } else {
                        images.append(GroupCallTheme.video_status_muted_gray)
                    }
                } else {
                    if data.isSpeaking {
                        images.append(GroupCallTheme.video_status_unmuted_green)
                    } else if data.wantsToSpeak {
                        images.append(GroupCallTheme.video_status_unmuted_accent)
                    } else {
                        images.append(GroupCallTheme.video_status_unmuted_gray)
                    }
                }
            }
            
            if hasVideo {
                if let endpoint = data.videoEndpoint {
                    if baseEndpoint == nil || baseEndpoint == endpoint {
                        if let muteState = state.muteState, muteState.mutedByYou {
                            images.append(GroupCallTheme.status_video_red)
                        } else {
                            if data.isSpeaking {
                                images.append(GroupCallTheme.status_video_green)
                            } else if data.wantsToSpeak {
                                images.append(GroupCallTheme.status_video_accent)
                            } else {
                                images.append(GroupCallTheme.status_video_gray)
                            }
                        }
                    }
                }
                if let endpoint = data.presentationEndpoint {
                    if baseEndpoint == nil || baseEndpoint == endpoint {
                        if let muteState = state.muteState, muteState.mutedByYou {
                            images.append(GroupCallTheme.status_screencast_red)
                        } else {
                            if data.isSpeaking {
                                images.append(GroupCallTheme.status_screencast_green)
                            } else if data.wantsToSpeak {
                                images.append(GroupCallTheme.status_screencast_accent)
                            } else {
                                images.append(GroupCallTheme.status_screencast_gray)
                            }
                        }
                    }
                }
            } else {
                if let muteState = state.muteState, muteState.mutedByYou {
                    images.append(GroupCallTheme.status_muted_red)
                } else if !data.videoMode {
                    if data.isSpeaking {
                        images.append(GroupCallTheme.status_unmuted_green)
                    } else if data.wantsToSpeak {
                        images.append(GroupCallTheme.status_unmuted_accent)
                    } else {
                        images.append(GroupCallTheme.status_unmuted_gray)
                    }
                }
            }
        }
        return images
    }
    
    var videoBoxImage: [CGImage] {
        if isInvited {
            return [GroupCallTheme.videoBox_muted_locked]
        }
        var images:[CGImage] = []
        
        if let _ = data.state?.muteState {
            images.append(GroupCallTheme.videoBox_muted)
        } else if data.state == nil {
            images.append(GroupCallTheme.videoBox_muted)
        } else {
            images.append(GroupCallTheme.videoBox_unmuted)
        }

        if let endpoint = data.videoEndpoint {
            if baseEndpoint == nil || baseEndpoint == endpoint {
                images.append(GroupCallTheme.videoBox_video)
            }
        }
        if let endpoint = data.presentationEndpoint {
            if baseEndpoint == nil || baseEndpoint == endpoint {
                images.append(GroupCallTheme.videoBox_screencast)
            }
        }
        
        return images
    }
    
    var actionInteractionEnabled: Bool {
        if data.accountPeerId == data.peer.id {
            return false
        }
        if isActivePeer {
            return canManageCall
        } else {
            if isInvited {
                return false
            } else {
                return true
            }
        }
    }
    
    var activityColor: NSColor {
        if  let muteState = data.state?.muteState, muteState.mutedByYou {
            return GroupCallTheme.speakLockedColor
        } else {
            return data.isSpeaking ? GroupCallTheme.speakActiveColor : GroupCallTheme.speakInactiveColor
        }
    }
    
    deinit {
       
    }
}

protocol GroupCallParticipantRowProtocolView : NSView {
    func getPhotoView() -> NSView
}




final class VerticalContainerView : GeneralContainableRowView, GroupCallParticipantRowProtocolView {
    private let photoView: GroupCallAvatarView = GroupCallAvatarView(frame: NSMakeRect(0, 0, 68, 68), photoSize: NSMakeSize(48, 48))

    private final class VideoContainer : View {
        private let shadowView = ShadowView()
        var view: NSView? {
            didSet {
                if let view = view {
                    addSubview(view, positioned: .below, relativeTo: shadowView)
                }
                needsLayout = true
            }
        }
        
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(shadowView)
            shadowView.direction = .vertical(true)
            shadowView.shadowBackground = NSColor.black.withAlphaComponent(0.3)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layout() {
            super.layout()
            view?.frame = bounds
            shadowView.frame = NSMakeRect(0, frame.height - 30, frame.width, 30)
        }
    }
    
    func getPhotoView() -> NSView {
        return self.photoView
    }
    
    private var videoContainer: VideoContainer?
    private let nameContainer = View()
    private let titleView = TextView()
    private let statusView = ImageView()
    private var pinnedFrameView: View?
    private let imagesView: View = View()
    private let speakingView: View = View()

    private let audioLevelDisposable = MetaDisposable()
    private var scaleAnimator: DisplayLinkAnimator?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(photoView)
        nameContainer.addSubview(titleView)
        nameContainer.addSubview(imagesView)
        addSubview(statusView)
       
        addSubview(nameContainer)
        
        addSubview(speakingView)
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        photoView.userInteractionEnabled = false
        
        containerView.layer?.masksToBounds = false
        
        speakingView.layer?.cornerRadius = 10
        speakingView.layer?.borderWidth = 2
        speakingView.layer?.borderColor = GroupCallTheme.speakActiveColor.cgColor
    
        containerView.set(handler: { [weak self] _ in
            if let item = self?.item as? GroupCallParticipantRowItem {
                item.focusVideo(item.baseEndpoint)
            }
        }, for: .Click)
        
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Hover)
        
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Normal)
        
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Highlight)
        
        containerView.scaleOnClick = true
    }
    
    
    override var backdorColor: NSColor {
        let color: NSColor
        if containerView.controlState == .Highlight || contextMenu != nil {
            color = GroupCallTheme.membersColor.lighter()
        } else {
            color = GroupCallTheme.membersColor
        }
        return color
    }
    override func updateColors() {
        super.updateColors()
    }
    
    override func showContextMenu(_ event: NSEvent) {
        super.showContextMenu(event)
    }
    
    override var maxBlockWidth: CGFloat {
        return GroupCallTheme.tileTableWidth
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? GroupCallParticipantRowItem else {
            return
        }
        
        let blockWidth = min(maxBlockWidth, frame.width - item.inset.left - item.inset.right)
        
        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (maxWidth - blockWidth) / 2), 0, blockWidth, maxHeight)
        self.containerView.setCorners(item.viewType.corners)

        
        photoView.center()
        videoContainer?.frame = containerView.bounds
        
        nameContainer.frame = NSMakeRect(0, 0, containerView.frame.width, max(imagesView.frame.height, titleView.frame.height))
        nameContainer.centerX(y: containerView.frame.height - nameContainer.frame.height - 8)
        
        imagesView.setFrameOrigin(NSMakePoint(8, 0))
        titleView.setFrameOrigin(NSMakePoint(imagesView.frame.maxX + 8, 0))

        
        pinnedFrameView?.frame = containerView.bounds
        
        speakingView.frame = containerView.bounds
    }

    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? GroupCallParticipantRowItem else {
            return
        }
        photoView.update(item.audioLevel, data: item.data, activityColor: item.activityColor, account: item.account, animated: animated)
        photoView._change(opacity: item.isActivePeer ? 1.0 : 0.5, animated: animated)
                
        
        let showSpeakingView = item.data.isSpeaking == true && (item.data.state?.muteState?.mutedByYou == nil || item.data.state?.muteState?.mutedByYou == false)
        
        speakingView.change(opacity: showSpeakingView ? 1 : 0, animated: animated)

        speakingView.layer?.borderColor = item.data.state?.muteState?.mutedByYou == true ? GroupCallTheme.customTheme.redColor.cgColor : GroupCallTheme.speakActiveColor.cgColor
        
        let videoBoxImages = item.videoBoxImage
        
        while imagesView.subviews.count > videoBoxImages.count {
            imagesView.subviews.removeLast()
        }
        while imagesView.subviews.count < videoBoxImages.count {
            imagesView.addSubview(ImageView())
        }
        for (i, image) in videoBoxImages.enumerated() {
            let view = (imagesView.subviews[i] as? ImageView)
            view?.image = image
            view?.sizeToFit()
        }
        imagesView.setFrameSize(imagesView.subviewsWidthSize)
        
        var x: CGFloat = 0
        for view in imagesView.subviews {
            view.centerY(x: x)
            x += view.frame.width + 2
        }

        titleView.update(item.titleLayout)
        
        let videoView = item.takeCurrentVideo()
        
        
        if let videoView = videoView {
            
            var isPresented: Bool = false
            
            let videoContainer: VideoContainer
            if let current = self.videoContainer {
                videoContainer = current
            } else {
                videoContainer = VideoContainer(frame: containerView.bounds)
                videoContainer.isEventLess = true
                self.videoContainer = videoContainer
                addSubview(videoContainer, positioned: .above, relativeTo: photoView)
                isPresented = true
            }
            videoContainer.view = videoView

            if animated && isPresented {
                videoContainer.layer?.animateAlpha(from: 0, to: 1, duration: 0.3)
                let from = Float(videoContainer.frame.height / 2)
                videoContainer.layer?.animate(from: NSNumber(value: from), to: NSNumber(value: 0), keyPath: "cornerRadius", timingFunction: .easeInEaseOut, duration: 0.2, forKey: "cornerRadius")
                
                videoContainer.layer?.animateScaleCenter(from: photoView.frame.height / videoContainer.frame.width, to: 1, duration: 0.2)
                
                videoContainer.layer?.animatePosition(from: NSMakePoint(0, -photoView.frame.minY - 10), to: videoContainer.frame.origin, duration: 0.2)
                
            }
        } else {
            if let first = self.videoContainer {
                self.videoContainer = nil
                if animated {
                    first.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak first, weak self] _ in
                        if first?.superview == self?.videoContainer {
                            first?.removeFromSuperview()
                        }
                    })
                    
                    let to = Float(first.frame.height / 2)
                    first.layer?.animate(from: NSNumber(value: 0), to: NSNumber(value: to), keyPath: "cornerRadius", timingFunction: .easeInEaseOut, duration: 0.2, removeOnCompletion: false, forKey: "cornerRadius")
                    
                    first.layer?.animateScaleCenter(from: 1, to: photoView.frame.height / first.frame.width, duration: 0.3, removeOnCompletion: false)
                    
                    first.layer?.animatePosition(from: first.frame.origin, to: NSMakePoint(0, -photoView.frame.minY - 10), duration: 0.2, removeOnCompletion: false)
                    
                } else {
                    first.removeFromSuperview()
                }
            }
        }
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
      
    }
}

private final class HorizontalContainerView : GeneralContainableRowView, GroupCallParticipantRowProtocolView {
    
    private final class VideoContainer : View {
        weak var view: NSView? {
            didSet {
                if let view = view {
                    addSubview(view)
                }
                needsLayout = true
            }
        }

        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layout() {
            super.layout()
            view?.frame = bounds
        }

    }

    
    private let photoView: GroupCallAvatarView = GroupCallAvatarView(frame: NSMakeRect(0, 0, 55, 55), photoSize: NSMakeSize(35, 35))
    private let titleView: TextView = TextView()
    private var statusView: TextView?
    private let button = ImageButton()
    private let separator: View = View()
    private let videoContainer: VideoContainer = VideoContainer(frame: .zero)
    private var volumeView: TextView?
    private var statusImageContainer: View = View()
    private var statusControl: PremiumStatusControl?
    private let audioLevelDisposable = MetaDisposable()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(photoView)
        addSubview(titleView)
        addSubview(separator)
        addSubview(button)
        addSubview(statusImageContainer)
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false

        photoView.userInteractionEnabled = false

        addSubview(videoContainer)
        videoContainer.frame = .init(origin: .zero, size: photoView.photoSize)
        videoContainer.layer?.cornerRadius = photoView.photoSize.height / 2
        
        button.animates = true

        button.autohighlight = true
        button.set(handler: { [weak self] _ in
            guard let item = self?.item as? GroupCallParticipantRowItem else {
                return
            }
            if item.data.state == nil {
                item.invite(item.peer.id)
            }
        }, for: .SingleClick)
        
        button.set(handler: { [weak self] _ in
            guard let item = self?.item as? GroupCallParticipantRowItem else {
                return
            }
            if item.data.state != nil {
                _ = item.menuItems(in: .zero).start(next: { [weak self] items in
                    if let event = NSApp.currentEvent, let button = self?.button {
                        let menu = ContextMenu()
                        menu.appearance = darkPalette.appearance
                        for item in items {
                            menu.addItem(item)
                        }
                        NSMenu.popUpContextMenu(menu, with: event, for: button)
                    //    AppMenu.show(menu: menu, event: event, for: button)
                    }
                })
            } 
        }, for: .Down)
        
        containerView.set(handler: { [weak self] _ in
            if let event = NSApp.currentEvent {
                self?.showContextMenu(event)
            }
        }, for: .Click)
        
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Hover)
        
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Normal)
        
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Highlight)
    }
    
    override var backdorColor: NSColor {
        let color: NSColor
        if containerView.controlState == .Highlight || contextMenu != nil {
            color = GroupCallTheme.membersColor.lighter()
        } else {
            color = GroupCallTheme.membersColor
        }
        return color
    }
    
    
    func getPhotoView() -> NSView {
        return self.photoView
    }
    
    override func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        guard let item = item as? GroupCallParticipantRowItem else {
            return
        }
        
        let frame = size.bounds
        
        if let statusView = statusView {
            transition.updateFrame(view: statusView, frame: CGRect(origin: statusViewPoint, size: statusView.frame.size))
        }
        if let volumeView = volumeView {
            transition.updateFrame(view: volumeView, frame: CGRect(origin: volumeViewPoint, size: volumeView.frame.size))
        }
        transition.updateFrame(view: statusImageContainer, frame: CGRect(origin: statusImageViewViewPoint, size: statusImageContainer.frame.size))
        
        transition.updateFrame(view: self.photoView, frame: self.photoView.centerFrameY(x: item.itemInset.left - (self.photoView.frame.width - photoView.photoSize.width) / 2))

        transition.updateFrame(view: titleView, frame: CGRect(origin: NSMakePoint(item.itemInset.left + photoView.photoSize.width + item.itemInset.left, 6), size: titleView.frame.size))
        
        if let statusControl = self.statusControl {
            transition.updateFrame(view: statusControl, frame: CGRect(origin: NSMakePoint(titleView.frame.maxX + 3, titleView.frame.minY), size: statusControl.frame.size))
        }
        if item.drawLine {
            transition.updateFrame(view: separator, frame: NSMakeRect(titleView.frame.minX, frame.height - .borderSize, frame.width - titleView.frame.minX, .borderSize))
        } else {
            transition.updateFrame(view: separator, frame: .zero)
        }

        transition.updateFrame(view: button, frame: button.centerFrameY(x: frame.width - 12 - button.frame.width))
        
        transition.updateFrame(view: videoContainer, frame: videoContainer.centerFrameY(x: item.itemInset.left, addition: -1))

        
    }
    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }
    
    override func updateColors() {
        super.updateColors()
        self.titleView.backgroundColor = backdorColor
        self.statusView?.backgroundColor = backdorColor
        self.separator.backgroundColor = GroupCallTheme.memberSeparatorColor
    }
    
    
    override func set(item: TableRowItem, animated: Bool = false) {
        let previousItem = self.item as? GroupCallParticipantRowItem
        super.set(item: item, animated: animated)
        
        guard let item = item as? GroupCallParticipantRowItem else {
            return
        }
        
        let videoView = item.takeCurrentVideo()
        
        if let videoView = videoView {
            let previous = self.videoContainer.view
            
            videoView.frame = self.videoContainer.bounds
            self.videoContainer.view = videoView
            
            if animated && previous == nil {
                videoView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
        } else {
            if let first = self.videoContainer.view {
                self.videoContainer.view = nil
                if animated {
                    first.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak first, weak self] _ in
                        if first?.superview == self?.videoContainer {
                            first?.removeFromSuperview()
                        }
                    })
                } else {
                    first.removeFromSuperview()
                }
            }
        }
        
        let control = PremiumStatusControl.control(item.peer, account: item.account, inlinePacksContext: nil, isSelected: false, cached: self.statusControl, animated: animated)
        if let control = control {
            self.statusControl = control
            self.containerView.addSubview(control)
        } else if let view = self.statusControl {
            performSubviewRemoval(view, animated: animated)
            self.statusControl = nil
        }
        
        
        if previousItem?.buttonImage?.0 != item.buttonImage?.0 {
            if let image = item.buttonImage {
                button.set(image: image.0, for: .Normal)
                if let highlight = image.1 {
                    button.set(image: highlight, for: .Highlight)
                } else {
                    button.removeImage(for: .Highlight)
                }
            }
            button.sizeToFit(.zero, NSMakeSize(28, 28), thatFit: true)
        }
        button.userInteractionEnabled = item.actionInteractionEnabled
        button.isHidden = item.data.videoMode
        photoView.update(item.audioLevel, data: item.data, activityColor: item.activityColor, account: item.account, animated: animated)

        titleView.update(item.titleLayout)
        photoView._change(opacity: item.isActivePeer ? 1.0 : 0.5, animated: animated)

        
        while statusImageContainer.subviews.count > item.statusImage.count {
            statusImageContainer.subviews.last?.removeFromSuperview()
        }
        while statusImageContainer.subviews.count < item.statusImage.count {
            let statusImageView = ImageView()
            statusImageContainer.addSubview(statusImageView)
        }
        
        for (i, statusImage) in item.statusImage.enumerated() {
            let statusImageView = statusImageContainer.subviews[i] as! ImageView
            if statusImageView.image != statusImage {
                statusImageView.image = statusImage
                statusImageView.sizeToFit()
            }
        }
        
        statusImageContainer.setFrameSize(statusImageContainer.subviewsWidthSize + NSMakeSize((2 * CGFloat(statusImageContainer.subviews.count) - 1), 0))
        var x: CGFloat = 0
        for subview in statusImageContainer.subviews {
            subview.setFrameOrigin(NSMakePoint(x, 0))
            x += subview.frame.width + 2
        }
        
        if statusView?.textLayout?.attributedString.string != item.statusLayout.attributedString.string {
            if let statusView = statusView {
                if animated, previousItem?.peer.id == item.peer.id {
                    statusView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak statusView] _ in
                        statusView?.removeFromSuperview()
                    })
                    statusView.layer?.animatePosition(from: statusView.frame.origin, to: NSMakePoint(statusView.frame.minX, statusView.frame.minY + 10))
                } else {
                    statusView.removeFromSuperview()
                }
            }
            
            let animated = statusView?.textLayout != nil && previousItem?.peer.id == item.peer.id
            
            let statusView = TextView()
            let hadOld = self.statusView != nil
            self.statusView = statusView
            statusView.userInteractionEnabled = false
            statusView.isSelectable = false
            statusView.update(item.statusLayout)
            addSubview(statusView)
            statusView.setFrameOrigin(statusViewPoint)
            
            if animated && hadOld {
                statusView.layer?.animateAlpha(from: 0, to: 1, duration: 0.3)
                statusView.layer?.animatePosition(from: NSMakePoint(statusViewPoint.x, statusViewPoint.y - 10), to: statusViewPoint)
            }
        } else {
            statusView?.change(pos: statusViewPoint, animated: animated)
        }
        
        statusView?.update(item.statusLayout)
        
        
        if let volume = item.volume {
            var isPresented: Bool = false
            if volumeView == nil {
                self.volumeView = TextView()
                self.volumeView?.userInteractionEnabled = false
                self.volumeView?.isSelectable = false
                addSubview(volumeView!)
                isPresented = true
            }
            guard let volumeView = volumeView else {
                return
            }
            volumeView.update(volume)

            if isPresented {
                volumeView.setFrameOrigin(volumeViewPoint)
            }
            if isPresented && animated {
                volumeView.layer?.animateAlpha(from: 0, to: 1, duration: 0.3)
                volumeView.layer?.animatePosition(from: NSMakePoint(volumeView.frame.minX - volumeView.frame.width, volumeView.frame.minY), to: volumeView.frame.origin)
                
                if let statusView = statusView {
                    statusView.change(pos: statusViewPoint, animated: animated)
                }
            }
        } else {
            if let volumeView = volumeView {
                self.volumeView = nil
                if animated {
                    volumeView.layer?.animateAlpha(from: 1, to: 0, duration: 0.3, removeOnCompletion: false, completion: { [weak volumeView] _ in
                        volumeView?.removeFromSuperview()
                    })
                    volumeView.layer?.animatePosition(from: volumeView.frame.origin, to: NSMakePoint(volumeView.frame.minX - volumeView.frame.width, volumeView.frame.minY))
                } else {
                    volumeView.removeFromSuperview()
                }
                if let statusView = statusView {
                    statusView.change(pos: statusViewPoint, animated: animated)
                }
            }
        }
        needsLayout = true
    }
    
    
    var statusViewPoint: NSPoint {
        guard let item = item as? GroupCallParticipantRowItem else {
            return .zero
        }
        var point: NSPoint = .zero
        
        if let statusView = statusView {
            point = NSMakePoint(item.itemInset.left + photoView.photoSize.width + item.itemInset.left, frame.height - statusView.frame.height - 6)
        }
        if let volume = item.volume {
            point.x += volume.layoutSize.width + 3
        }
        if !statusImageContainer.subviews.isEmpty {
            point.x += statusImageContainer.frame.width + 3
        }
        
        return point
    }
    var volumeViewPoint: NSPoint {
        guard let item = item as? GroupCallParticipantRowItem else {
            return .zero
        }
        var point: NSPoint = .zero
        
        if let volumeView = volumeView {
            point = NSMakePoint(item.itemInset.left + photoView.photoSize.width + item.itemInset.left, frame.height - volumeView.frame.height - 6)
        }
        if !statusImageContainer.subviews.isEmpty {
            point.x += statusImageContainer.frame.width + 3
        }
        return point
    }
    
    var statusImageViewViewPoint: NSPoint {
        guard let item = item as? GroupCallParticipantRowItem else {
            return .zero
        }
        var point: NSPoint = .zero
        
        point = NSMakePoint(item.itemInset.left + photoView.photoSize.width + item.itemInset.left, containerView.frame.height - statusImageContainer.frame.height - 5)
        return point
    }

    deinit {
        audioLevelDisposable.dispose()
    }

    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        showContextMenu(event)
    }
    
    override var rowAppearance: NSAppearance? {
        return darkPalette.appearance
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



private final class GroupCallParticipantRowView : GeneralContainableRowView, GroupCallParticipantRowProtocolView {
    
    private var container: (GroupCallParticipantRowProtocolView & GeneralContainableRowView)?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
    }
    
    override var backdorColor: NSColor {
        let color: NSColor
        if containerView.controlState == .Highlight || contextMenu != nil {
            color = GroupCallTheme.membersColor.lighter()
        } else {
            color = GroupCallTheme.membersColor
        }
        return color
    }
    
    
    override var borderColor: NSColor {
        return GroupCallTheme.memberSeparatorColor
    }
    
    func getPhotoView() -> NSView {
        return self.container?.getPhotoView() ?? self
    }
        
    override func layout() {
        super.layout()
        if let container = container as? HorizontalContainerView {
            container.frame = containerView.bounds
        }
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        if let container = container as? HorizontalContainerView {
            transition.updateFrame(view: container, frame: containerView.bounds)
            container.updateLayout(size: size, transition: transition)
        }
    }
    
    override func updateColors() {
        super.updateColors()
    }
    
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? GroupCallParticipantRowItem else {
            return
        }
        
        let current: (GeneralContainableRowView & GroupCallParticipantRowProtocolView)
        
        var previous: NSView?
        if item.isVertical {
            if self.container is VerticalContainerView {
                current = self.container!
            } else {
                current = VerticalContainerView(frame: NSMakeRect(0, 0, GroupCallTheme.tileTableWidth, item.height - 5))
                previous = self.container
                self.container = current
                addSubview(current)
            }
        } else {
            if self.container is HorizontalContainerView {
                current = self.container!
            } else {
                current = HorizontalContainerView(frame: containerView.bounds)
                previous = self.container
                self.container = current
                addSubview(current)
            }
        }
        
        if let previous = previous {
            previous.removeFromSuperview()
            if animated {
                current.layer?.animateAlpha(from: 0, to: 1, duration: 0.3)
            }
        }
        
        self.container?.set(item: item, animated: animated && previous == nil)
        self.container?.needsLayout = true
        needsLayout = true
    }
    
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        showContextMenu(event)
    }
    
    override var rowAppearance: NSAppearance? {
        return darkPalette.appearance
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


