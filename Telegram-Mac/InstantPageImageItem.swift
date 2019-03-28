//
//  InstantPageImageItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12/12/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import TelegramCoreMac

protocol InstantPageImageAttribute {
}

struct InstantPageMapAttribute: InstantPageImageAttribute {
    let zoom: Int32
    let dimensions: CGSize
}

final class InstantPageImageItem: InstantPageItem {
    let hasLinks: Bool = false
    let isInteractive: Bool
    let separatesTiles: Bool = false

    func linkSelectionViews() -> [InstantPageLinkSelectionView] {
        return []
    }
    
    var frame: CGRect
    
    let webPage: TelegramMediaWebpage
    
    let media: InstantPageMedia
    let attributes: [InstantPageImageAttribute]
    
    var medias: [InstantPageMedia] {
        return [self.media]
    }
    
    let roundCorners: Bool
    let fit: Bool
    
    let wantsView: Bool = true
    
    init(frame: CGRect, webPage: TelegramMediaWebpage, media: InstantPageMedia, attributes: [InstantPageImageAttribute] = [], interactive: Bool, roundCorners: Bool, fit: Bool) {
        self.frame = frame
        self.webPage = webPage
        self.media = media
        self.isInteractive = interactive
        self.attributes = attributes
        self.roundCorners = roundCorners
        self.fit = fit
    }
    
    func view(arguments: InstantPageItemArguments, currentExpandedDetails: [Int : Bool]?) -> (InstantPageView & NSView)? {
        
        let viewArguments: InstantPageMediaArguments
        if let _ = media.media as? TelegramMediaMap, let attribute = attributes.first as? InstantPageMapAttribute {
            viewArguments = .map(attribute)
        } else {
            viewArguments = .image(interactive: self.isInteractive, roundCorners: self.roundCorners, fit: self.fit)
        }
        
        return  InstantPageMediaView(context: arguments.context, media: media, arguments: viewArguments)
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func matchesView(_ node: InstantPageView) -> Bool {
        if let node = node as? InstantPageMediaView {
            return node.media == self.media
        } else {
            return false
        }
    }
    
    func distanceThresholdGroup() -> Int? {
        return 1
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        if count > 3 {
            return 400.0
        } else {
            return CGFloat.greatestFiniteMagnitude
        }
    }
    
    func drawInTile(context: CGContext) {
    }
    
    func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        return []
    }
}




