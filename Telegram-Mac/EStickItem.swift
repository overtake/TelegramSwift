//
//  EStickItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 17/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
class EStickItem: TableStickItem {
    
    override var height: CGFloat {
        return 30
    }
    

    
    var segment:EmojiSegment
    override var stableId: AnyHashable {
        return Int64(segment.rawValue)
    }
    
    let layout:(TextNodeLayout, TextNode)
    
    init(_ initialSize:NSSize, segment:EmojiSegment, segmentName:String) {
        layout = TextNode.layoutText(maybeNode: nil,  NSAttributedString.initialize(string: segmentName.uppercased(), color: theme.colors.grayText, font: .medium(.short)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .left)
        self.segment = segment
        super.init(initialSize)
    }
    
    required init(_ initialSize: NSSize) {
        layout = TextNode.layoutText(nil, nil, 0, .end, NSZeroSize, nil, false, .center)
        segment = .Recent
        super.init(initialSize)
    }
    
    override func viewClass() -> AnyClass {
        return EStickView.self
    }
    
}
