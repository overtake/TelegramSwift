//
//  AboutModalController.swift
//  TelegramMac
//
//  Created by keepcoder on 06/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

fileprivate class AboutModalView : Control {
    fileprivate let copyright:TextView = TextView()
    fileprivate let descView:TextView = TextView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        
        
        let copyrightLayout = TextViewLayout(.initialize(string: "Copyright © 2016 - \(formatter.string(from: Date(timeIntervalSinceReferenceDate: Date.timeIntervalSinceReferenceDate))) TELEGRAM MESSENGER", color: theme.colors.grayText, font: .normal(.text)), alignment: .center)
        copyrightLayout.measure(width:frameRect.width - 40)
        
        
        var vText = "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "1").\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? "0")"
        

        #if STABLE
            vText += " Stable"
        #elseif APP_STORE
            vText += " AppStore"
        #else
            vText += " Beta"
        #endif

        let attr = NSMutableAttributedString()
        
        _ = attr.append(string: appName, color: theme.colors.text, font: .medium(.header))
        _ = attr.append(string: "\n\(vText)", color: theme.colors.grayText, font: .medium(.text))
        
        _ = attr.append(string: "\n\n")
        
        _ = attr.append(string: L10n.aboutDescription, color: theme.colors.text, font: .normal(.text))
        
        let descLayout = TextViewLayout(attr, alignment: .center)
        descLayout.measure(width:frameRect.width - 40)
        

        descLayout.interactions.copy = {
            copyToClipboard(vText)
            return true
        }
        
        copyright.update(copyrightLayout)
        descView.update(descLayout)
        copyright.backgroundColor = theme.colors.background
        descView.backgroundColor = theme.colors.background
        addSubview(copyright)
        addSubview(descView)
        
        
 
        
        descView.isSelectable = false
        copyright.isSelectable = false
    }
    
    fileprivate override func layout() {
        super.layout()
        descView.setFrameOrigin(20, 20)
        copyright.centerX(y:frame.height - copyright.frame.height - 20)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class AboutModalController: ModalViewController {

    
    override func viewClass() -> AnyClass {
        return AboutModalView.self
    }
    
    override init() {
        super.init(frame: NSMakeRect(0, 0, 300, 190))
        bar = .init(height: 0)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.descView.layout?.interactions.processURL = { [weak self] url in
            if let url = url as? inAppLink {
                execute(inapp: url)
            }
            self?.close()
        }
        readyOnce()
    }
    
    private var genericView:AboutModalView {
        return self.view as! AboutModalView
    }
    
}
