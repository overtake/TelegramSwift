//
//  GroupVideoView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 11.01.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit


final class GroupVideoView: View {
    
    
    private let videoViewContainer: View
    let videoView: PresentationCallVideoView
    var gravity: CALayerContentsGravity = .resizeAspect
    var initialGravity: CALayerContentsGravity? = nil
    private var validLayout: CGSize?
    
    private var videoAnimator: DisplayLinkAnimator?
    
    private var isMirrored: Bool = false {
        didSet {
            CATransaction.begin()
            if isMirrored {
                let rect = self.videoViewContainer.bounds
                var fr = CATransform3DIdentity
                fr = CATransform3DTranslate(fr, rect.width / 2, 0, 0)
                fr = CATransform3DScale(fr, -1, 1, 1)
                fr = CATransform3DTranslate(fr, -(rect.width / 2), 0, 0)
                self.videoViewContainer.layer?.sublayerTransform = fr
            } else {
                self.videoViewContainer.layer?.sublayerTransform = CATransform3DIdentity
            }
            CATransaction.commit()
        }
    }
    
    var tapped: (() -> Void)?
    
    init(videoView: PresentationCallVideoView) {
        self.videoViewContainer = View()
        self.videoView = videoView
        
        super.init()
        
        self.videoViewContainer.addSubview(self.videoView.view)
        self.addSubview(self.videoViewContainer)
        
        
        videoView.setOnOrientationUpdated({ [weak self] _, _ in
            guard let strongSelf = self else {
                return
            }
            if let size = strongSelf.validLayout {
                strongSelf.updateLayout(size: size, transition: .immediate)
            }
        })
        
        videoView.setOnIsMirroredUpdated({ [weak self] isMirrored in
            self?.isMirrored = isMirrored
        })
        
//        videoView.setIsPaused(true);
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
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
    
    func setVideoContentMode(_ contentMode: CALayerContentsGravity, animated: Bool) {


        self.gravity = contentMode
        self.validLayout = nil
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.3, curve: .easeInOut) : .immediate
        self.updateLayout(size: frame.size, transition: transition)
    }
    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        guard self.validLayout != size else {
            return
        }
        self.validLayout = size
        
        var videoRect: CGRect = .zero
        videoRect = focus(size)
        
        transition.updateFrame(view: self.videoViewContainer, frame: videoRect)
        
        if transition.isAnimated {
            let videoView = self.videoView
                        
            videoView.renderToSize(self.videoView.view.frame.size, true)
            videoView.setIsPaused(true)

            transition.updateFrame(view: videoView.view, frame: videoRect, completion: { [weak videoView] _ in
                videoView?.setIsPaused(false)
                videoView?.renderToSize(videoRect.size, false)
            })
        } else {
            transition.updateFrame(view: videoView.view, frame: videoRect)
        }
        

        for subview in self.videoView.view.subviews {
            transition.updateFrame(view: subview, frame: videoRect.size.bounds)
        }
        
        var fr = CATransform3DIdentity
        if isMirrored {
            let rect = videoRect
            fr = CATransform3DTranslate(fr, rect.width / 2, 0, 0)
            fr = CATransform3DScale(fr, -1, 1, 1)
            fr = CATransform3DTranslate(fr, -(rect.width / 2), 0, 0)
        }
        
        switch transition {
        case .immediate:
            self.videoViewContainer.layer?.sublayerTransform = fr
        case let .animated(duration, curve):
            let animation = CABasicAnimation(keyPath: "sublayerTransform")
            animation.fromValue = self.videoViewContainer.layer?.presentation()?.sublayerTransform ?? self.videoViewContainer.layer?.sublayerTransform ?? CATransform3DIdentity
            animation.toValue = fr
            animation.timingFunction = .init(name: curve.timingFunction)
            animation.duration = duration
            self.videoViewContainer.layer?.add(animation, forKey: "sublayerTransform")
            self.videoViewContainer.layer?.sublayerTransform = fr
        }

    }
    
    override func viewDidMoveToSuperview() {
        if superview == nil {
            didRemoveFromSuperview?()
        } 
    }
    
    var didRemoveFromSuperview: (()->Void)? = nil
}
