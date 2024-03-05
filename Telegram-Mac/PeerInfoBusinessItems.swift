//
//  PeerInfoLocationRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 20.02.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import TGUIKit


private func dayBusinessHoursText(_ day: TelegramBusinessHours.WeekDay, offsetMinutes: Int) -> String {
    var businessHoursText: String = ""
    switch day {
    case .open:
        businessHoursText += strings().peerInfoBusinessHoursOpens24Hours
    case .closed:
        businessHoursText += strings().peerInfoBusinessHoursClosed
    case let .intervals(intervals):
        func clipMinutes(_ value: Int) -> Int {
            return value % (24 * 60)
        }
        
        var resultText: String = ""
        for range in intervals {
            let range = TelegramBusinessHours.WorkingTimeInterval(startMinute: range.startMinute + offsetMinutes, endMinute: range.endMinute + offsetMinutes)
            
            if !resultText.isEmpty {
                resultText.append("\n")
            }
            let startHours = clipMinutes(range.startMinute) / 60
            let startMinutes = clipMinutes(range.startMinute) % 60
            let startText = stringForShortTimestamp(hours: Int32(startHours), minutes: Int32(startMinutes))
            let endHours = clipMinutes(range.endMinute) / 60
            let endMinutes = clipMinutes(range.endMinute) % 60
            let endText = stringForShortTimestamp(hours: Int32(endHours), minutes: Int32(endMinutes))
            resultText.append("\(startText) - \(endText)")
        }
        businessHoursText += resultText
    }
    
    return businessHoursText
}



final class PeerInfoLocationRowItem : GeneralRowItem {
    
   
    let context: AccountContext
    let peer: Peer
    let location: TelegramBusinessLocation
    let addressLayout: TextViewLayout
    let titleLayout: TextViewLayout
    let arguments: TransformImageArguments?
    let media: TelegramMediaImage?
    let resource: MapSnapshotMediaResource?
    let open:()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, peer: Peer, location: TelegramBusinessLocation, viewType: GeneralViewType, open:@escaping()->Void) {
        self.context = context
        self.peer = peer
        self.open = open
        self.location = location
        self.titleLayout = .init(.initialize(string: strings().peerInfoBusinessLocation, color: theme.colors.text, font: .normal(.text)))
        self.addressLayout = .init(.initialize(string: location.address, color: theme.colors.text, font: .normal(.text)))
        
        if let coordinates = location.coordinates {
            let resource = MapSnapshotMediaResource(latitude: coordinates.latitude, longitude: coordinates.longitude, width: 320 * 2, height: 120 * 2, zoom: 15)

            self.resource = resource
            
            let imageSize = NSMakeSize(50, 50)
            
            let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(imageSize), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)
            
            self.media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: MediaId.Id((resource.latitude * resource.longitude).hashValue)), representations: [representation], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
            
            self.arguments = TransformImageArguments(corners: ImageCorners(radius: 8), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: NSEdgeInsets())
        } else {
            self.resource = nil
            self.media = nil
            self.arguments = nil
        }

        
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        var textWidth: CGFloat = blockWidth
        textWidth -= viewType.innerInset.left * 2
        if resource != nil {
            textWidth -= 50
            textWidth -= 10
        }
        titleLayout.measure(width: textWidth)
        addressLayout.measure(width: textWidth)
        
        return true
    }
    
    override var height: CGFloat {
        return max(viewType.innerInset.top * 2 + 50, viewType.innerInset.top * 2 + titleLayout.layoutSize.height + 6 + addressLayout.layoutSize.height)
    }
    
    override func viewClass() -> AnyClass {
        return PeerInfoLocationRowView.self
    }
}

private final class PeerInfoLocationRowView: GeneralContainableRowView {
    private let title = TextView()
    private let text = TextView()
    private let imageView = TransformImageView()
    private let pinView = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(title)
        addSubview(text)
        addSubview(imageView)
        imageView.addSubview(pinView)
        imageView.setFrameSize(NSMakeSize(50, 50))
        
        imageView.layer?.cornerRadius = 4
        
        title.userInteractionEnabled = false
        title.isSelectable = false
        
        
        
        containerView.set(handler: { [weak self] _ in
            if let item = self?.item as? PeerInfoLocationRowItem {
                item.open()
            }
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PeerInfoLocationRowItem else {
            return
        }

        pinView.image = theme.icons.locationPin
        pinView.setFrameSize(NSMakeSize(25, 25))
        
        
        if let arguments = item.arguments, let media = item.media, let resource = item.resource {
            imageView.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: backingScaleFactor, positionFlags: nil), clearInstantly: false)
            
            imageView.setSignal( chatMapSnapshotImage(account: item.context.account, resource: resource), clearInstantly: false, animate: false, cacheImage: { result in
                cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale, positionFlags: nil)
            })
            
