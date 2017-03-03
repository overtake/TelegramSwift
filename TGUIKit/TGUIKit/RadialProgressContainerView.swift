//
//  RadialProgressContainerView.swift
//  TGUIKit
//
//  Created by keepcoder on 03/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa

public class RadialProgressContainerView: View {
    public let progress:RadialProgressView
    private let proggressBackground:View = View()
    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    public init(theme: RadialProgressTheme) {
        progress = RadialProgressView(theme: theme)
        proggressBackground.backgroundColor = .blackTransparent
        super.init()
        addSubview(proggressBackground)
        addSubview(progress)
        self.backgroundColor = .clear
    }
    
    override public func layout() {
        super.layout()
        progress.center()
    }
    
    override public func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        proggressBackground.setFrameSize(newSize)
        layer?.cornerRadius = newSize.width/2
    }
    
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
