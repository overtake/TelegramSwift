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

private final class BackView : Control {
    private let imageView:ImageView = ImageView()
    private var textView: TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        
        addSubview(textView)

        
        backgroundColor = GroupCallTheme.windowBackground.withAlphaComponent(0.9)
        imageView.isEventLess = true
        scaleOnClick = true
        set(background: GroupCallTheme.windowBackground.withAlphaComponent(0.7), for: .Highlight)
        
        let textLayout = TextViewLayout(.initialize(string: L10n.navigationBack, color: GroupCallTheme.customTheme.textColor, font: .medium(.title)))
        textLayout.measure(width: .greatestFiniteMagnitude)
        textView.update(textLayout)
        
        imageView.animates = false
        imageView.image = GroupCallTheme.video_back
        imageView.sizeToFit()

        setFrameSize(NSMakeSize(imageView.frame.width + textView.frame.width + 25, 30))
        
        layer?.cornerRadius = frame.height / 2
        
        imageView.isEventLess = true
        textView.userInteractionEnabled = false
        textView.isSelectable = false

        layout()
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: imageView, frame: imageView.centerFrameY(x: 10))
        let textFrame = textView.centerFrameY(x: frame.width - textView.frame.width - 10, addition: -1)
        transition.updateFrame(view: textView, frame: textFrame)
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
    
    enum PinMode {
        case permanent
        case focused
    }
    
    let peerId: PeerId
    let endpointId: String
    let mode: VideoSourceMacMode
    let pinMode: PinMode?
    init(_ peerId: PeerId, _ endpointId: String, _ mode: VideoSourceMacMode, _ pinMode: PinMode?) {
        self.peerId = peerId
        self.endpointId = endpointId
        self.mode = mode
        self.pinMode = pinMode
    }
}

final class GroupCallMainVideoContainerView: Control {
    private let call: PresentationGroupCall
    
    private(set) var backstageView: GroupVideoView?
    private let backstage: NSVisualEffectView = NSVisualEffectView(frame: .zero)

    
    private(set) var currentVideoView: GroupVideoView?
    private(set) var currentPeer: DominantVideo?
    
    let shadowView: ShadowView = ShadowView()
    
    private var validLayout: CGSize?
    
    private let nameView: TextView = TextView()
    private let statusView = ImageView()
    
    private let speakingView: View = View()
    private let audioLevelDisposable = MetaDisposable()
    
    private var arguments: GroupCallUIArguments?
    
    private var backView: BackView?
    private var pinView: PinView?

    
    private var pausedTextView: TextView?
    
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
        backstage.material = .dark
        backstage.blendingMode = .withinWindow
        backstage.state = .active
        
        
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        
        statusView.isEventLess = true
                
        addSubview(speakingView)
        
        
        self.set(handler: { [weak self] _ in
            if let dominant = self?.currentPeer, self?.isPinned == false {
                self?.arguments?.focusVideo(dominant.endpointId)
            }
        }, for: .SingleClick)
        
        self.set(handler: { [weak self] control in
            if let data = self?.participant {
                if let menuItems = self?.arguments?.contextMenuItems(data), let event = NSApp.currentEvent {
                    ContextMenu.show(items: menuItems, view: control, event: event)
                }
            }
        }, for: .RightDown)
        
      
        
        self.set(handler: { [weak self] control in
            self?.pinView?.change(opacity: self?.pinIsVisible == true ? 1 : 0, animated: true)
            self?.backView?.change(opacity: self?.pinIsVisible == true ? 1 : 0, animated: true)
        }, for: .Hover)
        
        self.set(handler: { [weak self] control in
            self?.pinView?.change(opacity: self?.pinIsVisible == true ? 1 : 0, animated: true)
            self?.backView?.change(opacity: self?.pinIsVisible == true ? 1 : 0, animated: true)
        }, for: .Highlight)
        
