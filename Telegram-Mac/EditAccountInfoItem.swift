//
//  EditAccountInfoItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 26/04/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

class EditAccountInfoItem: GeneralRowItem {

    fileprivate let account: Account
    fileprivate let state: EditInfoState
    fileprivate let photo: AvatarNodeState
    fileprivate let updateText: (String, String)->Void
    fileprivate let uploadNewPhoto: ()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, account: Account, state: EditInfoState, updateText:@escaping(String, String)->Void, uploadNewPhoto: @escaping()->Void) {
        self.account = account
        self.updateText = updateText
        self.state = state
        self.uploadNewPhoto = uploadNewPhoto
        self.photo = .PeerAvatar(account.peerId, [state.firstName.first, state.lastName.first].compactMap{$0}.map{String($0)}, state.representation)
        super.init(initialSize, height: 90, stableId: stableId)
    }
    
    override func viewClass() -> AnyClass {
        return EditAccountInfoItemView.self
    }
}

private final class EditAccountInfoItemView : TableRowView, TGModernGrowingDelegate {
    private let firstNameTextView: TGModernGrowingTextView = TGModernGrowingTextView(frame: NSZeroRect)
    private let lastNameTextView: TGModernGrowingTextView = TGModernGrowingTextView(frame: NSZeroRect)
    private let avatar: AvatarControl = AvatarControl(font: .avatar(22))
    private let nameSeparator: View = View()
    private let secondSeparator: View = View()
    
    private let updoadPhotoCap:ImageButton = ImageButton()
    private let progressView:RadialProgressContainerView = RadialProgressContainerView(theme: RadialProgressTheme(backgroundColor: .clear, foregroundColor: .white, icon: nil))
    private var ignoreUpdates: Bool = false
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        avatar.setFrameSize(NSMakeSize(60, 60))
        progressView.frame = avatar.bounds
        firstNameTextView.delegate = self
        lastNameTextView.delegate = self
        
        firstNameTextView.textFont = .normal(.text)
        lastNameTextView.textFont = .normal(.text)
        
        addSubview(firstNameTextView)
        addSubview(lastNameTextView)
        addSubview(nameSeparator)
        addSubview(secondSeparator)
        addSubview(avatar)

        
        updoadPhotoCap.backgroundColor = NSColor.black.withAlphaComponent(0.4)
        updoadPhotoCap.setFrameSize(avatar.frame.size)
        updoadPhotoCap.layer?.cornerRadius = updoadPhotoCap.frame.width / 2
        updoadPhotoCap.set(image: ControlStyle(highlightColor: .white).highlight(image: theme.icons.chatAttachCamera), for: .Normal)
        updoadPhotoCap.set(image: ControlStyle(highlightColor: theme.colors.blueIcon).highlight(image: theme.icons.chatAttachCamera), for: .Highlight)
        
        
        updoadPhotoCap.set(handler: { [weak self] _ in
            guard let item = self?.item as? EditAccountInfoItem else {return}
            item.uploadNewPhoto()
        }, for: .Click)
        
        avatar.addSubview(updoadPhotoCap)
        
