//
//  ChartStackSection.swift
//  Graph
//
//  Created by Mikhail Filimonov on 24.02.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import GraphCore

private enum Constants {
    static let chartViewHeightFraction: CGFloat = 0.55
}

public class ChartStackSection: View, ChartThemeContainer {
    var chartView: ChartView
    var rangeView: RangeChartView
    var visibilityView: ChartVisibilityView
    var sectionContainerView: View
    var separators: [View] = []
    
    var headerLabel: NSTextField!
    var titleLabel: NSTextField!
    var backButton: TitleButton!
    
    var controller: BaseChartController!
    
    override init() {
        sectionContainerView = View()
        chartView = ChartView(frame: NSZeroRect)
        rangeView = RangeChartView(frame: NSZeroRect)
        visibilityView = ChartVisibilityView()
        headerLabel = NSTextField()
        titleLabel = NSTextField()
        backButton = TitleButton()
        
        super.init(frame: CGRect())
        
        self.addSubview(sectionContainerView)
        sectionContainerView.addSubview(chartView)
        sectionContainerView.addSubview(visibilityView)
        sectionContainerView.addSubview(rangeView)

        headerLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .bold)
       // visibilityView.clipsToBounds = true
     //   backButton.isExclusiveTouch = true
        
        backButton.setVisible(false, animated: false)
        
        headerLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.drawsBackground = false
       // visibilityView.clipsToBounds = true
     //   backButton.isExclusiveTouch = true
        
        
        addSubview(titleLabel)
        addSubview(backButton)
        
