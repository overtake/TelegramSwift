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
    
    private var nameView: TextView?
    private var statusView: TextView?
    
    let gravityButton = ImageButton()

    var currentResizeMode: CALayerContentsGravity = .resizeAspect {
        didSet {
            self.currentVideoView?.setVideoContentMode(currentResizeMode, animated: true)
            gravityButton.set(image:  currentResizeMode == .resizeAspectFill ?  GroupCallTheme.videoZoomOut : GroupCallTheme.videoZoomIn, for: .Normal)
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
        
        gravityButton.set(image:  resizeMode == .resizeAspectFill ?  GroupCallTheme.videoZoomOut : GroupCallTheme.videoZoomIn, for: .Normal)
        gravityButton.sizeToFit()
        gravityButton.scaleOnClick = true
        gravityButton.autohighlight = false
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
    
    func updateMode(controlsMode: GroupCallView.ControlsMode, animated: Bool) {
        shadowView.change(opacity: controlsMode == .normal ? 1 : 0, animated: animated)
        gravityButton.change(opacity: controlsMode == .normal ? 1 : 0, animated: animated)
    }
    
    func updatePeer(peer: DominantVideo?, transition: ContainedViewLayoutTransition, controlsMode: GroupCallView.ControlsMode) {
        
        
        transition.updateAlpha(view: shadowView, alpha: controlsMode == .normal ? 1 : 0)
        transition.updateAlpha(view: gravityButton, alpha: controlsMode == .normal ? 1 : 0)

        
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
        transition.updateFrame(view: gravityButton, frame: CGRect.init(origin: NSMakePoint(size.width - 15 - gravityButton.frame.width, size.height - 15 - gravityButton.frame.height), size: gravityButton.frame.size))
    }
    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }
}
