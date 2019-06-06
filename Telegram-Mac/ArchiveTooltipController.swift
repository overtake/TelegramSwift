//
//  ArchiveTooltipController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 26/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import SwiftSignalKitMac
import TelegramCoreMac


enum ArchiveTooltipType : Equatable {
    case first
    case second
    case third
    case justArchive
    
    var localizedTitle: String {
        switch self {
        case .first:
            return L10n.archiveTooltipFirstTitle
        case .second:
            return L10n.archiveTooltipSecondTitle
        case .third:
            return L10n.archiveTooltipThirdTitle
        case .justArchive:
            return L10n.archiveTooltipJustArchiveTitle
        }
    }
    var localizedText: String? {
        switch self {
        case .first:
            return L10n.archiveTooltipFirstText
        case .second:
            return L10n.archiveTooltipSecondText
        case .third:
            return L10n.archiveTooltipThirdText
        case .justArchive:
            return nil
        }
    }
}

final class ArchiveTooltipView : View {
    private let titleView: TextView = TextView()
    private var textView: TextView?
    private var undo: TitleButton?
    private let type: ArchiveTooltipType
    private let undoHandler: ()->Void
    init(frame frameRect: NSRect, type: ArchiveTooltipType, undo: @escaping()->Void) {
        self.type = type
        self.undoHandler = undo
        super.init(frame: frameRect)
       // self.wantsLayer = true
//        self.blendingMode = .behindWindow
//        self.material = .ultraDark
//        self.state = .active
        
      //  self.material = .ultraDark
        
        self.layer?.cornerRadius = 6
        addSubview(titleView)
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        titleView.disableBackgroundDrawing = true
        needsLayout = true
    }
    
    override func updateLocalizationAndTheme() {
        needsLayout = true
        self.backgroundColor = NSColor.black.withAlphaComponent(0.8)
    }
    
    func update() {
        let titleLayout = TextViewLayout(.initialize(string: type.localizedTitle, color: .white, font: .medium(.title)), maximumNumberOfLines: 1, alwaysStaticItems: true)
        titleLayout.measure(width: frame.width - 20)
        
        var height: CGFloat = titleLayout.layoutSize.height + 10
        
        self.titleView.update(titleLayout)
        
        if let text = type.localizedText {
            let textLayout = TextViewLayout(.initialize(string: text, color: .white, font: .normal(.text)), maximumNumberOfLines: 2, alwaysStaticItems: true)
            textLayout.measure(width: frame.width - 20)
            let textView = self.textView ?? TextView()
            textView.update(textLayout)
            
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            textView.disableBackgroundDrawing = true

            height += textLayout.layoutSize.height
            
            self.textView = textView
            addSubview(textView)
            
        } else {
            height = 40
            if type == .justArchive {
                let undo = self.undo ?? TitleButton()
                undo.set(font: .medium(.title), for: .Normal)
                undo.set(color: .blueIcon, for: .Normal)
                undo.set(text: L10n.chatUndoManagerUndo, for: .Normal)
                
                undo.removeAllHandlers()
                undo.set(handler: { [weak self] _ in
                    self?.undoHandler()
                }, for: .Down)
                
                
                _ = undo.sizeToFit()
                
                self.undo = undo
                addSubview(undo)
            }
        }
        setFrameSize(frame.width, height)
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    override func layout() {
        super.layout()
        update()
        if let textView = self.textView {
            self.titleView.setFrameOrigin(NSMakePoint(10, 5))
            textView.setFrameOrigin(NSMakePoint(10, frame.height - textView.frame.height - 5))
        } else {
            self.titleView.centerY(x: 10)
            if let undo = self.undo {
                undo.centerY(x: frame.width - undo.frame.width - 10)
            }
        }
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

class ArchiveTooltipController: TelegramGenericViewController<ArchiveTooltipView> {
    private let peerId: PeerId
    private let type: ArchiveTooltipType
    private let undo: (PeerId)->Void
    private weak var controller: ViewController?
    init(_ context: AccountContext, controller: ViewController, peerId: PeerId, type: ArchiveTooltipType, undo: @escaping(PeerId)->Void = { _ in }) {
        self.peerId = peerId
        self.type = type
        self.undo = undo
        self.controller = controller
        super.init(context)
        self.bar = .init(height: 0)
        self._frameRect = NSMakeRect(0, 0, controller.frame.width - 40, 60)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        readyOnce()
    }
    override func initializer() -> ArchiveTooltipView {
        return ArchiveTooltipView(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - bar.height), type: self.type, undo: { [weak self] in
            if let `self` = self {
                _ = updatePeerGroupIdInteractively(postbox: self.context.account.postbox, peerId: self.peerId, groupId: .root).start()
            }
        })
    }
    
    
    func show() {
        
        guard let controller = controller else { return }
        loadViewIfNeeded()
        controller.view.addSubview(self.view)
        self.genericView.update()
        self.view.frame = NSMakeRect(20, controller.frame.height - self.frame.height - 30, controller.frame.width - 40, self.frame.height)
        
        NotificationCenter.default.addObserver(self, selector: #selector(parentFrameDidChange(_:)), name: NSView.frameDidChangeNotification, object: controller.view)

    }
    
    override func updateLocalizationAndTheme() {
        genericView.updateLocalizationAndTheme()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func parentFrameDidChange(_ notification:Notification) {
        
        guard let controller = controller else { return }
        
        
        self.view.isHidden = controller.frame.width < 100

        self.view.frame = NSMakeRect(20, controller.frame.height - self.frame.height - 30, controller.frame.width - 40, self.frame.height)
    }
    
}
