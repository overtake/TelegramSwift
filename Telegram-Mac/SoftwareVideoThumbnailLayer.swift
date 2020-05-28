//
//  SoftwareVideoThumbnailLayer.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 27/05/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa

import Foundation
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit

private final class SoftwareVideoThumbnailLayerNullAction: NSObject, CAAction {
    @objc func run(forKey event: String, object anObject: Any, arguments dict: [AnyHashable : Any]?) {
    }
}

final class SoftwareVideoThumbnailView: NSView {
    private var asolutePosition: (CGRect, CGSize)?
    
    var disposable = MetaDisposable()
    
    var ready: (() -> Void)? {
        didSet {
            if self.layer?.contents != nil {
                self.ready?()
            }
        }
    }
    
    init(account: Account, fileReference: FileMediaReference, synchronousLoad: Bool) {
        super.init(frame: .zero)
        

        self.layer?.backgroundColor = NSColor.clear.cgColor
        self.layer?.contentsGravity = .resizeAspectFill
        self.layer?.masksToBounds = true
        
        if let dimensions = fileReference.media.dimensions {
            self.disposable.set((mediaGridMessageVideo(postbox: account.postbox, fileReference: fileReference, scale: backingScaleFactor, synchronousLoad: synchronousLoad)
                |> deliverOnMainQueue).start(next: { [weak self] transform in
                    var boundingSize = dimensions.size.aspectFilled(CGSize(width: 93.0, height: 93.0))
                    let imageSize = boundingSize
                    boundingSize.width = min(200.0, boundingSize.width)
                    
                    let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: NSEdgeInsets(), resizeMode: .fill(.clear))
                    
                    if let image = transform.execute(arguments, transform.data)?.generateImage() {
                        Queue.mainQueue().async {
                            if let strongSelf = self {
                                strongSelf.layer?.contents = image
                                strongSelf.ready?()
                            }
                        }
                    }
                }))
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
    }

}

