//
//  PeerMediaEmptyRowItem.swift
//  TelegramMac
//
//  Created by keepcoder on 24/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox



class PeerMediaEmptyRowItem: TableRowItem {
    let textLayout:TextViewLayout
    let tags:MessageTags
    let image:CGImage
    init(_ initialSize:NSSize, tags:MessageTags) {
        self.tags = tags
        let attr:NSAttributedString
        if tags.contains(.file) {
            image = theme.icons.mediaEmptyFiles
            attr = .initialize(string: tr(L10n.peerMediaSharedFilesEmptyList), color: theme.colors.grayText, font: .normal(.header))
        } else if tags.contains(.music) || tags.contains(.voiceOrInstantVideo) {
            image = theme.icons.mediaEmptyMusic
            attr = .initialize(string: tags.contains(.voiceOrInstantVideo) ? L10n.peerMediaSharedVoiceEmptyList : L10n.peerMediaSharedMusicEmptyList, color: theme.colors.grayText, font: .normal(.header))
        } else if tags.contains(.webPage) {
            image = theme.icons.mediaEmptyLinks
            attr = .initialize(string: tr(L10n.peerMediaSharedLinksEmptyList), color: theme.colors.grayText, font: .normal(.header))
        } else {
            image = theme.icons.mediaEmptyShared
            attr = .initialize(string: tr(L10n.peerMediaSharedMediaEmptyList), color: theme.colors.grayText, font: .normal(.header))
        }
        textLayout = TextViewLayout(attr, alignment: .center)
        super.init(initialSize)
    }
    
    override var height: CGFloat {
        if let table = table {
            return table.frame.height
        } else {
            return initialSize.height
        }
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        return true
    }
    
    override func viewClass() -> AnyClass {
        return PeerMediaEmptyRowView.self
    }
}

class PeerMediaEmptyRowView : TableRowView {
    private let textView:TextView = TextView()
    private let imageView:ImageView = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        textView.isSelectable = false
        addSubview(imageView)
    }
    
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
    
    override func updateColors() {
        super.updateColors()
        textView.backgroundColor = backdorColor
    }
    
    override func layout() {
        super.layout()
        if let item = item as? PeerMediaEmptyRowItem {
            imageView.centerX(y: bounds.midY - imageView.frame.height - 40)
            item.textLayout.measure(width: frame.width - 60)
            textView.update(item.textLayout)
            textView.centerX(y: imageView.frame.maxY + 16)
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        if let item = item as? PeerMediaEmptyRowItem {
            imageView.image = item.image
            imageView.sizeToFit()
            needsLayout = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
