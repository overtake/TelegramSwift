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
    let blobView = CallBlobView(frame: NSMakeRect(0, 0, 170, 170))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(self.blobView)
        layer?.masksToBounds = false
        userInteractionEnabled = false
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
    }
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        if let photoView = photoView {
            transition.updateFrame(view: photoView, frame: photoView.centerFrame())
        }
        transition.updateFrame(view: blobView, frame: blobView.centerFrame())
    }
}
