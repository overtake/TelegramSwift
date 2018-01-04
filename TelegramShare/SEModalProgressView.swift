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
    private let header:TextView = TextView()
    private let borderView:View = View()
    private let containerView:View = View()
    override init() {
        super.init()
        containerView.addSubview(progress)
        containerView.addSubview(cancel)
        containerView.addSubview(borderView)
        containerView.addSubview(header)
        addSubview(containerView)
        self.backgroundColor = theme.colors.blackTransparent
        self.containerView.backgroundColor = theme.colors.grayBackground
        let layout = TextViewLayout(.initialize(string: tr(L10n.shareExtensionShare), color: theme.colors.text, font: .normal(.title)))
        layout.measure(width: .greatestFiniteMagnitude)
        
        header.update(layout)
        header.backgroundColor = theme.colors.grayBackground
        containerView.setFrameSize(250, 80)
        containerView.layer?.cornerRadius = .cornerRadius
        progress.style = ControlStyle(foregroundColor: theme.colors.blueUI, backgroundColor: theme.colors.grayBackground)
        progress.setFrameSize(250, 4)
        
        
        cancel.set(font: .medium(.title), for: .Normal)
        cancel.set(color: theme.colors.blueUI, for: .Normal)
        cancel.set(text: tr(L10n.shareExtensionCancel), for: .Normal)
        cancel.sizeToFit()
        
        cancel.set(handler: { [weak self] _ in
            self?.cancelImpl?()
        }, for: .Click)
        
        progress.set(progress: 0.0)
    }
    
    var cancelImpl:(()->Void)? = nil
    
    func set(progress: CGFloat) {
        self.progress.set(progress: progress, animated: true)
    }
    
    override func layout() {
        super.layout()
        containerView.center()
        progress.center()
        cancel.centerX(y: containerView.frame.height - cancel.frame.height - 10)
        header.centerX(y: 10)
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
