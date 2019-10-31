//
//  WalletTestWordsItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
private func _id_word(_ index:Int) -> InputDataIdentifier {
    return InputDataIdentifier("_id_word_\(index)")
}
class WalletTestWordsItem: GeneralRowItem {
    fileprivate let items:[InputDataRowItem]
    fileprivate let indexes:[Int]
    init(_ initialSize: NSSize, stableId: AnyHashable, indexes:[Int], words:[InputDataIdentifier: InputDataValue], viewType: GeneralViewType, update:@escaping(InputDataIdentifier, InputDataValue)->Void) {
        self.indexes = indexes
        var items: [InputDataRowItem] = []
        let insets = NSEdgeInsets(left: 5, right: 0, top: 12, bottom: 12)
        for index in indexes {
            let item = InputDataRowItem(NSMakeSize(240, 40), stableId: _id_word(index), mode: .plain, error: nil, viewType: .modern(position: bestGeneralViewType(indexes, for: index).position, insets: insets), currentText: words[_id_word(index)]?.stringValue ?? "", placeholder: nil, inputPlaceholder: "", defaultText: nil, rightItem: nil, insets: NSEdgeInsets(), filter: { $0 }, updated: { text in
                update(_id_word(index), .string(text))
            }, pasteFilter: nil, limit: 8)
            items.append(item)
        }
        self.items = items
        
        super.init(initialSize, height: 40 * 3, stableId: stableId, type: .none, viewType: viewType)
    }
    
    override var blockWidth: CGFloat {
        return 280
    }
    
    override var instantlyResize: Bool {
        return false
    }
    
    
    override func viewClass() -> AnyClass {
        return WalletTestWordsView.self
    }
}

private final class WalletTestWordsView : TableRowView {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private let holderViews:[TextView]
    
    private let views:[InputDataRowView]
    private let viewsContainer = View()
    required init(frame frameRect: NSRect) {
        var views:[InputDataRowView] = []
        var holdersView: [TextView] = []
        
        for _ in 0 ..< 3 {
            views.append(InputDataRowView(frame: NSZeroRect))
            holdersView.append(TextView())
        }
        self.views = views
        self.holderViews = holdersView
        super.init(frame: frameRect)
        
        for view in views {
            viewsContainer.addSubview(view)
        }
        for view in holderViews {
            viewsContainer.addSubview(view)
        }
        containerView.addSubview(viewsContainer)
        addSubview(containerView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? WalletTestWordsItem else {
            return
        }
        
        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
        self.containerView.setCorners(item.viewType.corners)
        
        viewsContainer.setFrameSize(NSMakeSize(item.blockWidth - item.viewType.innerInset.left - item.viewType.innerInset.right, self.containerView.frame.height))
        viewsContainer.center()
        
        let x: CGFloat = item.viewType.innerInset.left
        var y: CGFloat = 0
        
        for (i, view) in views.enumerated() {
            view.setFrameOrigin(NSMakePoint(x, y))
            holderViews[i].setFrameOrigin(NSMakePoint(x - holderViews[i].frame.width, y + floorToScreenPixels(backingScaleFactor, (view.frame.height - holderViews[i].frame.height) / 2)))
            y += view.frame.height
        }
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func updateColors() {
        guard let item = item as? WalletTestWordsItem else {
            return
        }
        for view in views {
            view.updateColors()
        }
        
        for (i, index) in item.indexes.enumerated() {
            let layout = TextViewLayout(.initialize(string: "\(index):", color: theme.colors.grayText, font: .normal(.text)))
            layout.measure(width: .greatestFiniteMagnitude)
            holderViews[i].update(layout)
        }
        self.backgroundColor = item.viewType.rowBackground
        self.containerView.backgroundColor = backdorColor
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? WalletTestWordsItem else {
            return
        }
        
        for (i, view) in views.enumerated() {
            view.setFrameSize(NSMakeSize(item.items[i].blockWidth, item.items[i].height))
            view.set(item: item.items[i], animated: animated)
        }
        
        needsLayout = true
    }
    
    override func shakeViewWithData(_ data: Any) {
        super.shakeViewWithData(data)
        if let data = data as? [InputDataIdentifier : InputDataValidationFailAction] {
            for (key, _) in data {
                let view = views.first(where: {
                    $0.item?.stableId.base as? InputDataIdentifier == key
                })
                view?.shakeView()
            }
        }
    }
    
    override var firstResponder: NSResponder? {
        for view in views {
            if view.textView.inputView == window?.firstResponder {
                return view.textView.inputView
            }
        }
        return views.first?.textView.inputView
    }
    
    override func hasFirstResponder() -> Bool {
        return true
    }
    
    override func nextResponder() -> NSResponder? {
        for (i, view) in views.enumerated() {
            if view.textView.inputView == window?.firstResponder {
                if view != views.last {
                    return views[i + 1].textView.inputView
                }
            }
        }
        return views.first?.textView.inputView
    }
}

