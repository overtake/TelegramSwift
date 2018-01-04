//
//  MessageActionsPanelView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 31/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac



class MessageActionsPanelView: Control, Notifable {
    
    private var deleteButton:TitleButton = TitleButton()
    private var forwardButton:TitleButton = TitleButton()
    private var countTitle:TitleButton = TitleButton()
    
    private let loadMessagesDisposable:MetaDisposable = MetaDisposable()
    
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
        
        updateLocalizationAndTheme()
    }
    
    private var buttonActiveStyle:ControlStyle {
        return ControlStyle(font:.normal(.header), foregroundColor: theme.colors.grayText, backgroundColor: theme.colors.background, highlightColor: theme.colors.blueIcon)
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
        forwardButton.set(color: !canForward ? theme.colors.grayText : theme.colors.blueUI, for: .Normal)
        
        deleteButton.set(image: !deleteButton.userInteractionEnabled ? theme.icons.chatDeleteMessagesInactive : theme.icons.chatDeleteMessagesActive, for: .Normal)
        forwardButton.set(image: !forwardButton.userInteractionEnabled ? theme.icons.chatForwardMessagesInactive : theme.icons.chatForwardMessagesActive, for: .Normal)
        
        countTitle.set(text: count == 0 ? tr(L10n.messageActionsPanelEmptySelected) : tr(L10n.messageActionsPanelSelectedCountCountable(count)), for: .Normal)
        countTitle.set(color: (!canForward && !canDelete) || count == 0 ? theme.colors.grayText : theme.colors.text, for: .Normal)
        countTitle.sizeToFit(NSZeroSize, NSMakeSize(frame.width - deleteButton.frame.width - forwardButton.frame.width - 80, frame.height))
        countTitle.center()
    }
    
    func notify(with value: Any, oldValue: Any, animated:Bool) {
        if let selectingState = (value as? ChatPresentationInterfaceState)?.selectionState, let account = chatInteraction?.account {
            let ids = Array(selectingState.selectedIds)
            loadMessagesDisposable.set((account.postbox.messagesAtIds(ids) |> deliverOnMainQueue).start( next:{ [weak self] messages in
                var canDelete:Bool = !ids.isEmpty
                var canForward:Bool = !ids.isEmpty
                for message in messages {
                    if !canDeleteMessage(message, account: account) {
                        canDelete = false
                    }
                    if !canForwardMessage(message, account: account) {
                        canForward = false
                    }
                }
                self?.updateUI(canDelete, canForward, ids.count)
                
            }))
           
        }
    }
    
    deinit {
        loadMessagesDisposable.dispose()
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
        
        forwardButton.set(handler: {_ in
            chatInteraction.forwardSelectedMessages()
        }, for: .Click)
        deleteButton.set(handler: {_ in
            chatInteraction.deleteSelectedMessages()
        }, for: .Click)
        
        self.notify(with: chatInteraction.presentation, oldValue: chatInteraction.presentation, animated: false)
    }
    
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        
        deleteButton.set(text: tr(L10n.messageActionsPanelDelete), for: .Normal)
        forwardButton.set(text: tr(L10n.messageActionsPanelForward), for: .Normal)
        
        deleteButton.set(image: !deleteButton.userInteractionEnabled ? theme.icons.chatDeleteMessagesInactive : theme.icons.chatDeleteMessagesActive, for: .Normal)
        forwardButton.set(image: !forwardButton.userInteractionEnabled ? theme.icons.chatForwardMessagesInactive : theme.icons.chatForwardMessagesActive, for: .Normal)
        
        deleteButton.set(color: !deleteButton.userInteractionEnabled ? theme.colors.grayText : theme.colors.redUI, for: .Normal)
        forwardButton.set(color: !forwardButton.userInteractionEnabled ? theme.colors.grayText : theme.colors.blueUI, for: .Normal)
        
        deleteButton.sizeToFit(NSZeroSize, NSMakeSize(0, frame.height))
        forwardButton.sizeToFit(NSZeroSize, NSMakeSize(0, frame.height))
        
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
