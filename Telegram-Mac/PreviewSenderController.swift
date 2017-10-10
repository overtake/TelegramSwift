//
//  PreviewSenderController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 02/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac

private enum SecretMediaTtl {
    case off
    case seconds(Int32)
}

fileprivate class PreviewSenderView : Control {
    fileprivate let tableView:TableView = TableView()
    fileprivate let textView:TGModernGrowingTextView = TGModernGrowingTextView(frame: NSZeroRect)
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        tableView.setFrameSize(frameRect.width, frameRect.height - 34)
        backgroundColor = theme.colors.background
        textView.setPlaceholderAttributedString(.initialize(string: tr(.previderSenderCaptionPlaceholder), color: theme.colors.grayText, font: .normal(.text)), update: false)
        textView.background = theme.colors.background
        textView.textFont = .normal(.text)
        textView.textColor = theme.colors.text
        textView.linkColor = theme.colors.link
        textView.max_height = 120
        backgroundColor = theme.colors.background
        textView.setFrameSize(NSMakeSize(frameRect.width - 48, 34))
        
        addSubview(tableView)
        addSubview(textView)
    }
    
    override func layout() {
        super.layout()
        textView.setFrameOrigin(NSMakePoint(24, frame.height - textView.frame.height))
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class PreviewSenderController: ModalViewController, TGModernGrowingDelegate {

    private var urls:[URL]
    private let account:Account
    private let chatInteraction:ChatInteraction
    private var isNeedAsMedia:Bool = true
    
    override func viewClass() -> AnyClass {
        return PreviewSenderView.self
    }
    
    private var genericView:PreviewSenderView {
        return self.view as! PreviewSenderView
    }
    
    
    func makeItems(_ urls:[URL]) -> Signal<Bool,Void> {
        let initialSize = atomicSize
        let account = self.account
        return Signal {[weak self] (subscriber) in
        
            if let strongSelf = self {
                
                let headerItem:TableRowItem?
                
                let options = takeSenderOptions(for: urls)
                
                if urls.count == 1 {
                    let url = urls[0]
                    let mime = MIMEType(url.path.nsstring.pathExtension.lowercased())
                    if mime.hasPrefix("image") && mediaExts.contains(url.path.nsstring.pathExtension.lowercased()) {
                        headerItem = PreviewThumbRowItem(initialSize.modify({$0}), url: url, account:account)
                    } else {
                        headerItem = PreviewDocumentRowItem(initialSize.modify({$0}), url: url, account:account)
                    }
                } else {
                    headerItem = nil
                }
                if let headerItem = headerItem {
                    let _ = strongSelf.genericView.tableView.addItem(item: headerItem)
                }
                
                if options.contains(.image) || options.contains(.video) {
                    let _ = strongSelf.genericView.tableView.addItem(item: GeneralRowItem(initialSize.modify({$0}), height:10))
                    let _ = strongSelf.genericView.tableView.addItem(item: GeneralInteractedRowItem(initialSize.modify({$0}), name: tr(.previewSenderCompressFile), type: .switchable(stateback: { [weak strongSelf] () -> Bool in
                        if let strongSelf = strongSelf {
                            return strongSelf.isNeedAsMedia
                        }
                        return true
                    }), action:{ [weak strongSelf] in
                        if let strongSelf = strongSelf {
                            strongSelf.isNeedAsMedia = !strongSelf.isNeedAsMedia
                        }
                    }))
                    
                }
               
                
                let _ = strongSelf.genericView.tableView.addItem(item: GeneralRowItem(initialSize.modify({$0}), height:10))
                if headerItem == nil {
                    strongSelf.expandUrls(urls)
                } else {
                    strongSelf.textViewHeightChanged(34, animated: false)
                }
                
                subscriber.putNext(true)
                subscriber.putCompletion()

            }
            
            return EmptyDisposable
        } |> runOn(Queue.mainQueue())
    }
    
    private func expandUrls(_ urls:[URL]) {
        var index:Int = -1
        let initialSize = atomicSize.modify({$0})
        var inserted:[(Int, TableRowItem)] = []
        for url in urls {
            index += 1
            inserted.append((index, ExpandedPreviewRowItem(initialSize, account:account, url: url, onDelete: { [weak self] item in
                if let strongSelf = self {
                    if let index = strongSelf.genericView.tableView.index(of: item) {
                        strongSelf.genericView.tableView.remove(at: index, redraw: true, animation: .effectFade)
                        if let urlIndex = strongSelf.urls.index(of: url) {
                            strongSelf.urls.remove(at: urlIndex)
                        }
                        strongSelf.updateSize()
                        if strongSelf.urls.isEmpty {
                            strongSelf.modal?.close()
                        }
                    }
                }
               
            })))
        }

        genericView.tableView.merge(with: TableUpdateTransition(deleted: [0], inserted: inserted, updated: [], animated: false, state: .saveVisible(.lower)))
        updateSize()
        genericView.tableView.scroll(to: .down(false))
    }
    
    private func updateSize() {
        if let contentSize = self.window?.contentView?.frame.size {
            self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(contentSize.height - 70, genericView.tableView.listHeight + genericView.textView.frame.height)), animated: false)
        }
    }
    
    override var modalInteractions: ModalInteractions? {
        let chatInteraction = self.chatInteraction
        
        return ModalInteractions(acceptTitle:tr(.modalSend), accept: { [weak self] in
            if let urls = self?.urls, let asMedia = self?.isNeedAsMedia {
                let text = self?.genericView.textView.string() ?? ""
                var containers:[MediaSenderContainer] = []
                for url in urls {
                    let asMedia = asMedia && mediaExts.contains(url.path.nsstring.pathExtension.lowercased())
                    containers.append(MediaSenderContainer(path:url.path, caption: urls.count == 1 ? text : "", isFile:!asMedia))
                }
                if urls.count > 1 && !text.isEmpty {
                    chatInteraction.forceSendMessage(text)
                }
                chatInteraction.sendMedia(containers)
            }
            self?.modal?.close()
            }, cancelTitle: tr(.modalCancel), drawBorder: true)
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        if let currentEvent = NSApp.currentEvent {
            if FastSettings.checkSendingAbility(for: currentEvent) {
                self.modal?.close(true)
                return .invoked
            }
        }
        
        return .invokeNext
    }
    
    override func measure(size: NSSize) {
        self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(size.height - 70, genericView.tableView.listHeight + genericView.textView.frame.height)), animated: false)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.textView.delegate = self
        textViewHeightChanged(34, animated: false)
        ready.set(makeItems(self.urls))
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    override func firstResponder() -> NSResponder? {
        return genericView.textView
    }
    
    init(urls:[URL], account:Account, chatInteraction:ChatInteraction, asMedia:Bool = true) {
        self.urls = urls
        self.account = account
        self.isNeedAsMedia = asMedia
        self.chatInteraction = chatInteraction
        super.init(frame:NSMakeRect(0,0,350,350))
        bar = .init(height: 0)
    }
    
    
    func textViewHeightChanged(_ height: CGFloat, animated: Bool) {
      //  genericView.tableView.change(size: NSMakeSize(frame.width, frame.height - height), animated: animated)
        modal?.resize(with:NSMakeSize(genericView.frame.width, min(mainWindow.frame.height - 80, genericView.tableView.listHeight + genericView.textView.frame.height)), animated: animated)
        genericView.textView._change(pos: NSMakePoint(genericView.textView.frame.minX, frame.height - genericView.textView.frame.height), animated: animated)
    }
    
    func textViewEnterPressed(_ event: NSEvent) -> Bool {
        if FastSettings.checkSendingAbility(for: event) {
            return true
        }
        return false
    }
    
    func textViewTextDidChange(_ string: String) {
        
    }
    
    func textViewTextDidChangeSelectedRange(_ range: NSRange) {
        
    }
    
    func textViewDidPaste(_ pasteboard: NSPasteboard) -> Bool {
        return false
    }
    
    func textViewSize() -> NSSize {
        return NSMakeSize(frame.width - 40, genericView.textView.frame.height)
    }
    
    func textViewIsTypingEnabled() -> Bool {
        return true
    }
    
    func maxCharactersLimit() -> Int32 {
        return 200
    }
    
}
