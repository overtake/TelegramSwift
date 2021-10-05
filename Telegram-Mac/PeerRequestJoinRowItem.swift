//
//  PeerRequestJoinRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01.10.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import TelegramCore

final class PeerRequestJoinRowItem: GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let data: PeerRequestChatJoinData
    
    fileprivate let nameLayout: TextViewLayout
    fileprivate let dateLayout: TextViewLayout
    fileprivate let aboutLayout: TextViewLayout

    fileprivate let add: (PeerId)->Void
    fileprivate let dismiss: (PeerId)->Void
    
    fileprivate let statusLayout: TextViewLayout?
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, data: PeerRequestChatJoinData, add: @escaping(PeerId)->Void, dismiss: @escaping(PeerId)->Void, viewType: GeneralViewType) {
        self.data = data
        self.context = context
        self.add = add
        self.dismiss = dismiss
        self.nameLayout = TextViewLayout(.initialize(string: data.peer.peer.displayTitle, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1, truncationType: .middle)
        
        self.aboutLayout = TextViewLayout(.initialize(string: data.about, color: theme.colors.grayText, font: .normal(.text)))
        self.dateLayout = TextViewLayout(.initialize(string: DateUtils.string(forMessageListDate: Int32(data.timeInterval)), color: theme.colors.grayText, font: .normal(.text)))
        
        if data.added || data.dismissed {
            let text: String
            if data.added {
                text = "\(data.peer.peer.compactDisplayTitle) is added"
            } else {
                text = "\(data.peer.peer.compactDisplayTitle) is dismissed"
            }
            self.statusLayout = TextViewLayout(.initialize(string: text, color: theme.colors.grayText, font: .medium(.text)))
        } else {
            self.statusLayout = nil
        }

        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override var height: CGFloat {
        let inset = viewType.innerInset
        return max(inset.top + nameLayout.layoutSize.height + inset.top / 2 + aboutLayout.layoutSize.height + 30 + inset.bottom * 2, 40 + inset.top + inset.bottom)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.aboutLayout.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right - 40 - viewType.innerInset.right)
        self.dateLayout.measure(width: .greatestFiniteMagnitude)
        self.nameLayout.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right - 40 - viewType.innerInset.left - self.dateLayout.layoutSize.width - viewType.innerInset.right)
        
        self.statusLayout?.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right - 40 - viewType.innerInset.right)
        return true
    }
    
    override func viewClass() -> AnyClass {
        return PeerRequestJoinRowView.self
    }
}


private final class PeerRequestJoinRowView: GeneralContainableRowView {
    private let avatar = AvatarControl(font: .avatar(14))
    private let timeView = TextView()
    private let nameView = TextView()
    private let aboutView = TextView()
    private let addButton = TitleButton()
    private let dismissButton = TitleButton()
    
    private var statusView: TextView?
    private var progressIndicator: ProgressIndicator?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        avatar.setFrameSize(NSMakeSize(40, 40))
        addSubview(avatar)
        addSubview(timeView)
        addSubview(aboutView)
        addSubview(nameView)
        addSubview(addButton)
        addSubview(dismissButton)
        
        timeView.userInteractionEnabled = false
        timeView.isSelectable = false
        
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        
        addButton.scaleOnClick = true
        addButton.autohighlight = false
        
        self.addButton.set(handler: { [weak self] _ in
            guard let item = self?.item as? PeerRequestJoinRowItem else {
                return
            }
            item.add(item.data.peer.peer.id)
        }, for: .Click)
        