            imageView.set(arguments: arguments)
            imageView.isHidden = false
        } else {
            imageView.isHidden = true
        }
        
        title.update(item.titleLayout)
        text.update(item.addressLayout)
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        guard let item = item as? GeneralRowItem else {
            return
        }
        
        transition.updateFrame(view: title, frame: NSMakeRect(item.viewType.innerInset.left, item.viewType.innerInset.top, title.frame.width, title.frame.height))
        
        transition.updateFrame(view: text, frame: NSMakeRect(item.viewType.innerInset.left, title.frame.maxY + 6, text.frame.width, text.frame.height))
        
        transition.updateFrame(view: imageView, frame: imageView.centerFrameY(x: containerView.frame.width - imageView.frame.width - item.viewType.innerInset.right))
        
        transition.updateFrame(view: pinView, frame: pinView.centerFrame())

    }
}



final class PeerInfoHoursRowItem : GeneralRowItem {
    
    struct Day {
        let day: TextViewLayout
        let hours: [TextViewLayout]
        init(day: String, hours: String) {
            self.day = .init(.initialize(string: day, color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1)
            var list:[TextViewLayout] = []
            let hours = hours.components(separatedBy: "\n")
            for hour in hours {
                list.append(.init(.initialize(string: hour, color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1))
            }
            self.hours = list
        }
        
        var height: CGFloat {
            return max(30, CGFloat(hours.count) * 20 + 10)
        }
    }
    
    let days:[Day]
    let context: AccountContext
    let peer: Peer
    let businessHours: TelegramBusinessHours
    let titleLayout: TextViewLayout
    let statusLayout: TextViewLayout
    let todayHoursLayout: TextViewLayout
    let revealed: Bool
    let open:()->Void
    let displayZoneText: TextViewLayout?
    let toggleDisplayZoneTime:()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, revealed: Bool, peer: Peer, businessHours: TelegramBusinessHours, displayLocalTimezone: Bool, viewType: GeneralViewType, open:@escaping()->Void, toggleDisplayZoneTime:@escaping()->Void) {
        self.context = context
        self.peer = peer
        self.open = open
        self.businessHours = businessHours
        self.revealed = revealed
        self.toggleDisplayZoneTime = toggleDisplayZoneTime
        
        var currentCalendar = Calendar(identifier: .gregorian)
        currentCalendar.timeZone = TimeZone(identifier: businessHours.timezoneId) ?? TimeZone.current
        let currentDate = Date()
        var currentDayIndex = currentCalendar.component(.weekday, from: currentDate)
        if currentDayIndex == 1 {
            currentDayIndex = 6
        } else {
            currentDayIndex -= 2
        }
        
        let currentMinute = currentCalendar.component(.minute, from: currentDate)
        let currentHour = currentCalendar.component(.hour, from: currentDate)
        let currentWeekMinute = currentDayIndex * 24 * 60 + currentHour * 60 + currentMinute
        
        var timezoneOffsetMinutes: Int = 0
        if displayLocalTimezone {
            timezoneOffsetMinutes = (TimeZone.current.secondsFromGMT() - currentCalendar.timeZone.secondsFromGMT()) / 60
        }
        
        if abs(TimeZone.current.secondsFromGMT() - currentCalendar.timeZone.secondsFromGMT()) > 0 {
            displayZoneText = .init(.initialize(string: displayLocalTimezone ? strings().peerInfoBusinessHoursLocal : strings().peerInfoBusinessHoursMy, color: theme.colors.accent, font: .normal(.small)), maximumNumberOfLines: 1, alignment: .center)
            displayZoneText?.measure(width: .greatestFiniteMagnitude)
        } else {
            displayZoneText = nil
        }

        let businessDays = businessHours.splitIntoWeekDays()
        let weekMinuteSet = businessHours.weekMinuteSet()

        
        var currentDayStatusText = currentDayIndex >= 0 && currentDayIndex < businessDays.count ? dayBusinessHoursText(businessDays[currentDayIndex], offsetMinutes: timezoneOffsetMinutes) : " "

        let isOpen = weekMinuteSet.contains(currentWeekMinute)
        let openStatusText = isOpen ? strings().peerInfoBusinessHoursCurrentOpen : strings().peerInfoBusinessHoursCurrentClosed

        if !isOpen {
            for range in weekMinuteSet.rangeView {
                if range.lowerBound > currentWeekMinute {
                    let openInMinutes = range.lowerBound - currentWeekMinute - timezoneOffsetMinutes
                    if openInMinutes < 60 {
                        currentDayStatusText = strings().peerInfoBusinessHoursCurrentOpenInMinutesCountable(openInMinutes)
                    } else if openInMinutes < 6 * 60 {
                        currentDayStatusText = strings().peerInfoBusinessHoursCurrentOpenInHoursCountable(openInMinutes / 60)
                    } else {
                        let openDate = currentDate.addingTimeInterval(Double(openInMinutes * 60))
                        let openTimestamp = Int32(openDate.timeIntervalSince1970) + Int32(currentCalendar.timeZone.secondsFromGMT() - TimeZone.current.secondsFromGMT())
                        let dateText = stringForRelativeSymbolicTimestamp(relativeTimestamp: openTimestamp, relativeTo: Int32(Date().timeIntervalSince1970))
                        currentDayStatusText = strings().peerInfoBusinessHoursCurrentOpenIn(dateText)
                    }
                    break
                }
            }
        }
        
        self.titleLayout = .init(.initialize(string: strings().peerInfoBusinessHours, color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1)
        self.statusLayout = .init(.initialize(string: openStatusText, color: isOpen ? theme.colors.greenUI : theme.colors.redUI, font: .normal(.text)), maximumNumberOfLines: 1)
        
        self.todayHoursLayout = .init(.initialize(string: currentDayStatusText, color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
        
        var days: [Day] = []
        
        for i in 0 ..< businessDays.count {
            let dayTitleValue: String
            switch i {
            case 0:
                dayTitleValue = strings().weekdayMonday
            case 1:
                dayTitleValue = strings().weekdayTuesday
            case 2:
                dayTitleValue = strings().weekdayWednesday
            case 3:
                dayTitleValue = strings().weekdayThursday
            case 4:
                dayTitleValue = strings().weekdayFriday
            case 5:
                dayTitleValue = strings().weekdaySaturday
            case 6:
                dayTitleValue = strings().weekdaySunday
            default:
                dayTitleValue = " "
            }
            let businessHoursText = dayBusinessHoursText(businessDays[i], offsetMinutes: timezoneOffsetMinutes)
            days.append(.init(day: dayTitleValue, hours: businessHoursText))
        }
        
        let pastDays = days.prefix(currentDayIndex)
        days.removeFirst(currentDayIndex)
        days.removeFirst()
        days.append(contentsOf: pastDays)
        
        self.days = days

        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        var textWidth: CGFloat = blockWidth
        textWidth -= viewType.innerInset.left * 2
        titleLayout.measure(width: textWidth)
        statusLayout.measure(width: textWidth)
        todayHoursLayout.measure(width: textWidth - statusLayout.layoutSize.width - 5)
        
        for day in days {
            day.day.measure(width: textWidth)
            for hour in day.hours {
                hour.measure(width: textWidth - day.day.layoutSize.width - 5)
            }
        }
        return true
    }
    
    override var height: CGFloat {
        var height = basicHeight
        if revealed {
            height += days.reduce(0, { $0 + $1.height })
            height += viewType.innerInset.top
        }
        return height

    }
    
    var basicHeight: CGFloat {
        return viewType.innerInset.top * 2 + titleLayout.layoutSize.height + 6 + statusLayout.layoutSize.height
    }
    
    override func viewClass() -> AnyClass {
        return PeerInfoHoursRowView.self
    }
}

private final class PeerInfoHoursRowView: GeneralContainableRowView {
    
    private class Day: View {
        private let status = TextView()
        private let hours = View()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(status)
            addSubview(hours)
            
            status.userInteractionEnabled = false
            status.isSelectable = false
            
            hours.layer?.masksToBounds = false
            
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(day: PeerInfoHoursRowItem.Day) {
            self.status.update(day.day)
            
            while hours.subviews.count > day.hours.count {
                hours.subviews.last?.removeFromSuperview()
            }
            while hours.subviews.count < day.hours.count {
                let view = TextView()
                hours.addSubview(view)
            }
            
            var y: CGFloat = 0
            var w: CGFloat = 0
            for (i, hour) in day.hours.enumerated() {
                let view = hours.subviews[i] as! TextView
                view.update(hour)
                view.frame = NSMakeRect(0, y, view.frame.width, view.frame.height)
                y += view.frame.height + 4
                w = max(w, view.frame.width)
            }
            hours.setFrameSize(NSMakeSize(w, y))
            
            for hour in hours.subviews {
                hour.setFrameOrigin(hours.frame.width - hour.frame.width, hour.frame.minY)
            }
            needsLayout = true
        }
        
        override func layout() {
            super.layout()
            self.status.setFrameOrigin(NSMakePoint(0, 10))
            self.hours.setFrameOrigin(NSMakePoint(frame.width - hours.frame.width, 10))
        }
    }
    
    private let title = TextView()
    private let status = TextView()
    private let today = TextView()
    private let daysContainer: View = View()
    private var displayZoneView: TextView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(title)
        addSubview(status)
        addSubview(today)
        addSubview(daysContainer)
        title.userInteractionEnabled = false
        title.isSelectable = false
        
        today.userInteractionEnabled = false
        today.isSelectable = false

        status.userInteractionEnabled = false
        status.isSelectable = false
        
        containerView.set(handler: { [weak self] _ in
            if let item = self?.item as? PeerInfoHoursRowItem {
                item.open()
            }
        }, for: .Click)
        
        daysContainer.layer?.masksToBounds = false

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PeerInfoHoursRowItem else {
            return
        }
                
        title.update(item.titleLayout)
        status.update(item.statusLayout)
        today.update(item.todayHoursLayout)
        
        if item.revealed {
            while daysContainer.subviews.count > item.days.count {
                daysContainer.subviews.last?.removeFromSuperview()
            }
            let subviews = daysContainer.subviews
            for subview in subviews {
                if subview.identifier == .init("removed") {
                    subview.removeFromSuperview()
                }
            }
            while daysContainer.subviews.count < item.days.count {
                let view = Day(frame: .zero)
                daysContainer.addSubview(view)
                if animated {
                    view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            
            var y: CGFloat = 0
            for (i, day) in item.days.enumerated() {
                let view = daysContainer.subviews[i] as! Day
                view.update(day: day)
                view.frame = NSMakeRect(0, y, daysContainer.frame.width, day.height)
                y += view.frame.height
            }
            
        } else {
            for subview in daysContainer.subviews {
                performSubviewRemoval(subview, animated: animated)
                subview.identifier = .init("removed")
            }
        }
        
        if let displayZone = item.displayZoneText {
            let current: TextView
            if let view = self.displayZoneView {
                current = view
            } else {
                current = TextView()
                current.isSelectable = false
                addSubview(current)
                self.displayZoneView = current
                
                current.scaleOnClick = true
                
                current.set(handler: { [weak self] _ in
                    if let item = self?.item as? PeerInfoHoursRowItem {
                        item.toggleDisplayZoneTime()
                    }
                }, for: .Click)
            }
            current.update(displayZone)
            current.setFrameSize(NSMakeSize(displayZone.layoutSize.width + 10, displayZone.layoutSize.height + 4))
            current.setFrameOrigin(NSMakePoint(containerView.frame.width - current.frame.width - item.viewType.innerInset.right, item.viewType.innerInset.top))
            current.layer?.cornerRadius = current.frame.height / 2
            current.backgroundColor = theme.colors.accent.withAlphaComponent(0.1)
        } else if let view = displayZoneView {
            performSubviewRemoval(view, animated: animated)
            self.displayZoneView = nil
        }
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        guard let item = item as? PeerInfoHoursRowItem else {
            return
        }
        
        
        
        ContainedViewLayoutTransition.immediate.updateFrame(view: title, frame: NSMakeRect(item.viewType.innerInset.left, item.viewType.innerInset.top, title.frame.width, title.frame.height))
        
        ContainedViewLayoutTransition.immediate.updateFrame(view: status, frame: NSMakeRect(item.viewType.innerInset.left, title.frame.maxY + 6, status.frame.width, status.frame.height))
        
        ContainedViewLayoutTransition.immediate.updateFrame(view: today, frame: NSMakeRect(containerView.frame.width - today.frame.width - item.viewType.innerInset.right, status.frame.minY, today.frame.width, today.frame.height))

        transition.updateFrame(view: daysContainer, frame: NSMakeRect(item.viewType.innerInset.left, item.basicHeight, containerView.frame.width - item.viewType.innerInset.left * 2, 0))

        
        if let displayZoneView {
            transition.updateFrame(view: displayZoneView, frame: CGRect(origin: CGPoint(x: containerView.frame.width - displayZoneView.frame.width - item.viewType.innerInset.right, y: item.viewType.innerInset.top), size: displayZoneView.frame.size))
        }
        
    }
}
