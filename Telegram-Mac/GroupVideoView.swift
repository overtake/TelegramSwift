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
    
    var tapped: (() -> Void)?
    
    init(videoView: PresentationCallVideoView) {
        self.videoViewContainer = View()
        self.videoView = videoView
        
        super.init()
        
        self.videoViewContainer.addSubview(self.videoView.view)
        self.addSubview(self.videoViewContainer)
        
        
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
        
        transition.updateFrame(view: self.videoViewContainer, frame: focus(size))
        let aspect = videoView.getAspect()
        
        var videoRect: CGRect = .zero
        switch gravity {
        case .resizeAspect:
            videoRect = focus(size)
        case .resizeAspectFill:
            var boundingSize = size
            boundingSize = NSMakeSize(max(size.width, size.height) * aspect, max(size.width, size.height))
            boundingSize = boundingSize.aspectFilled(size)
            videoRect = focus(boundingSize)
        default:
            break
        }
        transition.updateFrame(view: self.videoView.view, frame: videoRect)
        for subview in self.videoView.view.subviews {
            transition.updateFrame(view: subview, frame: videoRect.size.bounds)
        }
    }
    
    override func viewDidMoveToSuperview() {
        if superview == nil {
            didRemoveFromSuperview?()
        } 
    }
    
    var didRemoveFromSuperview: (()->Void)? = nil
    
}
