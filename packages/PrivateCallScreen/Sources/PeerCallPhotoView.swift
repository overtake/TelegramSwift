//
//  File.swift
//  
//
//  Created by Mikhail Filimonov on 08.02.2024.
//

import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import CallVideoLayer
import TGUIKit
import MetalEngine
import AppKit



final class PeerCallPhotoView : Control, CallViewUpdater {
    private var photoView: NSView?
    let blobView: CallBlobView?
    let blobView_fallback: VoiceBlobView?
    required init(frame frameRect: NSRect) {
        
    #if arch(arm64)
        self.blobView = CallBlobView(frame: NSMakeRect(0, 0, 170, 170))
        self.blobView_fallback = nil
    #else
        self.blobView = nil
        self.blobView_fallback = VoiceBlobView(
            frame: NSMakeRect(0, 0, 200, 200),
            maxLevel: 1.0,
            smallBlobRange: (0, 0),
            mediumBlobRange: (0.7, 0.8),
            bigBlobRange: (0.8, 0.9)
            )
    #endif
        
        
        super.init(frame: frameRect)
        if let blobView {
            addSubview(blobView)
        } else if let blobView_fallback {
            addSubview(blobView_fallback)
        }
        layer?.masksToBounds = false
        userInteractionEnabled = false
        
        blobView_fallback?.startAnimating()
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateState(_ state: PeerCallState, arguments: Arguments, transition: ContainedViewLayoutTransition) {
        let photoView = arguments.makeAvatar(self.photoView, state.peer?._asPeer())
        if let photoView = photoView {
            self.addSubview(photoView)
            self.photoView = photoView
        }
        blobView_fallback?.setColor(colorSets_fallback[state.stateIndex][0], animated: transition.isAnimated)
        

    }
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        if let photoView = photoView {
            transition.updateFrame(view: photoView, frame: photoView.centerFrame())
        }
        if let blobView {
            transition.updateFrame(view: blobView, frame: blobView.centerFrame())
        }
        if let blobView_fallback {
            transition.updateFrame(view: blobView_fallback, frame: blobView_fallback.centerFrame())
        }
    }
}
