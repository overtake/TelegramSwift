//
//  LanguageRowItem.swift
//  Telegram
//
//  Created by keepcoder on 25/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

class LanguageRowItem: GeneralRowItem {
    fileprivate let selected:Bool
    fileprivate let locale:TextViewLayout
    fileprivate let title:TextViewLayout
    fileprivate let deleteAction: ()->Void
    fileprivate let deletable: Bool

    fileprivate let _stableId:AnyHashable
    override var stableId: AnyHashable {
        return _stableId
    }
    
    init(initialSize: NSSize, stableId: AnyHashable, selected: Bool, deletable: Bool, value:LocalizationInfo, viewType: GeneralViewType = .legacy, action:@escaping()->Void, deleteAction: @escaping()->Void = {}, reversed: Bool = false) {
        self._stableId = stableId
        self.selected = selected
        self.title = TextViewLayout(.initialize(string: reversed ? value.localizedTitle : value.title, color: theme.colors.text, font: .normal(.title)), maximumNumberOfLines: 1)
        self.locale = TextViewLayout(.initialize(string: reversed ? value.title : value.localizedTitle, color: reversed ? theme.colors.grayText : theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
        self.deletable = deletable
        self.deleteAction = deleteAction
        super.init(initialSize, viewType: viewType, action: action)
        
        _ = makeSize(initialSize.width, oldWidth: initialSize.width)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        locale.measure(width: width - 100)
        title.measure(width: width - 100)
        return true
    }
    
    override var height: CGFloat {
        return 48
    }
    
    override func viewClass() -> AnyClass {
        return LanguageRowView.self
    }
}


class LanguageRowView : TableRowView {
    private let localeTextView:TextView = TextView()
    private let titleTextView:TextView = TextView()
    private let selectedImage:ImageView = ImageView()
    private let overalay:OverlayControl = OverlayControl()
    private let deleteButton = ImageButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleTextView)
        addSubview(localeTextView)
        addSubview(selectedImage)
       
        selectedImage.sizeToFit()
        localeTextView.isSelectable = false
        titleTextView.isSelectable = false
        addSubview(overalay)
        overalay.set(background: .grayTransparent, for: .Highlight)
        addSubview(deleteButton)
        overalay.set(handler: { [weak self] _ in
            if let item = self?.item as? LanguageRowItem {
                item.action()
            }
        }, for: .Click)
        
        deleteButton.set(handler: { [weak self] _ in
            if let item = self?.item as? LanguageRowItem {
                item.deleteAction()
            }
        }, for: .Click)
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        overalay.setFrameSize(newSize)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        if let item = item as? LanguageRowItem {
            titleTextView.update(item.title)
            localeTextView.update(item.locale)
            
            deleteButton.set(image: theme.icons.customLocalizationDelete, for: .Normal)
            _ = deleteButton.sizeToFit()
            
            selectedImage.image = theme.icons.generalSelect
            selectedImage.sizeToFit()
            titleTextView.backgroundColor = theme.colors.background
            localeTextView.backgroundColor = theme.colors.background
            selectedImage.isHidden = !item.selected
            
            deleteButton.isHidden = !item.deletable || item.selected
            
            needsLayout = true
        }
    }

    
    override func layout() {
        super.layout()
        selectedImage.centerY(x: frame.width - 25 - selectedImage.frame.width)
        deleteButton.centerY(x: frame.width - 18 - deleteButton.frame.width)
        if let item = item as? LanguageRowItem {
            titleTextView.update(item.title, origin: NSMakePoint(25, 5))
            localeTextView.update(item.locale, origin: NSMakePoint(25, frame.height - titleTextView.frame.height - 5))
        }
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(25, frame.height - .borderSize, frame.width - 50, .borderSize))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
