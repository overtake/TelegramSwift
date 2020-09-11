//
//  VolumeControllerPopover.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 28/07/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class VolumeControllerPopover: GenericViewController<HorizontalSliderControl> {

    
    private let initialValue: CGFloat
    private let updatedValue: (CGFloat)->Void
    init(initialValue: CGFloat, updatedValue: @escaping(CGFloat)->Void) {
        self.initialValue = initialValue
        self.updatedValue = updatedValue
        super.init(frame: NSMakeRect(0, 0, 30, 100))
        bar = .init(height: 0)
    }
    
    override var isAutoclosePopover: Bool {
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.value = initialValue
        genericView.updateInteractiveValue = updatedValue
        
        readyOnce()
    }
    
    override func becomeFirstResponder() -> Bool? {
        return nil
    }
    
    var value:CGFloat = 0 {
        didSet {
            genericView.value = value
        }
    }
    
}