        self.set(handler: { [weak self] control in
            self?.pinView?.change(opacity: 0, animated: true)
            self?.backView?.change(opacity: 0, animated: true)
        }, for: .Normal)
        
    }
    
    private var pinIsVisible: Bool {
        return ((self.isFocused && !isAlone) || self.isPinned)
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
        self.pinView?.change(opacity: self.mouseInside() && self.pinIsVisible ? 1 : 0, animated: animated)
        self.backView?.change(opacity: self.mouseInside() && self.pinIsVisible ? 1 : 0, animated: animated)
    }
    
    private var participant: PeerGroupCallData?
    
    private var isPinned: Bool = false
    private var isFocused: Bool = false
    private var isAlone: Bool = false
    func updatePeer(peer: DominantVideo?, participant: PeerGroupCallData?, resizeMode: CALayerContentsGravity, transition: ContainedViewLayoutTransition, animated: Bool, controlsMode: GroupCallView.ControlsMode, isPinned: Bool, isFocused: Bool, isAlone: Bool, arguments: GroupCallUIArguments?) {
        
       
        self.isFocused = isFocused
        self.isPinned = isPinned
        self.isAlone = isAlone
        self.arguments = arguments
        
        
        if self.pinIsVisible {
            let currentPinView: PinView
            if let current = self.pinView {
                currentPinView = current
            } else {
                currentPinView = PinView(frame: .zero)
                let pinnedSize = currentPinView.size(isPinned)
                let pinRect = CGRect(origin: CGPoint(x: frame.width - pinnedSize.width - 10, y: 10), size: pinnedSize)
                currentPinView.frame = pinRect
                currentPinView.layer?.opacity = self.mouseInside() && pinIsVisible ? 1 : 0
                self.pinView = currentPinView
                addSubview(currentPinView)
                currentPinView.set(handler: { [weak self] _ in
                    if let strongSelf = self, let dominant = strongSelf.currentPeer {
                        if !strongSelf.isPinned {
                            self?.arguments?.pinVideo(dominant)
                        } else {
                            self?.arguments?.unpinVideo()
                        }
                    }
                }, for: .SingleClick)
                
                if currentPinView.layer?.opacity != 0, animated {
                    currentPinView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            currentPinView.update(self.isPinned, animated: animated)
            
            
        } else {
            if let view = pinView {
                self.pinView = nil
                if animated {
                    if view.layer?.opacity != 0 {
                        view.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] _ in
                            view?.removeFromSuperview()
                        })
                    }
                } else {
                    view.removeFromSuperview()
                }
            }
        }
        
        if pinIsVisible {
            let currentBackView: BackView
            if let current = self.backView {
                currentBackView = current
            } else {
                currentBackView = BackView(frame: .zero)
                currentBackView.frame = NSMakeRect(10, 10, currentBackView.frame.width, currentBackView.frame.height)
                currentBackView.layer?.opacity = self.mouseInside() && pinIsVisible ? 1 : 0
                self.backView = currentBackView
                addSubview(currentBackView)
                currentBackView.set(handler: { [weak self] _ in
                    self?.arguments?.focusVideo(nil)
                }, for: .SingleClick)
                
                if currentBackView.layer?.opacity != 0, animated {
                    currentBackView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
        } else {
            if let view = backView {
                self.backView = nil
                if animated {
                    if view.layer?.opacity != 0 {
                        view.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] _ in
                            view?.removeFromSuperview()
                        })
                    }
                } else {
                    view.removeFromSuperview()
                }
            }
        }
        
