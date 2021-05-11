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
    
    private(set) var currentVideoView: GroupVideoView?
    private(set) var currentPeer: DominantVideo?
    
    let shadowView: ShadowView = ShadowView()
    
    private var validLayout: CGSize?
    
    private let nameView: TextView = TextView()
    private var statusView: TextView = TextView()
    let gravityButton = ImageButton()

    var currentResizeMode: CALayerContentsGravity = .resizeAspect {
        didSet {
            self.currentVideoView?.setVideoContentMode(currentResizeMode, animated: true)
        }
    }
    
    private let speakingView: View = View()
    
    init(call: PresentationGroupCall, resizeMode: CALayerContentsGravity) {
        self.call = call
        self.currentResizeMode = resizeMode
        super.init()
        
        
        speakingView.layer?.cornerRadius = 10
        speakingView.layer?.borderWidth = 2
        speakingView.layer?.borderColor = GroupCallTheme.speakActiveColor.cgColor
        
        self.backgroundColor =  GroupCallTheme.membersColor
        addSubview(shadowView)
        
        shadowView.shadowBackground = NSColor.black.withAlphaComponent(0.3)
        shadowView.direction = .vertical(true)
        
        self.layer?.cornerRadius = 10
        
        //addSubview(gravityButton)
        
        gravityButton.sizeToFit()
        gravityButton.scaleOnClick = true
        gravityButton.autohighlight = false
        addSubview(nameView)
        addSubview(statusView)
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        
        statusView.userInteractionEnabled = false
        statusView.isSelectable = false
        
        addSubview(speakingView)
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
        gravityButton.change(opacity: controlsMode == .normal ? 1 : 0, animated: animated)
        
        nameView.change(opacity: controlsMode == .normal ? 1 : 0, animated: animated)
        statusView.change(opacity: controlsMode == .normal ? 1 : 0, animated: animated)

        gravityButton.set(image:  controlsState == .fullscreen ?  GroupCallTheme.videoZoomOut : GroupCallTheme.videoZoomIn, for: .Normal)
        gravityButton.sizeToFit()
    }
    
    private var participant: PeerGroupCallData?
    
    
    
    func updatePeer(peer: DominantVideo?, participant: PeerGroupCallData?, transition: ContainedViewLayoutTransition, animated: Bool, controlsMode: GroupCallView.ControlsMode) {
        
        
        transition.updateAlpha(view: speakingView, alpha: participant?.isSpeaking == true ? 1 : 0)
                
        transition.updateAlpha(view: shadowView, alpha: controlsMode == .normal ? 1 : 0)
        transition.updateAlpha(view: gravityButton, alpha: controlsMode == .normal ? 1 : 0)
        transition.updateAlpha(view: nameView, alpha: controlsMode == .normal ? 1 : 0)
        transition.updateAlpha(view: statusView, alpha: controlsMode == .normal ? 1 : 0)
        if participant != self.participant, let participant = participant {
            self.participant = participant
            let nameLayout = TextViewLayout(.initialize(string: participant.peer.displayTitle, color: NSColor.white.withAlphaComponent(0.8), font: .medium(.short)), maximumNumberOfLines: 1)
            nameLayout.measure(width: frame.width - 20)
            self.nameView.update(nameLayout)
                        
            if self.statusView.layout?.attributedString.string != participant.status.0 {
                let statusLayout = TextViewLayout(.initialize(string: participant.status.0, color: NSColor.white.withAlphaComponent(0.8), font: .normal(.short)), maximumNumberOfLines: 1)
                
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
            
                        
            self.updateLayout(size: self.frame.size, transition: transition)
        }

        
        if self.currentPeer == peer {
            return
        }
        
        self.currentPeer = peer
        if let peer = peer {
            var videoMode: GroupCallVideoMode = .video
            if peer.peerId == participant?.accountPeerId {
                switch peer.mode {
                case .video:
                    videoMode = .video
                case .screencast:
                    videoMode = .screencast
                }
            }
            
            self.call.makeVideoView(endpointId: peer.endpointId, videoMode: videoMode, completion: { [weak self] videoView in
                guard let strongSelf = self, let videoView = videoView else {
                    return
                }
                
                videoView.setVideoContentMode(strongSelf.currentResizeMode)

                
                let videoViewValue = GroupVideoView(videoView: videoView)
                if let currentVideoView = strongSelf.currentVideoView {
                    currentVideoView.removeFromSuperview()
                    strongSelf.currentVideoView = nil
                }
                videoViewValue.initialGravity = strongSelf.currentResizeMode
                strongSelf.currentVideoView = videoViewValue
                strongSelf.addSubview(videoViewValue, positioned: .below, relativeTo: strongSelf.shadowView)
                strongSelf.updateLayout(size: strongSelf.frame.size, transition: transition)
            })
        } else {
            if let currentVideoView = self.currentVideoView {
                currentVideoView.removeFromSuperview()
                self.currentVideoView = nil
            }
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        if let currentVideoView = self.currentVideoView {
            transition.updateFrame(view: currentVideoView, frame: bounds)
            currentVideoView.updateLayout(size: size, transition: transition)
        }
        transition.updateFrame(view: shadowView, frame: CGRect(origin: NSMakePoint(0, size.height - 50), size: NSMakeSize(size.width, 50)))
        transition.updateFrame(view: gravityButton, frame: CGRect(origin: NSMakePoint(size.width - 10 - gravityButton.frame.width, size.height - 10 - gravityButton.frame.height), size: gravityButton.frame.size))
        
        
        self.nameView.resize(size.width - 20)
        self.statusView.resize(size.width - 30 - self.nameView.frame.width)

        
        transition.updateFrame(view: self.nameView, frame: CGRect(origin: NSMakePoint(10, size.height - 10 - self.nameView.frame.height), size: self.nameView.frame.size))
        transition.updateFrame(view: self.statusView, frame: CGRect(origin: NSMakePoint(self.nameView.frame.maxX + 10, self.nameView.frame.minY), size: self.statusView.frame.size))
        

        transition.updateFrame(view: speakingView, frame: bounds)
    }
    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }
}
