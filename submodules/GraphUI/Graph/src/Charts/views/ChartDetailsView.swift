//
//  ChartDetailsView.swift
//  GraphTest
//
//  Created by Andrew Solovey on 14/03/2019.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Cocoa
import TGUIKit
import GraphCore

private let cornerRadius: CGFloat = 5
private let verticalMargins: CGFloat = 8
private var labelHeight: CGFloat = 18
private var margin: CGFloat = 10
private var prefixLabelWidth: CGFloat = 35
private var valueLabelWidth: CGFloat = 65


class ChartDetailsView: Control {
   
    
    override var alphaValue: CGFloat {
        didSet {
            self.isHidden = self.alphaValue == 0
        }
    }
    
    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
    }
    
    let titleLabel = TransparentTextField()
    let arrowView = TransparentImageView()
    
    var prefixViews: [TransparentTextField] = []
    var labelsViews: [TransparentTextField] = []
    var valuesViews: [TransparentTextField] = []
    
    private var viewModel: ChartDetailsViewModel?
    private var theme: ChartTheme = .defaultDayTheme
    
  
    required init(frame: CGRect) {
        super.init(frame: frame)
        
        layer?.cornerRadius = cornerRadius
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.allowsDefaultTighteningForTruncation = true
        titleLabel.drawsBackground = false
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        arrowView.image = NSImage.arrowRight
        arrowView.imageScaling = .scaleAxesIndependently
        addSubview(titleLabel)
        addSubview(arrowView)
        
        set(handler: { [weak self] _ in
            self?.viewModel?.tapAction?()
        }, for: .Click)
        
    }
    

    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup(viewModel: ChartDetailsViewModel, animated: Bool) {
        self.viewModel = viewModel
        
        titleLabel.setText(viewModel.title, animated: animated)
        titleLabel.setVisible(!viewModel.title.isEmpty, animated: animated)
        arrowView.setVisible(viewModel.showArrow, animated: animated)
        
        let textLabelWidth = max(TitleButton.size(with: viewModel.title, font: NSFont.systemFont(ofSize: 12, weight: .bold)).width, 60)

        let viewWidth = intrinsicContentSize.width
        
        let width: CGFloat = margin * 2 + (viewModel.showPrefixes ? (prefixLabelWidth + margin) : 0) + textLabelWidth + valueLabelWidth
        var y: CGFloat = verticalMargins

        if (!viewModel.title.isEmpty || viewModel.showArrow) {
            titleLabel.frame = CGRect(x: margin, y: y, width: width, height: labelHeight)
            arrowView.frame = CGRect(x: viewWidth - 6 - margin, y: margin, width: 6, height: 10)
            y += labelHeight
        }
        let labelsCount: Int = viewModel.values.count + ((viewModel.totalValue == nil) ? 0 : 1)

        setLabelsCount(array: &prefixViews,
                       count: viewModel.showPrefixes ? labelsCount : 0,
                       font: NSFont.systemFont(ofSize: 12, weight: .bold))
        setLabelsCount(array: &labelsViews,
                       count: labelsCount,
                       font: NSFont.systemFont(ofSize: 12, weight: .regular),
                       textAlignment: .left)
        setLabelsCount(array: &valuesViews,
                       count: labelsCount,
                       font: NSFont.systemFont(ofSize: 12, weight: .bold))
        
        View.perform(animated: animated, animations: {
            for (index, value) in viewModel.values.enumerated() {
                var x: CGFloat = margin
                if viewModel.showPrefixes {
                    let prefixLabel = self.prefixViews[index]
                    prefixLabel.textColor = self.theme.chartDetailsTextColor
                    prefixLabel.setText(value.prefix, animated: false)
                    prefixLabel.frame = CGRect(x: x, y: y, width: prefixLabelWidth, height: labelHeight)
                    x += prefixLabelWidth + margin
                    prefixLabel.alphaValue = value.visible ? 1 : 0
                }
                let titleLabel = self.labelsViews[index]
                
                let textLabelWidth = max(TitleButton.size(with: value.title, font: NSFont.systemFont(ofSize: 12, weight: .regular)).width, 60)

                titleLabel.setTextColor(self.theme.chartDetailsTextColor, animated: false)
                titleLabel.setText(value.title, animated: false)
                titleLabel.frame = CGRect(x: x, y: y, width: textLabelWidth, height: labelHeight)
                titleLabel.alphaValue = value.visible ? 1 : 0
                x += textLabelWidth
                
                let valueLabel = self.valuesViews[index]
                valueLabel.setTextColor(value.color, animated: false)
                valueLabel.setText(value.value, animated: false)
                valueLabel.frame = CGRect(x: viewWidth - valueLabelWidth - margin, y: y, width: valueLabelWidth, height: labelHeight)
                valueLabel.alphaValue = value.visible ? 1 : 0
                
                if value.visible {
                    y += labelHeight
                }
            }
            if let value = viewModel.totalValue {
                var x: CGFloat = margin
                if viewModel.showPrefixes {
                    let prefixLabel = self.prefixViews[viewModel.values.count]
                    prefixLabel.textColor = self.theme.chartDetailsTextColor
                    prefixLabel.setText(value.prefix, animated: false)
                    prefixLabel.frame = CGRect(x: x, y: y, width: prefixLabelWidth, height: labelHeight)
                    prefixLabel.alphaValue = value.visible ? 1 : 0
                    x += prefixLabelWidth + margin
                }
                let titleLabel = self.labelsViews[viewModel.values.count]
                titleLabel.setTextColor(self.theme.chartDetailsTextColor, animated: false)
                titleLabel.setText(value.title, animated: false)
                
                let textLabelWidth = max(TitleButton.size(with: viewModel.title, font: NSFont.systemFont(ofSize: 12, weight: .regular)).width, 60)
                
                titleLabel.frame = CGRect(x: x, y: y, width: textLabelWidth, height: labelHeight)
                titleLabel.alphaValue = value.visible ? 1 : 0
                
                let valueLabel = self.valuesViews[viewModel.values.count]
                valueLabel.setTextColor(self.theme.chartDetailsTextColor, animated: false)
                valueLabel.setText(value.value, animated: false)
                valueLabel.frame = CGRect(x: self.bounds.width - valueLabelWidth - margin, y: y, width: valueLabelWidth, height: labelHeight)
                valueLabel.alphaValue = value.visible ? 1 : 0
            }
        })
    }
    
    override var intrinsicContentSize: CGSize {
        if let viewModel = viewModel {
            let height = ((!viewModel.title.isEmpty || viewModel.showArrow) ? labelHeight : 0) +
                (CGFloat(viewModel.values.filter({ $0.visible }).count) * labelHeight) +
                (viewModel.totalValue?.visible == true ? labelHeight : 0) +
                verticalMargins * 2
            
            var textLabelWidth = max(TitleButton.size(with: viewModel.title, font: NSFont.systemFont(ofSize: 12, weight: .bold)).width, 60)

            let maxValue = viewModel.values.map { value -> CGFloat in
                return TitleButton.size(with: value.title, font: NSFont.systemFont(ofSize: 12, weight: .regular)).width
            }.max() ?? 0
            
            textLabelWidth = max(maxValue, textLabelWidth)
            
            let width: CGFloat = margin * 2 +
                (viewModel.showPrefixes ? (prefixLabelWidth + margin) : 0) +
                textLabelWidth +
                valueLabelWidth
            
            return CGSize(width: width,
                          height: height)
        } else {
            return CGSize(width: 140,
                          height: labelHeight + verticalMargins)
        }
    }
    
    func setLabelsCount(array: inout [TransparentTextField],
                        count: Int,
                        font: NSFont,
                        textAlignment: NSTextAlignment = .right) {
        while array.count > count {
            let subview = array.removeLast()
            subview.removeFromSuperview()
        }
        while array.count < count {
            let label = TransparentTextField()
            label.isEditable = false
            label.isBordered = false
            label.drawsBackground = false
           // label.allowsDefaultTighteningForTruncation = true
            label.drawsBackground = false
            label.lineBreakMode = .byTruncatingTail

            label.font = font
          //  label.adjustsFontSizeToFitWidth = true
          //  label.minimumScaleFactor = 0.5
            label.alignment = textAlignment
            addSubview(label)
            array.append(label)
        }
    }
}

