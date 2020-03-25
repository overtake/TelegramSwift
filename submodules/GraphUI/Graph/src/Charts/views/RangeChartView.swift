//
//  RangeChartView.swift
//  Graph
//
//  Created by Mikhail Filimonov on 24.02.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import GraphCore
private enum Constants {
    static let cropIndocatorLineWidth: CGFloat = 1
    static let markerSelectionRange: CGFloat = 25
    static let defaultMinimumRangeDistance: CGFloat = 0.05
    static let titntAreaWidth: CGFloat = 10
    static let horizontalContentMargin: CGFloat = 16
    static let cornerRadius: CGFloat = 5
}

class RangeChartView: Control {
    private enum Marker {
        case lower
        case upper
        case center
    }
    public var lowerBound: CGFloat = 0 {
        didSet {
            needsLayout = true
        }
    }
    public var upperBound: CGFloat = 1 {
        didSet {
            needsLayout = true
        }
    }
    public var selectionColor: NSColor = .blue
    public var defaultColor: NSColor = .lightGray
    
    public var minimumRangeDistance: CGFloat = Constants.defaultMinimumRangeDistance
    
    private let lowerBoundTintView = View()
    private let upperBoundTintView = View()
    private let cropFrameView = TransparentImageView()
    
    private var selectedMarker: Marker?
    private var selectedMarkerHorizontalOffet: CGFloat = 0
    private var isBoundCropHighlighted: Bool = false
    private var isRangePagingEnabled: Bool = false
    
    public let chartView = ChartView(frame: NSZeroRect)
    
    var layoutMargins: NSEdgeInsets
    
    required init(frame: CGRect) {
        layoutMargins = NSEdgeInsets(top: Constants.cropIndocatorLineWidth,
                                     left: Constants.horizontalContentMargin,
                                     bottom: Constants.cropIndocatorLineWidth,
                                     right: Constants.horizontalContentMargin)
        super.init(frame: frame)
        
        self.setup()
    }
    
    func setup() {
//        isMultipleTouchEnabled = false
        
        chartView.chartInsets = .init()
        chartView.backgroundColor = .clear
        cropFrameView.wantsLayer = true
        addSubview(chartView)
        lowerBoundTintView.isEventLess = true
        upperBoundTintView.isEventLess = true
        addSubview(lowerBoundTintView)
        addSubview(upperBoundTintView)
        addSubview(cropFrameView)
        
        cropFrameView.isEnabled = false
        
        cropFrameView.imageScaling = .scaleAxesIndependently
        
        cropFrameView.layer?.contentsGravity = .resize
        
        //cropFrameView.isUserInteractionEnabled = false
        chartView.userInteractionEnabled = false
        chartView.isEventLess = true
        lowerBoundTintView.userInteractionEnabled = false
        upperBoundTintView.userInteractionEnabled = false
        
        chartView.layer?.cornerRadius = 5
        upperBoundTintView.layer?.cornerRadius = 5
        lowerBoundTintView.layer?.cornerRadius = 5
        
        chartView.layer?.masksToBounds = true
        upperBoundTintView.layer?.masksToBounds = true
        lowerBoundTintView.layer?.masksToBounds = true
        
        layoutViews()
    }
    
    
    public var rangeDidChangeClosure: ((ClosedRange<CGFloat>) -> Void)?
    public var touchedOutsideClosure: (() -> Void)?
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("not supported")
    }
    
    func setRangePaging(enabled: Bool, minimumSize: CGFloat) {
        isRangePagingEnabled = enabled
        minimumRangeDistance = minimumSize
    }
    
    func setRange(_ range: ClosedRange<CGFloat>, animated: Bool) {
        View.perform(animated: animated) {
            self.lowerBound = range.lowerBound
            self.upperBound = range.upperBound
            self.needsLayout = true
        }
    }
    
    override func layout() {
        super.layout()
        
        layoutViews()
    }
    
    override var isEnabled: Bool {
        get {
            return super.isEnabled
        }
        set {
            if newValue == false {
                selectedMarker = nil
            }
            super.isEnabled = newValue
        }
    }
    
    // MARK: - Touches
    
    override func mouseDown(with event: NSEvent) {
        
        super.mouseDown(with: event)
        
        guard isEnabled else { return }
        
        let point = self.convert(event.locationInWindow, from: nil)

        if abs(locationInView(for: upperBound) - point.x + Constants.markerSelectionRange / 2) < Constants.markerSelectionRange {
            selectedMarker = .upper
            selectedMarkerHorizontalOffet = point.x - locationInView(for: upperBound)
            isBoundCropHighlighted = true
        } else if abs(locationInView(for: lowerBound) - point.x - Constants.markerSelectionRange / 2) < Constants.markerSelectionRange {
            selectedMarker = .lower
            selectedMarkerHorizontalOffet = point.x - locationInView(for: lowerBound)
            isBoundCropHighlighted = true
        } else if point.x > locationInView(for: lowerBound) && point.x < locationInView(for: upperBound) {
            selectedMarker = .center
            selectedMarkerHorizontalOffet = point.x - locationInView(for: lowerBound)
            isBoundCropHighlighted = true
        } else {
            selectedMarker = nil
            return
        }

       // sendActions(for: .touchDown)
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        
        guard let selectedMarker = selectedMarker else { return }
        let point = self.convert(event.locationInWindow, from: nil)

        let horizontalPosition = point.x - selectedMarkerHorizontalOffet
        let fraction = fractionFor(offsetX: horizontalPosition)
        updateMarkerOffset(selectedMarker, fraction: fraction)

    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        guard isEnabled else { return }
        
        guard let selectedMarker = selectedMarker else {
            touchedOutsideClosure?()
            return
        }
        let point = self.convert(event.locationInWindow, from: nil)

        let horizontalPosition = point.x - selectedMarkerHorizontalOffet
        let fraction = fractionFor(offsetX: horizontalPosition)
        updateMarkerOffset(selectedMarker, fraction: fraction)
        
        self.selectedMarker = nil
        self.isBoundCropHighlighted = false

        rangeDidChangeClosure?(lowerBound...upperBound)

    }
}

