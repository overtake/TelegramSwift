//
//  SEUnauthorizedViewController.swift
//  Telegram
//
//  Created by keepcoder on 29/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Localization

class SEUnauthorizedView : View {
    fileprivate let imageView:ImageView = ImageView()
    fileprivate let cancel:TextButton = TextButton()
    fileprivate let textView:TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        imageView.image = #imageLiteral(resourceName: "Icon_TelegramLogin").precomposed()
        imageView.sizeToFit()
        self.backgroundColor = theme.colors.background
        cancel.set(font: .medium(.title), for: .Normal)
        cancel.set(color: theme.colors.accent, for: .Normal)
        cancel.set(text: L10n.shareExtensionUnauthorizedOK, for: .Normal)
        
        let layout = TextViewLayout(.initialize(string: L10n.shareExtensionUnauthorizedDescription, color: theme.colors.text, font: .normal(.text)), alignment: .center)
        textView.backgroundColor = theme.colors.background
        textView.update(layout)
        
        addSubview(cancel)
        addSubview(textView)
        addSubview(imageView)
    }
    
    
    override func layout() {
        super.layout()
        imageView.centerX(y: 30)
        textView.textLayout?.measure(width: frame.width - 60)
        textView.update(textView.textLayout)
        textView.center()
        cancel.centerX(y: textView.frame.maxY + 20)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SEUnauthorizedViewController: GenericViewController<SEUnauthorizedView> {
    private let cancelImpl:()->Void
    init(cancelImpl:@escaping()->Void) {
        self.cancelImpl = cancelImpl
        super.init()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.cancel.set(handler: { [weak self] _ in
            self?.cancelImpl()
        }, for: .Click)
    }
    
}
