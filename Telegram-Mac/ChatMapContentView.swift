//
//  ChatMapContentView.swift
//  TelegramMac
//
//  Created by keepcoder on 09/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore



class ChatMapContentView: ChatMediaContentView {
    private let imageView:TransformImageView = TransformImageView()
    private let iconView:ImageView = ImageView()
    private var textView:TextView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        imageView.addSubview(iconView)

    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func executeInteraction(_ isControl: Bool) {
        if let parameters = self.parameters as? ChatMediaMapLayoutParameters {
            parameters.execute()
        }
    }
    
    override func layout() {
        super.layout()
        if let parameters = parameters as? ChatMediaMapLayoutParameters {
            imageView.set(arguments: parameters.arguments)
            imageView.setFrameSize(parameters.arguments.imageSize)
            iconView.center()
            textView?.update(parameters.venueText)
            textView?.centerY(x:70)
        }
    }
    
    override func update(with media: Media, size: NSSize, context: AccountContext, parent: Message?, table: TableView?, parameters: ChatMediaLayoutParameters?, animated: Bool = false, positionFlags: LayoutPositionFlags? = nil, approximateSynchronousValue: Bool = false) {
        let versionUpdated = parent?.stableVersion != self.parent?.stableVersion
        var mediaUpdated = self.media == nil || !media.isSemanticallyEqual(to: self.media!) || versionUpdated
        iconView.image = theme.icons.chatMapPin
        iconView.sizeToFit()

        super.update(with: media, size: size, context: context, parent: parent, table: table, parameters: parameters, animated: animated, positionFlags: positionFlags)
        
        if let positionFlags = positionFlags {
            let path = CGMutablePath()
            
            let minx:CGFloat = 0, midx = frame.width/2.0, maxx = frame.width
            let miny:CGFloat = 0, midy = frame.height/2.0, maxy = frame.height
            
            path.move(to: NSMakePoint(minx, midy))
            
            var topLeftRadius: CGFloat = .cornerRadius
            var bottomLeftRadius: CGFloat = .cornerRadius
            var topRightRadius: CGFloat = .cornerRadius
            var bottomRightRadius: CGFloat = .cornerRadius
            
            
            if positionFlags.contains(.bottom) && positionFlags.contains(.left) {
                topLeftRadius = topLeftRadius * 3 + 2
            }
            if positionFlags.contains(.bottom) && positionFlags.contains(.right) {
                topRightRadius = topRightRadius * 3 + 2
            }
            if positionFlags.contains(.top) && positionFlags.contains(.left) {
                bottomLeftRadius = bottomLeftRadius * 3 + 2
            }
            if positionFlags.contains(.top) && positionFlags.contains(.right) {
                bottomRightRadius = bottomRightRadius * 3 + 2
            }
            
            path.addArc(tangent1End: NSMakePoint(minx, miny), tangent2End: NSMakePoint(midx, miny), radius: bottomLeftRadius)
            path.addArc(tangent1End: NSMakePoint(maxx, miny), tangent2End: NSMakePoint(maxx, midy), radius: bottomRightRadius)
            path.addArc(tangent1End: NSMakePoint(maxx, maxy), tangent2End: NSMakePoint(midx, maxy), radius: topLeftRadius)
            path.addArc(tangent1End: NSMakePoint(minx, maxy), tangent2End: NSMakePoint(minx, midy), radius: topRightRadius)
            
            let maskLayer: CAShapeLayer = CAShapeLayer()
            maskLayer.path = path
            layer?.mask = maskLayer
        } else {
            layer?.mask = nil
        }
        
        
        
        if let parameters = parameters as? ChatMediaMapLayoutParameters, let resource = parameters.resource as? MapSnapshotMediaResource {
            
            imageView.setSignal(signal: cachedMedia(media: media, arguments: parameters.arguments, scale: backingScaleFactor, positionFlags: positionFlags), clearInstantly: false)
            mediaUpdated = mediaUpdated && !self.imageView.hasImage
            
            imageView.setSignal( chatMapSnapshotImage(account: context.account, resource: resource), clearInstantly: false, animate: mediaUpdated, cacheImage: { [weak media] result in
                if let media = media {
                    cacheMedia(result, media: media, arguments: parameters.arguments, scale: System.backingScale, positionFlags: positionFlags)
                }
            })
            
            if parameters.isVenue {
                if textView == nil {
                    textView = TextView()
                    
                    textView?.isSelectable = false
                    addSubview(textView!)
                }
                
            }
        }
        needsLayout = true
    }
    
}
