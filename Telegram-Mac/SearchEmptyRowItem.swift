//
//  SearchEmptyRowItem.swift
//  Telegram
//
//  Created by keepcoder on 14/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class SearchEmptyRowItem: GeneralRowItem {
    
    let isLoading:Bool
    let icon:CGImage
    let text:TextViewLayout?

    
    init(_ initialSize: NSSize, stableId:AnyHashable, isLoading:Bool = false, icon:CGImage = theme.icons.emptySearch, text:String? = nil, border:BorderType = [], viewType: GeneralViewType = .legacy, customTheme: GeneralRowItem.Theme? = nil) {
        self.isLoading = isLoading
        self.icon = icon
        if let text = text {
            self.text = TextViewLayout(.initialize(string: text, color: customTheme?.grayTextColor ?? theme.colors.grayText, font: .normal(.title)), alignment: .center)
            self.text?.measure(width: initialSize.width - 60)
        } else {
            self.text = nil
        }
        super.init(initialSize, stableId: stableId, viewType: viewType, border: border, customTheme: customTheme)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        text?.measure(width: width - 60)
        return success
    }
    
    override var height: CGFloat {
        if let table = table {
            var basic:CGFloat = 0
            table.enumerateItems(with: { [weak self] item in
                if let strongSelf = self {
                    if item.index < strongSelf.index {
                        basic += item.height
                    }
                }
                return true
            })
            return table.frame.height - basic
        } else {
            return initialSize.height
        }
    }
    
    override func viewClass() -> AnyClass {
        return SearchEmptyRowView.self
    }
}


class SearchEmptyRowView : TableRowView {
    private let imageView:ImageView = ImageView()
    private let textView:TextView = TextView()
    private let indicator:ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 35, 35))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(indicator)
        addSubview(imageView)
        addSubview(textView)
        textView.isSelectable = false
        
    }
    

    override var backdorColor: NSColor {
        if let item = item as? SearchEmptyRowItem {
            if let customTheme = item.customTheme {
                return customTheme.backgroundColor
            }
            return item.viewType.rowBackground
        } else {
            return super.backdorColor
        }
    }
    
    override func layout() {
        super.layout()
        imageView.center()
        indicator.center()
        if let item = item as? SearchEmptyRowItem {
            textView.update(item.text)
            textView.center()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item)
        
        if let item = item as? SearchEmptyRowItem {
          //  indicator.color = theme.colors.indicatorColor
            super.border = item.border
            imageView.image = item.icon
            imageView.sizeToFit()
            imageView.isHidden = item.isLoading || item.text != nil
            indicator.isHidden = !item.isLoading
            
            if item.isLoading {
                indicator.animates = true
            } else {
                indicator.animates = false
            }
            
            textView.isHidden = item.text == nil || item.isLoading
            textView.backgroundColor = backdorColor
            self.needsLayout = true
        }
    }
}
