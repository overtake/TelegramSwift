//
//  StoryMyEmptyRowItem.swift
//  Telegram
//
//  Created by Mike Renoir on 18.05.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore

final class StoryMyEmptyRowItem : GeneralRowItem {
    fileprivate let titleLayout: TextViewLayout
    fileprivate let sticker: LocalAnimatedSticker = LocalAnimatedSticker.stories_archive
    fileprivate let stickerSize: NSSize = NSMakeSize(120, 120)
    fileprivate let context: AccountContext
    fileprivate let showArchive: ()->Void
    fileprivate let isArchive: Bool
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, viewType: GeneralViewType, isArchive: Bool, showArchive: @escaping()->Void) {
        self.showArchive = showArchive
        self.isArchive = isArchive
        let string = NSMutableAttributedString()
        
        if isArchive {
            _ = string.append(string: strings().storyMediaArchiveEmptyTitle, color: theme.colors.text, font: .medium(.header))
            _ = string.append(string: "\n", color: theme.colors.text, font: .medium(.small))
            _ = string.append(string: strings().storyMediaArchiveEmptyText, color: theme.colors.grayText, font: .normal(.text))
        } else {
            _ = string.append(string: strings().storyMediaEmptyTitle, color: theme.colors.text, font: .medium(.header))
            _ = string.append(string: "\n", color: theme.colors.text, font: .medium(.small))
            _ = string.append(string: strings().storyMediaEmptyText, color: theme.colors.grayText, font: .normal(.text))
        }

        self.titleLayout = TextViewLayout(string, alignment: .center)
        self.context = context
        super.init(initialSize, stableId: stableId, viewType: viewType)
        _ = makeSize(initialSize.width)
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _  = super.makeSize(width, oldWidth: oldWidth)
        
        titleLayout.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right)
        
        return true
    }
    
    override var height: CGFloat {
        var height = self.viewType.innerInset.top + stickerSize.height + self.viewType.innerInset.top + titleLayout.layoutSize.height + self.viewType.innerInset.top + 20 + self.viewType.innerInset.bottom + 20 + 10
        
        if isArchive {
            height -= (30 + 10)
        }
        return height
    }
    
    override func viewClass() -> AnyClass {
        return StoryMyEmptyRowView.self
    }
}


private final class StoryMyEmptyRowView: GeneralContainableRowView {
    private let imageView: MediaAnimatedStickerView = MediaAnimatedStickerView(frame: .zero)
    private let textView: TextView = TextView()
    private let archive = TitleButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(textView)
        addSubview(archive)
        
        archive.autohighlight = false
        archive.scaleOnClick = true
        
        textView.isSelectable = false
        textView.userInteractionEnabled = true
        
        archive.set(handler: { [weak self] _ in
            if let item = self?.item as? StoryMyEmptyRowItem {
                item.showArchive()
            }
        }, for: .SingleClick)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? StoryMyEmptyRowItem else {
            return
        }
        
        let params = item.sticker.parameters
        
        archive.set(font: .medium(.title), for: .Normal)
        archive.set(color: theme.colors.underSelectedColor, for: .Normal)
        archive.set(background: theme.colors.accent, for: .Normal)
        archive.layer?.cornerRadius = 10
        archive.set(text: strings().storyMediaEmptyOpen, for: .Normal)
        archive.sizeToFit(NSMakeSize(10, 10), NSMakeSize(200, 30), thatFit: false)
        
        archive.isHidden = item.isArchive
        
        imageView.update(with: item.sticker.file, size: item.stickerSize, context: item.context, parent: nil, table: item.table, parameters: params, animated: animated, positionFlags: nil, approximateSynchronousValue: false)
        
//        self.imageView.image = item.icon
//        self.imageView.sizeToFit()
        
        self.textView.update(item.titleLayout)
        
        needsLayout = true

    }
    override func layout() {
        super.layout()
        guard let item = item as? StoryMyEmptyRowItem else { return }

        self.imageView.centerX(y: item.viewType.innerInset.top)
        self.textView.centerX(y: self.imageView.frame.maxY + 20 + item.inset.bottom)
        
        archive.centerX(y: self.textView.frame.maxY + item.inset.top + 10)
        
    }
}
