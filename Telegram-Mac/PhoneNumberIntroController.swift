//
//  PhoneNumberIntro.swift
//  Telegram
//
//  Created by keepcoder on 12/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import SwiftSignalKit

class ChaneNumberIntroView : View {
    let imageView:LottiePlayerView = LottiePlayerView()
    let textView:TextView = TextView()
    private let containerView:View = View()
    fileprivate let next = TitleButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(containerView)
        wantsLayer = true
        containerView.addSubview(imageView)
        containerView.addSubview(textView)
        addSubview(next)
        textView.userInteractionEnabled = false
        textView.userInteractionEnabled = false
        
        next.autohighlight = false
        next.scaleOnClick = true
        
        updateLocalizationAndTheme(theme: theme)
        
    }
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        let theme = (theme as! TelegramPresentationTheme)
        if let data = LocalAnimatedSticker.change_sim.data {
            self.imageView.setFrameSize(NSMakeSize(120, 120))
            self.imageView.set(LottieAnimation(compressed: data, key: .init(key: .bundle("change_sim"), size: NSMakeSize(120, 120), backingScale: Int(System.backingScale), fitzModifier: nil), playPolicy: .loop, colors: []))
        }
        
        backgroundColor = theme.colors.background
        textView.background = theme.colors.background
        containerView.background = theme.colors.background
        let attr = NSMutableAttributedString()
        _ = attr.append(string: strings().changePhoneNumberIntroDescription, color: theme.colors.grayText, font: .normal(.text))
        attr.detectBoldColorInString(with: .bold(.text))
        textView.set(layout: TextViewLayout(attr, alignment:.center))
        
        next.set(color: theme.colors.underSelectedColor, for: .Normal)
        next.set(background: theme.colors.accent, for: .Normal)
        next.set(font: .medium(.text), for: .Normal)
        next.set(text: strings().navigationNext, for: .Normal)
        next.sizeToFit()
        next.layer?.cornerRadius = 10
        
        needsLayout = true
    }
    
    
    override func layout() {
        super.layout()
        containerView.setFrameSize(frame.width, 0)
        
        textView.textLayout?.measure(width: frame.width - 60)
        textView.update(textView.textLayout)
        imageView.centerX(y: 0)
        textView.centerX(y:imageView.frame.maxY + 10)
        containerView.setFrameSize(frame.width, textView.frame.maxY + 30)
        
        containerView.centerX(y: 10)
        
        next.setFrameSize(NSMakeSize(frame.width - 60, 40))
        next.centerX(y: frame.height - next.frame.height - 50 - 30)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class PhoneNumberIntroController: EmptyComposeController<Void,Bool,ChaneNumberIntroView> {
    
    
    override init(_ context: AccountContext) {
        super.init(context)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ready.set(context.account.postbox.loadedPeerWithId(context.peerId) |> deliverOnMainQueue |> map { [weak self] peer -> Bool in
            if let phone = (peer as? TelegramUser)?.phone {
                self?.setCenterTitle(formatPhoneNumber("+" + phone))
            }
            return true
        })
        genericView.next.set(handler: { [weak self] _ in
            self?.executeNext()
        }, for: .Click)
    }
    
    
    override var enableBack: Bool {
        return false
    }
    
    
    func executeNext() {
        confirm(for: context.window, information: strings().changePhoneNumberIntroAlert, successHandler: { [weak self] _ in
            if let context = self?.context {
                self?.navigationController?.push(PhoneNumberConfirmController(context: context))
            }
        })
    }
    
}
