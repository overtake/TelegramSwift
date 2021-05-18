//
//  GroupCallMainVideoContainer.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06.04.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private final class PinView : Control {
    private let imageView:ImageView = ImageView()
    private var textView: TextView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        backgroundColor = GroupCallTheme.windowBackground.withAlphaComponent(0.9)
        imageView.isEventLess = true
        scaleOnClick = true
        set(background: GroupCallTheme.windowBackground.withAlphaComponent(0.7), for: .Highlight)
    }
    
    func update(_ isPinned: Bool, animated: Bool) {
        if isPinned {
            var isNew: Bool = false
            let current: TextView
            if let c = self.textView {
                current = c
            } else {
                current = TextView()
                self.textView = current
                current.userInteractionEnabled = false
                current.isSelectable = false
                addSubview(current, positioned: .below, relativeTo: imageView)
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                isNew = true
            }
            
            let textLayout = TextViewLayout(.initialize(string: L10n.voiceChatVideoShortUnpin, color: GroupCallTheme.customTheme.textColor, font: .medium(.title)))
            textLayout.measure(width: .greatestFiniteMagnitude)
            current.update(textLayout)
            
            if isNew {
                textView?.centerY(x: 10, addition: -1)
            }
        } else {
            if let textView = textView {
                self.textView = nil
                if animated {
                    textView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak textView] _ in
                        textView?.removeFromSuperview()
                    })
                } else {
                    textView.removeFromSuperview()
                }
            }
        }
        imageView.animates = true
        imageView.image = !isPinned ? GroupCallTheme.pin_video :GroupCallTheme.unpin_video
        imageView.sizeToFit()
        layer?.cornerRadius = (imageView.frame.height + 10) / 2
    }
    
    func size(_ isPinned: Bool) -> NSSize {
        if let textView = textView {
            return imageView.frame.size + NSMakeSize(textView.frame.width, 0) + NSMakeSize(20, 10)
        } else {
            return imageView.frame.size + NSMakeSize(10, 10)
        }
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: imageView, frame: imageView.centerFrameY(x: frame.width - imageView.frame.width - 5))
        if let textView = textView {
            let textFrame = textView.centerFrameY(x: 10, addition: -1)
            transition.updateFrame(view: textView, frame: textFrame)
        }
    }
    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


struct DominantVideo : Equatable {
    let peerId: PeerId
    let endpointId: String
    let mode: VideoSourceMacMode
    let temporary: Bool
    init(_ peerId: PeerId, _ endpointId: String, _ mode: VideoSourceMacMode, _ temporary: Bool) {
        self.peerId = peerId
        self.endpointId = endpointId
        self.mode = mode
        self.temporary = temporary
    }
}

final class GroupCallMainVideoContainerView: Control {
    private let call: PresentationGroupCall
    
    private(set) var backstageView: GroupVideoView?
    private let backstage: NSVisualEffectView = NSVisualEffectView(frame: .zero)

    
    private(set) var currentVideoView: GroupVideoView?
    private(set) var currentPeer: DominantVideo?
    
    let shadowView: ShadowView = ShadowView()
    private let pinView: PinView = PinView(frame: .zero)
    
    private var validLayout: CGSize?
    
    private let nameView: TextView = TextView()
    private var statusView: TextView = TextView()

    private let speakingView: View = View()
    private let audioLevelDisposable = MetaDisposable()
    
    private var arguments: GroupCallUIArguments?
    
    
    
