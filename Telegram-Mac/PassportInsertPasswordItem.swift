//
//  PassportInsertPasswordItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 20/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac

private final class PassportInsertPasswordField : NSSecureTextField {
    
    override func resignFirstResponder() -> Bool {
        (self.delegate as? PassportInsertPasswordRowView)?.controlTextDidBeginEditing(Notification(name: NSControl.textDidChangeNotification))
        return super.resignFirstResponder()
    }
    
    override func becomeFirstResponder() -> Bool {
        (self.delegate as? PassportInsertPasswordRowView)?.controlTextDidEndEditing(Notification(name: NSControl.textDidChangeNotification))
        return super.becomeFirstResponder()
    }
    
    override func mouseDown(with event: NSEvent) {
        superview?.mouseDown(with: event)
    }
}

class PassportInsertPasswordItem: GeneralRowItem {
    private let _stableId: AnyHashable
    fileprivate let descLayout: TextViewLayout
    fileprivate let checkPasswordAction:((String, ()->Void))->Void
    fileprivate let forgotPassword: ()->Void
    fileprivate let hasRecoveryEmail: Bool
    init(_ initialSize: NSSize, stableId: AnyHashable, checkPasswordAction: @escaping((String, ()->Void))->Void, forgotPassword: @escaping()->Void, hasRecoveryEmail: Bool, isSettings: Bool) {
        self._stableId = stableId
        self.checkPasswordAction = checkPasswordAction
        self.forgotPassword = forgotPassword
        self.hasRecoveryEmail = hasRecoveryEmail
        descLayout = TextViewLayout(.initialize(string: isSettings ? L10n.secureIdInsertPasswordSettingsDescription : L10n.secureIdInsertPasswordDescription, color: theme.colors.grayText, font: .normal(.text)), alignment: .center)
        super.init(initialSize)
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        
        descLayout.measure(width: width - inset.left - inset.right)
        
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override var stableId: AnyHashable {
        return _stableId
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override func viewClass() -> AnyClass {
        return PassportInsertPasswordRowView.self
    }
    
    override var height: CGFloat {
        return descLayout.layoutSize.height + 36 + 20 + 30 + 15
    }
}


final class PassportInsertPasswordRowView : GeneralRowView, NSTextFieldDelegate {
    let input:NSSecureTextField
    private let inputContainer: View = View()
    private let descTextView: TextView = TextView()
    private let nextButton: TitleButton = TitleButton()
    private let forgotPassword: ImageButton = ImageButton()
    required init(frame frameRect: NSRect) {
        input = PassportInsertPasswordField(frame: NSZeroRect)
        super.init(frame: frameRect)
        input.stringValue = ""
        
        
        descTextView.userInteractionEnabled = false
        descTextView.isSelectable = false
        
        addSubview(inputContainer)
        inputContainer.setFrameSize(250, 36)

        input.wantsLayer = true
        input.isBordered = false
        input.isBezeled = false
        input.focusRingType = .none
        input.delegate = self
        input.drawsBackground = false
        input.isEditable = true
        input.isSelectable = true
        input.font = .normal(.text)
        inputContainer.backgroundColor = theme.colors.grayBackground
        inputContainer.layer?.cornerRadius = .cornerRadius
        
        inputContainer.addSubview(input)
        
        
        input.target = self
        input.action = #selector(checkPasscode)
        
        addSubview(descTextView)
        addSubview(nextButton)
        inputContainer.addSubview(forgotPassword)
        
        nextButton.set(handler: { [weak self] _ in
            self?.checkPasscode()
        }, for: .Click)
        
        forgotPassword.set(handler: { [weak self] _ in
            if let item = self?.item as? PassportInsertPasswordItem {
                if item.hasRecoveryEmail {
                    item.forgotPassword()
                } else {
                    alert(for: mainWindow, info: L10n.secureIdForgotPasswordNoEmail)
                }
            }
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseDown(with event: NSEvent) {
        if inputContainer.mouseInside() || input._mouseInside() {
            (window as? Window)?.applyResponderIfNeeded()
        } else {
            super.mouseDown(with: event)
        }
    }
    
    override func controlTextDidChange(_ obj: Notification) {
  
    }
    
    override func controlTextDidBeginEditing(_ obj: Notification) {
        input.textView?.insertionPointColor = theme.colors.text
    }
    
    override func controlTextDidEndEditing(_ obj: Notification) {
        
    }
    
    override func layout() {
        input.setFrameSize(NSMakeSize(inputContainer.frame.width - 20 - forgotPassword.frame.width - 10, input.frame.height))
        input.centerY(x: 10)
        descTextView.centerX()
        inputContainer.centerX(y: descTextView.frame.maxY + 20)
        nextButton.centerX(y: inputContainer.frame.maxY + 15)
        forgotPassword.centerY(x: inputContainer.frame.width - forgotPassword.frame.width - 10)
    }
    
    @objc func checkPasscode() {
        guard let item = item as? PassportInsertPasswordItem else {return}

        item.checkPasswordAction((input.stringValue, { [weak self] in
            assertOnMainThread()
            (self?.window as? Window)?.applyResponderIfNeeded()
            self?.input.shake()
            self?.input.textView?.selectAllText()
        }))
    }
    
    
    
    override func updateColors() {
        super.updateColors()
        input.textColor = theme.colors.text
        input.backgroundColor = .clear
        descTextView.backgroundColor = theme.colors.background
        inputContainer.backgroundColor = theme.colors.grayBackground
        
        let attr = NSMutableAttributedString()
        //TODOLANG
        _ = attr.append(string: L10n.secureIdInsertPasswordPassword, color: theme.colors.grayText, font: .normal(.title))
        input.placeholderAttributedString = attr
        input.font = .normal(.title)
        input.sizeToFit()
        
        nextButton.set(font: .normal(.title), for: .Normal)
        nextButton.set(color: .white, for: .Normal)
        nextButton.set(background: theme.colors.blueUI, for: .Normal)
        //TODOLANG
        nextButton.set(text: L10n.secureIdInsertPasswordNext, for: .Normal)
        _ = nextButton.sizeToFit(NSMakeSize(20, 0), NSMakeSize(.greatestFiniteMagnitude, 30))
        nextButton.layer?.cornerRadius = .cornerRadius
        
        forgotPassword.set(image: theme.icons.passportForgotPassword, for: .Normal)
        _ = forgotPassword.sizeToFit()
    }
    
    override func viewDidMoveToWindow() {
        if let window = window as? Window {
            window.applyResponderIfNeeded()
        }
    }
    
    override var firstResponder: NSResponder? {
        return input.textView
    }
    
    override var mouseInsideField: Bool {
        return input._mouseInside()
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        switch true {
        case NSPointInRect(point, inputContainer.frame):
            return input
        default:
            return super.hitTest(point)
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        guard let item = item as? PassportInsertPasswordItem else {return}
        descTextView.update(item.descLayout)
        needsLayout = true
    }
    
}
