//
//  StatisticsLoadingRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 18.03.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class StatisticsLoadingRowItem: GeneralRowItem {
    
    let text:TextViewLayout?
    
    let context: AccountContext
    init(_ initialSize: NSSize, stableId:AnyHashable, context: AccountContext, text:String? = nil, viewType: GeneralViewType = .legacy) {
        self.context = context
        if let text = text {
            self.text = TextViewLayout(.initialize(string: text, color: theme.colors.grayText, font: .normal(.title)), alignment: .center)
            self.text?.measure(width: initialSize.width - 60)
        } else {
            self.text = nil
        }
        super.init(initialSize, stableId: stableId, viewType: viewType)
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
        return StatisticsLoadingRowView.self
    }
}


class StatisticsLoadingRowView : TableRowView {
    private let imageView:MediaAnimatedStickerView = MediaAnimatedStickerView(frame: NSZeroRect)
    private let textView:TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(textView)
        textView.isSelectable = false
        
    }
    
    
    override var backdorColor: NSColor {
        if let item = item as? StatisticsLoadingRowItem {
            return item.viewType.rowBackground
        } else {
            return super.backdorColor
        }
    }
    
    override func layout() {
        super.layout()
        imageView.center()
        if let item = item as? StatisticsLoadingRowItem {
            textView.update(item.text)
            textView.centerX(y: imageView.frame.maxY + 10)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item)
        
        if let item = item as? StatisticsLoadingRowItem {
            
            imageView.update(with: LocalAnimatedSticker.graph_loading.file, size: NSMakeSize(80, 80), context: item.context, parent: nil, table: item.table, parameters: LocalAnimatedSticker.graph_loading.parameters, animated: animated, positionFlags: nil, approximateSynchronousValue: false)
            
            textView.backgroundColor = backdorColor
            self.needsLayout = true
        }
    }
}
