//
//  HorizontalScrollView.swift
//  TGUIKit
//
//  Created by Mikhail Filimonov on 26/12/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
//
//public class HorizontalScrollView: ScrollView {
//    
//    public override func scrollWheel(with event: NSEvent) {
//        
//        var scrollPoint = contentView.bounds.origin
//        let isInverted: Bool = System.isScrollInverted
//        if event.scrollingDeltaY != 0 {
//            if isInverted {
//                scrollPoint.y += -event.scrollingDeltaY
//            } else {
//                scrollPoint.y -= event.scrollingDeltaY
//            }
//        }
//        
//        if event.scrollingDeltaX != 0 {
//            if !isInverted {
//                scrollPoint.y += -event.scrollingDeltaX
//            } else {
//                scrollPoint.y -= event.scrollingDeltaX
//            }
//        }
//        
//        clipView.scroll(to: scrollPoint)
//        
//        
//    }
//    
//    
//    open override var hasVerticalScroller: Bool {
//        get {
//            return false
//        }
//        set {
//            super.hasVerticalScroller = newValue
//        }
//    }
//    
//    required public init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    
//}
