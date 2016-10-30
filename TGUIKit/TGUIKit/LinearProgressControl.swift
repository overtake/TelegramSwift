//
//  LinearProgressControl.swift
//  TGUIKit
//
//  Created by keepcoder on 28/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public class LinearProgressControl: Control {
    
    private var progressView:View!
    
    private var progress:CGFloat = 0
    
    public override var style: ControlStyle {
        didSet {
            self.progressView.layer?.backgroundColor = style.foregroundColor.cgColor
        }
    }
    
    public func set(progress:CGFloat, animated:Bool = false) {
        self.progress = progress
        let size = NSMakeSize(floorToScreenPixels(frame.width * progress), frame.height)
        progressView.change(size: size, animated: animated)
    }
    

    override init() {
        super.init()
        initialize()
    }
    
    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        progressView.setFrameSize(progressView.frame.width,newSize.height)
    }
    
    private func initialize() {
        progressView = View(frame:NSMakeRect(0, 0, 0, frame.height))
        progressView.layer?.backgroundColor = style.foregroundColor.cgColor
        addSubview(progressView)
    }
    
    required public init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
        initialize()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