private extension RangeChartView {
    var contentFrame: CGRect {
        return CGRect(x: layoutMargins.right,
                      y: layoutMargins.top,
                      width: (bounds.width - layoutMargins.right - layoutMargins.left),
                      height: bounds.height - layoutMargins.top - layoutMargins.bottom)
    }
    
    func locationInView(for fraction: CGFloat) -> CGFloat {
        return contentFrame.minX + contentFrame.width * fraction
    }
    
    func locationInView(for fraction: Double) -> CGFloat {
        return locationInView(for: CGFloat(fraction))
    }
    
    func fractionFor(offsetX: CGFloat) -> CGFloat {
        guard contentFrame.width > 0 else {
            return 0
        }
        
        return crop(0, CGFloat((offsetX - contentFrame.minX ) / contentFrame.width), 1)
    }
    
    private func updateMarkerOffset(_ marker: Marker, fraction: CGFloat, notifyDelegate: Bool = true) {
        let fractionToCount: CGFloat
        if isRangePagingEnabled {
            guard let minValue = stride(from: CGFloat(0.0), through: CGFloat(1.0), by: minimumRangeDistance).min(by: { abs($0 - fraction) < abs($1 - fraction) }) else { return }
            fractionToCount = minValue
        } else {
            fractionToCount = fraction
        }
        
        switch marker {
        case .lower:
            lowerBound = min(fractionToCount, upperBound - minimumRangeDistance)
        case .upper:
            upperBound = max(fractionToCount, lowerBound + minimumRangeDistance)
        case .center:
            let distance = upperBound - lowerBound
            lowerBound = max(0, min(fractionToCount, 1 - distance))
            upperBound = lowerBound + distance
        }
        if notifyDelegate {
            rangeDidChangeClosure?(lowerBound...upperBound)
        }
        self.layoutIfNeeded(animated: true)
    }
    
    // MARK: - Layout
    
    func layoutViews() {
        cropFrameView.frame = CGRect(x: locationInView(for: lowerBound),
                                     y: contentFrame.minY - Constants.cropIndocatorLineWidth,
                                     width: locationInView(for: upperBound) - locationInView(for: lowerBound),
                                     height: contentFrame.height + Constants.cropIndocatorLineWidth * 2)
        
        if chartView.frame != contentFrame {
            chartView.frame = contentFrame
        }
        
        lowerBoundTintView.frame = CGRect(x: contentFrame.minX,
                                          y: contentFrame.minY,
                                          width: max(0, locationInView(for: lowerBound) - contentFrame.minX + Constants.titntAreaWidth),
                                          height: contentFrame.height)
        
        upperBoundTintView.frame = CGRect(x: locationInView(for: upperBound) - Constants.titntAreaWidth,
                                          y: contentFrame.minY,
                                          width: max(0, contentFrame.maxX - locationInView(for: upperBound) + Constants.titntAreaWidth),
                                          height: contentFrame.height)
    }
}

extension RangeChartView: ChartThemeContainer {
    func apply(theme: ChartTheme, animated: Bool) {
        let closure = {
            self.lowerBoundTintView.backgroundColor = theme.rangeViewTintColor
            self.upperBoundTintView.backgroundColor = theme.rangeViewTintColor
        }
        
        let rangeCropImage = theme.rangeCropImage
        rangeCropImage?.resizingMode = .stretch
        rangeCropImage?.capInsets = NSEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
        
        self.cropFrameView.setImage(rangeCropImage, animated: animated)

        //        self.chartView.apply(theme: theme, animated: animated)
        
        if animated {
            View.perform(animated: true, animations: closure)
        } else {
            closure()
        }
    }
}