        backButton.direction = .left
        _ = backButton.sizeToFit()
        backButton.set(handler: { [weak self] _ in
            self?.didTapBackButton()
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    public func apply(theme: ChartTheme, animated: Bool) {
        View.perform(animated: animated && self.isVisibleInWindow) {
            self.backgroundColor = theme.tableBackgroundColor
            
            self.sectionContainerView.backgroundColor = theme.chartBackgroundColor
            self.rangeView.backgroundColor = theme.chartBackgroundColor
            self.visibilityView.backgroundColor = theme.chartBackgroundColor
         //  self.backButton.tintColor = theme.actionButtonColor
            self.backButton.set(color: theme.actionButtonColor, for: .Normal)
            
            self.backButton.set(text: "Zoom Out", for: .Normal)
            _ = self.backButton.sizeToFit()
            
            for separator in self.separators {
                separator.backgroundColor = theme.tableSeparatorColor
            }
        }
        
        if rangeView.isVisibleInWindow || chartView.isVisibleInWindow {
            chartView.loadDetailsViewIfNeeded()
            chartView.apply(theme: theme, animated: animated && chartView.isVisibleInWindow)
            controller.apply(theme: theme, animated: animated)
            rangeView.apply(theme: theme, animated: animated && rangeView.isVisibleInWindow)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval.random(in: 0...0.1)) {
                self.chartView.loadDetailsViewIfNeeded()
                self.controller.apply(theme: theme, animated: false)
                self.chartView.apply(theme: theme, animated: false)
                self.rangeView.apply(theme: theme, animated: false)
            }
          
        }
        
        self.titleLabel.setTextColor(theme.chartTitleColor, animated: animated && titleLabel.isVisibleInWindow)
        self.headerLabel.setTextColor(theme.chartTitleColor, animated: animated && headerLabel.isVisibleInWindow)
        
        needsLayout = true
    }
    
     func didTapBackButton() {
        controller.didTapZoomOut()
    }
    
    func setBackButtonVisible(_ visible: Bool, animated: Bool) {
        
        backButton.setVisible(visible, animated: animated)
        layoutIfNeeded(animated: animated)
    }
    
    func updateToolViews(animated: Bool) {
        rangeView.setRange(controller.currentChartHorizontalRangeFraction, animated: animated)
        rangeView.setRangePaging(enabled: controller.isChartRangePagingEnabled,
                                 minimumSize: controller.minimumSelectedChartRange)
        visibilityView.setVisible(controller.drawChartVisibity, animated: animated)
        if controller.drawChartVisibity {
            visibilityView.items = controller.actualChartsCollection.chartValues.map { value in
                return ChartVisibilityItem(title: value.name, color: value.color)
            }
            visibilityView.setItemsSelection(controller.actualChartVisibility)
            visibilityView.needsLayout = true
            visibilityView.layoutIfNeeded(animated: animated)
        }
    }
    
    override public func layout() {
        super.layout()
        
        let bounds = self.bounds
        self.titleLabel.frame = CGRect(origin: CGPoint(x: 0.0, y: 10.0), size: CGSize(width: bounds.width, height: 30))
        self.backButton.frame = CGRect(origin: CGPoint(x: 0.0, y: 10.0), size: self.backButton.frame.size)
        
        self.sectionContainerView.frame = CGRect(origin: CGPoint(), size: CGSize(width: bounds.width, height: frame.height))
        self.chartView.frame = CGRect(origin: CGPoint(), size: CGSize(width: bounds.width, height: 250.0))
        self.rangeView.frame = CGRect(origin: CGPoint(x: 0.0, y: 250.0), size: CGSize(width: bounds.width, height: 48.0))
        let visibilityHeight = ChartVisibilityItem.generateItemsFrames(for: bounds.width, items: self.visibilityView.items).last?.maxY ?? 0
        self.visibilityView.frame = CGRect(origin: CGPoint(x: 0.0, y: 308.0), size: CGSize(width: bounds.width, height: visibilityHeight))
    }
    
    public func setup(controller: BaseChartController, title: String) {
        self.controller = controller
        self.headerLabel.setText(title, animated: false)
        
        // Chart
        chartView.renderers = controller.mainChartRenderers
        chartView.userDidSelectCoordinateClosure = { [unowned self] point in
            self.controller.chartInteractionDidBegin(point: point)
        }
        chartView.userDidDeselectCoordinateClosure = { [unowned self] in
            self.controller.chartInteractionDidEnd()
        }
        controller.cartViewBounds = { [unowned self] in
            return self.chartView.bounds
        }
        controller.chartFrame = { [unowned self] in
            return self.chartView.chartFrame
        }
        controller.setDetailsViewModel = { [unowned self] viewModel, animated in
            self.chartView.setDetailsViewModel(viewModel: viewModel, animated: animated)
        }
        controller.setDetailsChartVisibleClosure = { [unowned self] visible, animated in
            self.chartView.setDetailsChartVisible(visible, animated: animated)
        }
        controller.setDetailsViewPositionClosure = { [unowned self] position in
            self.chartView.detailsViewPosition = position
        }
        controller.setChartTitleClosure = { [unowned self] title, animated in
            self.titleLabel.setText(title, animated: animated)
        }
        controller.setBackButtonVisibilityClosure = { [unowned self] visible, animated in
            self.setBackButtonVisible(visible, animated: animated)
        }
        controller.refreshChartToolsClosure = { [unowned self] animated in
            self.updateToolViews(animated: animated)
        }
        
        // Range view
        rangeView.chartView.renderers = controller.navigationRenderers
        rangeView.rangeDidChangeClosure = { range in
            controller.updateChartRange(range)
        }
        rangeView.touchedOutsideClosure = {
            controller.cancelChartInteraction()
        }
        controller.chartRangeUpdatedClosure = { [unowned self] (range, animated) in
            self.rangeView.setRange(range, animated: animated)
        }
        controller.chartRangePagingClosure = {  [unowned self] (isEnabled, pageSize) in
            self.rangeView.setRangePaging(enabled: isEnabled, minimumSize: pageSize)
        }
        
        // Visibility view
        visibilityView.selectionCallbackClosure = { [unowned self] visibility in
            self.controller.updateChartsVisibility(visibility: visibility, animated: true)
        }
        
        controller.initializeChart()
        updateToolViews(animated: false)
        
    }
}
