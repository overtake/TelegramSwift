//
//  ScheduledMessageModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07/08/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import TGUIKit


private var dayFormatter: DateFormatter {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: appAppearance.language.languageCode)
    
    dateFormatter.dateFormat = "MMM d, yyyy"
    return dateFormatter
}

private var dayFormatterRelative: DateFormatter {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: appAppearance.language.languageCode)
    
    dateFormatter.dateStyle = .short
    dateFormatter.doesRelativeDateFormatting = true
    return dateFormatter
}

private func formatDay(_ date: Date) -> String {
    if CalendarUtils.isSameDate(date, date: Date(), checkDay: true) {
        return dayFormatterRelative.string(from: date)
    } else {
        return dayFormatter.string(from: date)
    }
}

final class ScheduledMessageModalView : View {
    private let dayPicker: DatePicker<Date>
    private let atView = TextView()
    private let timePicker: DatePicker<Int>
    required init(frame frameRect: NSRect) {
        
        self.dayPicker = DatePicker<Date>(selected: DatePickerOption<Date>(name: formatDay(Date()), value: Date()))
        self.timePicker = DatePicker<Int>(selected: DatePickerOption<Int>(name: "22:00", value: 79200))
        super.init(frame: frameRect)
        self.addSubview(self.dayPicker)
        self.addSubview(self.atView)
        self.addSubview(self.timePicker)
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
    }
    
    override func layout() {
        super.layout()
        self.dayPicker.setFrameSize(NSMakeSize(90, 30))
        self.dayPicker.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ScheduledMessageModalController: ModalViewController {
    private let context: AccountContext
    init(context: AccountContext) {
        self.context = context
        super.init(frame: NSMakeRect(0, 0, 300, 200))
    }
    
    override func viewClass() -> AnyClass {
        return ScheduledMessageModalView.self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.readyOnce()
    }
}
