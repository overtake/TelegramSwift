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
    let ssrc: UInt32
    init(_ peerId: PeerId, _ ssrc: UInt32) {
        self.peerId = peerId
        self.ssrc = ssrc
    }
}

final class MainVideoContainerView: Control {
    private let call: PresentationGroupCall
    
    private(set) var currentVideoView: GroupVideoView?
    private(set) var currentPeer: DominantVideo?
    
    let shadowView: ShadowView = ShadowView()
    
    private var validLayout: CGSize?
    
    private let nameView: TextView = TextView()
    private let statusView: TextView = TextView()
    private let pinnedImage = ImageView()
    let gravityButton = ImageButton()

    var currentResizeMode: CALayerContentsGravity = .resizeAspect {
        didSet {
            self.currentVideoView?.setVideoContentMode(currentResizeMode, animated: true)
        }
    }
    
    init(call: PresentationGroupCall, resizeMode: CALayerContentsGravity) {
        self.call = call
        self.currentResizeMode = resizeMode
        super.init()
        
        self.backgroundColor = .black
        addSubview(shadowView)
        
        shadowView.shadowBackground = NSColor.black.withAlphaComponent(0.6)
        shadowView.direction = .vertical(true)
        
        addSubview(gravityButton)
        
        gravityButton.sizeToFit()
        gravityButton.scaleOnClick = true
        gravityButton.autohighlight = false
        addSubview(nameView)
        addSubview(statusView)
        addSubview(pinnedImage)
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        
        statusView.userInteractionEnabled = false
        statusView.isSelectable = false
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
        pinnedImage.change(opacity: controlsMode == .normal ? 1 : 0, animated: animated)

        
        gravityButton.set(image:  controlsState == .fullscreen ?  GroupCallTheme.videoZoomOut : GroupCallTheme.videoZoomIn, for: .Normal)
        gravityButton.sizeToFit()
    }
    
    private var participant: PeerGroupCallData?
    
    
    func updatePeer(peer: DominantVideo?, participant: PeerGroupCallData?, transition: ContainedViewLayoutTransition, controlsMode: GroupCallView.ControlsMode) {
        
        
        transition.updateAlpha(view: shadowView, alpha: controlsMode == .normal ? 1 : 0)
        transition.updateAlpha(view: gravityButton, alpha: controlsMode == .normal ? 1 : 0)
        transition.updateAlpha(view: nameView, alpha: controlsMode == .normal ? 1 : 0)
        transition.updateAlpha(view: statusView, alpha: controlsMode == .normal ? 1 : 0)
        transition.updateAlpha(view: pinnedImage, alpha: controlsMode == .normal ? 1 : 0)
        if participant != self.participant, let participant = participant {
            self.participant = participant
            let nameLayout = TextViewLayout(.initialize(string: participant.peer.displayTitle, color: .white, font: .medium(.text)))
            self.nameView.update(nameLayout)
            
            let color = participant.status.1 == GroupCallTheme.grayStatusColor ? .white : participant.status.1
            
            let statusLayout = TextViewLayout(.initialize(string: participant.status.0, color: color, font: .normal(.short)))
            self.statusView.update(statusLayout)
            
            self.pinnedImage.image = GroupCallTheme.pinned_video
            self.pinnedImage.sizeToFit()
            
            self.updateLayout(size: self.frame.size, transition: transition)
        }

        
        if self.currentPeer == peer {
            return
        }
        
        self.currentPeer = peer
        if let peer = peer {
            self.call.makeVideoView(source: peer.ssrc, completion: { [weak self] videoView in
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
        
        
        self.nameView.resize(size.width / 2)
        self.statusView.resize(size.width / 2)

        
        transition.updateFrame(view: self.pinnedImage, frame: CGRect(origin: NSMakePoint(10, size.height - 10 - self.pinnedImage.frame.height), size: self.pinnedImage.frame.size))
        
        transition.updateFrame(view: self.nameView, frame: CGRect(origin: NSMakePoint(45, size.height - 10 - self.nameView.frame.height - self.statusView.frame.height), size: self.nameView.frame.size))
        transition.updateFrame(view: self.statusView, frame: CGRect(origin: NSMakePoint(45, size.height - 10 - self.statusView.frame.height), size: self.statusView.frame.size))
        

        
    }
    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }
}