extension ChartDetailsView: ChartThemeContainer {
    func apply(theme: ChartTheme, animated: Bool) {
        self.theme = theme
        self.titleLabel.setTextColor(theme.chartDetailsTextColor, animated: animated)
        if let viewModel = self.viewModel {
            self.setup(viewModel: viewModel, animated: animated)
        }
        View.perform(animated: animated) {
            if #available(OSX 10.14, *) {
                self.arrowView.contentTintColor = theme.chartDetailsArrowColor
            } else {
                // Fallback on earlier versions
            }
            self.backgroundColor = theme.chartDetailsViewColor
        }
    }
}

// MARK: UIStackView+removeAllArrangedSubviews
public extension NSStackView {
    func setLabelsCount(_ count: Int,
                        font: NSFont,
                        huggingPriority: NSLayoutConstraint.Priority,
                        textAlignment: NSTextAlignment = .right) {
        while arrangedSubviews.count > count {
            let subview = arrangedSubviews.last!
            removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        while arrangedSubviews.count < count {
            let label = TransparentTextField()
            label.isEditable = false
            label.isBordered = false
            label.drawsBackground = false
            //label.allowsDefaultTighteningForTruncation = true
            label.drawsBackground = false
            label.lineBreakMode = .byTruncatingTail
            label.font = font
            label.alignment = textAlignment
            label.setContentHuggingPriority(huggingPriority, for: .horizontal)
            label.setContentHuggingPriority(huggingPriority, for: .vertical)
            label.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(rawValue: 999), for: .horizontal)
            label.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(rawValue: 999), for: .vertical)
            addArrangedSubview(label)
        }
    }
    
    func label(at index: Int) -> NSTextField {
        return arrangedSubviews[index] as! TransparentTextField
    }
    
    func removeAllArrangedSubviews() {
        for subview in arrangedSubviews {
            removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
    }
}

// MARK: UIStackView+addArrangedSubviews
public extension NSStackView {
    func addArrangedSubviews(_ views: [View]) {
        views.forEach({ addArrangedSubview($0) })
    }
}

// MARK: UIStackView+insertArrangedSubviews
public extension NSStackView {
    func insertArrangedSubviews(_ views: [View], at index: Int) {
        views.reversed().forEach({ insertArrangedSubview($0, at: index) })
    }
}
