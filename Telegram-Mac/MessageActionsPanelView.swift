//
//  MessageActionsPanelView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 31/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import SyncCore
import Postbox



class MessageActionsPanelView: Control, Notifable {
    
    private var deleteButton:TitleButton = TitleButton()
    private var forwardButton:TitleButton = TitleButton()
    private var countTitle:TitleButton = TitleButton()
        
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        self.countTitle.userInteractionEnabled = false
        
        countTitle.style = countStyle
        
        deleteButton.disableActions()
        forwardButton.disableActions()
        countTitle.disableActions()
    
        
        forwardButton.direction = .right
        addSubview(deleteButton)
        addSubview(forwardButton)
        addSubview(countTitle)
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    private var buttonActiveStyle:ControlStyle {
        return ControlStyle(font:.normal(.header), foregroundColor: theme.colors.grayText, backgroundColor: theme.colors.background, highlightColor: theme.colors.accentIcon)
    }
    private var deleteButtonActiveStyle:ControlStyle {
        return ControlStyle(font:.normal(.header), foregroundColor: theme.colors.grayText, backgroundColor: theme.colors.background, highlightColor: theme.colors.redUI)
    }
    private var countStyle:ControlStyle {
        return ControlStyle(font:.normal(.header), foregroundColor: theme.colors.grayText, backgroundColor: theme.colors.background, highlightColor: theme.colors.text)
    }

    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        self.needsLayout = true
    }
    
    override func layout() {
        super.layout()
        countTitle.sizeToFit(NSZeroSize, NSMakeSize(frame.width - deleteButton.frame.width - forwardButton.frame.width - 80, frame.height))

        deleteButton.centerY(x:20)
        forwardButton.centerY(x:frame.width - forwardButton.frame.width - 20)
        countTitle.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var chatInteraction:ChatInteraction?
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    private func updateUI(_ canDelete:Bool , _ canForward:Bool, _ count:Int) -> Void {
        deleteButton.userInteractionEnabled = canDelete
        forwardButton.userInteractionEnabled = canForward
        
        deleteButton.set(color: !canDelete ? theme.colors.grayText : theme.colors.redUI, for: .Normal)
        forwardButton.set(color: !canForward ? theme.colors.grayText : theme.colors.accent, for: .Normal)

        deleteButton.set(text: leftText, for: .Normal)
        forwardButton.set(text: rightText, for: .Normal)

        if let leftIcon = leftIcon {
            deleteButton.set(image: leftIcon, for: .Normal)
        } else {
            deleteButton.removeImage(for: .Normal)
        }
        if let rightIcon = rightIcon {
            forwardButton.set(image: rightIcon, for: .Normal)
        } else {
            forwardButton.removeImage(for: .Normal)
        }

        deleteButton.set(color: !deleteButton.userInteractionEnabled ? theme.colors.grayIcon : leftColor, for: .Normal)
        forwardButton.set(color: !forwardButton.userInteractionEnabled ? theme.colors.grayIcon : rightColor, for: .Normal)


        countTitle.set(text: count == 0 ? L10n.messageActionsPanelEmptySelected : L10n.messageActionsPanelSelectedCountCountable(count), for: .Normal)
        countTitle.set(color: (!canForward && !canDelete) || count == 0 ? theme.colors.grayText : theme.colors.text, for: .Normal)
        countTitle.sizeToFit(NSZeroSize, NSMakeSize(frame.width - deleteButton.frame.width - forwardButton.frame.width - 80, frame.height))
        countTitle.center()
    }
    
    func notify(with value: Any, oldValue: Any, animated:Bool) {
        if let value = value as? ChatPresentationInterfaceState, let selectionState = value.selectionState {
            if value.reportMode != nil {
                updateUI(true, true, selectionState.selectedIds.count)
            } else {
                updateUI(value.canInvokeBasicActions.delete, value.canInvokeBasicActions.forward, selectionState.selectedIds.count)
            }
        }
    }
    
    deinit {
    }
    
    func isEqual(to other: Notifable) -> Bool {
        if let other = other as? MessageActionsPanelView {
            return self == other
        }
        return false
    }
    

    func prepare(with chatInteraction:ChatInteraction) -> Void {
        if let chatInteraction = self.chatInteraction {
            chatInteraction.remove(observer: self)
        }
        self.chatInteraction = chatInteraction
        self.chatInteraction?.add(observer: self)
        
        forwardButton.set(handler: { [weak chatInteraction] _ in
            chatInteraction?.forwardSelectedMessages()
        }, for: .Click)
        deleteButton.set(handler: { [weak chatInteraction] _ in
            chatInteraction?.deleteSelectedMessages()
        }, for: .Click)
        
        self.notify(with: chatInteraction.presentation, oldValue: chatInteraction.presentation, animated: false)
    }

    private var leftColor: NSColor {
        if chatInteraction?.presentation.reportMode != nil {
            return theme.colors.accent
        }
        return theme.colors.redUI
    }
    private var rightColor: NSColor {
        if chatInteraction?.presentation.reportMode != nil {
            return theme.colors.redUI
        }
        return theme.colors.accent
    }

    private var leftText: String {
        if chatInteraction?.presentation.reportMode != nil {
            return L10n.modalCancel
        }
        return L10n.messageActionsPanelDelete
    }
    private var rightText: String {
        if chatInteraction?.presentation.reportMode != nil {
            return L10n.modalReport
        }
        return L10n.messageActionsPanelForward
    }
    private var leftIcon: CGImage? {
        if chatInteraction?.presentation.reportMode != nil {
            return nil
        }
        return !deleteButton.userInteractionEnabled ? theme.icons.chatDeleteMessagesInactive : theme.icons.chatDeleteMessagesActive
    }
    private var rightIcon: CGImage? {
        if chatInteraction?.presentation.reportMode != nil {
            return nil
        }
        return !forwardButton.userInteractionEnabled ? theme.icons.chatForwardMessagesInactive : theme.icons.chatForwardMessagesActive
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        deleteButton.set(text: leftText, for: .Normal)
        forwardButton.set(text: rightText, for: .Normal)

        if let leftIcon = leftIcon {
            deleteButton.set(image: leftIcon, for: .Normal)
        } else {
            deleteButton.removeImage(for: .Normal)
        }
        if let rightIcon = rightIcon {
            forwardButton.set(image: rightIcon, for: .Normal)
        } else {
            forwardButton.removeImage(for: .Normal)
        }

        deleteButton.set(color: !deleteButton.userInteractionEnabled ? theme.colors.grayIcon : leftColor, for: .Normal)
        forwardButton.set(color: !forwardButton.userInteractionEnabled ? theme.colors.grayIcon : rightColor, for: .Normal)
        
        _ = deleteButton.sizeToFit(NSZeroSize, NSMakeSize(0, frame.height))
        _ = forwardButton.sizeToFit(NSZeroSize, NSMakeSize(0, frame.height))
        
        deleteButton.style = deleteButtonActiveStyle
        forwardButton.style = buttonActiveStyle
        countTitle.style = countStyle

        countTitle.set(background: theme.colors.background, for: .Normal)
        
        backgroundColor = theme.colors.background
        if let chatInteraction = chatInteraction {
            self.notify(with: chatInteraction.presentation, oldValue: chatInteraction.presentation, animated: false)
        }


    }

    override func viewDidMoveToWindow() {
        if window == nil {
            self.chatInteraction?.remove(observer: self)
            self.resignFirstResponder()
        }
    }
    
}
