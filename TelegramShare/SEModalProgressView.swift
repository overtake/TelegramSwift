//
//  SEModalProgressView.swift
//  TelegramMac
//
//  Created by keepcoder on 04/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa

import TGUIKit

class SEModalProgressView: View {
    private let progress:LinearProgressControl = LinearProgressControl()
    private let cancel:TitleButton = TitleButton()
    private let borderView:View = View()
    override init() {
        super.init()
        addSubview(progress)
        addSubview(cancel)
        addSubview(borderView)
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
