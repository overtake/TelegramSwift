//
//  AlertControllerView.swift
//  Telegram
//
//  Created by keepcoder on 07/11/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class AlertControllerView: View {

    private let okButton: TitleButton = TitleButton()
    private let cancelButton: TitleButton = TitleButton()
    private let thridButton: TitleButton = TitleButton()
    
    private let headerTextView: TextView = TextView()
    private let informativeTextView: TextView = TextView()
    
    private let logoView: ImageView = ImageView()
    private let containerView: View = View()
    private let borderView: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundColor = .clear
        headerTextView.backgroundColor = theme.colors.background
        headerTextView.isSelectable = false
        
        
       // let icons = Bundle.main.infoDictionary?["CFBundleIconFiles"]
        // [[[NSBundle mainBundle] infoDictionary] valueForKeyPath:@"CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconFiles"];

        
        informativeTextView.backgroundColor = theme.colors.background
        
        logoView.image = #imageLiteral(resourceName: "Icon_TelegramLogin").precomposed()
        logoView.setFrameSize(50, 50)
        
        containerView.addSubview(headerTextView)
        containerView.addSubview(informativeTextView)
        containerView.addSubview(logoView)
        //border = [.Bottom, .Left, .Right]
        logoView.setFrameOrigin(30, 27)
        
        containerView.layer?.cornerRadius = .cornerRadius
        containerView.layer?.borderWidth = .borderSize
        containerView.layer?.borderColor = theme.colors.border.cgColor
        
        containerView.frame = bounds
        
        borderView.backgroundColor = theme.colors.background
        borderView.border = [.Left, .Right]
        
        borderView.frame = NSMakeRect(0, 0, frame.width, 4)
        
        addSubview(containerView)
        addSubview(borderView)
        
        
        self.okButton.set(font: .medium(.text), for: .Normal)
        self.okButton.set(color: theme.colors.blueUI, for: .Normal)
        
        self.cancelButton.set(font: .medium(.text), for: .Normal)
        self.cancelButton.set(color: theme.colors.redUI, for: .Normal)
        
        self.thridButton.set(font: .medium(.text), for: .Normal)
        self.thridButton.set(color: theme.colors.blueUI, for: .Normal)
        
        containerView.addSubview(okButton)
    }
    
    func layoutTexts(with header: String, information: String, maxWidth: CGFloat) -> Void {
        
        var height: CGFloat = 130
        var width: CGFloat = frame.width
        
        let headerLayout = TextViewLayout(.initialize(string: header, color: theme.colors.text, font: .bold(.title)), maximumNumberOfLines: 1)
        headerLayout.measure(width: frame.width - logoView.frame.maxX - 50)
        headerTextView.update(headerLayout, origin: NSMakePoint(logoView.frame.maxX + 20, 30))
        
        
        let textLayout = TextViewLayout(.initialize(string: information, color: theme.colors.text, font: .normal(.text)))
        textLayout.measure(width: frame.width - logoView.frame.maxX - 50)
        informativeTextView.update(textLayout, origin: NSMakePoint(logoView.frame.maxX + 20, headerTextView.frame.maxY + 10))
        
        let lineHeight = textLayout.layoutSize.height / CGFloat(textLayout.lines.count)
        
        if textLayout.lines.count == 1 {
            width = max(logoView.frame.maxX + 80 + textLayout.layoutSize.width, 350)
        }
        
        height -= lineHeight
        height += lineHeight * CGFloat(textLayout.lines.count)
        
        setFrameSize(width, height)
        containerView.frame = bounds
        
    }
    

    func layoutButtons(okTitle: String, cancelTitle: String?, thridTitle: String?, swapColors: Bool, okHandler: @escaping()->Void, cancelHandler:@escaping()->Void, thridHandler:@escaping()->Void) {
        okButton.set(text: okTitle, for: .Normal)
        okButton.sizeToFit(NSMakeSize(40, 0))
        
        self.okButton.set(color: swapColors ? theme.colors.redUI : theme.colors.blueUI, for: .Normal)
        self.cancelButton.set(color: !swapColors ? theme.colors.redUI : theme.colors.blueUI, for: .Normal)
        
        okButton.set(handler: { _ in
            okHandler()
        }, for: .Click)
        
        if let cancelTitle = cancelTitle  {
            cancelButton.set(text: cancelTitle, for: .Normal)
            cancelButton.sizeToFit()
            containerView.addSubview(cancelButton)
            cancelButton.set(handler: { _ in
                cancelHandler()
            }, for: .Click)
        }
        
        if let thridTitle = thridTitle  {
            thridButton.set(text: thridTitle, for: .Normal)
            thridButton.sizeToFit()
            containerView.addSubview(thridButton)
            thridButton.set(handler: { _ in
                thridHandler()
            }, for: .Click)
        }
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        logoView.setFrameOrigin(30, 27)
        containerView.frame = bounds
        borderView.frame = NSMakeRect(0, 0, frame.width, 4)

        
        okButton.setFrameOrigin(frame.width - okButton.frame.width - 40, frame.height - okButton.frame.height - 20)
        
        cancelButton.setFrameOrigin(okButton.frame.minX - cancelButton.frame.width - 20, frame.height - cancelButton.frame.height - 20)
        
        thridButton.setFrameOrigin(logoView.frame.minX, frame.height - thridButton.frame.height - 20 )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
