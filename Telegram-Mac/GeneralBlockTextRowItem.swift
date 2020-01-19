//
//  GeneralBlockTextRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 24/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

struct GeneralBlockTextHeader {
    let text: String
    let icon: CGImage?
    init(text: String, icon: CGImage?) {
        self.text = text
        self.icon = icon
    }
}

class GeneralBlockTextRowItem: GeneralRowItem {
    fileprivate let textLayout: TextViewLayout
    fileprivate let header: GeneralBlockTextHeader?
    fileprivate let headerLayout: TextViewLayout?
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, text: String, font: NSFont, header: GeneralBlockTextHeader? = nil) {
        self.textLayout = TextViewLayout(.initialize(string: text, color: theme.colors.text, font: font), alwaysStaticItems: false)
        self.header = header
        if let header = header {
            self.headerLayout = TextViewLayout(.initialize(string: header.text, color: theme.colors.text, font: .medium(.title)), maximumNumberOfLines: 3)
        } else {
            self.headerLayout = nil
        }
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.textLayout.measure(width: self.blockWidth - self.viewType.innerInset.left - self.viewType.innerInset.right)
        self.headerLayout?.measure(width: self.blockWidth - self.viewType.innerInset.left - self.viewType.innerInset.right)
        return true
    }
    
    override func viewClass() -> AnyClass {
        return GeneralBlockTextRowView.self
    }
    
    override var height: CGFloat {
        var height: CGFloat = textLayout.layoutSize.height + viewType.innerInset.bottom + viewType.innerInset.top
    
        if let headerLayout = self.headerLayout {
            height += (headerLayout.layoutSize.height + 4)
        }
        
        return height
    }
}


private final class GeneralBlockTextRowView : TableRowView {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private let textView = TextView()
    private var headerView: TextView?
    private var headerImageView : ImageView?
    private let separator: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(containerView)
        containerView.addSubview(textView)
        containerView.addSubview(separator)
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func updateColors() {
        guard let item = item as? GeneralBlockTextRowItem else {
            return
        }
        self.backgroundColor = item.viewType.rowBackground
        self.containerView.backgroundColor = backdorColor
        self.textView.backgroundColor = backdorColor
        self.separator.backgroundColor = theme.colors.border
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? GeneralBlockTextRowItem else {
            return
        }
        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
        self.containerView.setCorners(item.viewType.corners)
        
        if let headerView = headerView {
            var inset: CGFloat = 0
            if let headerImageView = headerImageView {
                headerImageView.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left, item.viewType.innerInset.top + 2))
                inset += headerImageView.frame.width + 4
            }
            headerView.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left + inset, item.viewType.innerInset.top))
            textView.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left, headerView.frame.maxY + 4))
        } else {
            textView.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left, item.viewType.innerInset.top))
        }
        
        
        separator.frame = NSMakeRect(item.viewType.innerInset.left, containerView.frame.height - .borderSize, containerView.frame.width - item.viewType.innerInset.left - item.viewType.innerInset.right, .borderSize)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? GeneralBlockTextRowItem else {
            return
        }
        
        if let headerLayout = item.headerLayout {
            if headerView == nil {
                self.headerView = TextView()
                self.headerView?.userInteractionEnabled = false
                self.headerView?.isSelectable = false
                containerView.addSubview(self.headerView!)
            }
            headerView?.update(headerLayout)
            
            if let image = item.header?.icon {
                if headerImageView == nil {
                    self.headerImageView = ImageView()
                    containerView.addSubview(self.headerImageView!)
                }
                headerImageView?.image = image
                headerImageView?.sizeToFit()
            }
        } else {
            self.headerView?.removeFromSuperview()
            self.headerView = nil
        }
        
        textView.update(item.textLayout)
        self.separator.isHidden = !item.viewType.hasBorder
        needsLayout = true
    }
    
    override var firstResponder: NSResponder? {
        return nil
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