    init(call: PresentationGroupCall) {
        self.call = call
        super.init()
        
        
        speakingView.layer?.cornerRadius = 10
        speakingView.layer?.borderWidth = 2
        speakingView.layer?.borderColor = GroupCallTheme.speakActiveColor.cgColor
        
        
        self.backgroundColor =  GroupCallTheme.membersColor
        addSubview(shadowView)
        
        shadowView.shadowBackground = NSColor.black.withAlphaComponent(0.3)
        shadowView.direction = .vertical(true)
        
        self.layer?.cornerRadius = 10
        
        addSubview(nameView)
        addSubview(statusView)
        
        backstage.wantsLayer = true
        backstage.material = .ultraDark
        backstage.blendingMode = .withinWindow
        backstage.state = .active
        
        
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        
        statusView.userInteractionEnabled = false
        statusView.isSelectable = false
        
        addSubview(speakingView)
        
        addSubview(pinView)
        
        pinView.set(handler: { [weak self] _ in
            if let strongSelf = self, let dominant = strongSelf.currentPeer {
                if !strongSelf.isPinned {
                    self?.arguments?.pinVideo(dominant)
                } else {
                    self?.arguments?.unpinVideo(dominant.mode)
                }
            }
        }, for: .Click)
        
        self.set(handler: { [weak self] _ in
            self?.pinView.send(event: .Click)
        }, for: .DoubleClick)
    }
    
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    func updateMode(controlsMode: GroupCallView.ControlsMode, controlsState: GroupCallControlsView.Mode, animated: Bool) {
        shadowView.change(opacity: controlsMode == .normal ? 1 : 0, animated: animated)
        
        nameView.change(opacity: controlsMode == .normal ? 1 : 0, animated: animated)
        statusView.change(opacity: controlsMode == .normal ? 1 : 0, animated: animated)
        pinView.change(opacity: controlsMode == .normal ? 1 : 0, animated: animated)
    }
    
    private var participant: PeerGroupCallData?
    
    private var isPinned: Bool = false
    
