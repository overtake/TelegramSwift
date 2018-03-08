//
//  SectionViewController.swift
//  TGUIKit
//
//  Created by keepcoder on 03/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac

private final class SectionControllerArguments {
    let select:(Int)->Void
    init(select:@escaping(Int)->Void) {
        self.select = select
    }
}

public class SectionControllerView : View {
    private var header: View = View()
    private let selector:View = View()
    private let container: View = View()
    private weak var current: ViewController?
    
    fileprivate var selectorIndex:Int = 0 {
        didSet {
            if selectorIndex != oldValue {
                var index:Int = 0
                for hContainer in header.subviews {
                    for t in hContainer.subviews {
                        if let t = t as? TextView {
                            t.update(TextViewLayout(.initialize(string: t.layout?.attributedString.string, color: selectorIndex == index ? presentation.colors.blueUI : presentation.colors.grayText, font: .medium(.title)), maximumNumberOfLines: 1, truncationType: .middle))
                        }
                        
                    }
                    index += 1
                }
            }
        }
    }
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(header)
        addSubview(container)
        addSubview(selector)
        updateLocalizationAndTheme()
        needsLayout = true
    }
    
    fileprivate func layout(sections: [SectionControllerItem], selected: Int, arguments: SectionControllerArguments) {
        header.removeAllSubviews()
        self.selectorIndex = selected
        for i in 0 ..< sections.count {
            let section = sections[i]
            let headerContainer = Control(frame: NSMakeRect(0, 0, 0, 50))
            let title: TextView = TextView()
            title.isSelectable = false
            title.userInteractionEnabled = false
            title.backgroundColor = presentation.colors.background
            title.update(TextViewLayout(.initialize(string: section.title(), color: i == selected ? presentation.colors.blueUI : presentation.colors.grayText, font: .medium(.title)), maximumNumberOfLines: 1, truncationType: .middle))
            headerContainer.addSubview(title)
            header.addSubview(headerContainer)
            headerContainer.border = [.Bottom]
            headerContainer.set(handler: { _ in
                 arguments.select(i)
            }, for: .Click)
        }
        needsLayout = true
    }
    
    fileprivate func select(controller: ViewController, index: Int, animated: Bool) {
        let previousIndex = self.selectorIndex
        let previous = self.current
        self.current = controller
        selectorIndex = index
        
        controller.view.frame = container.bounds
        previous?.viewWillDisappear(animated)
        
        container.addSubview(controller.view)
        
        if animated {
            CATransaction.begin()
            let container = header.subviews[index]
            selector.change(pos: NSMakePoint(container.frame.minX, selector.frame.minY), animated: animated, timingFunction: kCAMediaTimingFunctionSpring)
            
            
            let pto: NSPoint
            let nfrom: NSPoint
            
          
            if previousIndex < index {
                pto = NSMakePoint(-container.frame.width, 0)
                nfrom = NSMakePoint(container.frame.width, 0)
            } else {
                pto = NSMakePoint(container.frame.width, 0)
                nfrom = NSMakePoint(-container.frame.width, 0)
            }
            
            previous?.view._change(pos: pto, animated: animated, timingFunction: kCAMediaTimingFunctionSpring, completion: { [weak previous, weak controller] complete in
                if complete {
                    previous?.view.removeFromSuperview()
                    previous?.viewDidDisappear(animated)
                    controller?.viewDidAppear(animated)
                }
            })
            controller.view.layer?.animatePosition(from: nfrom, to: NSZeroPoint, timingFunction: kCAMediaTimingFunctionSpring)
            CATransaction.commit()
        } else {
            container.removeAllSubviews()
            previous?.viewDidDisappear(animated)
            container.addSubview(controller.view)
            controller.viewDidAppear(animated)
        }
        needsLayout = true
    }
    
    public override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        self.backgroundColor = presentation.colors.background
        selector.backgroundColor = presentation.colors.blueUI
        container.backgroundColor = presentation.colors.background
        var index:Int = 0
        for hContainer in header.subviews {
            hContainer.background = presentation.colors.background
            for t in hContainer.subviews {
                if let t = t as? TextView {
                    let layout = TextViewLayout(.initialize(string: t.layout?.attributedString.string, color: selectorIndex == index ? presentation.colors.blueUI : presentation.colors.grayText, font: .medium(.title)), maximumNumberOfLines: 1, truncationType: .middle)
                    layout.measure(width: hContainer.frame.width - 20)
                    t.update(layout)
                    t.center()
                }
                
                t.background = presentation.colors.background
            }
            index += 1
        }
    }
    
    public override func layout() {
        super.layout()
        header.setFrameSize(NSMakeSize(frame.width, 50))
        let width = floorToScreenPixels(scaleFactor: backingScaleFactor, frame.width / CGFloat(max(header.subviews.count, 3)))
        
        selector.frame = NSMakeRect(CGFloat(selectorIndex) * width, 50 - .borderSize, width, .borderSize)
        container.frame = NSMakeRect(0, header.frame.maxY, frame.width, frame.height - header.frame.height)
        container.subviews.first?.frame = container.bounds

        var x:CGFloat = 0
        for i in 0 ..< header.subviews.count {
            let hContainer = header.subviews[i]
            let width = i == header.subviews.count - 1 ? frame.width - x : width
            hContainer.frame = NSMakeRect(x, 0, width, hContainer.frame.height)
            if let textView = hContainer.subviews.first as? TextView {
                textView.layout?.measure(width: width - 10)
                textView.update(textView.layout)
                textView.center()
            }
            x += width
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public class SectionControllerItem {
    let title: ()->String
    let controller: ViewController
    public init(title: @escaping()->String, controller: ViewController) {
        self.title = title
        self.controller = controller
    }
}


public class SectionViewController: GenericViewController<SectionControllerView> {

    private var sections:[SectionControllerItem] = []
    public var selectedSection:SectionControllerItem
    public private(set) var selectedIndex: Int = -1
    private let disposable = MetaDisposable()
    
    public var selectionUpdateHandler:((Int)->Void)?
    
    public func addSection(_ section: SectionControllerItem) {
        sections.append(section)
    }
    
    public override func updateLocalizationAndTheme() {
        let arguments = SectionControllerArguments { [weak self] index in
            self?.select(index, true)
        }
        genericView.layout(sections: sections, selected: selectedIndex, arguments: arguments)
        genericView.updateLocalizationAndTheme()
    }
    
    deinit {
        disposable.dispose()
    }
    
    fileprivate func select(_ index:Int, _ animated: Bool) {
        if selectedIndex != index || !animated {
            selectedSection = sections[index]
            sections[index].controller._frameRect = NSMakeRect(0, 0, frame.width, frame.height - 50)
            sections[index].controller.loadViewIfNeeded()
            let controller = sections[index].controller
            selectedIndex = index
            selectionUpdateHandler?(index)
            sections[index].controller.viewWillAppear(animated)
            disposable.set((sections[index].controller.ready.get() |> filter {$0} |> take(1)).start(next: { [weak self, weak controller] ready in
                if let strongSelf = self, let controller = controller {
                    strongSelf.genericView.select(controller: controller, index: index, animated: animated)
                }
            }))
        }
    }
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        selectedSection.controller._frameRect = NSMakeRect(0, 0, frame.width, frame.height - 50)
        selectedSection.controller.viewWillAppear(animated)
        self.ready.set(sections[selectedIndex].controller.ready.get())
    }
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        selectedSection.controller.viewWillDisappear(animated)
        window?.remove(object: self, for: .Tab)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        selectedSection.controller.viewDidAppear(animated)
        
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            
            if !self.sections.isEmpty {
                var index:Int = self.selectedIndex
                if index == self.sections.count - 1 {
                    index = 0
                } else {
                    index += 1
                }
                self.select(index, true)
            }
            
            return .invoked
        }, with: self, for: .Tab)
    }
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        selectedSection.controller.viewDidDisappear(animated)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        let arguments = SectionControllerArguments { [weak self] index in
            self?.select(index, true)
        }
        genericView.layout(sections: sections, selected: selectedIndex, arguments: arguments)
        select(selectedIndex, false)
    }
    
    public init(sections: [SectionControllerItem], selected: Int = 0) {
        assert(!sections.isEmpty)
        self.sections = sections
        self.selectedSection = sections[selected]
        self.selectedIndex = selected
        super.init()
        bar = .init(height: 0)
    }
    
}