//        self.pinView.update(isPinned, animated: animated)
//
        self.pinView?.change(opacity: self.mouseInside() && pinIsVisible ? 1 : 0, animated: animated)
        self.backView?.change(opacity: self.mouseInside() && pinIsVisible ? 1 : 0, animated: animated)

        
        
        let showSpeakingView = participant?.isSpeaking == true && (participant?.state?.muteState?.mutedByYou == nil || participant?.state?.muteState?.mutedByYou == false)
        
        transition.updateAlpha(view: speakingView, alpha: showSpeakingView ? 1 : 0)
        
        speakingView.layer?.borderColor = participant?.state?.muteState?.mutedByYou == true ? GroupCallTheme.customTheme.redColor.cgColor : GroupCallTheme.speakActiveColor.cgColor
                
        transition.updateAlpha(view: shadowView, alpha: controlsMode == .normal ? 1 : 0)
        transition.updateAlpha(view: nameView, alpha: controlsMode == .normal ? 1 : 0)
        transition.updateAlpha(view: statusView, alpha: controlsMode == .normal ? 1 : 0)
        
        
        if participant != self.participant, let participant = participant {
            let text: String
            if participant.peer.id == participant.accountPeerId {
                text = L10n.voiceChatStatusYou
            } else {
                text = participant.peer.displayTitle
            }
            let nameLayout = TextViewLayout(.initialize(string: text, color: NSColor.white.withAlphaComponent(1), font: .medium(.short)), maximumNumberOfLines: 1)
            nameLayout.measure(width: frame.width - 20)
            self.nameView.update(nameLayout)
            
            self.statusView.image = participant.state?.muteState == nil ? GroupCallTheme.videoBox_unmuted : GroupCallTheme.videoBox_muted
            self.statusView.sizeToFit()
        }
        self.currentPeer = peer
        if let peer = peer {
           
            let videoView = arguments?.takeVideo(peer.peerId, peer.mode, .main) as? GroupVideoView
            let backstageVideo = arguments?.takeVideo(peer.peerId, peer.mode, .backstage) as? GroupVideoView
            
            
            
            if let videoView = videoView, self.currentVideoView != videoView || videoView.superview != self {
                if let currentVideoView = self.currentVideoView {
                    currentVideoView.removeFromSuperview()
                }
                self.currentVideoView = videoView
                self.addSubview(videoView, positioned: .below, relativeTo: self.shadowView)
            }
            if let videoView = videoView {
                let isPaused = participant?.isVideoPaused(peer.endpointId) == true
                let prevIsPaused = self.participant?.isVideoPaused(peer.endpointId) == true
                if prevIsPaused != isPaused {
                    if isPaused {
                        self.pausedTextView?.removeFromSuperview()
                        self.pausedTextView = TextView()
                        
                        let layout = TextViewLayout(.initialize(string: peer.mode == .video ? L10n.voiceChatVideoPaused : L10n.voiceChatScreencastPaused, color: GroupCallTheme.customTheme.textColor, font: .medium(.text)))
                        layout.measure(width: .greatestFiniteMagnitude)
                        self.pausedTextView?.update(layout)
                        self.pausedTextView?.frame = focus(layout.layoutSize)
                        addSubview(self.pausedTextView!)
                        if animated {
                            if videoView.superview != nil {
                                videoView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak videoView] completion in
                                    if completion {
                                        videoView?.removeFromSuperview()
                                    }
                                    videoView?.layer?.removeAnimation(forKey: "opacity")
                                })
                            }
                            pausedTextView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                        } else {
                            videoView.removeFromSuperview()
                        }
                    } else {
                        if animated {
                            videoView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                        }
                        if let pausedTextView = pausedTextView {
                            self.pausedTextView = nil
                            if animated {
                                pausedTextView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak pausedTextView] _ in
                                    pausedTextView?.removeFromSuperview()
                                })
                            } else {
                                pausedTextView.removeFromSuperview()
                            }
                        }
                    }
                }
            }
            
            
            self.currentVideoView?.gravity = resizeMode

            if let backstageVideo = backstageVideo, self.backstageView != backstageView || backstageVideo.superview != self {
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
        self.participant = participant

        self.updateLayout(size: self.frame.size, transition: transition)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        
        
        self.validLayout = size
        if let currentVideoView = self.currentVideoView {
            transition.updateFrame(view: currentVideoView, frame: size.bounds)
            currentVideoView.updateLayout(size: size, transition: transition)
        }
        
        if let backstageView = self.backstageView {
            transition.updateFrame(view: backstageView, frame: size.bounds)
            backstageView.updateLayout(size: size, transition: transition)
        }
    
        if let window = window {
            transition.updateFrame(view: backstage, frame: window.frame.size.bounds)
        }
        

        
        transition.updateFrame(view: shadowView, frame: CGRect(origin: NSMakePoint(0, size.height - 50), size: NSMakeSize(size.width, 50)))
        
        
        self.nameView.resize(size.width - 40)

        
        transition.updateFrame(view: statusView, frame: CGRect(origin: NSMakePoint(10, size.height - 10 - self.statusView.frame.height), size: self.statusView.frame.size))
        transition.updateFrame(view: self.nameView, frame: CGRect(origin: NSMakePoint(statusView.frame.maxX + 5, size.height - 10 - self.nameView.frame.height), size: self.nameView.frame.size))
        
        transition.updateFrame(view: speakingView, frame: bounds)
        
        if let pausedTextView = pausedTextView {
            transition.updateFrame(view: pausedTextView, frame: focus(pausedTextView.frame.size))
        }
        
        if let pinView = pinView {
            let pinnedSize = pinView.size(self.isPinned)
            let pinRect = CGRect(origin: CGPoint(x: frame.width - pinnedSize.width - 10, y: 10), size: pinnedSize)
            transition.updateFrame(view: pinView, frame: pinRect)
            pinView.updateLayout(size: pinRect.size, transition: transition)
        }
        if let backView = self.backView {
            let backRect = NSMakeRect(10, 10, backView.frame.width, backView.frame.height)
            transition.updateFrame(view: backView, frame: backRect)
            backView.updateLayout(size: backRect.size, transition: transition)
        }
    }
    
    deinit {
        audioLevelDisposable.dispose()
    }
    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }
}