    func updatePeer(peer: DominantVideo?, participant: PeerGroupCallData?, resizeMode: CALayerContentsGravity, transition: ContainedViewLayoutTransition, animated: Bool, controlsMode: GroupCallView.ControlsMode, isFullScreen: Bool, isPinned: Bool, arguments: GroupCallUIArguments?) {
        
        self.isPinned = isPinned
        self.arguments = arguments
        
        self.pinView.update(isPinned, animated: animated)
        
        let showSpeakingView = participant?.isSpeaking == true && (participant?.state?.muteState?.mutedByYou == nil || participant?.state?.muteState?.mutedByYou == false)
        
        transition.updateAlpha(view: speakingView, alpha: showSpeakingView ? 1 : 0)
        
        speakingView.layer?.borderColor = participant?.state?.muteState?.mutedByYou == true ? GroupCallTheme.customTheme.redColor.cgColor : GroupCallTheme.speakActiveColor.cgColor
                
        transition.updateAlpha(view: pinView, alpha: controlsMode == .normal ? 1 : 0)
        transition.updateAlpha(view: shadowView, alpha: controlsMode == .normal ? 1 : 0)
        transition.updateAlpha(view: nameView, alpha: controlsMode == .normal ? 1 : 0)
        transition.updateAlpha(view: statusView, alpha: controlsMode == .normal ? 1 : 0)
        if participant != self.participant, let participant = participant, let peer = peer {
            self.participant = participant
            let text: String
            if participant.peer.id == participant.accountPeerId {
                text = L10n.voiceChatStatusYou
            } else {
                text = participant.peer.displayTitle
            }
            let nameLayout = TextViewLayout(.initialize(string: text, color: NSColor.white.withAlphaComponent(1), font: .medium(.short)), maximumNumberOfLines: 1)
            nameLayout.measure(width: frame.width - 20)
            self.nameView.update(nameLayout)
                        
            
            var status = participant.videoStatus(peer.mode)
            
            if frame.width - 20 - nameLayout.layoutSize.width - 20 < 100 {
                status = ""
            }
            
            if self.statusView.layout?.attributedString.string != status {
                let statusLayout = TextViewLayout(.initialize(string: status, color: NSColor.white.withAlphaComponent(0.7), font: .normal(.short)), maximumNumberOfLines: 1)
                
                statusLayout.measure(width: frame.width - nameView.frame.width - 30)
                
                let statusView = TextView()
                statusView.update(statusLayout)
                statusView.userInteractionEnabled = false
                statusView.isSelectable = false
                statusView.layer?.opacity = controlsMode == .normal ? 1 : 0
                
                statusView.frame = CGRect(origin: NSMakePoint(nameView.frame.width + 20, frame.height - statusView.frame.height - 10), size: self.statusView.frame.size)
                self.addSubview(statusView)
                
                let previous = self.statusView
                self.statusView = statusView
                if animated, controlsMode == .normal {
                    previous.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak previous] _ in
                        previous?.removeFromSuperview()
                    })
                    statusView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    statusView.layer?.animatePosition(from: statusView.frame.origin - NSMakePoint(10, 0), to: statusView.frame.origin)

                    previous.layer?.animatePosition(from: previous.frame.origin, to: previous.frame.origin + NSMakePoint(10, 0))
                } else {
                    previous.removeFromSuperview()
                }
            }
                        
        }

        self.currentPeer = peer
        if let peer = peer {
           
            guard let videoView = arguments?.takeVideo(peer.peerId, peer.mode, .main) as? GroupVideoView else {
                return
            }
            
            guard let backstageVideo = arguments?.takeVideo(peer.peerId, peer.mode, .backstage) as? GroupVideoView else {
                return
            }
            
            
            
            

//            videoView.videoView.setVideoContentMode(resizeMode)

            
            if self.currentVideoView != videoView || videoView.superview != self {
                if let currentVideoView = self.currentVideoView {
                    currentVideoView.removeFromSuperview()
                }
                self.currentVideoView = videoView
                self.addSubview(videoView, positioned: .below, relativeTo: self.shadowView)
            }
            
            self.currentVideoView?.gravity = resizeMode

            
            if self.backstageView != backstageView || backstageVideo.superview != self {
                if let backstageVideo = self.backstageView {
                    backstageVideo.removeFromSuperview()
                }
                backstageVideo.videoView.setVideoContentMode(.resizeAspectFill)
                self.backstageView = backstageVideo
                self.addSubview(backstageVideo, positioned: .below, relativeTo: self.currentVideoView)
                self.addSubview(backstage, positioned: .above, relativeTo: backstageVideo)
            }
        } else {
            if let currentVideoView = self.currentVideoView {
                currentVideoView.removeFromSuperview()
                self.currentVideoView = nil
            }
        }
        
        self.updateLayout(size: self.frame.size, transition: transition)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        
        guard let window = window else {
            return
        }
        self.validLayout = size
        if let currentVideoView = self.currentVideoView {
            transition.updateFrame(view: currentVideoView, frame: size.bounds)
            currentVideoView.updateLayout(size: size, transition: transition)
        }
        
        if let backstageView = self.backstageView {
            transition.updateFrame(view: backstageView, frame: size.bounds)
            backstageView.updateLayout(size: size, transition: transition)
        }
        transition.updateFrame(view: backstage, frame: window.frame.size.bounds)
        

        
        transition.updateFrame(view: shadowView, frame: CGRect(origin: NSMakePoint(0, size.height - 50), size: NSMakeSize(size.width, 50)))
        
        
        self.nameView.resize(size.width - 20)
        self.statusView.resize(size.width - 30 - self.nameView.frame.width)

        
        transition.updateFrame(view: self.nameView, frame: CGRect(origin: NSMakePoint(10, size.height - 10 - self.nameView.frame.height), size: self.nameView.frame.size))
        transition.updateFrame(view: self.statusView, frame: CGRect(origin: NSMakePoint(self.nameView.frame.maxX + 10, self.nameView.frame.minY), size: self.statusView.frame.size))
        
        

        transition.updateFrame(view: speakingView, frame: bounds)
        
        
        let pinnedSize = pinView.size(self.isPinned)
        
        let pinRect = CGRect(origin: CGPoint(x: frame.width - pinnedSize.width - 10, y: 10), size: pinnedSize)
        transition.updateFrame(view: pinView, frame: pinRect)
        pinView.updateLayout(size: pinRect.size, transition: transition)
    }
    
    deinit {
        audioLevelDisposable.dispose()
    }
    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }
}