        progressView.progress.fetchControls = FetchControls(fetch: { [weak self] in
            guard let item = self?.item as? EditAccountInfoItem else {return}
            item.state.updatingPhotoState?.cancel()
        })
    }
    
    override var mouseInsideField: Bool {
        return lastNameTextView._mouseInside() || firstNameTextView._mouseInside()
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        switch true {
        case NSPointInRect(point, firstNameTextView.frame):
            return firstNameTextView.inputView
        case NSPointInRect(point, lastNameTextView.frame):
            return lastNameTextView.inputView
        default:
            return super.hitTest(point)
        }
    }
    
    override func hasFirstResponder() -> Bool {
        return true
    }
    
    override var firstResponder: NSResponder? {
        let isKeyDown = NSApp.currentEvent?.type == NSEvent.EventType.keyDown && NSApp.currentEvent?.keyCode == KeyboardKey.Tab.rawValue
        switch true {
        case firstNameTextView._mouseInside() && !isKeyDown:
            return firstNameTextView.inputView
        case lastNameTextView._mouseInside() && !isKeyDown:
            return lastNameTextView.inputView
        default:
            switch true {
            case firstNameTextView.inputView == window?.firstResponder:
                return firstNameTextView.inputView
            case lastNameTextView.inputView == window?.firstResponder:
                return lastNameTextView.inputView
            default:
                return firstNameTextView.inputView
            }
        }
    }
    
    override func nextResponder() -> NSResponder? {
        if window?.firstResponder == firstNameTextView.inputView {
            return lastNameTextView.inputView
        }

        return nil
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? EditAccountInfoItem else {return}
        
        avatar.setState(account: item.account, state: item.photo)
        ignoreUpdates = true
        firstNameTextView.animates = false
        lastNameTextView.animates = false
        
        firstNameTextView.placeholderAttributedString = .initialize(string: L10n.peerInfoFirstNamePlaceholder, color: theme.colors.grayText, font: .normal(.text))
        lastNameTextView.placeholderAttributedString = .initialize(string: L10n.peerInfoLastNamePlaceholder, color: theme.colors.grayText, font: .normal(.text))
        
        firstNameTextView.setString(item.state.firstName)
        lastNameTextView.setString(item.state.lastName)
        
        firstNameTextView.animates = true
        lastNameTextView.animates = true
        
        if let uploadState = item.state.updatingPhotoState {
            if progressView.superview == nil {
                avatar.addSubview(progressView)
                progressView.layer?.opacity = 0
            }
            progressView.change(opacity: 1, animated: animated)
            progressView.progress.state = .Fetching(progress: uploadState.progress, force: false)
            self.updoadPhotoCap.isHidden = true
        } else {
            if animated {
                progressView.change(opacity: 0, animated: animated, removeOnCompletion: false, completion: { [weak self] complete in
                    if complete {
                        self?.progressView.removeFromSuperview()
                        self?.progressView.layer?.removeAllAnimations()
                    }
                })
            } else {
                progressView.removeFromSuperview()
            }
            self.updoadPhotoCap.isHidden = false
        }
        
        needsLayout = true
        ignoreUpdates = false
    }
    
    override func updateColors() {
        super.updateColors()
        firstNameTextView.textColor = theme.colors.text
        lastNameTextView.textColor = theme.colors.text
        nameSeparator.backgroundColor = theme.colors.border
        secondSeparator.backgroundColor = theme.colors.border
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? EditAccountInfoItem else {return}

        avatar.setFrameOrigin(item.inset.left, 16)
        firstNameTextView.setFrameOrigin(NSMakePoint(avatar.frame.maxX + 10, avatar.frame.minY - 6))
        nameSeparator.frame = NSMakeRect(avatar.frame.maxX + 14, firstNameTextView.frame.maxY + 2, frame.width - avatar.frame.maxX - item.inset.right - 14, .borderSize)
        lastNameTextView.setFrameOrigin(NSMakePoint(avatar.frame.maxX + 10, firstNameTextView.frame.maxY + 4))
        secondSeparator.frame = NSMakeRect(item.inset.left, frame.height - .borderSize, frame.width - item.inset.right - item.inset.left, .borderSize)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func maxCharactersLimit(_ textView: TGModernGrowingTextView!) -> Int32 {
        return 64
    }
    
    func textViewHeightChanged(_ height: CGFloat, animated: Bool) {
        
    }
    
    func textViewSize(_ textView: TGModernGrowingTextView!) -> NSSize {
        return textView.frame.size
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        guard let item = item as? EditAccountInfoItem else {return}
        firstNameTextView.setFrameSize(NSMakeSize(frame.width - item.inset.left - item.inset.right - avatar.frame.width - 10, firstNameTextView.frame.height))
        lastNameTextView.setFrameSize(NSMakeSize(frame.width - item.inset.left - item.inset.right - avatar.frame.width - 10, lastNameTextView.frame.height))
    }
    
    func textViewEnterPressed(_ event:NSEvent) -> Bool {
        if FastSettings.checkSendingAbility(for: event) {
            return true
        }
        return false
    }
    
    func textViewIsTypingEnabled() -> Bool {
        return true
    }
    
    func textViewNeedClose(_ textView: Any) {
        
    }
    
    func textViewTextDidChange(_ string: String) {
        guard let item = item as? EditAccountInfoItem else {return}
        guard !ignoreUpdates else {return}
        
        item.updateText(firstNameTextView.string(), lastNameTextView.string())
    }
    
    func textViewDidReachedLimit(_ textView: Any) {
//        if let responder = nextResponder() {
//            window?.makeFirstResponder(responder)
//        }
    }
    
    override func controlTextDidChange(_ obj: Notification) {
        
    }
    
    func textViewTextDidChangeSelectedRange(_ range: NSRange) {
        
    }
    
    func textViewDidPaste(_ pasteboard: NSPasteboard) -> Bool {
        return false
    }
}
