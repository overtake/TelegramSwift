//
//  WalletImportWordsItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 22/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
private func _id_word(_ index:Int) -> InputDataIdentifier {
    return InputDataIdentifier("_id_word_\(index)")
}
class WalletImportWordsItem: GeneralRowItem {
    fileprivate let leftItems:[InputDataRowItem]
    fileprivate let rightItems:[InputDataRowItem]
    init(_ initialSize: NSSize, stableId: AnyHashable, words:[InputDataIdentifier: InputDataValue], viewType: GeneralViewType, update:@escaping(InputDataIdentifier, InputDataValue)->Void) {
        
        var left: [InputDataRowItem] = []
        var right: [InputDataRowItem] = []

        let insets = NSEdgeInsets(left: 5, right: 0, top: 12, bottom: 12)
        let arrayLeft:[Int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
        for index in arrayLeft {
            let item = InputDataRowItem(NSMakeSize(100, 40), stableId: _id_word(index), mode: .plain, error: nil, viewType: .modern(position: bestGeneralViewType(arrayLeft, for: index).position, insets: insets), currentText: words[_id_word(index)]?.stringValue ?? "", placeholder: nil, inputPlaceholder: "", defaultText: nil, rightItem: nil, insets: NSEdgeInsets(), filter: { $0 }, updated: { text in
                update(_id_word(index), .string(text))
            }, pasteFilter: nil, limit: 8)
            left.append(item)
        }
        let arrayRight:[Int] = [13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24]
        for index in arrayRight {
            let item = InputDataRowItem(NSMakeSize(100, 40), stableId: _id_word(index), mode: .plain, error: nil, viewType: .modern(position: bestGeneralViewType(arrayRight, for: index).position, insets: insets), currentText: words[_id_word(index)]?.stringValue ?? "", placeholder: nil, inputPlaceholder: "", defaultText: nil, rightItem: nil, insets: NSEdgeInsets(), filter: { $0 }, updated: { text in
                update(_id_word(index), .string(text))
            }, pasteFilter: nil, limit: 8)
            right.append(item)
        }
        self.leftItems = left
        self.rightItems = right
        
        super.init(initialSize, height: 40 * 12, stableId: stableId, type: .none, viewType: viewType)
    }
    
    override var blockWidth: CGFloat {
        return 280
    }
    
    override var instantlyResize: Bool {
        return false
    }
    
    
    override func viewClass() -> AnyClass {
        return WalletImportWordsView.self
    }
}

private final class WalletImportWordsView : TableRowView {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private let leftHolderViews:[TextView]
    private let rightHolderViews:[TextView]
    private let leftSeparatorViews:[View]
    private let rightSeparatorViews:[View]

