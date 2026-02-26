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
    struct RightAction {
        var image: CGImage
        var action: (NSView)->Void
    }
    fileprivate let textLayout: TextViewLayout
    fileprivate let header: GeneralBlockTextHeader?
    fileprivate let headerLayout: TextViewLayout?
    fileprivate let rightAction: RightAction?
    fileprivate let centerViewAlignment: Bool
    fileprivate let _hasBorder: Bool?
    fileprivate let reversedBackground: Bool
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, text: String, font: NSFont, color: NSColor = theme.colors.text, header: GeneralBlockTextHeader? = nil, insets: NSEdgeInsets = NSEdgeInsets(left: 20, right: 20), centerViewAlignment: Bool = false, rightAction: RightAction? = nil, hasBorder: Bool? = nil, singleLine: Bool = false, customTheme: GeneralRowItem.Theme? = nil, linkCallback:((String)->Void)? = nil, reversedBackground: Bool = false) {
        
        self.reversedBackground = reversedBackground
        let color = customTheme?.textColor ?? color
        let linkColor = customTheme?.accentColor ?? theme.colors.link

        let attr = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: font, textColor: color), bold: MarkdownAttributeSet(font: .medium(font.pointSize), textColor: color), link: MarkdownAttributeSet(font: .normal(font.pointSize), textColor: linkColor), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents, { value in
                linkCallback?(value)
            }))
        })).mutableCopy() as! NSMutableAttributedString
        
        attr.detectBoldColorInString(with: .medium(font.pointSize))
        
        self.textLayout = TextViewLayout(attr, maximumNumberOfLines: singleLine ? 1 : 0, alwaysStaticItems: false)
        self.textLayout.interactions = globalLinkExecutor
        self.header = header
        self._hasBorder = hasBorder
        self.centerViewAlignment = centerViewAlignment
        self.rightAction = rightAction
        if let header = header {
            self.headerLayout = TextViewLayout(.initialize(string: header.text, color: customTheme?.textColor ?? color, font: .medium(.title)), maximumNumberOfLines: 3)
        } else {
            self.headerLayout = nil
        }
        super.init(initialSize, stableId: stableId, viewType: viewType, inset: insets, customTheme: customTheme)
    }
    
    override var hasBorder: Bool {
        if let _hasBorder = _hasBorder {
            return _hasBorder
        } else {
            return super.hasBorder
        }
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        var action_w: CGFloat = 0
        if let _ = self.rightAction {
            action_w = 45
        }
        
        self.textLayout.measure(width: self.blockWidth - self.viewType.innerInset.left - self.viewType.innerInset.right - action_w)
        self.headerLayout?.measure(width: self.blockWidth - self.viewType.innerInset.left - self.viewType.innerInset.right - action_w)
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


private final class GeneralBlockTextRowView : GeneralContainableRowView {
    private let textView = TextView()
    private var headerView: TextView?
    private var headerImageView : ImageView?
    private let separator: View = View()
    private var rightAction: ImageButton?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.addSubview(textView)
        self.addSubview(separator)
    }
    
    override var backdorColor: NSColor {
        guard let item = item as? GeneralRowItem else {
            return theme.colors.background
        }
        return item.customTheme?.backgroundColor ?? theme.colors.background
    }
    
    override func updateColors() {
        super.updateColors()
        
        guard let item = item as? GeneralBlockTextRowItem else {
            return
        }
        self.textView.backgroundColor = backdorColor
        self.separator.backgroundColor = item.customTheme?.borderColor ?? theme.colors.border
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
            if !item.centerViewAlignment {
                textView.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left, item.viewType.innerInset.top))
            } else {
                textView.center()
            }
        }
        
        
        separator.frame = NSMakeRect(item.viewType.innerInset.left, containerView.frame.height - .borderSize, containerView.frame.width - item.viewType.innerInset.left - item.viewType.innerInset.right, .borderSize)
        
        if let current = self.rightAction {
            current.centerY(x: containerView.frame.width - current.frame.width - 10)
        }
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
        
        if let action = item.rightAction {
            let current: ImageButton
            if let view = self.rightAction {
                current = view
            } else {
                current = ImageButton()
                current.scaleOnClick = true
                current.autohighlight = false
                containerView.addSubview(current)
                self.rightAction = current
            }
            current.set(image: action.image, for: .Normal)
            current.sizeToFit()
            current.removeAllHandlers()
            current.set(handler: { control in
                action.action(control)
            }, for: .Click)
        } else if let view = self.rightAction {
            performSubviewRemoval(view, animated: animated)
            self.rightAction = nil
        }
        
        textView.update(item.textLayout)
        self.separator.isHidden = !item.hasBorder
        needsLayout = true
    }
    
    override var firstResponder: NSResponder? {
        return nil
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
