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
    fileprivate let sendButton = ImageButton()
    fileprivate let emojiButton = ImageButton()
    fileprivate let actionsContainerView: View = View()
    fileprivate let headerView: View = View()
    
    fileprivate let closeButton = ImageButton()
    fileprivate let title: TextView = TextView()
    
    fileprivate let photoButton = ImageButton()
    fileprivate let fileButton = ImageButton()
    
    fileprivate let textContainerView: View = View()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        closeButton.set(image: theme.icons.modalClose, for: .Normal)
        closeButton.sizeToFit()
        
        photoButton.set(image: ControlStyle(highlightColor: theme.colors.grayIcon).highlight(image: theme.icons.chatAttachPhoto), for: .Normal)
        photoButton.sizeToFit()
        
        photoButton.isSelected = true
        
        fileButton.set(image: ControlStyle(highlightColor: theme.colors.grayIcon).highlight(image: theme.icons.chatAttachFile), for: .Normal)
        fileButton.sizeToFit()
        
        title.backgroundColor = theme.colors.background
        
        headerView.addSubview(closeButton)
        headerView.addSubview(title)
        headerView.addSubview(fileButton)
        headerView.addSubview(photoButton)
        
        
        sendButton.set(image: theme.icons.chatSendMessage, for: .Normal)
        sendButton.sizeToFit()
        
        emojiButton.set(image: theme.icons.chatEntertainment, for: .Normal)
        emojiButton.sizeToFit()
        
        actionsContainerView.addSubview(sendButton)
        actionsContainerView.addSubview(emojiButton)
        
        
        actionsContainerView.setFrameSize(sendButton.frame.width + emojiButton.frame.width + 40, 50)
        
        emojiButton.centerY(x: 0)
        sendButton.centerY(x: emojiButton.frame.maxX + 20)
        
        tableView.setFrameSize(frameRect.width, frameRect.height - 50)
        backgroundColor = theme.colors.background
        textView.setPlaceholderAttributedString(.initialize(string: tr(.previewSenderCaptionPlaceholder), color: theme.colors.grayText, font: .normal(.text)), update: false)
        textView.background = theme.colors.background
        textView.textFont = .normal(.text)
        textView.textColor = theme.colors.text
        textView.linkColor = theme.colors.link
        textView.max_height = 120
        backgroundColor = theme.colors.background
        
        textView.setFrameSize(NSMakeSize(0, 34))

        addSubview(tableView)
        textContainerView.addSubview(textView)
        addSubview(actionsContainerView)
        addSubview(headerView)
        addSubview(textContainerView)
        
    }
    
    var additionHeight: CGFloat {
        return max(50, textView.frame.height) + headerView.frame.height
    }
    
    func updateTitle(_ options: [PreviewOptions]) -> Void {
        let layout = TextViewLayout(.initialize(string: "Send 1 File", color: theme.colors.text, font: .medium(.title)), maximumNumberOfLines: 1)
        title.update(layout)
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        actionsContainerView.setFrameOrigin(frame.width - actionsContainerView.frame.width, frame.height - actionsContainerView.frame.height)
        headerView.setFrameSize(frame.width, 50)
        tableView.setFrameOrigin(0, headerView.frame.maxY)
        
        title.layout?.measure(width: frame.width - 100)
        title.update(title.layout)
        title.center()
        closeButton.centerY(x: headerView.frame.width - closeButton.frame.width - 10)
        
        photoButton.centerY(x: 10)
        fileButton.centerY(x: photoButton.frame.maxX + 10)
        
        textContainerView.setFrameSize(frame.width - actionsContainerView.frame.width, max(50, textView.frame.height))
        textContainerView.setFrameOrigin(0, frame.height - textContainerView.frame.height)
        textView.setFrameSize(NSMakeSize(textContainerView.frame.width - 10, textView.frame.height))
        textView.centerY(x: 10)

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
    private let disposable = MetaDisposable()
    override func viewClass() -> AnyClass {
        return PreviewSenderView.self
    }
    
    private var genericView:PreviewSenderView {
        return self.view as! PreviewSenderView
    }
    
    
    func makeItems(_ urls:[URL])  {
        let initialSize = atomicSize.modify({$0})
        let account = self.account
        let options = takeSenderOptions(for: urls)
        
        genericView.updateTitle(options)
        
        let signal = combineLatest(urls.map({Sender.generateMedia(for: MediaSenderContainer(path: $0.path, caption: "", isFile: urls.count > 1), account: account)}))
            |> map { $0.map({$0.0})}
            |> map { $0.map{MediaPreviewRowItem(initialSize, media: $0, account: account)} }
            |> deliverOnMainQueue
        
        disposable.set(signal.start(next: { [weak self] items in
            if let strongSelf = self {
                strongSelf.genericView.tableView.insert(items: items)
                let maxWidth = items.map({$0.contentSize.width}).max()! + 20
                let maxHeight = strongSelf.genericView.tableView.listHeight + strongSelf.genericView.additionHeight
                strongSelf.modal?.resize(with:NSMakeSize(maxWidth, maxHeight), animated: false)
                strongSelf.readyOnce()
            }
        }))
        
        
//        return Signal { [weak self] (subscriber) in
//
//            if let strongSelf = self {
//
//                let headerItem:TableRowItem?
//
//
//
//                if urls.count == 1 {
//                    let url = urls[0]
//                    let mime = MIMEType(url.path.nsstring.pathExtension.lowercased())
//                    if mime.hasPrefix("image") && mediaExts.contains(url.path.nsstring.pathExtension.lowercased()) {
//                        headerItem = PreviewThumbRowItem(initialSize.modify({$0}), url: url, account:account)
//                    } else {
//                        headerItem = PreviewDocumentRowItem(initialSize.modify({$0}), url: url, account:account)
//                    }
//                } else {
//                    headerItem = nil
//                }
//                if let headerItem = headerItem {
//                    let _ = strongSelf.genericView.tableView.addItem(item: headerItem)
//                }
//
//                if options.contains(.image) || options.contains(.video) {
//                    let _ = strongSelf.genericView.tableView.addItem(item: GeneralRowItem(initialSize.modify({$0}), height:10))
//                }
//
//
//                let _ = strongSelf.genericView.tableView.addItem(item: GeneralRowItem(initialSize.modify({$0}), height:10))
//                strongSelf.textViewHeightChanged(34, animated: false)
//
//                subscriber.putNext(true)
//                subscriber.putCompletion()
//
//            }
//
//            return EmptyDisposable
//        } |> runOn(Queue.mainQueue())
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
            self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(contentSize.height - 70, genericView.tableView.listHeight + genericView.additionHeight)), animated: false)
        }
    }
    
//    override var modalInteractions: ModalInteractions? {
//        let chatInteraction = self.chatInteraction
//
//        return ModalInteractions(acceptTitle:tr(.modalSend), accept: { [weak self] in
//            if let urls = self?.urls, let asMedia = self?.isNeedAsMedia {
//                let text = self?.genericView.textView.string() ?? ""
//                var containers:[MediaSenderContainer] = []
//                for url in urls {
//                    let asMedia = asMedia && mediaExts.contains(url.path.nsstring.pathExtension.lowercased())
//                    containers.append(MediaSenderContainer(path:url.path, caption: urls.count == 1 ? text : "", isFile:!asMedia))
//                }
//                if urls.count > 1 && !text.isEmpty {
//                    chatInteraction.forceSendMessage(text)
//                }
//                chatInteraction.sendMedia(containers)
//            }
//            self?.modal?.close()
//            }, cancelTitle: tr(.modalCancel), drawBorder: true)
//    }
    
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
        self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(size.height - 70, genericView.tableView.listHeight + 100)), animated: false)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.textView.delegate = self
        textViewHeightChanged(34, animated: false)
        makeItems(self.urls)
        //ready.set(makeItems(self.urls))
    }
    
    deinit {
        disposable.dispose()
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
