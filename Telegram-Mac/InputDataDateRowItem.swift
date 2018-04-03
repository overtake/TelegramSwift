//
//  InputDataDateRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class InputDataDateRowItem: GeneralRowItem, InputDataRowDataValue {
    fileprivate let placeholderLayout: TextViewLayout
    fileprivate let dayHolderLayout: TextViewLayout
    fileprivate let monthHolderLayout: TextViewLayout
    fileprivate let yearHolderLayout: TextViewLayout

    private let updated:()->Void
    fileprivate var _value: InputDataValue {
        didSet {
            if _value != oldValue {
                updated()
            }
        }
    }
    
    var value: InputDataValue {
        return _value
    }
    
    init(_ initialSize: NSSize, stableId: AnyHashable, value: InputDataValue, updated:@escaping()->Void, placeholder: String) {
        self._value = value
        self.updated = updated
        placeholderLayout = TextViewLayout(.initialize(string: placeholder, color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1)
        
        dayHolderLayout = TextViewLayout(.initialize(string: L10n.inputDataDateDayPlaceholder, color: theme.colors.text, font: .normal(.text)))
        monthHolderLayout = TextViewLayout(.initialize(string: L10n.inputDataDateMonthPlaceholder, color: theme.colors.text, font: .normal(.text)))
        yearHolderLayout = TextViewLayout(.initialize(string: L10n.inputDataDateYearPlaceholder, color: theme.colors.text, font: .normal(.text)))

        dayHolderLayout.measure(width: .greatestFiniteMagnitude)
        monthHolderLayout.measure(width: .greatestFiniteMagnitude)
        yearHolderLayout.measure(width: .greatestFiniteMagnitude)
        
        super.init(initialSize, height: 86, stableId: stableId)
        _ = makeSize(initialSize.width, oldWidth: oldWidth)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        placeholderLayout.measure(width: 100)
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override func viewClass() -> AnyClass {
        return InputDataDateRowView.self
    }
    
}


final class InputDataDateRowView : TableRowView {
    private let placeholderTextView = TextView()
    private let dayPlaceholder: TextView = TextView()
    private let monthPlaceholder: TextView = TextView()
    private let yearPlaceholder: TextView = TextView()
    
    private let daySelector = TitleButton()
    private let monthSelector = TitleButton()
    private let yearSelector = TitleButton()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(placeholderTextView)
        
        dayPlaceholder.userInteractionEnabled = false
        dayPlaceholder.isSelectable = false
        monthPlaceholder.userInteractionEnabled = false
        monthPlaceholder.isSelectable = false
        yearPlaceholder.userInteractionEnabled = false
        yearPlaceholder.isSelectable = false
        placeholderTextView.userInteractionEnabled = false
        placeholderTextView.isSelectable = false
        
        addSubview(dayPlaceholder)
        addSubview(monthPlaceholder)
        addSubview(yearPlaceholder)
        
        addSubview(daySelector)
        addSubview(monthSelector)
        addSubview(yearSelector)
        
        daySelector.set(font: .normal(.text), for: .Normal)
        monthSelector.set(font: .normal(.text), for: .Normal)
        yearSelector.set(font: .normal(.text), for: .Normal)
        
        monthSelector.set(handler: { [weak self] control in
            
            guard let item = self?.item as? InputDataDateRowItem else {return}

            
            var items: [SPopoverItem] = []
            var date = Date(timeIntervalSince1970: 0)
            for i in 0 ..< 12 {
                let month = Int32(i) + 1
                let formatter:DateFormatter = DateFormatter()
                formatter.locale = Locale(identifier: appAppearance.language.languageCode)
                formatter.dateFormat = "MMMM"
                let monthString:String = formatter.string(from: date)
                date = CalendarUtils.stepMonth(1, date: date)
                items.append(SPopoverItem(monthString, {
                    switch item.value {
                    case let .date(day, _, year):
                        formatter.dateFormat = "dd.MM.yyyy"
                        let _year = year ?? 1970
                        let date = formatter.date(from: "02.\(month < 10 ? "0\(month)" : "\(month)").\(_year)")
                        if let date = date {
                            item._value = .date(day != nil ? min(Int32(CalendarUtils.lastDay(ofTheMonth: date)), day!) : nil, month, year)
                            item.redraw()
                        }
                        
                    default:
                        break
                    }
                }))
            }
            
            showPopover(for: control, with: SPopoverViewController(items: items, visibility: 5), edge: .maxY, inset: NSMakePoint(-(control.frame.width/2), -30))
            
        }, for: .Click)
        
        
        yearSelector.set(handler: { [weak self] control in
            
            guard let item = self?.item as? InputDataDateRowItem else {return}
            
            
            var items: [SPopoverItem] = []
            
            let formatter:DateFormatter = DateFormatter()
            formatter.locale = Locale(identifier: appAppearance.language.languageCode)
            formatter.dateFormat = "yyyy"
            let year:Int32 = Int32(formatter.string(from: Date()))!
            
            for year in stride(from: year, to: year - 101, by: -1) {
                
                items.append(SPopoverItem("\(year)", {
                    switch item.value {
                    case let .date(day, month, _):
                        formatter.dateFormat = "dd.MM.yyyy"
                        let _month = month ?? 1
                        let date = formatter.date(from: "02.\(_month < 10 ? "0\(_month)" : "\(_month)").\(year)")
                        if let date = date {
                            item._value = .date(day != nil ? min(Int32(CalendarUtils.lastDay(ofTheMonth: date)), day!) : nil, month, year)
                            item.redraw()
                        }
                        
                    default:
                        break
                    }
                }))
            }
            
            showPopover(for: control, with: SPopoverViewController(items: items, visibility: 5), edge: .maxY, inset: NSMakePoint(-(control.frame.width/2), -30))
            
        }, for: .Click)
        
        daySelector.set(handler: { [weak self] control in
            
            guard let item = self?.item as? InputDataDateRowItem else {return}
            
            
            var items: [SPopoverItem] = []
            
            let formatter:DateFormatter = DateFormatter()
            formatter.locale = Locale(identifier: appAppearance.language.languageCode)
            
            switch item.value {
            case let .date(_, month, year):
                formatter.dateFormat = "dd.MM.yyyy"
                let _month = month ?? 1
                let _year = year ?? 1970
                let date = formatter.date(from: "02.\(_month < 10 ? "0\(_month)" : "\(_month)").\(_year)")
                if let date = date {
                    for day in 1 ... Int32(CalendarUtils.lastDay(ofTheMonth: date)) {
                        items.append(SPopoverItem("\(day < 10 ? "0\(day)" : "\(day)")", {
                            item._value = .date(day, month, year)
                            item.redraw()
                        }))
                    }
                }
                
            default:
                break
            }
            
            
            
            showPopover(for: control, with: SPopoverViewController(items: items, visibility: 5), edge: .maxY, inset: NSMakePoint(-(control.frame.width/2), -30))
            
            }, for: .Click)
        
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        guard let item = item as? InputDataDateRowItem else {return}
        
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(item.inset.left, frame.height - .borderSize, frame.width - item.inset.left - item.inset.right, .borderSize))
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? InputDataDateRowItem else {return}
        placeholderTextView.setFrameOrigin(item.inset.left, 14)
        
        let defaultLeftInset = item.inset.left + 106
        
        dayPlaceholder.setFrameOrigin(defaultLeftInset, 14)
        daySelector.setFrameOrigin(dayPlaceholder.frame.maxX + 3, dayPlaceholder.frame.minY - 3)
        
        monthPlaceholder.setFrameOrigin(defaultLeftInset, dayPlaceholder.frame.maxY + 5)
        monthSelector.setFrameOrigin(monthPlaceholder.frame.maxX + 3, monthPlaceholder.frame.minY - 3)
        
        yearPlaceholder.setFrameOrigin(defaultLeftInset, monthPlaceholder.frame.maxY + 5)
        yearSelector.setFrameOrigin(yearPlaceholder.frame.maxX + 3, yearPlaceholder.frame.minY - 3)
    }
    
    override func shakeView() {
        guard let item = item as? InputDataDateRowItem else {return}

        switch item.value {
        case let .date(day, month, year):
            if day == nil {
                daySelector.shake()
            }
            if month == nil {
                monthSelector.shake()
            }
            if year == nil {
                yearSelector.shake()
            }
        default:
            break
        }
        
        
    }
    
    override func updateColors() {
        placeholderTextView.backgroundColor = theme.colors.background
        dayPlaceholder.backgroundColor = theme.colors.background
        monthPlaceholder.backgroundColor = theme.colors.background
        yearPlaceholder.backgroundColor = theme.colors.background
        
       
        
        daySelector.set(color: theme.colors.blueText, for: .Normal)
        monthSelector.set(color: theme.colors.blueText, for: .Normal)
        yearSelector.set(color: theme.colors.blueText, for: .Normal)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? InputDataDateRowItem else {return}
        placeholderTextView.update(item.placeholderLayout)
        
        switch item.value {
        case let .date(day, month, year):
            if let day = day {
                daySelector.set(text: "\(day < 10 ? "0\(day)" : "\(day)")", for: .Normal)
            } else {
                daySelector.set(text: "-", for: .Normal)
            }
            
            if let month = month {
                let formatter:DateFormatter = DateFormatter()
                formatter.locale = Locale(identifier: appAppearance.language.languageCode)
                formatter.dateFormat = "MMMM"
                let monthString:String = formatter.string(from: CalendarUtils.stepMonth(Int(month - 1), date: Date(timeIntervalSince1970: 0)))
                monthSelector.set(text: monthString, for: .Normal)
            } else {
                monthSelector.set(text: "-", for: .Normal)
            }
            
            if let year = year {
                yearSelector.set(text: "\(year)", for: .Normal)
            } else {
                yearSelector.set(text: "-", for: .Normal)
            }
            
            break
        default:
            break
        }
       
        _ = daySelector.sizeToFit(NSMakeSize(0, 8))
        _ = monthSelector.sizeToFit(NSMakeSize(0, 8))
        _ = yearSelector.sizeToFit(NSMakeSize(0, 8))

        dayPlaceholder.update(item.dayHolderLayout)
        monthPlaceholder.update(item.monthHolderLayout)
        yearPlaceholder.update(item.yearHolderLayout)
        
        
        needsLayout = true
        needsDisplay = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
