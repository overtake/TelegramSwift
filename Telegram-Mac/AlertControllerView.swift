//
//  AlertControllerView.swift
//  Telegram
//
//  Created by keepcoder on 07/11/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac

class AlertControllerView: View {

    private let okButton: TitleButton = TitleButton()
    private let cancelButton: TitleButton = TitleButton()
    
    private let headerTextView: TextView = TextView()
    private let informativeTextView: TextView = TextView()
    let checkbox: CheckBox = CheckBox(selectedImage: theme.icons.alertCheckBoxSelected, unselectedImage: theme.icons.alertCheckBoxUnselected)
    private let photoView: AvatarControl = AvatarControl(font: .avatar(22))
    private let accessoryImage: ImageView = ImageView()
    private let containerView: View = View()
    private let borderView: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundColor = .clear
        headerTextView.backgroundColor = theme.colors.background
        headerTextView.isSelectable = false
        
        informativeTextView.backgroundColor = theme.colors.background
        
        photoView.setFrameSize(50, 50)
        
        containerView.addSubview(headerTextView)
        containerView.addSubview(informativeTextView)
        containerView.addSubview(photoView)
        containerView.addSubview(accessoryImage)
        containerView.addSubview(checkbox)
        
        photoView.setFrameOrigin(30, 30)
        
        containerView.backgroundColor = theme.colors.background
        containerView.layer?.cornerRadius = .cornerRadius
        
        containerView.layer?.borderWidth = .borderSize
        containerView.layer?.borderColor = theme.colors.border.cgColor
        
        containerView.frame = bounds
        
        borderView.backgroundColor = theme.colors.background
        borderView.border = [.Left, .Right]
        
        borderView.frame = NSMakeRect(0, 0, frame.width, 4)
        
        addSubview(containerView)
        addSubview(borderView)
        
        cancelButton.autohighlight = false
        okButton.autohighlight = false
        
        self.okButton.set(font: .medium(.text), for: .Normal)
        self.okButton.set(color: theme.colors.blueUI, for: .Normal)
        
        self.cancelButton.set(font: .medium(.text), for: .Normal)
        okButton.set(background: theme.colors.blueUI, for: .Normal)
        okButton.set(background: theme.colors.blueIcon, for: .Highlight)
        
        self.cancelButton.set(background: theme.colors.blueUI, for: .Highlight)
        self.cancelButton.set(color: .white, for: .Highlight)
        
        cancelButton.layer?.borderWidth = .borderSize
        cancelButton.layer?.borderColor = theme.colors.blueUI.cgColor
        cancelButton.disableActions()
        containerView.addSubview(okButton)
        
        checkbox.isSelected = true
        checkbox.set(handler: { _ in
            
        }, for: .Click)
        
    }
    
    func layoutTexts(with header: String, information: String?, account: Account?, peer: Peer?, thridTitle: String?, accessory: CGImage?, maxWidth: CGFloat) -> Void {
        
        var height: CGFloat = 130
        var width: CGFloat = frame.width
        
        if let account = account {
            photoView.setPeer(account: account, peer: peer)
        }
        accessoryImage.image = accessory
        accessoryImage.sizeToFit()
        
        if let thridTitle = thridTitle {
            checkbox.update(with: thridTitle, maxWidth: maxWidth - photoView.frame.maxX - 60)
            height += checkbox.frame.height + 20
        }
        
        let headerLayout = TextViewLayout(.initialize(string: header, color: theme.colors.text, font: .bold(.title)), maximumNumberOfLines: 1)
        headerLayout.measure(width: frame.width - photoView.frame.maxX - 50)
        headerTextView.update(headerLayout, origin: NSMakePoint(photoView.frame.maxX + 30, 34))
        
        
        informativeTextView.isHidden = information == nil
        checkbox.isHidden = thridTitle == nil
        accessoryImage.isHidden = accessory == nil
        photoView.isHidden = peer == nil
        
        if let information = information {
            let textLayout = TextViewLayout(.initialize(string: information, color: theme.colors.text, font: .normal(.text)))
            textLayout.measure(width: frame.width - photoView.frame.maxX - 60)
            informativeTextView.update(textLayout, origin: NSMakePoint(photoView.frame.maxX + 30, headerTextView.frame.maxY + 10))
                    
            width = photoView.frame.maxX + 60 + max(max(textLayout.layoutSize.width, headerLayout.layoutSize.width), checkbox.frame.width)
            
            height += textLayout.layoutSize.height + 10
            
        } else {
            width = photoView.frame.maxX + 60 + max(headerLayout.layoutSize.width, checkbox.frame.width)
        }
        
        
        setFrameSize(width, height)
        containerView.frame = bounds
        
    }
    

    func layoutButtons(okTitle: String, cancelTitle: String?, okHandler: @escaping()->Void, cancelHandler:@escaping()->Void) -> CGFloat {
        okButton.set(text: okTitle, for: .Normal)
        _ = okButton.sizeToFit(NSMakeSize(40, 10))
        
        okButton.layer?.cornerRadius = okButton.frame.height / 2
        
        
        self.okButton.set(color: .white, for: .Normal)

        self.cancelButton.set(color: theme.colors.blueUI, for: .Normal)
        
        okButton.set(handler: { _ in
            okHandler()
        }, for: .Click)
        
        if let cancelTitle = cancelTitle  {
            cancelButton.set(text: cancelTitle, for: .Normal)
            _ = cancelButton.sizeToFit(NSMakeSize(40, 10))
            cancelButton.layer?.cornerRadius = cancelButton.frame.height / 2
            
            containerView.addSubview(cancelButton)
            cancelButton.set(handler: { _ in
                cancelHandler()
            }, for: .Click)
        }
        
        
        
        needsLayout = true
        
        return frame.width
    }
    
    override func layout() {
        super.layout()
        photoView.setFrameOrigin(30, 30)
        containerView.frame = bounds
        borderView.frame = NSMakeRect(0, 0, frame.width, 4)

        
        headerTextView.setFrameOrigin(NSMakePoint(photoView.frame.maxX + 30, 34))
        informativeTextView.setFrameOrigin(NSMakePoint(photoView.frame.maxX + 30, headerTextView.frame.maxY + 10))
        
        checkbox.setFrameOrigin(NSMakePoint(photoView.frame.maxX + 30, (informativeTextView.isHidden ? headerTextView : informativeTextView).frame.maxY + 14))
        
        okButton.setFrameOrigin(frame.width - okButton.frame.width - 40, frame.height - okButton.frame.height - 30)
        
        cancelButton.setFrameOrigin(okButton.frame.minX - cancelButton.frame.width - 10, frame.height - cancelButton.frame.height - 30)
        if photoView.isHidden {
            accessoryImage.frame = photoView.frame
        } else {
            accessoryImage.setFrameOrigin(photoView.frame.maxX - accessoryImage.frame.width / 2, photoView.frame.midY)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
