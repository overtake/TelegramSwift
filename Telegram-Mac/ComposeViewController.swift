//
//  ComposeViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 09/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac
struct ComposeTitles {
    let center:String
    let done:String
    init(_ center:String, _ done:String) {
        self.center = center
        self.done = done
    }
}



class ComposeViewController<T, I, V>: EmptyComposeController<I, T, V> where V: NSView {
    
    let titles:ComposeTitles
    fileprivate(set) var enableNext:Bool = true
    
    override func getRightBarViewOnce() -> BarView {
        return TextButtonBarView(controller: self, text: titles.done, style: navigationButtonStyle, alignment:.Right)
    }
    
    override func executeReturn() -> Void {
        onCancel.set(Signal<Void, Void>.single(Void()))
        super.executeReturn()
    }
    
    override func requestUpdateRightBar() {
        super.requestUpdateRightBar()
        rightBarView.style = navigationButtonStyle
    }

    public override func returnKeyAction() -> KeyHandlerResult {
         self.executeNext()
         return .invoked
    }

    func nextEnabled(_ enable:Bool) {
        self.enableNext = enable
        rightBarView.isEnabled = enable
    }
    
    func executeNext() -> Void {
        
    }
    
    override var enableBack: Bool {
        return true
    }
    
    override func loadView() {
        super.loadView()
        
        setCenterTitle(titles.center)
        self.rightBarView.set(handler:{ [weak self] _ in
            self?.executeNext()
        }, for: .Click)
    }
    
    
    
    public init(titles:ComposeTitles, account:Account) {
        self.titles = titles
        super.init(account)
    }
}
