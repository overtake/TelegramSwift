//
//  AnimatedWebpRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12.04.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import libwebp
import SwiftSignalKit

final class AnimatedWebpRowItem : GeneralRowItem {
    
    fileprivate let data: Data
    init(_ initialSize: NSSize, stableId: AnyHashable, data: Data) {
        self.data = data
        super.init(initialSize, height: 200, stableId: stableId)
    }
    
    override func viewClass() -> AnyClass {
        return AnimatedWebpRowView.self
    }
}


private final class AnimatedWebpRowView : GeneralContainableRowView {
    private let imageView: NSImageView = NSImageView()
    private var timer: SwiftSignalKit.Timer?
    private var decoder: WebPImageDecoder?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
    }
    
    override func layout() {
        super.layout()
        imageView.frame = containerView.bounds
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? AnimatedWebpRowItem else {
            return
        }
        
        self.decoder = WebPImageDecoder(data: item.data, scale: System.backingScale)
        
        var frame: UInt = 0
        
        if let decoder = self.decoder {
            
            var invokeNext:(()->Void)? = nil
            let next:()->Void = { [weak decoder, weak self] in
                guard let decoder = decoder else {
                    return
                }
                guard let decodedFrame = decoder.frame(at: frame, decodeForDisplay: true) else {
                    return
                }
                self?.imageView.image = decodedFrame.image
                
                frame += 1
                if frame >= decoder.frameCount {
                    frame = 0
                }
                self?.timer = SwiftSignalKit.Timer.init(timeout: decodedFrame.duration, repeat: false, completion: {
                    invokeNext?()
                }, queue: .mainQueue())
                
                self?.timer?.start()
            }
            
            invokeNext = {
                next()
            }
            
            next()
            
            
        }
        
        
        
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