    private let leftViews:[InputDataRowView]
    private let rightViews:[InputDataRowView]
    private let viewsContainer = View()
    required init(frame frameRect: NSRect) {
        var left:[InputDataRowView] = []
        var right:[InputDataRowView] = []
        var leftHolders: [TextView] = []
        var rightHolders: [TextView] = []
        
        var leftSeparatorViews:[View] = []
        var rightSeparatorViews:[View] = []

        for _ in 1 ... 12 {
            left.append(InputDataRowView(frame: NSZeroRect))
            leftHolders.append(TextView())
            leftSeparatorViews.append(View())
        }
        
        for _ in 13 ... 24 {
            right.append(InputDataRowView(frame: NSZeroRect))
            rightHolders.append(TextView())
            rightSeparatorViews.append(View())
        }
        
        
        
        self.leftHolderViews = leftHolders
        self.rightHolderViews = rightHolders
        self.leftSeparatorViews = leftSeparatorViews
        self.rightSeparatorViews = rightSeparatorViews
        self.leftViews = left
        self.rightViews = right
        super.init(frame: frameRect)
        
        for view in leftViews {
            viewsContainer.addSubview(view)
        }
        for view in rightViews {
            viewsContainer.addSubview(view)
        }
        
        for view in leftHolderViews {
            viewsContainer.addSubview(view)
        }
        for view in rightHolderViews {
            viewsContainer.addSubview(view)
        }
        
        for view in leftSeparatorViews {
            viewsContainer.addSubview(view)
        }
        for view in rightSeparatorViews {
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
        
        guard let item = item as? WalletImportWordsItem else {
            return
        }
        
        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
        self.containerView.setCorners(item.viewType.corners)
        
        viewsContainer.setFrameSize(NSMakeSize(item.viewType.innerInset.left + item.viewType.innerInset.right + 200 + 30 + 30 + 30, self.containerView.frame.height))
        viewsContainer.center()
        
        var x: CGFloat = item.viewType.innerInset.left + 32
        var y: CGFloat = 0
        
        for (i, view) in leftViews.enumerated() {
            view.setFrameOrigin(NSMakePoint(x, y))
            leftHolderViews[i].setFrameOrigin(NSMakePoint(x - leftHolderViews[i].frame.width, y + floorToScreenPixels(backingScaleFactor, (view.frame.height - leftHolderViews[i].frame.height) / 2)))
            y += view.frame.height
        }
        y = 0
        x = item.viewType.innerInset.left + 100 + 30 + 30 + 10
        
        for (i, view) in rightViews.enumerated() {
            view.setFrameOrigin(NSMakePoint(x, y))
            rightHolderViews[i].setFrameOrigin(NSMakePoint(x - rightHolderViews[i].frame.width, y + floorToScreenPixels(backingScaleFactor, (view.frame.height - rightHolderViews[i].frame.height) / 2)))
            y += view.frame.height
        }
        
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func updateColors() {
        guard let item = item as? WalletImportWordsItem else {
            return
        }
        
        for view in leftSeparatorViews {
            view.backgroundColor = theme.colors.border
        }
        for view in rightSeparatorViews {
            view.backgroundColor = theme.colors.border
        }
        
        for (i, view) in leftHolderViews.enumerated() {
            let layout = TextViewLayout(.initialize(string: "\(i + 1):", color: theme.colors.grayText, font: .normal(.text)))
            layout.measure(width: .greatestFiniteMagnitude)
            view.update(layout)
        }
        
        for (i, view) in rightHolderViews.enumerated() {
            let layout = TextViewLayout(.initialize(string: "\(i + 13):", color: theme.colors.grayText, font: .normal(.text)))
            layout.measure(width: .greatestFiniteMagnitude)
            view.update(layout)
        }
     //   self.viewsContainer.backgroundColor = .random
        self.backgroundColor = item.viewType.rowBackground
        self.containerView.backgroundColor = backdorColor
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? WalletImportWordsItem else {
            return
        }
        
        for (i, view) in leftViews.enumerated() {
            view.setFrameSize(NSMakeSize(item.leftItems[i].blockWidth, item.leftItems[i].height))
            view.set(item: item.leftItems[i], animated: animated)
        }
        
        for (i, view) in rightViews.enumerated() {
            view.setFrameSize(NSMakeSize(item.leftItems[i].blockWidth, item.rightItems[i].height))
            view.set(item: item.rightItems[i], animated: animated)
        }
        
        
        
        needsLayout = true
    }
    
    override func shakeViewWithData(_ data: Any) {
        super.shakeViewWithData(data)
        if let data = data as? [InputDataIdentifier : InputDataValidationFailAction] {
            for (key, _) in data {
                let leftView = leftViews.first(where: {
                    $0.item?.stableId.base as? InputDataIdentifier == key
                })
                let rightView = rightViews.first(where: {
                    $0.item?.stableId.base as? InputDataIdentifier == key
                })
                
                leftView?.shakeView()
                rightView?.shakeView()
            }
        }
    }
    
    override var firstResponder: NSResponder? {
        for left in leftViews {
            if left.textView.inputView == window?.firstResponder {
                return left.textView.inputView
            }
        }
        for right in rightViews {
            if right.textView.inputView == window?.firstResponder {
                return right.textView.inputView
            }
        }
        return leftViews.first?.textView.inputView
    }
    
    override func hasFirstResponder() -> Bool {
        return true
    }
    
    override func nextResponder() -> NSResponder? {
        
        for (i, view) in leftViews.enumerated() {
            if view.textView.inputView == window?.firstResponder {
                if view != leftViews.last {
                    return leftViews[i + 1].textView.inputView
                }
            }
        }
        if leftViews.last?.textView.inputView == window?.firstResponder {
            return rightViews.first?.textView.inputView
        }
        
        for (i, view) in rightViews.enumerated() {
            if view.textView.inputView == window?.firstResponder  {
                if view != rightViews.last {
                    return rightViews[i + 1].textView.inputView
                }
            }
            
        }

        return leftViews.first?.textView.inputView
    }
}
