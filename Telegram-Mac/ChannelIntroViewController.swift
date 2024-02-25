//
//  ChannelIntroViewController.swift
//  TelegramMac
//
//  Created by keepcoder on 26/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import TGUIKit
import TelegramCore

import Postbox

class ChannelIntroView : NSScrollView, AppearanceViewProtocol {
    let imageView:ImageView = ImageView()
    let textView:TextView = TextView()
    let button:TextButton = TextButton()
    private let containerView:View = View()
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        documentView = containerView
        wantsLayer = true
        documentView?.addSubview(imageView)
        documentView?.addSubview(textView)
        documentView?.addSubview(button)

        button.set(font: .medium(.title), for: .Normal)
        updateLocalizationAndTheme(theme: theme)
        
    }
    func updateLocalizationAndTheme(theme: PresentationTheme) {
        let theme = (theme as! TelegramPresentationTheme)
        imageView.image = theme.icons.channelIntro
        imageView.sizeToFit()
        
        
        button.set(text: strings().channelIntroCreateChannel, for: .Normal)

        button.set(color: theme.colors.accent, for: .Normal)
        _ = button.sizeToFit()
        
        backgroundColor = theme.colors.background
        textView.background = theme.colors.background
        documentView?.background = theme.colors.background
        let attr = NSMutableAttributedString()
        _ = attr.append(string: strings().channelIntroDescriptionHeader, color: theme.colors.text, font: .medium(.header))
        _ = attr.append(string:"\n\n")
        _ = attr.append(string: strings().channelIntroDescription, color: theme.colors.grayText, font: .normal(.text))
        textView.set(layout: TextViewLayout(attr, alignment:.center))
        
    }
    
    
    override func layout() {
        super.layout()
        containerView.setFrameSize(frame.width, 0)

        textView.textLayout?.measure(width: 380 - 60)
        textView.update(textView.textLayout)
        imageView.centerX(y:30)
        textView.centerX(y:imageView.frame.maxY + 30)
        
        button.centerX(y: textView.frame.maxY + 30)
        
        containerView.setFrameSize(frame.width, button.frame.maxY + 30)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ChannelIntroViewController: EmptyComposeController<Void,Void,ChannelIntroView> {


    
    override func getRightBarViewOnce() -> BarView {
        return TextButtonBarView(controller: self, text: strings().channelCreate, style: navigationButtonStyle, alignment:.Right)
    }
    
    override var removeAfterDisapper: Bool {
        return true
    }
    
    override var enableBack: Bool {
        return true
    }
    
    func executeNext() {
        onComplete.set(.single(Void()))
    }
    
    
    override func returnKeyAction() -> KeyHandlerResult {
        executeNext()
        return .rejected
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        (self.rightBarView as? TextButtonBarView)?.set(handler:{ [weak self] _ in
            self?.executeNext()
        }, for: .Click)
        
        self.genericView.button.set(handler: { [weak self] _ in
            self?.executeNext()
        }, for: .Click)
        
        readyOnce()
    }
    
    
}
