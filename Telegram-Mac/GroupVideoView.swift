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
    private var gravity: CALayerContentsGravity = .resizeAspect
    private var validLayout: CGSize?
    
    var tapped: (() -> Void)?
    
    init(videoView: PresentationCallVideoView) {
        self.videoViewContainer = View()
        self.videoView = videoView
        
        super.init()
        
        self.videoViewContainer.addSubview(self.videoView.view)
        self.addSubview(self.videoViewContainer)
        
        videoView.setOnFirstFrameReceived({ [weak self] _ in
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                if let size = strongSelf.validLayout {
                    strongSelf.updateLayout(size: size, transition: .immediate)
                }
            }
        })
        
        videoView.setOnOrientationUpdated({ [weak self] _, _ in
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                if let size = strongSelf.validLayout {
                    strongSelf.updateLayout(size: size, transition: .immediate)
                }
            }
        })
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    func setVideoContentMode(_ contentMode: CALayerContentsGravity, animated: Bool) {
        self.gravity = contentMode
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.3, curve: .easeInOut) : .immediate
        
        self.validLayout = nil
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
        
        transition.updateFrame(view: self.videoViewContainer, frame: focus(size))
        let aspect = videoView.getAspect()
        
        switch gravity {
        case .resizeAspect:
            transition.updateFrame(view: self.videoView.view, frame: focus(size))
        case .resizeAspectFill:
            var boundingSize = size
            boundingSize = NSMakeSize(max(size.width, size.height) * aspect, max(size.width, size.height))
            boundingSize = boundingSize.aspectFilled(size)
            transition.updateFrame(view: self.videoView.view, frame: focus(boundingSize))
        default:
            break
        }
        

        
        let orientation = self.videoView.getOrientation()
//        if aspect <= 0.01 {
//            aspect = 3.0 / 4.0
//        }
        
        let rotatedAspect: CGFloat
        let angle: CGFloat
        let switchOrientation: Bool
        switch orientation {
        case .rotation0:
            angle = 0.0
            rotatedAspect = 1 / aspect
            switchOrientation = false
        case .rotation90:
            angle = CGFloat.pi / 2.0
            rotatedAspect = aspect
            switchOrientation = true
        case .rotation180:
            angle = CGFloat.pi
            rotatedAspect = 1 / aspect
            switchOrientation = false
        case .rotation270:
            angle = CGFloat.pi * 3.0 / 2.0
            rotatedAspect = aspect
            switchOrientation = true
        }
        
        var rotatedVideoSize = CGSize(width: 100.0, height: rotatedAspect * 100.0)
        
        if size.width < 100.0 || true {
            rotatedVideoSize = rotatedVideoSize.aspectFilled(size)
        } else {
            rotatedVideoSize = rotatedVideoSize.aspectFitted(size)
        }
        
        if switchOrientation {
            rotatedVideoSize = CGSize(width: rotatedVideoSize.height, height: rotatedVideoSize.width)
        }
        var rotatedVideoFrame = CGRect(origin: CGPoint(x: floor((size.width - rotatedVideoSize.width) / 2.0), y: floor((size.height - rotatedVideoSize.height) / 2.0)), size: rotatedVideoSize)
        rotatedVideoFrame.origin.x = floor(rotatedVideoFrame.origin.x)
        rotatedVideoFrame.origin.y = floor(rotatedVideoFrame.origin.y)
        rotatedVideoFrame.size.width = ceil(rotatedVideoFrame.size.width)
        rotatedVideoFrame.size.height = ceil(rotatedVideoFrame.size.height)
      //  self.videoView.view.center = rotatedVideoFrame.center
//        self.videoView.view.frame = bounds
        
        let transition: ContainedViewLayoutTransition = .immediate
    }
    
}