        self.dismissButton.set(handler: { [weak self] _ in
            guard let item = self?.item as? PeerRequestJoinRowItem else {
                return
            }
            item.dismiss(item.data.peer.peer.id)
        }, for: .Click)
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? GeneralRowItem else {
            return
        }
        let inset = item.viewType.innerInset
        avatar.setFrameOrigin(NSMakePoint(inset.left, inset.top))
        nameView.setFrameOrigin(NSMakePoint(avatar.frame.maxX + inset.left, inset.top))
        timeView.setFrameOrigin(NSMakePoint(containerView.frame.width - timeView.frame.width - inset.right, inset.top))
        aboutView.setFrameOrigin(NSMakePoint(nameView.frame.minX, nameView.frame.maxY + inset.top / 2))
        addButton.setFrameOrigin(NSMakePoint(nameView.frame.minX, aboutView.frame.maxY + inset.top))
        dismissButton.setFrameOrigin(NSMakePoint(addButton.frame.maxX + 20, addButton.frame.minY))
        
        statusView?.setFrameOrigin(NSMakePoint(nameView.frame.minX, dismissButton.frame.minY + 5))
        progressIndicator?.setFrameOrigin(NSMakePoint(nameView.frame.minX, dismissButton.frame.minY))
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PeerRequestJoinRowItem else {
            return
        }
        
        self.timeView.update(item.dateLayout)
        self.aboutView.update(item.aboutLayout)
        self.nameView.update(item.nameLayout)
        
        avatar.setPeer(account: item.context.account, peer: item.data.peer.peer)
        
        self.addButton.set(text: "Add to Channel", for: .Normal)
        self.addButton.set(font: .medium(.text), for: .Normal)
        self.addButton.set(color: theme.colors.underSelectedColor, for: .Normal)
        self.addButton.set(background: theme.colors.accent, for: .Normal)
        
        self.addButton.sizeToFit(NSMakeSize(10, 10), .zero, thatFit: false)
        self.addButton.layer?.cornerRadius = self.addButton.frame.height / 2
        
        
        self.dismissButton.set(text: "Dismiss", for: .Normal)
        self.dismissButton.set(font: .medium(.text), for: .Normal)
        self.dismissButton.set(color: theme.colors.accent, for: .Normal)
        self.dismissButton.set(color: theme.colors.accent.lighter(), for: .Highlight)
        self.dismissButton.sizeToFit(.zero, NSMakeSize(0, self.addButton.frame.height), thatFit: true)
        
        
        self.addButton.isEnabled = !item.data.added && !item.data.dismissed && !item.data.dismissing && !item.data.adding
        self.dismissButton.isEnabled = !item.data.added && !item.data.dismissed && !item.data.dismissing && !item.data.adding

        if self.addButton.isEnabled {
           self.addButton.change(opacity: 1, animated: animated)
        }  else {
            self.addButton.change(opacity: 0, animated: animated)
        }
        if self.addButton.isEnabled {
            self.dismissButton.change(opacity: 1, animated: animated)
        } else {
            self.dismissButton.change(opacity: 0, animated: animated)
        }
        
        if item.data.dismissing || item.data.adding {
            let current: ProgressIndicator
            let isNew: Bool
            if let progressIndicator = self.progressIndicator {
                current = progressIndicator
                isNew = false
            } else {
                current = ProgressIndicator(frame: NSMakeRect(0, 0, addButton.frame.height, addButton.frame.height))
                self.progressIndicator = current
                current.progressColor = theme.colors.grayText
                addSubview(current)
                isNew = true
            }
            if isNew {
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
        } else {
            if let progressIndicator = self.progressIndicator {
                performSubviewRemoval(progressIndicator, animated: animated)
                self.progressIndicator = nil
            } else {
                self.progressIndicator?.removeFromSuperview()
                self.progressIndicator = nil
            }
        }
        
        if item.data.added || item.data.dismissed {
            let current: TextView
            let isNew: Bool
            if let statusView = self.statusView {
                current = statusView
                isNew = false
            } else {
                current = TextView()
                current.userInteractionEnabled = false
                current.isSelectable = false
                self.statusView = current
                addSubview(current)
                isNew = true
            }
            current.update(item.statusLayout)
            if isNew {
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
        } else {
            if let statusView = self.statusView {
                performSubviewRemoval(statusView, animated: animated)
                self.statusView = nil
            } else {
                self.statusView?.removeFromSuperview()
                self.statusView = nil
            }
        }
        
        needsLayout = true
    }
}
