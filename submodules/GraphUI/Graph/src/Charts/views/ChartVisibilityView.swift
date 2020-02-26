//
//  ChartVisibilityView.swift
//  Graph
//
//  Created by Mikhail Filimonov on 24.02.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import GraphCore

private enum Constants {
    static let itemHeight: CGFloat = 30
    static let itemSpacing: CGFloat = 8
    static let labelTextApproxInsets: CGFloat = 40
    static let insets = NSEdgeInsets(top: 0, left: 16, bottom: 16, right: 16)
}

struct ChartVisibilityItem {
    var title: String
    var color: NSColor
}

class ChartVisibilityView: View {
    var items: [ChartVisibilityItem] = [] {
        didSet {
            selectedItems = items.map { _ in true }
            while selectionViews.count > selectedItems.count {
                selectionViews.last?.removeFromSuperview()
                selectionViews.removeLast()
            }
            while selectionViews.count < selectedItems.count {
                let view = ChartVisibilityItemView(frame: bounds)
                addSubview(view)
                selectionViews.append(view)
            }
            
            for (index, item) in items.enumerated() {
                let view = selectionViews[index]
                view.item = item
                view.tapClosure = { [weak self] in
                    guard let self = self else { return }
                    self.setItemSelected(!self.selectedItems[index], at: index, animated: true)
                    self.notifyItemSelection()
                }
                
                view.longTapClosure = { [weak self] in
                    guard let self = self else { return }
                    let hasSelectedItem = self.selectedItems.enumerated().contains(where: { $0.element && $0.offset != index })
                    if hasSelectedItem {
                        for (itemIndex, _) in self.items.enumerated() {
                            self.setItemSelected(itemIndex == index, at: itemIndex, animated: true)
                        }
                    } else {
                        for (itemIndex, _) in self.items.enumerated() {
                            self.setItemSelected(true, at: itemIndex, animated: true)
                        }
                    }
                    self.notifyItemSelection()
                }
            }
        }
    }
    
    private (set) var selectedItems: [Bool] = []
    var isExpanded: Bool = true {
        didSet {
            invalidateIntrinsicContentSize()
           // setNeedsUpdateConstraints()
        }
    }
    
    private var selectionViews: [ChartVisibilityItemView] = []
    
    static func generateItemsFrames(for chartWidth: CGFloat, items: [ChartVisibilityItem]) -> [CGRect] {
        var previousPoint = CGPoint(x: Constants.insets.left, y: Constants.insets.top)
        var frames: [CGRect] = []
        
        for item in items {
            let labelSize = TitleButton.size(with: item.title, font: ChartVisibilityItemView.textFont)
            let width = (labelSize.width + Constants.labelTextApproxInsets).rounded(.up)
            if previousPoint.x + width < (chartWidth - Constants.insets.left - Constants.insets.right) {
                frames.append(CGRect(origin: previousPoint, size: CGSize(width: width, height: Constants.itemHeight)))
            } else if previousPoint.x <= Constants.insets.left {
                frames.append(CGRect(origin: previousPoint, size: CGSize(width: width, height: Constants.itemHeight)))
            } else {
                previousPoint.y += Constants.itemHeight + Constants.itemSpacing
                previousPoint.x = Constants.insets.left
                frames.append(CGRect(origin: previousPoint, size: CGSize(width: width, height: Constants.itemHeight)))
            }
            previousPoint.x += width + Constants.itemSpacing
        }
        
        return frames
    }
    
    var selectionCallbackClosure: (([Bool]) -> Void)?
    
    func setItemSelected(_ selected: Bool, at index: Int, animated: Bool) {
        self.selectedItems[index] = selected
        self.selectionViews[index].setChecked(isChecked: selected, animated: animated)
    }
    
    func setItemsSelection(_ selection: [Bool]) {
        assert(selection.count == items.count)
        self.selectedItems = selection
        for (index, selected) in self.selectedItems.enumerated() {
            selectionViews[index].setChecked(isChecked: selected, animated: false)
        }
    }
    
    override func removeFromSuperview() {
        super.removeFromSuperview()
    }
    
    private func notifyItemSelection() {
        selectionCallbackClosure?(selectedItems)
    }
    
    override func layout() {
        super.layout()
        
        updateFrames()
    }
    
    override var alphaValue: CGFloat {
        didSet {
            if self.alphaValue == 0 {
                var bp:Int = 0
                bp += 1
            }
        }
    }
    
    private func updateFrames() {
        for (index, frame) in ChartVisibilityView.generateItemsFrames(for: bounds.width, items: self.items).enumerated() {
            selectionViews[index].frame = frame
        }
    }
    
}

extension ChartVisibilityView: GColorModeContainer {
    func apply(colorMode: GColorMode, animated: Bool) {
        View.perform(animated: animated) {
            self.backgroundColor = colorMode.chartBackgroundColor
          //  self.tintColor = colorMode.descriptionActionColor
        }
    }
}
